
import 'dart:typed_data';

abstract class ZLibEncoder {
  Uint8List encode(List<int> data, {int? level});
}
