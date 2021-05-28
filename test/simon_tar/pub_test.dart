import 'dart:cli';
import 'dart:io';

import 'package:tarzan/simon_tar/impl/tar_decoder.dart';

void main() {
  // Simple tests to ensure that we can parse weird tars found on pub.
  //
  // The test cases were found by running an earlier version of this package
  // across all packages and versions found on pub.dev. This package needs to
  // be able to read every package version ever uploaded to pub.
  final onceBroken = [
    'access_settings_menu-0.0.1',
    'pana-0.12.19',
    'RAL-1.28.0',
    'rikulo_commons-0.7.6',
  ].map((name) => File('reference/pub/$name.tar.gz'));

  // ignore: prefer_foreach
  for (final package in onceBroken) {
    _test(package);
  }
  // const rootOfPubMirrorDirectory = "/Volumes/UNTITLED/pub/packages";
  // print("Start");
  // final fromArchive = Directory("/Users/valauskasmodestas/Desktop/archive/test/tests/out/pub")
  //     .listSync()
  //     .map((a) => MapEntry(a.path.split("/").last, a as File)).followedBy(onceBroken);
  // int i = 0;
  // for (final package in Directory(rootOfPubMirrorDirectory).listSync()) {
  //   if (package is Directory) {
  //     i++;
  //     print(i.toString() + " ${package.path}");
  //     () sync* {
  //       final versionDirectory = Directory(package.path + "/versions");
  //       final versions = versionDirectory.listSync(followLinks: false);
  //       for (final version in [versions.last]) {
  //         if (version is File) {
  //           final value = version;
  //           _test(value);
  //         } else {
  //           print("Not a file ${version.path}");
  //         }
  //       }
  //     }()
  //         .toList();
  //   }
  // }
}

final _gzipDecoder = gzip.decoder;

void _test(File file) {
  try {
    final tarStream = file.openRead().transform(_gzipDecoder);
    final reader = TarDecoderImpl(tarStream, disallowTrailingData: true);
    print("    ${file.path}");
    while (waitFor(reader.moveNext())) {}
    // ignore: avoid_catches_without_on_clauses
  } catch (e) {
    print("Failed: ${file.path} $e");
  }
}
