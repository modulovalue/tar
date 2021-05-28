import '../../base/interface/input_stream.dart';
import '../interface/bz2_bit_reader.dart';

class Bz2BitReaderImpl implements Bz2BitReader {
  static const List<int> _BIT_MASK = [0, 1, 3, 7, 15, 31, 63, 127, 255];

  @override
  InputStream input;
  int _bitBuffer = 0;
  int _bitPos = 0;

  Bz2BitReaderImpl(this.input);

  @override
  int readByte() => readBits(8);

  /// Read a number of bits from the input stream.
  @override
  int readBits(int numBits) {
    if (numBits == 0) {
      return 0;
    } else {
      if (_bitPos == 0) {
        _bitPos = 8;
        _bitBuffer = input.readByte();
      }
      var value = 0;
      while (numBits > _bitPos) {
        value = (value << _bitPos) + (_bitBuffer & _BIT_MASK[_bitPos]);
        // ignore: parameter_assignments
        numBits -= _bitPos;
        _bitPos = 8;
        _bitBuffer = input.readByte();
      }
      if (numBits > 0) {
        if (_bitPos == 0) {
          _bitPos = 8;
          _bitBuffer = input.readByte();
        }
        value = (value << numBits) + (_bitBuffer >> (_bitPos - numBits) & _BIT_MASK[numBits]);
        _bitPos -= numBits;
      }
      return value;
    }
  }
}
