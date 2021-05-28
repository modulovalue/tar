import 'dart:io';

import '../archive/interface/archive.dart';
import '../base/impl/input_stream.dart';
import '../bzip2/impl/bzip2_decoder.dart';
import '../gzip/impl/gzip_decoder.dart';
import '../io/impl/input_file_stream.dart';
import '../io/impl/output_file_stream.dart';
import '../tar/impl/tar_decoder.dart';
import '../zip/impl/decoder.dart';

void extractFileToDisk(String inputPath, String outputPath, {String? password}) {
  Directory? tempDir;
  var archivePath = inputPath;
  if (inputPath.endsWith('tar.gz') || inputPath.endsWith('tgz')) {
    tempDir = Directory.systemTemp.createTempSync('dart_archive');
    archivePath = '${tempDir.path}${Platform.pathSeparator}temp.tar';
    final input = InputFileStreamImpl(inputPath);
    final output = OutputFileStreamImpl(archivePath);
    const GZipDecoderImpl().decodeStream(input, output);
    input.close();
    output.close();
  } else if (inputPath.endsWith('tar.bz2') || inputPath.endsWith('tbz')) {
    tempDir = Directory.systemTemp.createTempSync('dart_archive');
    archivePath = '${tempDir.path}${Platform.pathSeparator}temp.tar';
    final input = InputFileStreamImpl(inputPath);
    final output = OutputFileStreamImpl(archivePath);
    BZip2DecoderImpl().decodeBuffer(input, output: output);
    input.close();
    output.close();
  }
  Archive archive;
  if (archivePath.endsWith('tar')) {
    final input = InputFileStreamImpl(archivePath);
    archive = const TarDecoderImpl().decodeBuffer(input);
  } else if (archivePath.endsWith('zip')) {
    final input = InputStreamImpl(File(archivePath).readAsBytesSync());
    archive = const ZipDecoderImpl().decodeBuffer(input, password: password);
  } else {
    throw ArgumentError.value(inputPath, 'inputPath', 'Must end tar.gz, tgz, tar.bz2, tbz, tar or zip.');
  }
  for (final file in archive.iterable) {
    if (file.isFile) {
      final f = File('${outputPath}${Platform.pathSeparator}${file.name}');
      f.parent.createSync(recursive: true);
      f.writeAsBytesSync(file.content as List<int>);
    }
  }
  if (tempDir != null) {
    tempDir.delete(recursive: true);
  }
}
