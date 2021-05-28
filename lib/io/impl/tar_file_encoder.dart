import 'dart:io';

import 'package:path/path.dart' as path;

import '../../archive/impl/constants.dart';
import '../../archive/impl/file.dart';
import '../../gzip/impl/gzip_encoder.dart';
import '../../tar/impl/tar_encoder.dart';
import '../../tar/interface/tar_encoder.dart';
import '../impl/input_file_stream.dart';
import '../impl/output_file_stream.dart';
import '../interface/output_file_stream.dart';
import '../interface/tar_file_encoder.dart';

class TarFileEncoderImpl implements TarFileEncoder {
  @override
  late String tar_path;
  late OutputFileStream _output;
  late TarEncodingSession _encodingSession;

  TarFileEncoderImpl();

  @override
  void tarDirectory(Directory dir, {int compression = ARCHIVE_STORE, String? filename}) {
    final dirPath = dir.path;
    var tar_path = filename ?? '${dirPath}.tar';
    final tgz_path = filename ?? '${dirPath}.tar.gz';
    Directory temp_dir;
    if (compression == ARCHIVE_GZIP) {
      temp_dir = Directory.systemTemp.createTempSync('dart_archive');
      tar_path = temp_dir.path + '/temp.tar';
    }
    // Encode a directory from disk to disk, no memory
    open(tar_path);
    addDirectory(Directory(dirPath));
    close();
    if (compression == ARCHIVE_GZIP) {
      final input = InputFileStreamImpl(tar_path);
      final output = OutputFileStreamImpl(tgz_path);
      const GZipEncoderImpl().encode(input, output: output);
      input.close();
      File(input.path).deleteSync();
    }
  }

  @override
  void open(String tar_path) => create(tar_path);

  @override
  void create(String tar_path) {
    this.tar_path = tar_path;
    _output = OutputFileStreamImpl(tar_path);
    _encodingSession = const TarEncoderImpl().start(_output);
  }

  @override
  void addDirectory(Directory dir) {
    final files = dir.listSync(recursive: true);
    for (final fe in files) {
      if (fe is File) {
        final f = fe;
        final rel_path = path.relative(f.path, from: dir.path);
        addFile(f, rel_path);
      }
    }
  }

  @override
  void addFile(File file, [String? filename]) {
    final file_stream = InputFileStreamImpl.file(file);
    final f = ArchiveFileImpl.stream(filename ?? file.path, file.lengthSync(), file_stream);
    f.lastModTime = file.lastModifiedSync().millisecondsSinceEpoch;
    f.mode = file.statSync().mode;
    _encodingSession.add(f);
    file_stream.close();
  }

  @override
  void close() {
    _encodingSession.finish();
    _output.close();
  }
}
