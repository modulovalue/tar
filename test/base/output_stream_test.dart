import 'package:tarzan/base/impl/input_stream.dart';
import 'package:tarzan/base/impl/output_stream.dart';
import 'package:test/test.dart';

void main() {
  test('empty', () {
    final out = OutputStreamImpl();
    final bytes = out.getBytes();
    expect(bytes.length, equals(0));
  });
  test('writeByte', () {
    final out = OutputStreamImpl();
    for (var i = 0; i < 10000; ++i) {
      out.writeByte(i % 256);
    }
    final bytes = out.getBytes();
    expect(bytes.length, equals(10000));
    for (var i = 0; i < 10000; ++i) {
      expect(bytes[i], equals(i % 256));
    }
  });

  test('writeUint16', () {
    final out = OutputStreamImpl();
    const LEN = 0xffff;
    for (var i = 0; i < LEN; ++i) {
      out.writeUint16(i);
    }
    final bytes = out.getBytes();
    expect(bytes.length, equals(LEN * 2));
    final input = InputStreamImpl(bytes);
    for (var i = 0; i < LEN; ++i) {
      final x = input.readUint16();
      expect(x, equals(i));
    }
  });

  test('writeUint32', () {
    final out = OutputStreamImpl();
    const LEN = 0xffff;
    for (var i = 0; i < LEN; ++i) {
      out.writeUint32(0xffff + i);
    }
    final bytes = out.getBytes();
    expect(bytes.length, equals(LEN * 4));
    final input = InputStreamImpl(bytes);
    for (var i = 0; i < LEN; ++i) {
      final x = input.readUint32();
      expect(x, equals(0xffff + i));
    }
  });
}
