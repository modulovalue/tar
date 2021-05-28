import 'dart:io';

import 'package:tarzan/bzip2/impl/bzip2_encoder.dart';
import 'package:tarzan/io/impl/zip_file_encoder.dart';
import 'package:tarzan/tar/impl/tar_encoder.dart';
import 'package:tarzan/zip/impl/decoder.dart';

void main() {
  // Read the Zip file from disk.
  final bytes = File('test.zip').readAsBytesSync();
  // Decode the Zip file
  final archive = const ZipDecoderImpl().decodeBytes(bytes);
  // Extract the contents of the Zip archive to disk.
  for (final file in archive.iterable) {
    final filename = file.name;
    if (file.isFile) {
      final data = file.content as List<int>;
      File('out/' + filename)
        ..createSync(recursive: true)
        ..writeAsBytesSync(data);
    } else {
      Directory('out/' + filename).create(recursive: true);
    }
  }
  // Encode the archive as a BZip2 compressed Tar file.
  final tar_data = const TarEncoderImpl().encode(archive);
  final tar_bz2 = BZip2EncoderImpl().encode(tar_data);
  // Write the compressed tar file to disk.
  final fp = File('test.tbz');
  fp.writeAsBytesSync(tar_bz2);
  // Zip a directory to out.zip using the zipDirectory convenience method
  final encoder = ZipFileEncoderImpl();
  encoder.zipDirectory(Directory('out'), filename: 'out.zip');
  // Manually create a zip of a directory and individual files.
  encoder.create('out2.zip');
  encoder.addDirectory(Directory('out'));
  encoder.addFile(File('test.zip'));
  encoder.close();
}
