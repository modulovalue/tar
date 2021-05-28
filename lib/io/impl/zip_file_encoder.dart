import 'dart:io' hide GZIP;

import 'package:path/path.dart' as path;

import '../../archive/impl/constants.dart';
import '../../archive/impl/file.dart';
import '../../archive/interface/file.dart';
import '../../zip/impl/encoder.dart';
import '../../zip/interface/encoder.dart';
import '../impl/input_file_stream.dart';
import '../impl/output_file_stream.dart';
import '../interface/output_file_stream.dart';
import '../interface/zip_file_encoder.dart';

class ZipFileEncoderImpl implements ZipFileEncoder {
  @override
  late String zip_path;
  late OutputFileStream _output;
  late ZipEncodingSession _encoder;

  ZipFileEncoderImpl();

  @override
  void zipDirectory(Directory dir, {String? filename, int? level}) {
    final dirPath = dir.path;
    final zip_path = filename ?? '${dirPath}.zip';
    level ??= ARCHIVE_GZIP;
    create(zip_path, level: level);
    addDirectory(dir, includeDirName: false, level: level);
    close();
  }

  @override
  void open(String zip_path) => create(zip_path);

  @override
  void create(String zip_path_, {int? level}) {
    zip_path = zip_path_;
    _output = OutputFileStreamImpl(zip_path);
    _encoder = const ZipEncoderImpl().startEncode(_output, level: level);
  }

  @override
  void addDirectory(Directory dir, {bool includeDirName = true, int? level}) {
    final files = dir.listSync(recursive: true);
    for (final file in files) {
      if (file is File) {
        final f = file;
        final dir_name = path.basename(dir.path);
        final rel_path = path.relative(f.path, from: dir.path);
        addFile(f, includeDirName ? (dir_name + '/' + rel_path) : rel_path, level);
      }
    }
  }

  @override
  void addFile(File file, [String? filename, int? level = ARCHIVE_GZIP]) {
    final file_stream = InputFileStreamImpl.file(file);
    final archiveFile = ArchiveFileImpl.stream(filename ?? path.basename(file.path), file.lengthSync(), file_stream);
    if (level == ARCHIVE_STORE) {
      archiveFile.compress = false;
    }
    archiveFile.lastModTime = file.lastModifiedSync().millisecondsSinceEpoch;
    archiveFile.mode = file.statSync().mode;
    _encoder.addFile(archiveFile);
    file_stream.close();
  }

  @override
  void addArchiveFile(ArchiveFile file) {
    _encoder.addFile(file);
  }

  @override
  void close() {
    _encoder.endEncode();
    _output.close();
  }
}
