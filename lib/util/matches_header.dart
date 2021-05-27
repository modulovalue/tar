import 'dart:typed_data';

bool matchesHeader(Uint8List list, List<int> header, int offset) {
  for (var i = 0; i < header.length; i++) {
    if (list[offset + i] != header[i]) {
      return false;
    }
  }
  return true;
}
