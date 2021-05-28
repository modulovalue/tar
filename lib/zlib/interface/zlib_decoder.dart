import 'dart:typed_data';

import '../../base/interface/input_stream.dart';

/// Decompress data with the zlib format decoder.
abstract class ZLibDecoder {
  Uint8List decodeBytes(List<int> data, {bool verify});

  Uint8List decodeBuffer(InputStream input, {bool verify});
}
