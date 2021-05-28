import 'dart:typed_data';

import '../impl/constants.dart';
import '../interface/tar_exception.dart';

/// Parse an octal string encoded from index [offset] with the maximum length
/// [length].
int readOctal(Uint8List list, int offset, int length) {
  var result = 0;
  var multiplier = 1;
  for (var i = length - 1; i >= 0; i--) {
    final charCode = list[offset + i];
    // Some tar implementations add a \0 or space at the end, ignore that
    if (charCode != 0 && charCode != $space) {
      if (charCode < $char0 || charCode > $char9) {
        throw const TarExceptionInvalidOctalImpl('Invalid octal value');
      }
      // Obtain the numerical value of this digit
      final digit = charCode - $char0;
      result += digit * multiplier;
      multiplier <<= 3; // Multiply by the base, 8
    }
  }
  return result;
}

class TarExceptionInvalidOctalImpl extends FormatException implements TarException {
  const TarExceptionInvalidOctalImpl(String message) : super(message);
}
