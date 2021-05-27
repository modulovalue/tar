import 'dart:io';
import 'dart:typed_data';

import 'package:tar/constants.dart';
import 'package:tar/entry/impl/entry.dart';
import 'package:tar/entry/interface/entry.dart';
import 'package:tar/header/impl/header.dart';
import 'package:tar/writer.dart';

Future<void> main() async {
  // Generate tar file claiming to have a 7 GB header
  await Stream<TarEntry>.fromIterable([
    TarEntryImpl(
      TarHeaderImpl(
        name: 'PaxHeader',
        mode: 0,
        typeFlag: TypeFlag.xHeader,
        // Note: this is a bad header, this header should be 0.
        size: 1024 * 1024 * 1024 * 7,
      ),
      Stream.value(Uint8List(0)),
    ),
    TarEntryImpl(
      TarHeaderImpl(
        name: 'test.txt',
        mode: 0,
        size: 0,
      ),
      Stream.value(Uint8List(0)),
    ),
  ]).transform(tarWriter).pipe(File('reference/evil_large_header.tar').openWrite());
}
