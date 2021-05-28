import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:tarzan/gzip/impl/gzip_decoder.dart';
import 'package:tarzan/gzip/impl/gzip_encoder.dart';
import 'package:test/test.dart';

import '../test_utils.dart';

void main() {
  group('gzip', () {
    final buffer = List<int>.filled(10000, 0);
    for (var i = 0; i < buffer.length; ++i) {
      buffer[i] = i % 256;
    }
    test('encode/decode', () {
      final compressed = const GZipEncoderImpl().encode(buffer);
      final decompressed = const GZipDecoderImpl().decodeBytes(compressed!, verify: true);
      expect(decompressed.length, equals(buffer.length));
      for (var i = 0; i < buffer.length; ++i) {
        expect(decompressed[i], equals(buffer[i]));
      }
    });
    test('decode res/cat.jpg.gz', () {
      final b = File(p.join(testDirPath, 'res/cat.jpg'));
      final b_bytes = b.readAsBytesSync();
      final file = File(p.join(testDirPath, 'res/cat.jpg.gz'));
      final bytes = file.readAsBytesSync();
      final z_bytes = const GZipDecoderImpl().decodeBytes(bytes, verify: true);
      compare_bytes(z_bytes, b_bytes);
    });
    test('decode res/test2.tar.gz', () {
      final b = File(p.join(testDirPath, 'res/test2.tar'));
      final b_bytes = b.readAsBytesSync();
      final file = File(p.join(testDirPath, 'res/test2.tar.gz'));
      final bytes = file.readAsBytesSync();
      final z_bytes = const GZipDecoderImpl().decodeBytes(bytes, verify: true);
      compare_bytes(z_bytes, b_bytes);
    });
    test('decode res/a.txt.gz', () {
      final a_bytes = a_txt.codeUnits;
      final file = File(p.join(testDirPath, 'res/a.txt.gz'));
      final bytes = file.readAsBytesSync();
      final z_bytes = const GZipDecoderImpl().decodeBytes(bytes, verify: true);
      compare_bytes(z_bytes, a_bytes);
    });
    test('encode res/cat.jpg', () {
      final b = File(p.join(testDirPath, 'res/cat.jpg'));
      final b_bytes = b.readAsBytesSync();
      final compressed = const GZipEncoderImpl().encode(b_bytes);
      final f = File(p.join(testDirPath, 'out/cat.jpg.gz'));
      f.createSync(recursive: true);
      f.writeAsBytesSync(compressed!);
    });
  });
}
