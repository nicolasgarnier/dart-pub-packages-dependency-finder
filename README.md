#Dart Pub packages dependency finder

This is a command line tool that will help you find all packages in Pub that have a given dependency.

##Usage

This script is written in [Dart](https://www.dartlang.org) so you'll need Dart installed. You run it using the following command:

    dart dependency_finder.dart <package_name> [--skip-downloads]
    
Where:

 - `<package_name>` Is the name if the dependency package you are looking for dependents of.
 - `--skip-downloads` This will skip downloading the latest version of all packages. You can use that on subsequent searches to avoid re-downloading everything (which is the slow part).

##Example usage

This is an example we'll explain later:

    dart dependency_finder.dart js
    
This will list all packages in Dart Pub that have a dependency on the `package:js` library in Pub. We do that by:

 - Fetching the list of all existing packages
 - Looking for what is their latest version
 - Downloading the latest version of each Pub packages archive
 - Extracting the `pubspec.yaml` file out of all package archives
 - Looking for the `js` dependency in the `pubspec.yaml`

In this particular example the output would be:

    computername:bin username$ dart dependency_finder.dart js
    Listing all packages... 1181 - Done.
    Finding last versions of each packages... 1181/1181 - Done.
    Downloading packages... 1181/1181 - Done.
    Analyzing packages... 1181/1181
    All Done! Found 26 packages with packages:js dependency:
     - add_v1_api-0.1.0
     - aloha-2.0.0
     - dancer-0.4.0+4
     - dartwork-0.1.0
     - diffbot-0.1.1
     - form_elements-1.1.0
     - google_adsense_v1_1_api-0.3.8
     - google_adsense_v1_api-0.3.8
     - google_compute_v1beta12_api-0.1.0
     - google_compute_v1beta13_api-0.1.6
     - google_compute_v1beta14_api-0.3.8
     - google_dynamiccreatives_v1_api-0.1.1
     - google_latitude_v1_api-0.3.8
     - google_plus_v1moments_api-0.1.0
     - google_plus_widget-0.0.1
     - haml-0.0.1
     ...

Now lets say you also want to know which packages have a dependency on the `yaml` package you can run the following command:

    dart dependency_finder.dart yaml --skip-downloads

This will be a lot faster than the first run because the script won't download all repos and just start looking into the `pubspec.yaml` files.
Here is what the output would look like:

    computername:bin username$ dart dependency_finder.dart yaml --skip-downloads
    Analyzing packages... 1181/1181
    All Done! Found 25 packages with packages:yaml dependency:
     - activemigration-0.2.2
     - ccompile-0.2.2
     - compiler-0.3.0
     - dart_config-0.5.0
     - docgen-0.9.0
     - FileTeCouch-0.1.0
     - flare-0.3.0
     - force_it-0.3.0
     - package_installer-0.0.2
     - ped-0.0.4
     - peg-0.0.9
     - plugins-1.0.1
     - polymer-0.9.5+2
     - polymer_one_script-0.0.1
     ...