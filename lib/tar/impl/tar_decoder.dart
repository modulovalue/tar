import '../../archive/impl/archive.dart';
import '../../archive/impl/constants.dart';
import '../../archive/impl/file_mixin.dart';
import '../../archive/interface/archive.dart';
import '../../base/impl/input_stream.dart';
import '../../base/interface/input_stream.dart';
import '../interface/tar_decoder.dart';
import '../interface/tar_file.dart';
import 'tar_file.dart';

class TarDecoderImpl implements TarDecoder {
  const TarDecoderImpl();

  @override
  Archive<TarArchiveFileImpl> decodeBytes(
    List<int> data, {
    bool verify = false,
    bool storeData = true,
  }) =>
      decodeBuffer(
        InputStreamImpl(data),
        verify: verify,
        storeData: storeData,
      );

  @override
  Archive<TarArchiveFileImpl> decodeBuffer(
    InputStream input, {
    bool verify = false,
    bool storeData = true,
  }) {
    final archive = ArchiveImpl<TarArchiveFileImpl>();
    String? nextName;
    // TarFile paxHeader = null;
    while (!input.isEOS) {
      // End of archive when two consecutive 0's are found.
      final end_check = input.peekBytes(2);
      if (end_check.length < 2 || (end_check[0] == 0 && end_check[1] == 0)) {
        break;
      }
      final tf = TarFileImpl.read(input, storeData: storeData);
      // GNU tar puts filenames in files when they exceed tar's native length.
      if (tf.filename == '././@LongLink') {
        nextName = tf.rawContent!.readString();
      } else {
        // In POSIX formatted tar files, a separate 'PAX' file contains extended
        // metadata for files. These are identified by having a type flag 'X'.
        // TODO: parse these metadata values.
        if (tf.typeFlag == TarFileImpl.TYPE_G_EX_HEADER || tf.typeFlag == TarFileImpl.TYPE_G_EX_HEADER2) {
          // TODO handle PAX global header.
        }
        if (tf.typeFlag == TarFileImpl.TYPE_EX_HEADER || tf.typeFlag == TarFileImpl.TYPE_EX_HEADER2) {
          //paxHeader = tf;
        } else {
          final file = TarArchiveFileImpl(tf, nextName ?? tf.filename, tf.fileSize, tf.rawContent);
          file.mode = tf.mode;
          file.ownerId = tf.ownerId;
          file.groupId = tf.groupId;
          file.lastModTime = tf.lastModTime;
          file.isFile = tf.isFile;
          file.isSymbolicLink = tf.typeFlag == TarFileImpl.TYPE_SYMBOLIC_LINK;
          file.nameOfLinkedFile = tf.nameOfLinkedFile;
          archive.addFile(file);
          nextName = null;
        }
      }
    }
    return archive;
  }
}

class TarArchiveFileImpl with ArchiveFileMixin implements TarArchiveFile {
  @override
  final TarFile tarFile;
  @override
  final String name;
  @override
  final int uncompressedSizeOfTheFile;
  @override
  int? compressionType = ARCHIVE_STORE;

  TarArchiveFileImpl(this.tarFile, String name, this.uncompressedSizeOfTheFile, InputStream? content) : this.name = name.replaceAll('\\', '/') {
    if (content is List<int>) {
      content_ = content;
      rawContent = InputStreamImpl(content_);
    } else if (content is InputStreamImpl) {
      rawContent = InputStreamImpl.from(content);
    }
  }
}
