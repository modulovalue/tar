import 'dart:typed_data';

import 'read_octal.dart';

/// Parses an encoded int, either as base-256 or octal.
///
/// This function may return negative numbers.
int readNumeric(Uint8List list, int offset, int length) {
  if (length == 0) {
    return 0;
  } else {
    // Check for base-256 (binary) format first. If the first bit is set, then
    // all following bits constitute a two's complement encoded number in big-
    // endian byte order.
    final firstByte = list[offset];
    if (firstByte & 0x80 != 0) {
      // Handling negative numbers relies on the following identity:
      // -a-1 == ~a
      //
      // If the number is negative, we use an inversion mask to invert the
      // date bytes and treat the value as an unsigned number.
      final inverseMask = firstByte & 0x40 != 0 ? 0xff : 0x00;
      // Ignore signal bit in the first byte
      var x = (firstByte ^ inverseMask) & 0x7f;
      for (var i = 1; i < length; i++) {
        var byte = list[offset + i];
        byte ^= inverseMask;
        x = x << 8 | byte;
      }
      return inverseMask == 0xff ? ~x : x;
    }
    return readOctal(list, offset, length);
  }
}
