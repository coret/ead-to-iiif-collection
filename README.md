# ead-to-iiif-collection
Convert an online EAD file to a IIIF Presentation API v3 based collection of manifests per inventory. This tool is tailored (and tested) with the online EAD files of the Dutch National Archives which contain links to the METS API of the National Archives and of course the IIIF Image v2 API proviced by the National Archives.
The resulting IIIF collection files can be viewed in a IIIF viewer or used as input for a HTR pipeline.

## Setup

This harvest and conversion tool has been written in Perl. Perl is commonly pre-installed on many Linux distributions, as it has been a staple scripting language for system administration and web development for decades.

Perl version 5 is required as well as the Perl modules LWP::Simple, XML::LibXML, JSON, Digest::SHA and File::Path. These can be installed via:
```
cpan LWP::Simple XML::LibXML JSON Digest::SHA File::Path
```

Make the file executable:
```
chmod +x ead-to-iiif-collection.pl
```

## Configuration

The configuration of the tool is handled via environment variables:

- (required) EAD2IIF_BASE_URL - a base HTTP URI used for the URIs of the IIIF collection and associated IIIF manifests
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

## Example run

When run on the EAD of the [3.01.27.07](https://www.nationaalarchief.nl/onderzoeken/archief/3.01.27.07)  _Inventaris van de charters, behorende tot het archief van de Grafelijkheidsrekenkamer van Holland_ archive via: 
```
./ead-to-iiif-collection.pl https://www.nationaalarchief.nl/onderzoeken/archief/3.01.27.07/download/xml
```

The verbose output reads:
```
Written manifest https://www.goudatijdmachine.nl/omeka/files/ead2iiif/NL-HaNA_3.01.27.07_720CHA2.1.jsonld to ./output/NL-HaNA_3.01.27.07_720CHA2.1.jsonld which references 2 scans
Written manifest https://www.goudatijdmachine.nl/omeka/files/ead2iiif/NL-HaNA_3.01.27.07_720CHA2.2.jsonld to./outpu/NL-HaNA_3.01.27.07_720CHA2.2.jsonld which references 3 scans
...
Written manifest https://www.goudatijdmachine.nl/omeka/files/ead2iiif/NL-HaNA_3.01.27.07_755CHA1.jsonld to ./outpu/NL-HaNA_3.01.27.07_755CHA1.jsonld which references 5 scans
Written manifest https://www.goudatijdmachine.nl/omeka/files/ead2iiif/NL-HaNA_3.01.27.07_755CHA2.jsonld to ./outpu/NL-HaNA_3.01.27.07_755CHA2.jsonld which references 2 scans

Written collection https://www.goudatijdmachine.nl/omeka/files/ead2iiif/NL-HaNA_3.01.27.07.jsonld (Inventaris van de charters, behorende tot het archief van de Grafelijkheidsrekenkamer van Holland) to ./output/NL-HaNA_3.01.27.07.jsonld with 3131 manifests referencing 5967 scans in total based on EAD https://www.nationaalarchief.nl/onderzoeken/archief/3.01.27.07/download/xml
```

When the generated IIIF collection is made available via a webserver, the collection can be easy visually checked by using an IIIF viewer like the [Theseus Viewer](https://theseusviewer.org/).

## Some collection examples

- [3.01.14.jsonld](https://www.goudatijdmachine.nl/omeka/files/ead2iiif/NL-HaNA_3.01.14.jsonld) - _Inventaris van het archief van Johan van Oldenbarnevelt, 1586-1619_ with **205** manifests referencing **833** scans in [Theseus Viewer](https://theseusviewer.org/?iiif-content=https://www.goudatijdmachine.nl/omeka/files/ead2iiif/NL-HaNA_3.01.14.jsonld)
- [3.01.17.jsonld](https://www.goudatijdmachine.nl/omeka/files/ead2iiif/NL-HaNA_3.01.17.jsonld) - _Inventaris van het archief van Johan de Witt, raadpensionaris van Holland, 1653-1672_ with **3.677** manifests referencing **141.940** scans in [Theseus Viewer](https://theseusviewer.org/?iiif-content=https://www.goudatijdmachine.nl/omeka/files/ead2iiif/NL-HaNA_3.01.17.jsonld)
- [3.01.27.07.jsonld](https://www.goudatijdmachine.nl/omeka/files/ead2iiif/NL-HaNA_3.01.27.07.jsonld) - _Inventaris van de charters, behorende tot het archief van de Grafelijkheidsrekenkamer van Holland_ with **3.131** manifests referencing **5.967** scans in [Theseus Viewer](https://theseusviewer.org/?iiif-content=https://www.goudatijdmachine.nl/omeka/files/ead2iiif/NL-HaNA_3.01.27.07.jsonld)
- [3.19.10.jsonld](https://www.goudatijdmachine.nl/omeka/files/ead2iiif/NL-HaNA_3.19.10.jsonld) - _Inventaris van het archief van de Graven van Blois, 1304-1397_ with **205** manifests referencing **833** scans in [Theseus Viewer](https://theseusviewer.org/?iiif-content=https://www.goudatijdmachine.nl/omeka/files/ead2iiif/NL-HaNA_3.19.10.jsonld)
