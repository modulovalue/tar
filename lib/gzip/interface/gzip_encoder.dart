import 'dart:typed_data';

abstract class GZipEncoder {
  /// TODO why is data and output dynamic
  Uint8List? encode(dynamic data, {int? level, dynamic output});
}
