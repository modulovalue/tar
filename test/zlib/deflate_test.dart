import 'package:tarzan/zlib/impl/deflate.dart';
import 'package:tarzan/zlib/impl/inflate.dart';
import 'package:test/test.dart';

void main() {
  final buffer = List<int>.filled(0xfffff, 0);
  for (var i = 0; i < buffer.length; ++i) {
    buffer[i] = i % 256;
  }
  test('NO_COMPRESSION', () {
    final deflated = DeflateImpl(buffer, level: DeflateImpl.NO_COMPRESSION).getBytes();
    final inflated = InflateImpl(deflated).getBytes();
    expect(inflated.length, equals(buffer.length));
    for (var i = 0; i < buffer.length; ++i) {
      expect(inflated[i], equals(buffer[i]));
    }
  });
  test('BEST_SPEED', () {
    final deflated = DeflateImpl(buffer, level: DeflateImpl.BEST_SPEED).getBytes();
    final inflated = InflateImpl(deflated).getBytes();
    expect(inflated.length, equals(buffer.length));
    for (var i = 0; i < buffer.length; ++i) {
      expect(inflated[i], equals(buffer[i]));
    }
  });
  test('BEST_COMPRESSION', () {
    final deflated = DeflateImpl(buffer, level: DeflateImpl.BEST_COMPRESSION).getBytes();
    final inflated = InflateImpl(deflated).getBytes();
    expect(inflated.length, equals(buffer.length));
    for (var i = 0; i < buffer.length; ++i) {
      expect(inflated[i], equals(buffer[i]));
    }
  });
}
