import '../../archive/impl/archive_mixin.dart';
import '../../archive/impl/constants.dart';
import '../../archive/impl/file.dart';
import '../../archive/interface/file.dart';
import '../../base/impl/exception.dart';
import '../../base/impl/input_stream.dart';
import '../../crc32/impl/crc32.dart';
import '../interface/decoder.dart';
import '../interface/directory.dart';
import 'directory.dart';

class ZipDecoderImpl implements ZipDecoder {
  const ZipDecoderImpl();

  @override
  ZipArchiveImpl decodeBytes(
    List<int> data, {
    bool verify = false,
    String? password,
  }) =>
      decodeBuffer(InputStreamImpl(data), verify: verify, password: password);

  @override
  ZipArchiveImpl decodeBuffer(
    InputStreamImpl input, {
    bool verify = false,
    String? password,
  }) {
    final archive = ZipArchiveImpl(ZipDirectoryImpl.read(input, password: password));
    for (final zfh in archive.zipDirectory.fileHeaders) {
      final zf = zfh.file!;
      // The attributes are stored in base 8
      final mode = zfh.externalFileAttributes!;
      final compress = zf.compressionMethod != ARCHIVE_STORE;
      if (verify) {
        final computedCrc = const Crc32Impl().getCrc32(zf.content);
        if (computedCrc != zf.crc32) {
          throw const ArchiveExceptionImpl('Invalid CRC for file in archive.');
        }
      }
      final dynamic content = zf.rawContent;
      final file = ArchiveFileImpl(zf.filename, zf.uncompressedSize!, content, zf.compressionMethod);
      file.mode = mode >> 16;
      // See https://github.com/brendan-duncan/archive/issues/21
      // UNIX systems has a creator version of 3 decimal at 1 byte offset
      if (zfh.versionMadeBy >> 8 == 3) {
        //final bool isDirectory = file.mode & 0x7000 == 0x4000;
        final isFile = file.mode & 0x3F000 == 0x8000;
        file.isFile = isFile;
      } else {
        file.isFile = !file.name.endsWith('/');
      }
      file.crc32 = zf.crc32;
      file.compress = compress;
      file.lastModTime = zf.lastModFileDate << 16 | zf.lastModFileTime;
      archive.addFile(file);
    }
    return archive;
  }
}

class ZipArchiveImpl<ARCHIVEFILE extends ArchiveFile> with ArchiveMixin<ARCHIVEFILE> implements ZipArchive<ARCHIVEFILE> {
  @override
  final List<ARCHIVEFILE> files;

  @override
  final String? comment;

  @override
  final ZipDirectory zipDirectory;

  ZipArchiveImpl(this.zipDirectory, [this.comment]) : files = [];
}
