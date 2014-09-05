#Dart Pub packages dependency finder

This is a command line tool that will help you find all packages in Pub that have a given dependency.

##Usage

This script is written in Dart so you'll need Dart installed. You run it using the following command:

    dart dependency_finder.dart <package_name> [--skip-downloads]
    
Where:

 - `<package_name>` Is the name if the dependency package you are looking for dependents of.
 - `--skip-downloads` This will skip downloading the latest version of all packages. You can use that on subsequent searches to avoid re-dowanloading everything which is slow.

##Example usage

This is an example we'll explain later:

    dart dependency_finder.dart js
    
This will list all packages in Dart Pub that have a dependency on the `package:js` library in Pub. We do that by:

 - Fetching the list of all existing packages
 - Looking for what is their latest version
 - Downloading the latest version of each Pub packages archive
 - Extracting the `pubspec.yaml` file out of all package archives
 - Looking for the `js` dependency

In this particular example the output would be:

    computername:bin username$ dart dependency_finder.dart js
    Listing all packages... 1181 - Done.
    Finding last versions of each packages... 1181/1181 - Done.
    Deleting existing .\pub_packages_dl directory.
    Downloading packages... 1181/1181 - Done.
    Analyzing packages... 1181/1181
    All Done! Found 75 packages with packages:js dependency:
     - add_v1_api-0.1.0
     - aloha-2.0.0
     - dancer-0.4.0+4
     - dartwork-0.1.0
     - diffbot-0.1.1
     - form_elements-1.1.0
     - google_adexchangeseller_v1_api-0.4.9
     - google_adsense_v1_1_api-0.3.8
     - google_adsense_v1_2_api-0.4.9
     - google_adsense_v1_api-0.3.8
     - google_adsensehost_v4_1_api-0.4.9
     - google_analytics_v2_4_api-0.4.9
     - google_analytics_v3_api-0.4.9
     - google_androidpublisher_v1_api-0.4.9
     - google_audit_v1_api-0.4.9
     - google_bigquery_v2_api-0.4.9
     - google_blogger_v2_api-0.4.9
     - google_blogger_v3_api-0.4.9
     - google_books_v1_api-0.4.9
     ...