import 'package:tarzan/crc32/impl/crc32.dart';
import 'package:test/test.dart';

void main() {
  group('crc32', () {
    test('empty', () {
      final crcVal = const Crc32Impl().getCrc32([]);
      expect(crcVal, 0);
    });
    test('1 byte', () {
      final crcVal = const Crc32Impl().getCrc32([1]);
      expect(crcVal, 0xA505DF1B);
    });
    test('10 bytes', () {
      final crcVal = const Crc32Impl().getCrc32([1, 2, 3, 4, 5, 6, 7, 8, 9, 0]);
      expect(crcVal, 0xC5F5BE65);
    });
    test('100000 bytes', () {
      var crcVal = const Crc32Impl().getCrc32([]);
      for (var i = 0; i < 10000; i++) {
        crcVal = const Crc32Impl().getCrc32([1, 2, 3, 4, 5, 6, 7, 8, 9, 0], crcVal);
      }
      expect(crcVal, 0x3AC67C2B);
    });
  });
}
