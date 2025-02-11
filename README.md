# ead-to-iiif-collection
Convert an online EAD file of the Dutch National Archives to a IIIF Presentation API v3 based collection of manifests per inventory.

## Setup

The harvest and conversion tool has been written in Perl. Perl is commonly pre-installed on many Linux distributions, as it has been a staple scripting language for system administration and web development for decades.

Perl version 5 is required as well as the Perl modules LWP::Simple, XML::LibXML, JSON, Digest::SHA and File::Path. These can be installed via:
```
cpan LWP::Simple XML::LibXML JSON Digest::SHA File::Path
```

Make the file executable:
```
chmod +x ead-to-iiif-collection.pl
```

## Configuration

The configuration of tool is handled via environment variable:

- (required) EAD2IIF_BASE_URL - a base HTTP URL used for the URIs of the IIIF collection and associated IIIF manifests
- (optional) EAD2IIF_OUTPUT_DIR - directory where all files are written to (if the directory does not exist, it's created), default is ./output/
- (optional) EAD2IIF_CACHE_DIR - directory where all harvested xml (EAD and METS) is cached (if the directory does not exist, it's created), default is ./cache/
- (optional) EAD2IIF_VERBOSE - level of information printed to STDERR: 0 = silent (default), 1 = status info, 2 = process info
- (optional) EAD2IIF_SLEEP - number of seconds to wait after an HTTP request (defaults to 1, be friendly)

Example configuration:
```
export EAD2IIF_BASE_URL="https://www.goudatijdmachine.nl/omeka/files/ead2iiif/"
export EAD2IIF_VERBOSE=2
```

## Usage

Find the URL of an online EAD XML on the website of the Dutch National Archive under the link `Download inventaris als XML`. Give this URL as parameter to the tool:
```
./ead-to-iiif-collection.pl <URL>
```

#@ Output example

When run on the EAD of the (3.19.10 Inventaris van het archief van de Graven van Blois, 1304-1397)[https://www.nationaalarchief.nl/onderzoeken/archief/3.19.10] via `./ead-to-iiif-collection.pl https://www.nationaalarchief.nl/onderzoeken/archief/3.19.10/download/xml` the generated IIIF collection is
https://www.goudatijdmachine.nl/omeka/files/ead2iiif/NL-HaNA_3.19.10.jsonld  This IIIF collection (and associated manifest files per inventory item) can be easy visually checked by using the IIIF viewer Theseus, in this example https://theseusviewer.org/?iiif-content=https://www.goudatijdmachine.nl/omeka/files/ead2iiif/NL-HaNA_3.19.10.jsonld
