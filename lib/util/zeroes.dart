import 'dart:typed_data';

/// Generates a chunked stream of [length] zeroes.
Stream<List<int>> zeroes(int length) async* {
  // Emit data in chunks for efficiency
  const chunkSize = 4 * 1024;
  if (length < chunkSize) {
    yield Uint8List(length);
  } else {
    final chunk = Uint8List(chunkSize);
    for (var i = 0; i < length ~/ chunkSize; i++) {
      yield chunk;
    }

    final remainingBytes = length % chunkSize;
    if (remainingBytes != 0) {
      yield Uint8List(remainingBytes);
    }
  }
}
