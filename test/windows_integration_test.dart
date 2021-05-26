@TestOn('windows')
import 'dart:io';

import 'package:tar/entry.dart';
import 'package:tar/header.dart';
import 'package:tar/writer.dart';
import 'package:test/test.dart';

import 'system_tar.dart';

void main() {
  test('emits long file names that are understood by 7zip', () async {
    final name = 'name' * 40;
    final entry = TarEntry.data(TarHeader(name: name), []);
    final file = File(Directory.systemTemp.path + '\\tar_test.tar');
    addTearDown(file.delete);
    await Stream.value(entry) //
        .transform(tarWriterWith(format: OutputFormat.gnuLongName))
        .pipe(file.openWrite());
    final proc = await Process.start('7za.exe', ['l', file.path]);
    expect(proc.lines, emitsThrough(contains(name)));
  });
}
