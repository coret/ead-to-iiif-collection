#!/usr/bin/perl

use strict;
use warnings;
use LWP::Simple;
use XML::LibXML;
use JSON;
use Digest::SHA qw(sha256_hex);
use File::Path qw(make_path);

my $baseUrl = $ENV{EAD2IIF_BASE_URL} || die "Required environment variable EAD2IIF_BASE_URL not set";
my $outputDir = $ENV{EAD2IIF_OUTPUT_DIR} || "./output/";
my $cacheDir = $ENV{EAD2IIF_CACHE_DIR} || "./cache/";
my $verbose = $ENV{EAD2IIF_VERBOSE} || 0;
my $sleep = $ENV{EAD2IIF_SLEEP} || 1;

unless (@ARGV) {
  die "Usage: $0 <URL of EAD XML>";
}

process_ead($ARGV[0]);

#######################################################


sub process_ead {
	my($urlEAD)=@_;

	if (! -e $outputDir) {
		make_path($outputDir);
	}

	# Download de XML van de URL
	my $contentsEAD = get_cached($urlEAD);

	# Controleer of het downloaden is gelukt
	unless (defined $contentsEAD) {
		die "Couldn't download $urlEAD\n";
	}

	my $scan_count=0;

	my $parser = XML::LibXML->new();
	my $ead = $parser->parse_string($contentsEAD);

	my $eadid_node = $ead->findnodes('/ead/eadheader/eadid')->[0]; # Get the first eadid node
	my $titleproper_node = $ead->findnodes('/ead/eadheader/filedesc/titlestmt/titleproper')->[0];


	my $collection_metadata;
	$collection_metadata->{url}=$urlEAD;
	$collection_metadata->{archieftoegang} = $eadid_node ? $eadid_node->textContent() : 'No /ead/eadheader/eadid found';
	$collection_metadata->{isil} = $eadid_node ? $eadid_node->getAttribute('mainagencycode') : 'No /ead/eadheader/eadid[@mainagencycode] found';
	$collection_metadata->{id}=$baseUrl.$collection_metadata->{isil}."_".$collection_metadata->{archieftoegang}.".jsonld";
	$collection_metadata->{archieftitel} = $titleproper_node ? $titleproper_node->textContent() : "No /ead/eadheader/filedesc/titlestmt/titleproper found";

	my @items;

	# Zoek naar alle <dao> tags
	my @dao_nodes = $ead->findnodes('//dao[@role="METS"]');

	# Print de informatie over de <dao> tags
	if (@dao_nodes) {

	  foreach my $dao_node (@dao_nodes) {

		my @identifier_unitids = $dao_node->findnodes('../unitid[@identifier]');
		my @handle_unitids = $dao_node->findnodes('../unitid[@type="handle"]');
		my @parent_titles = $dao_node->findnodes('../unittitle'); 

		if (@identifier_unitids) {
			my $inventarisnr=$identifier_unitids[0]->textContent();
			my $label= $inventarisnr." > ".$parent_titles[0]->textContent();
			
			my %registry;
			$registry{id} = $baseUrl.$collection_metadata->{isil}."_".$collection_metadata->{archieftoegang}."_".$inventarisnr.".jsonld";  
			$registry{type}="Manifest";
			$registry{label} = { "nl" => [ $label ] };
			push(@items,\%registry);
				
			my $metadata;
			$metadata->{daourl}=$dao_node->getAttributeNode('href')->getValue();
			$metadata->{baseuri}=$baseUrl.$collection_metadata->{isil}."_".$collection_metadata->{archieftoegang}."_".$inventarisnr;
			$metadata->{titel}=$label;
			$scan_count+=process_mets($metadata);
		}
	  }
	} else {
		die "No <dao role=\"METS\"> tags found in the XML file $urlEAD";
	}

	my $inventory_count=scalar(@items);

	my $collection=create_collection($collection_metadata);
	$collection->{items}=\@items;

	my $collectionFile=$collection->{'id'};
	$collectionFile=~s/$baseUrl/$outputDir/;
	open(FO,">",$collectionFile) || die "Can't write to file $collectionFile: ".$!;
	print FO encode_json($collection);
	close(FO);
	if ($verbose>0) {
		print STDERR "\nWritten collection ".$collection->{'id'}." (".$collection_metadata->{archieftitel}.") to $collectionFile with $inventory_count manifests referencing $scan_count scans in total based on EAD $urlEAD\n";
	}
}


sub create_collection {
	my ($collection_metadata)=@_;
	
	my $collection;
	$collection->{'@context'}="http://iiif.io/api/presentation/3/context.json";
	$collection->{'id'}=$collection_metadata->{id},
	$collection->{'type'}="Collection",
	$collection->{'label'}={ "nl" => [ $collection_metadata->{isil}." ".$collection_metadata->{archieftoegang}." ".$collection_metadata->{archieftitel} ] },
	$collection->{'seeAlso'}= [ {"id" => $collection_metadata->{url},"type"=>"application/xml"}];
	$collection->{'metadata'}= [ 
		{"label" => { "nl" => [ "Archiefinstelling" ] }, "value"=> { "nl" => [ $collection_metadata->{isil} ] } },
		{"label" => { "nl" => [ "Archieftoegang" ] } , "value"=> { "nl" => [ $collection_metadata->{archieftoegang} ] } },
		{"label" => { "nl" => [ "Archieftitel" ] } , "value"=> { "nl" => [ $collection_metadata->{archieftitel} ] } },
	];
  
	return $collection;
}


sub process_mets {
	my ($metadata)=@_;

	my $urlMETS=$metadata->{daourl};
	my $contentsMETS = get_cached($urlMETS) or die "Could not fetch XML from ".$metadata->{daourl};

	# Controleer of het downloaden is gelukt
	unless (defined $contentsMETS) {
		die "Couldn't download $$urlMETS\n";
	}
	
	my $scan_count=0;
	
	my $parser = XML::LibXML->new();
	my $mets = $parser->parse_string($contentsMETS);

	my @display_files;
	my @structmap_items;

	# Register namespace
	my $ns = 'http://www.loc.gov/METS/';
	my $xc = XML::LibXML::XPathContext->new($mets);
	$xc->registerNs('mets', $ns);

	my %display;
	# Extract file elements from <fileGrp USE="DISPLAY">
	foreach my $fileGrp ($xc->findnodes('//mets:fileSec/mets:fileGrp[@USE="DISPLAY"]')) {
		foreach my $file ($xc->findnodes('mets:file', $fileGrp)) {			
			foreach my $locat ($xc->findnodes('mets:FLocat', $file)) {
				$display{$file->getAttribute('ID')}=$locat->getAttribute('xlink:href');
			}
		}
	}

	my ($inventoryguid)=($metadata->{daourl}=~m/([0-9a-f]{8}\-[0-9a-f]{4}\-[0-9a-f]{4}\-[0-9a-f]{4}\-[0-9a-f]{12})/);
	my $inventory;
	$inventory->{id}=$metadata->{baseuri}.".jsonld";  # ."_".$inventoryguid
	$inventory->{title}=$metadata->{titel};
	
	my @items;
	# Extract structMap items
	foreach my $div ($xc->findnodes('//mets:structMap/mets:div/mets:div')) {
		my $file=$div->getAttribute('LABEL');
		$file=~s/\.[a-z09]+$//;

		my($scanid)=($display{$div->getAttribute('ID')."IIP"}=~m/([0-9a-f]{8}\-[0-9a-f]{4}\-[0-9a-f]{4}\-[0-9a-f]{4}\-[0-9a-f]{12})/);
		
		my $infojson=get_info_json($display{$div->getAttribute('ID')."IIP"});
		
		my $scan;
		$scan->{'title'}="TITLE";
		$scan->{'iiifimageuri'}=$display{$div->getAttribute('ID')."IIP"};
		$scan->{'iiifimageuri'}=~s/\/info\.jso[a-z]+$//;
		$scan->{'id'}=$metadata->{baseuri}."/".$inventoryguid."/".$scanid;
		$scan->{'height'}=$infojson->{height};
		$scan->{'width'}=$infojson->{width};
		$scan->{'name'}=$file;
		$scan_count++;
		push(@items,create_canvas($scan));
	}

	my $manifest=create_manifest($inventory,@items);
		
	my $manifestFile=$inventory->{id};
	$manifestFile=~s/$baseUrl/$outputDir/;
	open(FO,">",$manifestFile) || die "Can't write to file $manifestFile: ".$!;
	print FO encode_json($manifest);
	close(FO);
	if ($verbose>0) {
		print STDERR "Written manifest ".$manifest->{'id'}." to $manifestFile which references $scan_count scans\n";
	}
	
	return $scan_count;
}


sub create_manifest {
	my($inventory,@items)=@_;
	
	my $manifest;
	$manifest->{'@context'} = "http://iiif.io/api/presentation/3/context.json";
	$manifest->{'id'} = $inventory->{id};
	$manifest->{'type'} = "Manifest";
	$manifest->{'label'} = { "nl" => [ $inventory->{title} ] };
	$manifest->{'items'} = \@items;

	return $manifest;
}


sub create_canvas {
	my ($scan)=@_;

	my $canvas;
	$canvas->{'id'} = $scan->{id}."/canvas";
	$canvas->{'type'} = 'Canvas';
	$canvas->{'label'} = { "nl" => [ $scan->{name} ]};
	$canvas->{'height'} = $scan->{height}*1;
	$canvas->{'width'} = $scan->{width}*1;
	$canvas->{'items'} = [{ 
							'id' => $scan->{id}."/page",
							'type' => "AnnotationPage",
							'items' => [{
								'id' => $scan->{id}."/annotation",
								'type' => "Annotation",
								'motivation' => "painting",
								'body' => {
									"id" => $scan->{iiifimageuri}."/full/max/0/default.jpg",
									"type" => "Image",
									"format" => "image/jpeg",
									"service" => [{
										"id" => $scan->{iiifimageuri},
										"profile" => "level1",
										"type" => "ImageService2"	# National Archives only supports IIIF Image API v2
									  }]
								},
								'target' => $scan->{id}."/canvas"
							}]
						}];

	return $canvas;
}


sub get_info_json {
	my ($url)=@_;

#	Getting the info.json for each files takes forever. As it's only for the required width and height, but the value 0 suffices, retrieving the info.json files is skipped
#	my $infojson=get_cached($url);
#	my $info=decode_json($infojson);

	my $info;
	$info->{height}=1;
	$info->{width}=1;
	return $info;
}


sub get_cached { # be nice to the infrastructure of the archival institution, sleep after each request and cache all requests
	my ($url)=@_;
	
	if (! -e $cacheDir) {
		make_path($cacheDir);
	}
	
	my $cache=$cacheDir.sha256_hex($url);
	if (-e $cache && -s $cache) {
		open my $fh, "<", $cache or die "Cannot open '$cache': $!"; 
		local $/ = undef; # Slurp the whole file
		my $contents = <$fh>;
		close $fh;
		return $contents;
	} else {
		if ($verbose>1) { print STDERR "getting $url\n"; }
		my $contents=get($url); 
		if ($sleep>0) {
			sleep($sleep);
		}
		if ($contents && $contents ne "") {
			open(FO,">",$cache);
			print FO $contents;
			close(FO);
			return $contents;
		} else {
			if ($verbose>0) { print STDERR "WARN: $url has no contents\n"; }
			return "";
		}
	}
}
