import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:tarzan/base/impl/input_file_stream.dart';
import 'package:tarzan/base/impl/input_stream.dart';
import 'package:tarzan/base/impl/io_create_archive_from_dir.dart';
import 'package:tarzan/base/impl/output_file_stream.dart';
import 'package:tarzan/gzip/impl/gzip_decoder.dart';
import 'package:tarzan/gzip/impl/gzip_encoder.dart';
import 'package:tarzan/tar/impl/io_tar_file_encoder.dart';
import 'package:tarzan/tar/impl/tar_decoder.dart';
import 'package:tarzan/zip/impl/decoder.dart';
import 'package:tarzan/zip/impl/encoder.dart';
import 'package:tarzan/zip/impl/io_zip_file_encoder.dart';
import 'package:test/test.dart';

import '../test_utils.dart';

void main() {
  test('InputFileStream', () {
    // Test fundamental assumption setPositionSync does what we expect.
    final fp = File(p.join(testDirPath, 'res/cat.jpg')).openSync();
    fp.setPositionSync(9);
    var b1 = fp.readByteSync();
    var b2 = fp.readByteSync();
    fp.setPositionSync(9);
    var c1 = fp.readByteSync();
    var c2 = fp.readByteSync();
    expect(b1, equals(c1));
    expect(b2, equals(c2));
    // Test rewind across buffer boundary.
    var input = InputFileStreamImpl(p.join(testDirPath, 'res/cat.jpg'), bufferSize: 10);
    for (var i = 0; i < 9; ++i) {
      input.readByte();
    }
    b1 = input.readByte();
    b2 = input.readByte();
    input.rewind(2);
    c1 = input.readByte();
    c2 = input.readByte();
    expect(b1, equals(c1));
    expect(b2, equals(c2));
    // Test if peekBytes works across a buffer boundary.
    input = InputFileStreamImpl(p.join(testDirPath, 'res/cat.jpg'), bufferSize: 10);
    for (var i = 0; i < 9; ++i) {
      input.readByte();
    }
    b1 = input.readByte();
    b2 = input.readByte();
    input.close();
    input = InputFileStreamImpl(p.join(testDirPath, 'res/cat.jpg'), bufferSize: 10);
    for (var i = 0; i < 9; ++i) {
      input.readByte();
    }
    final b = input.peekBytes(2);
    expect(b.length, equals(2));
    expect(b[0], equals(b1));
    expect(b[1], equals(b2));
    final c = input.readBytes(2);
    expect(b[0], equals(c[0]));
    expect(b[1], equals(c[1]));
    input.close();
    input = InputFileStreamImpl(p.join(testDirPath, 'res/cat.jpg'), bufferSize: 10);
    final input2 = InputStreamImpl(File(p.join(testDirPath, 'res/cat.jpg')).readAsBytesSync());
    var same = true;
    while (!input.isEOS && same) {
      same = input.readByte() == input2.readByte();
    }
    expect(same, equals(true));
    expect(input.isEOS, equals(input2.isEOS));
    // Test skip across buffer boundary
    input = InputFileStreamImpl(p.join(testDirPath, 'res/cat.jpg'), bufferSize: 10);
    for (var i = 0; i < 11; ++i) {
      input.readByte();
    }
    b1 = input.readByte();
    input.close();
    input = InputFileStreamImpl(p.join(testDirPath, 'res/cat.jpg'), bufferSize: 10);
    for (var i = 0; i < 9; ++i) {
      input.readByte();
    }
    input.skip(2);
    c1 = input.readByte();
    expect(b1, equals(c1));
    input.close();
    // Test skip to end of buffer
    input = InputFileStreamImpl(p.join(testDirPath, 'res/cat.jpg'), bufferSize: 10);
    for (var i = 0; i < 10; ++i) {
      input.readByte();
    }
    b1 = input.readByte();
    input.close();
    input = InputFileStreamImpl(p.join(testDirPath, 'res/cat.jpg'), bufferSize: 10);
    for (var i = 0; i < 9; ++i) {
      input.readByte();
    }
    input.skip(1);
    c1 = input.readByte();
    expect(b1, equals(c1));
    input.close();
  });
  test('InputFileStream/OutputFileStream', () {
    final input = InputFileStreamImpl(p.join(testDirPath, 'res/cat.jpg'));
    final output = OutputFileStreamImpl(p.join(testDirPath, 'out/cat2.jpg'));
    while (!input.isEOS) {
      final bytes = input.readBytes(50);
      output.writeInputStream(bytes);
    }
    input.close();
    output.close();
    final a_bytes = File(p.join(testDirPath, 'res/cat.jpg')).readAsBytesSync();
    final b_bytes = File(p.join(testDirPath, 'out/cat2.jpg')).readAsBytesSync();
    expect(a_bytes.length, equals(b_bytes.length));
    var same = true;
    for (var i = 0; same && i < a_bytes.length; ++i) {
      same = a_bytes[i] == b_bytes[i];
    }
    expect(same, equals(true));
  });
  test('empty file', () {
    final encoder = ZipFileEncoderImpl();
    encoder.create('$testDirPath/out/testEmpty.zip');
    encoder.addFile(File('$testDirPath/res/emptyfile.txt'));
    encoder.close();
    const zipDecoder = ZipDecoderImpl();
    final f = File('${testDirPath}/out/testEmpty.zip');
    final archive = zipDecoder.decodeBytes(f.readAsBytesSync(), verify: true);
    expect(archive.numberOfFiles(), equals(1));
  });
  test('stream tar decode', () {
    // Decode a tar from disk to memory
    final stream = InputFileStreamImpl(p.join(testDirPath, 'res/test2.tar'));
    const tarArchive = TarDecoderImpl();
    final decoded = tarArchive.decodeBuffer(stream);
    for (final file in decoded.iterable) {
      if (file.isFile) {
        final filename = file.tarFile.filename;
        try {
          final f = File('${testDirPath}/out/${filename}');
          f.parent.createSync(recursive: true);
          f.writeAsBytesSync(file.content as List<int>);
          // ignore: avoid_catches_without_on_clauses
        } catch (e) {
          print(e);
        }
      }
    }
    expect(decoded.iterable.length, equals(4));
  });
  test('stream tar encode', () {
    // Encode a directory from disk to disk, no memory
    final encoder = TarFileEncoderImpl();
    encoder.open('$testDirPath/out/test3.tar');
    encoder.addDirectory(Directory('$testDirPath/res/test2'));
    encoder.close();
  });
  test('stream gzip encode', () {
    final input = InputFileStreamImpl(p.join(testDirPath, 'res/cat.jpg'));
    final output = OutputFileStreamImpl(p.join(testDirPath, 'out/cat.jpg.gz'));
    const encoder = GZipEncoderImpl();
    encoder.encode(input, output: output);
  });
  test('stream gzip decode', () {
    final input = InputFileStreamImpl(p.join(testDirPath, 'out/cat.jpg.gz'));
    final output = OutputFileStreamImpl(p.join(testDirPath, 'out/cat.jpg'));
    const GZipDecoderImpl().decodeStream(input, output);
  });
  test('stream tgz encode', () {
    // Encode a directory from disk to disk, no memory
    final encoder = TarFileEncoderImpl();
    encoder.create('$testDirPath/out/example2.tar');
    encoder.addDirectory(Directory('$testDirPath/res/test2'));
    encoder.close();
    final input = InputFileStreamImpl(p.join(testDirPath, 'out/example2.tar'));
    final output = OutputFileStreamImpl(p.join(testDirPath, 'out/example2.tgz'));
    const GZipEncoderImpl().encode(input, output: output);
    input.close();
    File(input.path).deleteSync();
  });
  test('stream zip encode', () {
    final encoder = ZipFileEncoderImpl();
    encoder.create('$testDirPath/out/example2.zip');
    encoder.addDirectory(Directory('$testDirPath/res/test2'));
    encoder.addFile(File('$testDirPath/res/cat.jpg'));
    encoder.close();
    const zipDecoder = ZipDecoderImpl();
    final f = File('${testDirPath}/out/example2.zip');
    final archive = zipDecoder.decodeBytes(f.readAsBytesSync(), verify: true);
    expect(archive.numberOfFiles(), equals(3));
  });
  test('create_archive_from_directory', () {
    final dir = Directory('$testDirPath/res/test2');
    final archive = createArchiveFromDirectory(dir);
    expect(archive.numberOfFiles(), equals(2));
    const encoder = ZipEncoderImpl();
    final bytes = encoder.encode(archive)!;
    const zipDecoder = ZipDecoderImpl();
    final archive2 = zipDecoder.decodeBytes(bytes, verify: true);
    expect(archive2.numberOfFiles(), equals(2));
  });
}
