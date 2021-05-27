@TestOn('windows')
import 'dart:io';

import 'package:tar/encoder/impl/tar_encoder.dart';
import 'package:tar/encoder/interface/tar_encoder.dart';
import 'package:tar/entry/impl/entry.dart';
import 'package:tar/entry/interface/entry.dart';
import 'package:tar/header/impl/header.dart';
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
