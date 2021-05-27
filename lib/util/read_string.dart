import 'dart:convert';

String readStringUint8List(
  List<int> list,
  int offset,
  int maxLength,
) =>
    readStringOrNullIfEmpty(list, offset, maxLength) ?? '';

String? readStringOrNullIfEmpty(List<int> list, int offset, int maxLength) {
  final end = offset + maxLength;
  final contentEndsAt = () {
    final indexOf0 = () {
      // Search for the first 0.
      for (int i = offset; i < end; i++) {
        if (list[i] == 0) {
          return i;
        }
      }
    }();
    // If there's no \0, assume that the string fills the whole segment.
    if (indexOf0 == null) {
      return end;
    } else {
      return indexOf0;
    }
  }();
  if (contentEndsAt - offset == 0) {
    return null;
  } else {
    try {
      return const Utf8Decoder(allowMalformed: false).convert(list, offset, contentEndsAt);
    } on FormatException {
      return String.fromCharCodes(list, offset, contentEndsAt)
          // That trimming looks suspicious.
          .trim();
    }
  }
}
