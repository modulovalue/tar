import 'dart:io' as io;
import 'dart:typed_data';

import '../../base/interface/input_stream.dart';
import '../interface/zlib_decoder.dart';

/// Decompress data with the zlib format decoder.
class ZLibDecoderIOImpl implements ZLibDecoder {
  static late final _codec = io.ZLibDecoder();

  const ZLibDecoderIOImpl();

  @override
  Uint8List decodeBytes(
    List<int> data, {
    bool verify = false,
  }) =>
      _codec.convert(data) as Uint8List;

  @override
  Uint8List decodeBuffer(
    InputStream input, {
    bool verify = false,
  }) =>
      decodeBytes(input.toUint8List(), verify: verify);
}
