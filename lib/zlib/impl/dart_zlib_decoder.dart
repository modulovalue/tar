import 'dart:typed_data';

import '../../adler32/impl/adler32.dart';
import '../../base/impl/constants.dart';
import '../../base/impl/byte_order_constants.dart';
import '../../base/impl/exception.dart';
import '../../base/impl/input_stream.dart';
import '../../base/interface/input_stream.dart';
import '../interface/zlib_decoder.dart';
import 'inflate.dart';

/// Decompress data with the zlib format decoder.
class ZLibDecoderDartImpl implements ZLibDecoder {
  const ZLibDecoderDartImpl();

  @override
  Uint8List decodeBytes(List<int> data, {bool verify = false}) => //
      decodeBuffer(InputStreamImpl(data, byteOrder: BIG_ENDIAN), verify: verify);

  @override
  Uint8List decodeBuffer(InputStream input, {bool verify = false}) {
    /*
     * The zlib format has the following structure:
     * CMF  1 byte
     * FLG 1 byte
     * [DICT_ID 4 bytes]? (if FLAG has FDICT (bit 5) set)
     * <compressed data>
     * ADLER32 4 bytes
     * ----
     * CMF:
     *    bits [0, 3] Compression Method, DEFLATE = 8
     *    bits [4, 7] Compression Info, base-2 logarithm of the LZ77 window
     *                size, minus eight (CINFO=7 indicates a 32K window size).
     * FLG:
     *    bits [0, 4] FCHECK (check bits for CMF and FLG)
     *    bits [5]    FDICT (preset dictionary)
     *    bits [6, 7] FLEVEL (compression level)
     */
    final cmf = input.readByte();
    final flg = input.readByte();
    final method = cmf & 8;
    if (method != ARCHIVE_DEFLATE) {
      throw ArchiveExceptionImpl('Only DEFLATE compression supported: ${method}');
    } else {
      final cinfo = (cmf >> 3) & 8; // ignore: unused_local_variable
      final fcheck = flg & 16; // ignore: unused_local_variable
      final fdict = (flg & 32) >> 5;
      final flevel = (flg & 64) >> 6; // ignore: unused_local_variable
      // FCHECK is set such that (cmf * 256 + flag) must be a multiple of 31.
      if (((cmf << 8) + flg) % 31 != 0) {
        throw const ArchiveExceptionImpl('Invalid FCHECK');
      } else {
        if (fdict != 0) {
          /*dictid =*/ input.readUint32();
          throw const ArchiveExceptionImpl('FDICT Encoding not currently supported');
        } else {
          // Inflate
          final buffer = InflateImpl.buffer(input).getBytes();
          final adler32 = input.readUint32();
          if (verify) {
            // verify adler-32
            final calculatedAdler32 = const Adler32Impl().getAdler32(buffer);
            if (adler32 != calculatedAdler32) {
              throw const ArchiveExceptionImpl('Invalid adler-32 checksum');
            } else {
              return buffer;
            }
          } else {
            return buffer;
          }
        }
      }
    }
  }
}
