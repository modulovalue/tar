import 'dart:io' as io;

import 'package:path/path.dart' as p;
import 'package:tarzan/bzip2/impl/bzip2_decoder.dart';
import 'package:tarzan/bzip2/impl/bzip2_encoder.dart';
import 'package:test/test.dart';

import '../test_utils.dart';

void main() {
  test('decode', () {
    final List<int> orig = io.File(p.join(testDirPath, 'res/bzip2/test.bz2')).readAsBytesSync();
    BZip2DecoderImpl().decodeBytes(orig, verify: true);
  });
  test('encode', () {
    final List<int> file = io.File(p.join(testDirPath, 'res/cat.jpg')).readAsBytesSync();
    final compressed = BZip2EncoderImpl().encode(file);
    final d2 = BZip2DecoderImpl().decodeBytes(compressed, verify: true);
    expect(d2.length, equals(file.length));
    final len = d2.length;
    for (var i = 0; i < len; ++i) {
      expect(d2[i], equals(file[i]));
    }
  });
}
