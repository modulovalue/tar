import 'dart:typed_data';

import '../../archive/impl/constants.dart';
import '../../base/impl/exception.dart';
import '../../base/impl/input_stream.dart';
import '../../base/interface/input_stream.dart';
import '../../base/interface/output_stream.dart';
import '../../crc32/impl/crc32.dart';
import '../../zlib/impl/inflate.dart';
import '../interface/gzip_decoder.dart';
import 'gzip_constants.dart';

/// Decompress data with the gzip format decoder.
class GZipDecoderImpl implements GZipDecoder {
  const GZipDecoderImpl();

  @override
  Uint8List decodeBytes(
    List<int> data, {
    bool verify = false,
  }) =>
      decodeBuffer(InputStreamImpl(data), verify: verify);

  @override
  void decodeStream(InputStream input, OutputStream output) {
    _readHeader(input);
    InflateImpl.stream(input, output);
  }

  @override
  Uint8List decodeBuffer(
    InputStream input, {
    bool verify = false,
  }) {
    _readHeader(input);
    // Inflate
    final buffer = InflateImpl.buffer(input).getBytes();
    if (verify) {
      final crc = input.readUint32();
      final computedCrc = const Crc32Impl().getCrc32(buffer);
      if (crc != computedCrc) {
        throw const ArchiveExceptionImpl('Invalid CRC checksum');
      }
      final size = input.readUint32();
      if (size != buffer.length) {
        throw const ArchiveExceptionImpl('Size of decompressed file not correct');
      }
    }
    return buffer;
  }

  void _readHeader(InputStream input) {
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
    final signature = input.readUint16();
    if (signature != GZipConstants.SIGNATURE) {
      throw const ArchiveExceptionImpl('Invalid GZip Signature');
    }
    final compressionMethod = input.readByte();
    if (compressionMethod != ARCHIVE_DEFLATE) {
      throw const ArchiveExceptionImpl('Invalid GZip Compression Methos');
    }
    final flags = input.readByte();
    /*int fileModTime =*/
    input.readUint32();
    /*int extraFlags =*/
    input.readByte();
    /*int osType =*/
    input.readByte();
    if (flags & GZipConstants.FLAG_EXTRA != 0) {
      final t = input.readUint16();
      input.readBytes(t);
    }
    if (flags & GZipConstants.FLAG_NAME != 0) {
      input.readString();
    }
    if (flags & GZipConstants.FLAG_COMMENT != 0) {
      input.readString();
    }
    // just throw away for now
    if (flags & GZipConstants.FLAG_HCRC != 0) {
      input.readUint16();
    }
  }
}
