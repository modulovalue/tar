import 'dart:typed_data';

import '../impl/constants.dart';

const _checksumEnd = checksumOffset + checksumLength;
const _checksumPlaceholder = $space;

int computeUnsignedHeaderChecksum(Uint8List list) {
  var result = 0;
  for (var i = 0; i < list.length; i++) {
    result += (i < checksumOffset || i >= _checksumEnd)
        ? list[i] // Not in range of where the checksum is written
        : _checksumPlaceholder;
  }
  return result;
}

int computeSignedHeaderChecksum(Uint8List list) {
  var result = 0;
  for (var i = 0; i < list.length; i++) {
// Note that _checksumPlaceholder.toSigned(8) == _checksumPlaceholder
    result += (i < checksumOffset || i >= _checksumEnd) ? list[i].toSigned(8) : _checksumPlaceholder;
  }
  return result;
}
