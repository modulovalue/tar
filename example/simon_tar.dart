import 'dart:convert';
import 'dart:io';

import 'package:tarzan/simon_tar/impl/entry.dart';
import 'package:tarzan/simon_tar/impl/header.dart';
import 'package:tarzan/simon_tar/impl/tar_decoder.dart';
import 'package:tarzan/simon_tar/impl/tar_encoder.dart';
import 'package:tarzan/simon_tar/interface/entry.dart';
import 'package:tarzan/simon_tar/interface/flags.dart';
import 'package:tarzan/simon_tar/interface/tar_encoder.dart';

Future<void> main() async {
  // Start reading a tar file
  final reader = TarDecoderImpl(File('reference/gnu.tar').openRead());
  while (await reader.moveNext()) {
    final header = reader.current.header;
    print(header.name + ": ");
    // Print the output if it's a regular file
    if (header.typeFlag == TypeFlags.reg) {
      await reader.current.contents.transform(utf8.decoder).forEach(print);
    }
  }
  // We can write tar files to any stream sink like this:
  final output = File('test.tar').openWrite();
  final data = utf8.encode('Hello world');
  await Stream<TarEntry>.value(
    TarEntryImpl(
      TarHeaderImpl(
        name: 'hello_dart.txt',
        mode: int.parse('644', radix: 8),
        userName: 'Dart',
        groupName: 'Dartgroup',
        size: data.length,
      ),
      Stream.value(data),
    ),
  )
      // transform tar entries back to a byte stream
      .transform(const TarEncoderTransformerImpl(OutputFormat.pax))
      // and then write that to the file
      .pipe(output);
}
