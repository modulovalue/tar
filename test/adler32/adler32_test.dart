import 'package:tarzan/adler32/impl/adler32.dart';
import 'package:test/test.dart';

void main() {
  group('adler32', () {
    test('empty', () {
      final adlerVal = const Adler32Impl().getAdler32([]);
      expect(adlerVal, 1);
    });
    test('1 byte', () {
      final adlerVal = const Adler32Impl().getAdler32([1]);
      expect(adlerVal, 0x20002);
    });
    test('10 bytes', () {
      final adlerVal = const Adler32Impl().getAdler32([1, 2, 3, 4, 5, 6, 7, 8, 9, 0]);
      expect(adlerVal, 0xDC002E);
    });
    test('100000 bytes', () {
      var adlerVal = const Adler32Impl().getAdler32([]);
      for (var i = 0; i < 10000; i++) {
        adlerVal = const Adler32Impl().getAdler32([1, 2, 3, 4, 5, 6, 7, 8, 9, 0], adlerVal);
      }
      expect(adlerVal, 0x96C8DE2B);
    });
  });
}
