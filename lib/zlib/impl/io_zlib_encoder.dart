import 'dart:io' show ZLibCodec, ZLibOption;
import 'dart:typed_data';

import '../interface/zlib_encoder.dart';

class ZLibEncoderIOImpl implements ZLibEncoder {
  const ZLibEncoderIOImpl();

  @override
  Uint8List encode(List<int> data, {int? level}) => //
      ZLibCodec(level: level ?? ZLibOption.defaultLevel).encoder.convert(data) as Uint8List;
}
