import 'dart:io';

import '../../archive/impl/constants.dart';
import '../../bzip2/impl/bzip2_decoder.dart';
import '../../gzip/impl/gzip_decoder.dart';
import '../../io/impl/input_file_stream.dart';
import '../../io/impl/output_file_stream.dart';
import '../../io/impl/tar_file_encoder.dart';
import '../interface/command.dart';
import 'tar_decoder.dart';

class TarCommandImpl implements TarCommand {
  const TarCommandImpl();

  @override
  void tarCommand(List<String> arguments) {
    // tar --list <file>
    // tar --extract <file> <dest>
    // tar --create <source>
    const usage = 'usage: tar [--list|--extract|--create] <file> [<dest>|<source>]';
    if (arguments.isEmpty) {
      fail(usage);
    } else {
      final command = arguments[0];
      if (command == '--list') {
        if (arguments.length < 2) {
          fail(usage);
        } else {
          listFiles(arguments[1]);
        }
      } else if (command == '--extract') {
        if (arguments.length < 3) {
          fail(usage);
        } else {
          extractFiles(arguments[1], arguments[2]);
        }
      } else if (command == '--create') {
        if (arguments.length < 2) {
          fail(usage);
        } else {
          createTarFile(arguments[1]);
        }
      } else {
        fail(usage);
      }
    }
  }

  @override
  void listFiles(String path) {
    final file = File(path);
    if (!file.existsSync()) fail('${path} does not exist');
    List<int> data = file.readAsBytesSync();
    if (path.endsWith('tar.gz') || path.endsWith('tgz')) {
      data = const GZipDecoderImpl().decodeBytes(data);
    } else if (path.endsWith('tar.bz2') || path.endsWith('tbz')) {
      data = BZip2DecoderImpl().decodeBytes(data);
    }
    const tarArchive = TarDecoderImpl();
    // Tell the decoder not to store the actual file data since we don't need it.
    final decoded = tarArchive.decodeBytes(data, storeData: false);
    print(decoded.iterable.length.toString() + ' file(s)');
    decoded.iterable.forEach((f) => print('  ${f.tarFile}'));
  }

  /// Extract the entries in the given tar file to a directory.
  @override
  Directory extractFiles(String inputPath, String outputPath) {
    Directory? temp_dir;
    var tar_path = inputPath;
    if (inputPath.endsWith('tar.gz') || inputPath.endsWith('tgz')) {
      temp_dir = Directory.systemTemp.createTempSync('dart_archive');
      tar_path = '${temp_dir.path}${Platform.pathSeparator}temp.tar';
      final input = InputFileStreamImpl(inputPath);
      final output = OutputFileStreamImpl(tar_path);
      const GZipDecoderImpl().decodeStream(input, output);
      input.close();
      output.close();
    }
    final outDir = Directory(outputPath);
    if (!outDir.existsSync()) {
      outDir.createSync(recursive: true);
    }
    final input = InputFileStreamImpl(tar_path);
    final decoded = const TarDecoderImpl().decodeBuffer(input);
    for (final file in decoded.iterable) {
      if (file.isFile) {
        final f = File(outputPath + Platform.pathSeparator + file.tarFile.filename);
        f.parent.createSync(recursive: true);
        f.writeAsBytesSync(file.tarFile.contentBytes);
        print('  extracted ${file.tarFile.filename}');
      }
    }
    input.close();
    if (temp_dir != null) {
      temp_dir.delete(recursive: true);
    }
    /*File inputFile = File(inputPath);
  if (!inputFile.existsSync()) fail('${inputPath} does not exist');

  Directory outDir = Directory(outputPath);
  if (!outDir.existsSync()) {
    outDir.createSync(recursive: true);
  }

  List<int> data = inputFile.readAsBytesSync();
  if (inputPath.endsWith('tar.gz') || inputPath.endsWith('tgz')) {
    data = GZipDecoder().decodeBytes(data);
  } else if (inputPath.endsWith('tar.bz2') || inputPath.endsWith('tbz')) {
    data = BZip2Decoder().decodeBytes(data);
  }

  TarDecoder tarArchive = TarDecoder();
  tarArchive.decodeBytes(data);*

  print('extracting to ${outDir.path}${Platform.pathSeparator}...');

  for (TarFile file in tarArchive.files) {
    if (!file.isFile) {
      continue;
    }
    File f = File(
        '${outputPath}${Platform.pathSeparator}${file.filename}');
    f.parent.createSync(recursive: true);
    f.writeAsBytesSync(file.content);
    print('  extracted ${file.filename}');
  };*/
    return outDir;
  }

  @override
  void createTarFile(String dirPath) {
    final dir = Directory(dirPath);
    if (!dir.existsSync()) fail('${dirPath} does not exist');
    // Encode a directory from disk to disk, no memory
    final encoder = TarFileEncoderImpl();
    encoder.tarDirectory(dir, compression: ARCHIVE_GZIP);
  }

  static void fail(String message) {
    print(message);
    exit(1);
  }
}
