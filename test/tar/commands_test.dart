import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:tarzan/gzip/impl/gzip_decoder.dart';
import 'package:tarzan/io/impl/input_file_stream.dart';
import 'package:tarzan/io/impl/output_file_stream.dart';
import 'package:tarzan/tar/impl/command.dart';
import 'package:test/test.dart';

import '../test_utils.dart';

void main() {
  test('bin/tar.dart list', () {
    // Test that 'tar --list' does not throw.
    const TarCommandImpl().listFiles(p.join(testDirPath, 'res/test2.tar.gz'));
  });
  test('tar extract', () {
    final dir = Directory.systemTemp.createTempSync('foo');
    try {
      // print(dir.path);
      final inputPath = p.join(testDirPath, 'res/test2.tar.gz');
      {
        final temp_dir = Directory.systemTemp.createTempSync('dart_archive');
        final tar_path = '${temp_dir.path}${Platform.pathSeparator}temp.tar';
        final input = InputFileStreamImpl(inputPath);
        final output = OutputFileStreamImpl(tar_path);
        const GZipDecoderImpl().decodeStream(input, output);
        input.close();
        output.close();
        final a_bytes = File(tar_path).readAsBytesSync();
        final b_bytes = File(p.join(testDirPath, 'res/test2.tar')).readAsBytesSync();
        expect(a_bytes.length, equals(b_bytes.length));
        var same = true;
        for (var i = 0; same && i < a_bytes.length; ++i) {
          same = a_bytes[i] == b_bytes[i];
        }
        expect(same, equals(true));
        temp_dir.deleteSync(recursive: true);
      }
      const TarCommandImpl().extractFiles(p.join(testDirPath, 'res/test2.tar.gz'), dir.path);
      expect(dir.listSync(recursive: true).length, 4);
    } finally {
      //dir.deleteSync(recursive: true);
    }
  });
  test('tar create', () {
    final dir = Directory.systemTemp.createTempSync('foo');
    final file = File('${dir.path}${Platform.pathSeparator}foo.txt');
    file.writeAsStringSync('foo bar');
    try {
      // Test that 'tar --create' does not throw.
      const TarCommandImpl().createTarFile(dir.path);
    } finally {
      dir.delete(recursive: true);
    }
  });
}
