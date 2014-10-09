///Copyright 2014 Google Inc. All rights reserved.
///
///Licensed under the Apache License, Version 2.0 (the "License");
///you may not use this file except in compliance with the License.
///You may obtain a copy of the License at
///
///    http://www.apache.org/licenses/LICENSE-2.0
///
///Unless required by applicable law or agreed to in writing, software
///distributed under the License is distributed on an "AS IS" BASIS,
///WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
///See the License for the specific language governing permissions and
///limitations under the License

import 'package:http/http.dart';
import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:yaml/yaml.dart';

// Template of the URL to fetch the list fo existing packages in Pub.
final String packagesListUrlTemplate = "https://pub.dartlang.org/packages.json?page={pageIndex}";
// Folder name where the packages will be dowloaded and extracted.
final String packageDownloadFolder = "pub_packages_dl";
// Template of the URL to download the package archives.
final String packageDownloadTemplate = "https://storage.googleapis.com/pub.dartlang.org/packages/{name}-{version}.tar.gz";

// List of all packages where we found the given dependency.
List<String> packagesWithDependency = new List<String>();
// Errors encountered during the analysis of packages.
List<String> errors = new List<String>();
// Name of the package dependency to look for.
String packageDependencyToFind;
// The list of all URLs of description files for all existing packages in pub.
List<String> packagesDescriptionFileUrls = new List<String>();
// Maps of last versions of package names.
Map<String, String> packagesVersions = new Map<String, String>();


/**
 * This is a comand line script that will download the latest version of all packages in pub and
 * check if they have the given dependency.
 * Usage: dart dependency_finder.dart <package_name> [--skip-downloads]
 *
 * <package_name>: name of the package dependency we'll look for in the pubspec.yaml files.
 * --skip-downloads: if you already have downloaded all packages (which is the slow part) this will
 *                   jump directly to the extraction/analysis process.
 */
void main(List<String> args) {

  // If no arguments were pased we display a help message.
  if (args.length == 0) {
    stdout.writeln("This script will download the latest version of all packages in pub and check if they have the given dependency.");
    stdout.writeln("Usage: dart dependency_finder.dart <package_name> [--skip-downloads]");
    return;
  }

  // Extracing first arg.
  stdout.write("Listing all packages... ");
  packageDependencyToFind = args[0];

  // We ump to step 4 if --skip-downloads is used. Otherwise Step 1.
  if (args.contains("--skip-downloads")) {
    _analyzeNextPackage();
  }else {
    _getPackages();
  }
}

// Step 1 - We get the list of all packages description files.
void _getPackages({int packagesListIndex : 1}) {

  // Download and readsn the next page of list of packages.
  String url = packagesListUrlTemplate.replaceFirst("{pageIndex}", "$packagesListIndex");
  get(url).then((Response response) {

    // Handle download errors.
    if (response.statusCode < 200 || response.statusCode > 299) {
      stderr.writeln("\nError reading URL $url: Exit with status code: ${response.statusCode} - reason: ${response.reasonPhrase}");
      return;
    }

    // Reads the content of the fil as JSON to extract the list of packages descriptors.
    var json = JSON.decode(response.body);
    packagesDescriptionFileUrls.addAll(json["packages"]);
    stdout.write("\rListing all packages... ${packagesDescriptionFileUrls.length}");

    // Move on to downloading the next page of packages listing.
    if (json["packages"].length != 0 && json["next"] != null) {
      _getPackages(packagesListIndex: packagesListIndex + 1);

    // We reached the last page so we move on to the next step.
    } else {
      stdout.writeln(" - Done.");
      stdout.write("Finding last versions of each packages... 0/${packagesDescriptionFileUrls.length}");
      _getNextPackageVersions();
    }

  // Handle download errors.
  }).catchError((error){
    stderr.write("\nError while reading URL $url: $error\n");
    return true;
  });
}

// Step 2 - For each package we fetch what is their last version.
void _getNextPackageVersions() {

  // If we are done reading all package description files.
  if (packagesDescriptionFileUrls.isEmpty) {
    stdout.writeln(" - Done.");

    // Delete potentially existing repo and creating empty new one
    Directory existingDir = new Directory(packageDownloadFolder);
    if (existingDir.existsSync()) {
      stdout.writeln("Deleting existing .\\$packageDownloadFolder directory.");
      existingDir.deleteSync(recursive: true);
    }
    new Directory(packageDownloadFolder).createSync();

    // Start the download of all packages.
    stdout.write("Downloading packages... 0/${packagesVersions.length}");
    _downloadNextPackage();
    return;
  }

  // Download and read the next package description file to find the latest version of the package.
  String packageDescrUrl = packagesDescriptionFileUrls.removeLast();
  get(packageDescrUrl).then((Response response) {

    // Handle download errors.
    if (response.statusCode < 200 && response.statusCode > 299) {
      stderr.writeln("\nError reading URL $packageDescrUrl: Exit with status code: ${response.statusCode} - reason: ${response.reasonPhrase}");
      _getNextPackageVersions();
      return;
    }

    // Extract last version from JSON body.
    var json = JSON.decode(response.body);
    List<String> versions = json["versions"];
    String lastVersion = versions.reduce((String s1, String s2) {
        Version v1 = Semver.parseString(s1);
        Version v2 = Semver.parseString(s2);
        return Semver.returnGreater(v1, v2).toString();
    });
    lastVersion = Semver.parseString(lastVersion).toString(); // In case there was only 1 version we still make it go through the Semver parser to clean it up.

    // Save last version in Map and move to next package.
    String name = json["name"];
    packagesVersions[name] = lastVersion;
    stdout.write("\rFinding last versions of each packages... ${packagesVersions.length}/${packagesDescriptionFileUrls.length + packagesVersions.length}");
    _getNextPackageVersions();

  // Handle download errors
  }).catchError((error){
    stderr.writeln("\nError while reading URL $packageDescrUrl: $error");
    _getNextPackageVersions();
    return true;
  });
}

/**
 * Describes a Dart Pub version and provides some helper classes.
 **/
class Semver {
  // All the attributes can either be int or String.
  var top = 0;
  var mid = 0;
  var last = 0;
  var minus = "";
  var plus = "";

  // Parses a String as a Semver. e.g. 1.3.1-dev+3
  static Semver parseString(String s) {
    Semver v = new Semver();

    String prefix;

    // First extract potential + and - parts.
    List<String> bumpSplit = s.split("-");
    if (bumpSplit.length == 1){
      bumpSplit = s.split("+");
      prefix = bumpSplit[0];
      if (bumpSplit.length == 2) {
        try {
          v.plus = int.parse(bumpSplit[1]);
        } catch(_) {
          v.plus = bumpSplit[1];
        }
      }
    } else {
      prefix = bumpSplit[0];
      List<String> plusSplit = bumpSplit[1].split("+");
      v.minus = plusSplit[0];
      if (plusSplit.length>1) {
        try{
          v.plus = int.parse(plusSplit[1]);
        } catch(_) {
          v.plus = plusSplit[1];
        }
      }
    }

    // Parsing the main version section z.y.z
    List<String> versionSplit = new List<String>();
    versionSplit = prefix.split(".");
    try {
      v.top = int.parse(versionSplit[0]);
    } catch(_) {
      v.top = versionSplit[0];
    }
    try {
      v.mid = int.parse(versionSplit[1]);
    } catch(_) {
      v.mid = versionSplit[1];
    }
    try {
      v.last = int.parse(versionSplit[2]);
    } catch(_) {
      v.last = versionSplit[2];
    }

    return v;
  }

  // Returns a String representation of the Semver
  String toString() {
    String plusStr = "";
    String minusStr = "";

    if (plus != "") {
      plusStr = "+${plus}";
    }

    if (minus != "") {
      minusStr = "-${minus}";
    }

    return "$top.$mid.$last$minusStr$plusStr";
  }

  // Returns the greater semver of the two.
  static Semver returnGreater(Semver v1, Semver v2){
    if (v2.top > v1.top) return v2;
    if (v2.top < v1.top) return v1;

    if (v2.mid > v1.mid) return v2;
    if (v2.mid < v1.mid) return v1;

    if(v2.last is String || v1.last is String) {
      if ("${v2.last}".compareTo("${v1.last}") > 0) return v2;
      if ("${v2.last}".compareTo("${v1.last}") < 0) return v1;
    } else {
      if (v2.last > v1.last) return v2;
      if (v2.last < v1.last) return v1;
    }

    if(v2.minus is String || v1.minus is String) {
      if ("${v2.minus}".compareTo("${v1.minus}") > 0) return v2;
      if ("${v2.minus}".compareTo("${v1.minus}") < 0) return v1;
    } else {
      if (v2.minus > v1.minus) return v2;
      if (v2.minus < v1.minus) return v1;
    }

    if(v2.plus is String || v1.plus is String) {
      if ("${v2.plus}".compareTo("${v1.plus}") > 0) return v2;
      if ("${v2.plus}".compareTo("${v1.plus}") < 0) return v1;
    } else {
      if (v2.plus > v1.plus) return v2;
      if (v2.plus < v1.plus) return v1;
    }

    return v1;
  }
}

// Step 3 - We download each packages archives.
void _downloadNextPackage() {
  Iterable<String> packageNames = packagesVersions.keys;

  // If we are done downloading all packages archives.
  if (packageNames.isEmpty) {
    stdout.write(" - Done.\n");

    // Start extacting and analyzing all packages
    stdout.write("Analyzing packages... 0/${new Directory(packageDownloadFolder).listSync().length}");
    _analyzeNextPackage();
    return;
  }

  // Download the next package archive in the queue.
  String packageName = packageNames.first;
  String packageVersion = packagesVersions[packageName];
  packagesVersions.remove(packageName);
  String packageUrl = packageDownloadTemplate.replaceFirst("{name}", packageName).replaceFirst("{version}", packageVersion);
  get(packageUrl).then((response) {

    // Handle download errors.
    if (response.statusCode < 200 && response.statusCode > 299) {
      stderr.writeln("\nError reading URL $packageUrl: Exit with status code: ${response.statusCode} - reason: ${response.reasonPhrase}");
      _downloadNextPackage();
      return;
    }

    // Write the output to a file in the [packageDownloadFolder] folder and move to download next file.
    new File("$packageDownloadFolder/$packageName-$packageVersion.tar.gz")..createSync()..writeAsBytes(response.bodyBytes).whenComplete((){
      int downloadedPackages = new Directory(packageDownloadFolder).listSync().length;
      stdout.write("\rDownloading packages... $downloadedPackages/${packagesVersions.length + downloadedPackages}");
      _downloadNextPackage();

    // Handle file creation/write errors
    }).catchError((error){
      stderr.writeln("\nError while writig to file $packageDownloadFolder/$packageName-$packageVersion.tar.gz: $error");
      _downloadNextPackage();
      return true;
    });

  // Handle download errors
  }).catchError((error){
    stderr.writeln("\nError while reading URL $packageUrl: $error");
    _downloadNextPackage();
    return true;
  });
}

// Step 4 - Extracting the pubspec.yaml fro the packages files
void _analyzeNextPackage({Iterator<FileSystemEntity> iter, int index : 1}) {
  // Initializaion if this is first iteration.
  List<FileSystemEntity> tars = new Directory(packageDownloadFolder).listSync();
  if (iter == null) {
    iter = tars.iterator;
  }

  // If we are done extracting and analysing all packages.
  if(!iter.moveNext()) {

    // No packages found
    if(packagesWithDependency.length == 0) {
      stdout.writeln("\nAll Done! No packages with package:$packageDependencyToFind dependency found!");

    // Packages with the searched for dependency found.
    } else {
      stdout.writeln("\nAll Done! Found ${packagesWithDependency.length} packages with packages:$packageDependencyToFind dependency:");
      packagesWithDependency.forEach((String path) {
        stdout.writeln(" - $path");
      });
    }

    // Dispay errors encountered during analyze.
    if(errors.length != 0) {
      stdout.writeln("\nThere was also ${errors.length} errors while analyzing packages:");
      errors.forEach((String path) {
        stdout.writeln(" - $path");
      });
    }
    return;
  }

  // Extract and Analyze the next ackage archive.
  FileSystemEntity file = iter.current;
  extractPubSpecFromTarGz(file.path).then((String yaml){

    // Error in case pubspec.yaml content returned as empty or null.
    if (yaml == null || yaml == "") {
      errors.add("${file.path}/pubspec.yaml is empty or null.");
      _analyzeNextPackage(iter: iter, index: index + 1);
      return;
    }

    // Parse the pubspec.yaml as Yaml content.
    var pubspecYaml;
    try {
      pubspecYaml = loadYaml(yaml);
    } catch (error) {
      errors.add("Problem parsing Yaml file of ${file.path}/pubspec.yaml: $error");
      _analyzeNextPackage(iter: iter, index: index + 1);
      return;
    }

    // Look for the searched for dependency in the pubspec.yaml's dependecies
    if(pubspecYaml["dependencies"] != null && pubspecYaml["dependencies"][packageDependencyToFind] != null) {
      packagesWithDependency.add(file.path.replaceFirst("$packageDownloadFolder/", "").replaceFirst(".tar.gz", ""));
    }

    // Move on to analyzing the next package.
    stdout.write("\rAnalyzing packages... $index/${tars.length}");
    _analyzeNextPackage(iter: iter, index: index + 1);

  // Handle Extraction errors.
  }).catchError((error){
    errors.add("There was an error extracting ${file.path}: $error");
    _analyzeNextPackage(iter: iter, index: index + 1);
    return true;
  });
}

/**
 * Extracts the pubspec.yaml file as a [String] from the targz file located at [filePath].
 */
Future<String> extractPubSpecFromTarGz(String filePath) {
  var completer = new Completer<String>();

  // Run tar from command line.
  var processFuture = Process.run("tar",
      ["--extract", "--gunzip", "--file", filePath, "--to-stdout", "pubspec.yaml"]);
  processFuture.then((ProcessResult result) {
    completer.complete(result.stdout);
  }).catchError((error) {
    completer.completeError(error);
    return true;
  });

  return completer.future;
}