import 'dart:io';
import 'dart:typed_data';

import 'package:tarzan/simon_tar/impl/entry.dart';
import 'package:tarzan/simon_tar/impl/header.dart';
import 'package:tarzan/simon_tar/impl/tar_encoder.dart';
import 'package:tarzan/simon_tar/interface/entry.dart';
import 'package:tarzan/simon_tar/interface/flags.dart';
import 'package:tarzan/simon_tar/interface/tar_encoder.dart';

Future<void> main() async {
  // Generate tar file claiming to have a 7 GB header
  await Stream<TarEntry>.fromIterable(
    [
      TarEntryImpl(
        TarHeaderImpl(
          name: 'PaxHeader',
          mode: 0,
          typeFlag: TypeFlags.xHeader,
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
    ],
  ) //
      .transform(const TarEncoderTransformerImpl(OutputFormat.pax))
      .pipe(File('reference/headers/evil_large_header.tar').openWrite());
}
