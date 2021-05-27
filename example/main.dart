import 'dart:convert';
import 'dart:io';

import 'package:tar/constants.dart';
import 'package:tar/entry/impl/entry.dart';
import 'package:tar/entry/interface/entry.dart';
import 'package:tar/header/impl/header.dart';
import 'package:tar/reader.dart';
import 'package:tar/writer.dart';

Future<void> main() async {
  // Start reading a tar file
  final reader = TarReader(File('reference/gnu.tar').openRead());
  while (await reader.moveNext()) {
    final header = reader.current.header;
    print('${header.name}: ');
    // Print the output if it's a regular file
    if (header.typeFlag == TypeFlag.reg) {
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
      .transform(tarWriter)
      // and then write that to the file
      .pipe(output);
}
