import 'dart:typed_data';

import '../../archive/impl/constants.dart';
import '../../base/impl/output_stream.dart';
import '../../base/interface/input_stream.dart';
import '../../base/interface/output_stream.dart';
import '../../zlib/impl/deflate.dart';
import '../interface/gzip_encoder.dart';
import 'gzip_constants.dart';

class GZipEncoderImpl implements GZipEncoder {
  // enum OperatingSystem
  static const int OS_FAT = 0;
  static const int OS_AMIGA = 1;
  static const int OS_VMS = 2;
  static const int OS_UNIX = 3;
  static const int OS_VM_CMS = 4;
  static const int OS_ATARI_TOS = 5;
  static const int OS_HPFS = 6;
  static const int OS_MACINTOSH = 7;
  static const int OS_Z_SYSTEM = 8;
  static const int OS_CP_M = 9;
  static const int OS_TOPS_20 = 10;
  static const int OS_NTFS = 11;
  static const int OS_QDOS = 12;
  static const int OS_ACORN_RISCOS = 13;
  static const int OS_UNKNOWN = 255;

  const GZipEncoderImpl();

  @override
  Uint8List? encode(dynamic data, {int? level, dynamic output}) {
    final dynamic output_stream = output ?? OutputStreamImpl();
    // The GZip format has the following structure:
    // Offset   Length   Contents
    // 0      2 bytes  magic header  0x1f, 0x8b (\037 \213)
    // 2      1 byte   compression method
    //                  0: store (copied)
    //                  1: compress
    //                  2: pack
    //                  3: lzh
    //                  4..7: reserved
    //                  8: deflate
    // 3      1 byte   flags
    //                  bit 0 set: file probably ascii text
    //                  bit 1 set: continuation of multi-part gzip file, part number present
    //                  bit 2 set: extra field present
    //                  bit 3 set: original file name present
    //                  bit 4 set: file comment present
    //                  bit 5 set: file is encrypted, encryption header present
    //                  bit 6,7:   reserved
    // 4      4 bytes  file modification time in Unix format
    // 8      1 byte   extra flags (depend on compression method)
    // 9      1 byte   OS type
    // [
    //        2 bytes  optional part number (second part=1)
    // ]?
    // [
    //        2 bytes  optional extra field length (e)
    //       (e)bytes  optional extra field
    // ]?
    // [
    //          bytes  optional original file name, zero terminated
    // ]?
    // [
    //          bytes  optional file comment, zero terminated
    // ]?
    // [
    //       12 bytes  optional encryption header
    // ]?
    //          bytes  compressed data
    //        4 bytes  crc32
    //        4 bytes  uncompressed input size modulo 2^32
    // ignore: avoid_dynamic_calls
    output_stream.writeUint16(GZipConstants.SIGNATURE);
    // ignore: avoid_dynamic_calls
    output_stream.writeByte(ARCHIVE_DEFLATE);
    const flags = 0;
    final fileModTime = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    const extraFlags = 0;
    const osType = OS_UNKNOWN;
    // ignore: avoid_dynamic_calls
    output_stream.writeByte(flags);
    // ignore: avoid_dynamic_calls
    output_stream.writeUint32(fileModTime);
    // ignore: avoid_dynamic_calls
    output_stream.writeByte(extraFlags);
    // ignore: avoid_dynamic_calls
    output_stream.writeByte(osType);
    DeflateImpl deflate;
    if (data is List<int>) {
      deflate = DeflateImpl(data, level: level, output: output_stream);
    } else {
      deflate = DeflateImpl.buffer(data as InputStream, level: level, output: output_stream);
    }
    if (!(output_stream is OutputStream)) {
      deflate.finish();
    }
    // ignore: avoid_dynamic_calls
    output_stream.writeUint32(deflate.crc32);
    // ignore: avoid_dynamic_calls
    output_stream.writeUint32(data.length);
    if (output_stream is OutputStreamImpl) {
      return output_stream.getBytes();
    } else {
      return null;
    }
  }
}
