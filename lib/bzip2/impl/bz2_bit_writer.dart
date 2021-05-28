import '../../base/interface/output_stream.dart';
import '../interface/bz2_bit_writer.dart';

class Bz2BitWriterImpl implements Bz2BitWriter {
  @override
  final OutputStream output;

  int _bitBuffer = 0;
  int _bitPos = 8;

  Bz2BitWriterImpl(this.output);

  @override
  void writeByte(int byte) => writeBits(8, byte);

  @override
  void writeBytes(List<int> bytes) {
    for (var i = 0; i < bytes.length; ++i) {
      writeBits(8, bytes[i]);
    }
  }

  @override
  void writeUint16(int value) => writeBits(16, value);

  @override
  void writeUint24(int value) => writeBits(24, value);

  @override
  void writeUint32(int value) => writeBits(32, value);

  @override
  void writeBits(int numBits, int value) {
    // TODO optimize
    if (_bitPos == 8 && numBits == 8) {
      output.writeByte(value & 0xff);
    } else {
      if (_bitPos == 8 && numBits == 16) {
        output.writeByte((value >> 8) & 0xff);
        output.writeByte(value & 0xff);
      } else {
        if (_bitPos == 8 && numBits == 24) {
          output.writeByte((value >> 16) & 0xff);
          output.writeByte((value >> 8) & 0xff);
          output.writeByte(value & 0xff);
        } else {
          if (_bitPos == 8 && numBits == 32) {
            output.writeByte((value >> 24) & 0xff);
            output.writeByte((value >> 16) & 0xff);
            output.writeByte((value >> 8) & 0xff);
            output.writeByte(value & 0xff);
          } else {
            while (numBits > 0) {
              // ignore: parameter_assignments
              numBits--;
              final b = (value >> numBits) & 0x1;
              _bitBuffer = (_bitBuffer << 1) | b;
              _bitPos--;
              if (_bitPos == 0) {
                output.writeByte(_bitBuffer);
                _bitPos = 8;
                _bitBuffer = 0;
              }
            }
          }
        }
      }
    }
  }

  @override
  void flush() {
    if (_bitPos != 8) {
      writeBits(_bitPos, 0);
    }
  }
}
