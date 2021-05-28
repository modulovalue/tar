@TestOn('windows')
import 'dart:io';

import 'package:tarzan/simon_tar/impl/entry.dart';
import 'package:tarzan/simon_tar/impl/header.dart';
import 'package:tarzan/simon_tar/impl/tar_encoder.dart';
import 'package:tarzan/simon_tar/interface/entry.dart';
import 'package:tarzan/simon_tar/interface/tar_encoder.dart';
import 'package:test/test.dart';

import 'system_tar.dart';

void main() {
  test('emits long file names that are understood by 7zip', () async {
    final name = 'name' * 40;
    final entry = TarEntryImpl(TarHeaderImpl(name: name, size: 0), Stream.value([]));
    final file = File(Directory.systemTemp.path + '\\tar_test.tar');
    addTearDown(file.delete);
    await Stream<TarEntry>.value(entry) //
        .transform(const TarEncoderTransformerImpl(OutputFormat.gnuLongName))
        .pipe(file.openWrite());
    final proc = await Process.start('7za.exe', ['l', file.path]);
    expect(proc.lines, emitsThrough(contains(name)));
  });
}
