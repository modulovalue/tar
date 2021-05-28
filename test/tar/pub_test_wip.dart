import 'dart:io';

import 'package:tarzan/gzip/impl/gzip_decoder.dart';
import 'package:tarzan/tar/impl/tar_decoder.dart';
import 'package:test/test.dart';

void main() {
  final client = HttpClient();
  for (final url in urls) {
    final name = url.split("/").last;
    final file = File('test/tests/out/pub/' + name);
    test("Loading " + name, () async {
      if (file.existsSync()) {
        print("Already exists, skipping: $url");
      } else {
        print("Downloading: $url");
        file.createSync(recursive: true);
        final request = await client.getUrl(Uri.parse(url));
        final response = await request.close();
        await response //
            .cast<List<int>>()
            .pipe(file.openWrite());
        await Future<void>.delayed(const Duration(milliseconds: 400));
      }
    });
    test(name, () {
      final data = file.readAsBytesSync();
      const tarArchive = TarDecoderImpl();
      final decoded = tarArchive.decodeBytes(const GZipDecoderImpl().decodeBytes(data));
      // print('Extracting ${file.path}');
      // final outDir = Directory("test/tests/out/extractedpub/" + name);
      // if (outDir.existsSync()) {
      //   outDir.deleteSync(recursive: true);
      // }
      // outDir.createSync(recursive: true);
      for (final file in decoded.iterable) {
        if (file.isFile) {
          // final filename = file.tarFile.filename;
          // final _file = File(outDir.path + Platform.pathSeparator + filename);
          // _file.parent.createSync(recursive: true);
          // _file.writeAsBytesSync(file.content as List<int>);
        }
      }
    });
  }
  client.close(force: true);
}

// void compareDirs(List<String> urls) {
//   final script = File(Platform.script.toFilePath());
//   final path = script.parent.path;
//   for (final url in urls) {
//     final filename = url.split('/').last;
//     final outPath7z = '$path\\out\\${filename}.7z';
//     final outPathDart = '$path\\out\\${filename}.out';
//     print('$outPathDart : $outPath7z');
//     final files7z = <File>[];
//     ListDir(files7z, Directory(outPath7z));
//     final filesDart = <File>[];
//     ListDir(filesDart, Directory(outPathDart));
//     expect(filesDart.length, files7z.length);
//     //print("#${filesDart.length} : ${files7z.length}");
//     for (var i = 0; i < filesDart.length; ++i) {
//       final fd = filesDart[i];
//       final f7z = files7z[i];
//       final bytes_dart = fd.readAsBytesSync();
//       final bytes_7z = f7z.readAsBytesSync();
//       expect(bytes_dart.length, bytes_7z.length);
//       for (var j = 0; j < bytes_dart.length; ++j) {
//         expect(bytes_dart[j], bytes_7z[j]);
//       }
//     }
//   }
// }

const urls = [
  "https://storage.googleapis.com/pub-packages/packages/atlassian_connect_shelf-0.11.8.tar.gz",
  "https://storage.googleapis.com/pub-packages/packages/atlassian_connect_shelf-0.11.9.tar.gz",
  "https://storage.googleapis.com/pub-packages/packages/aws_policy_expander_minimizer-0.0.1.tar.gz",
  "https://storage.googleapis.com/pub-packages/packages/aws_policy_expander_minimizer-0.0.2.tar.gz",
  "https://storage.googleapis.com/pub-packages/packages/aws_policy_expander_minimizer-0.0.3.tar.gz",
  "https://storage.googleapis.com/pub-packages/packages/code_builder-1.0.0-beta+4.tar.gz",
  "https://storage.googleapis.com/pub-packages/packages/dartrpc-0.3.1.tar.gz",
  "https://storage.googleapis.com/pub-packages/packages/dartrpc-0.3.2.tar.gz",
  "https://storage.googleapis.com/pub-packages/packages/dartrs-0.5.0.tar.gz",
  "https://storage.googleapis.com/pub-packages/packages/dartrs-0.5.1.tar.gz",
  "https://storage.googleapis.com/pub-packages/packages/dartrs-0.6.0.tar.gz",
  "https://storage.googleapis.com/pub-packages/packages/dartrs-0.6.1.tar.gz",
  "https://storage.googleapis.com/pub-packages/packages/dartrs-0.6.2.tar.gz",
  "https://storage.googleapis.com/pub-packages/packages/dherkin-0.2.0.tar.gz",
  "https://storage.googleapis.com/pub-packages/packages/dorm-0.1.2.tar.gz",
  "https://storage.googleapis.com/pub-packages/packages/dorm-0.1.3.tar.gz",
  "https://storage.googleapis.com/pub-packages/packages/dorm-0.1.4.tar.gz",
  "https://storage.googleapis.com/pub-packages/packages/dorm-0.1.5.tar.gz",
  "https://storage.googleapis.com/pub-packages/packages/dorm-0.1.6.tar.gz",
  "https://storage.googleapis.com/pub-packages/packages/dorm-0.1.7.tar.gz",
  "https://storage.googleapis.com/pub-packages/packages/dorm-0.1.8.tar.gz",
  "https://storage.googleapis.com/pub-packages/packages/dorm-0.1.9.tar.gz",
  "https://storage.googleapis.com/pub-packages/packages/dorm-0.2.0.tar.gz",
  "https://storage.googleapis.com/pub-packages/packages/dorm-0.2.1.tar.gz",
  "https://storage.googleapis.com/pub-packages/packages/dorm-0.2.2.tar.gz",
  "https://storage.googleapis.com/pub-packages/packages/dorm-0.2.3.tar.gz",
  "https://storage.googleapis.com/pub-packages/packages/dorm-0.2.4.tar.gz",
  "https://storage.googleapis.com/pub-packages/packages/dorm-0.2.5.tar.gz",
  "https://storage.googleapis.com/pub-packages/packages/dorm-0.2.6.tar.gz",
  "https://storage.googleapis.com/pub-packages/packages/dorm-0.2.7.tar.gz",
  "https://storage.googleapis.com/pub-packages/packages/dorm-0.2.8.tar.gz",
  "https://storage.googleapis.com/pub-packages/packages/dorm-0.2.9.tar.gz",
  "https://storage.googleapis.com/pub-packages/packages/dorm-0.3.0.tar.gz",
  "https://storage.googleapis.com/pub-packages/packages/dorm-0.3.1.tar.gz",
  "https://storage.googleapis.com/pub-packages/packages/dorm-0.3.2.tar.gz",
  "https://storage.googleapis.com/pub-packages/packages/dorm-0.3.3.tar.gz",
  "https://storage.googleapis.com/pub-packages/packages/dorm-0.3.4.tar.gz",
  "https://storage.googleapis.com/pub-packages/packages/dorm-0.3.5.tar.gz",
  "https://storage.googleapis.com/pub-packages/packages/dorm-0.3.6.tar.gz",
  "https://storage.googleapis.com/pub-packages/packages/dorm-0.3.7.tar.gz",
  "https://storage.googleapis.com/pub-packages/packages/dorm-0.3.8.tar.gz",
  "https://storage.googleapis.com/pub-packages/packages/embla-0.1.0.tar.gz",
  "https://storage.googleapis.com/pub-packages/packages/embla-0.1.1.tar.gz",
  "https://storage.googleapis.com/pub-packages/packages/embla-0.1.10.tar.gz",
  "https://storage.googleapis.com/pub-packages/packages/embla-0.1.11.tar.gz",
  "https://storage.googleapis.com/pub-packages/packages/embla-0.1.12.tar.gz",
  "https://storage.googleapis.com/pub-packages/packages/embla-0.1.13.tar.gz",
  "https://storage.googleapis.com/pub-packages/packages/embla-0.1.2.tar.gz",
  "https://storage.googleapis.com/pub-packages/packages/embla-0.1.3.tar.gz",
  "https://storage.googleapis.com/pub-packages/packages/embla-0.1.4.tar.gz",
  "https://storage.googleapis.com/pub-packages/packages/embla-0.1.6.tar.gz",
  "https://storage.googleapis.com/pub-packages/packages/embla-0.1.7.tar.gz",
  "https://storage.googleapis.com/pub-packages/packages/embla-0.1.8.tar.gz",
  "https://storage.googleapis.com/pub-packages/packages/embla-0.1.9.tar.gz",
  "https://storage.googleapis.com/pub-packages/packages/embla-0.2.0.tar.gz",
  "https://storage.googleapis.com/pub-packages/packages/embla-0.2.1.tar.gz",
  "https://storage.googleapis.com/pub-packages/packages/embla-0.2.2.tar.gz",
  "https://storage.googleapis.com/pub-packages/packages/embla-0.2.3.tar.gz",
  "https://storage.googleapis.com/pub-packages/packages/embla_templates-0.1.1.tar.gz",
  "https://storage.googleapis.com/pub-packages/packages/embla_templates-0.1.2.tar.gz",
  "https://storage.googleapis.com/pub-packages/packages/embla_templates-0.1.3.tar.gz",
  "https://storage.googleapis.com/pub-packages/packages/embla_templates-0.1.4.tar.gz",
  "https://storage.googleapis.com/pub-packages/packages/embla_templates-0.1.5.tar.gz",
  "https://storage.googleapis.com/pub-packages/packages/embla_trestle-0.1.0.tar.gz",
  "https://storage.googleapis.com/pub-packages/packages/embla_trestle-0.1.1.tar.gz",
  "https://storage.googleapis.com/pub-packages/packages/embla_trestle-0.1.2.tar.gz",
  "https://storage.googleapis.com/pub-packages/packages/embla_trestle-0.2.0.tar.gz",
  "https://storage.googleapis.com/pub-packages/packages/embla_trestle-0.3.0.tar.gz",
  "https://storage.googleapis.com/pub-packages/packages/fed-0.1.0.tar.gz",
  "https://storage.googleapis.com/pub-packages/packages/gcloud-0.1.4+1.tar.gz",
  "https://storage.googleapis.com/pub-packages/packages/god_engine-0.1.1.tar.gz",
  "https://storage.googleapis.com/pub-packages/packages/logfmt-0.1.0.tar.gz",
  "https://storage.googleapis.com/pub-packages/packages/logfmt-0.2.0.tar.gz",
  "https://storage.googleapis.com/pub-packages/packages/logfmt-0.2.1.tar.gz",
  "https://storage.googleapis.com/pub-packages/packages/logfmt-0.3.0.tar.gz",
  "https://storage.googleapis.com/pub-packages/packages/logfmt-0.4.0.tar.gz",
  "https://storage.googleapis.com/pub-packages/packages/logfmt-0.4.1.tar.gz",
  "https://storage.googleapis.com/pub-packages/packages/lost_dart-0.4.0+1.tar.gz",
  "https://storage.googleapis.com/pub-packages/packages/lost_dart-0.4.0+3.tar.gz",
  "https://storage.googleapis.com/pub-packages/packages/lost_dart-0.4.0+4.tar.gz",
  "https://storage.googleapis.com/pub-packages/packages/lost_dart-0.4.0+5.tar.gz",
  "https://storage.googleapis.com/pub-packages/packages/lost_dart-0.4.0+6.tar.gz",
  "https://storage.googleapis.com/pub-packages/packages/lost_dart-0.4.0+7.tar.gz",
  "https://storage.googleapis.com/pub-packages/packages/lost_dart-0.4.0+m3.tar.gz",
  "https://storage.googleapis.com/pub-packages/packages/lost_dart-0.4.0.tar.gz",
  "https://storage.googleapis.com/pub-packages/packages/lost_dart-0.4.10.tar.gz",
  "https://storage.googleapis.com/pub-packages/packages/lost_dart-0.4.11.tar.gz",
  "https://storage.googleapis.com/pub-packages/packages/lost_dart-0.4.12.tar.gz",
  "https://storage.googleapis.com/pub-packages/packages/lost_dart-0.4.13.tar.gz",
  "https://storage.googleapis.com/pub-packages/packages/lost_dart-0.4.2.tar.gz",
  "https://storage.googleapis.com/pub-packages/packages/lost_dart-0.4.3.tar.gz",
  "https://storage.googleapis.com/pub-packages/packages/lost_dart-0.4.4.tar.gz",
  "https://storage.googleapis.com/pub-packages/packages/lost_dart-0.4.5.tar.gz",
  "https://storage.googleapis.com/pub-packages/packages/lost_dart-0.4.6.tar.gz",
  "https://storage.googleapis.com/pub-packages/packages/lost_dart-0.4.7.tar.gz",
  "https://storage.googleapis.com/pub-packages/packages/lost_dart-0.4.8.tar.gz",
  "https://storage.googleapis.com/pub-packages/packages/lost_dart-0.4.9.tar.gz",
  "https://storage.googleapis.com/pub-packages/packages/lost_dart-0.5.0.tar.gz",
  "https://storage.googleapis.com/pub-packages/packages/lost_dart-0.5.1.tar.gz",
  "https://storage.googleapis.com/pub-packages/packages/lost_dart-0.5.2.tar.gz",
  "https://storage.googleapis.com/pub-packages/packages/lost_dart-0.5.3.tar.gz",
  "https://storage.googleapis.com/pub-packages/packages/lost_dart-0.5.4.tar.gz",
  "https://storage.googleapis.com/pub-packages/packages/puremvc-2.0.6.tar.gz",
  "https://storage.googleapis.com/pub-packages/packages/semantic_for_pub-1.12.2+1.tar.gz",
  "https://storage.googleapis.com/pub-packages/packages/semantic_for_pub-1.12.2.tar.gz",
  "https://storage.googleapis.com/pub-packages/packages/shared_textarea-0.0.0.tar.gz",
  "https://storage.googleapis.com/pub-packages/packages/sudoku-0.1.0.tar.gz",
  "https://storage.googleapis.com/pub-packages/packages/sudoku-0.1.1.tar.gz",
  "https://storage.googleapis.com/pub-packages/packages/sudoku-0.1.2.tar.gz",
  "https://storage.googleapis.com/pub-packages/packages/template_cache-0.1.1.tar.gz",
  "https://storage.googleapis.com/pub-packages/packages/trestle-0.10.0.tar.gz",
  "https://storage.googleapis.com/pub-packages/packages/trestle-0.11.1.tar.gz",
  "https://storage.googleapis.com/pub-packages/packages/trestle-0.7.0.tar.gz",
  "https://storage.googleapis.com/pub-packages/packages/trestle-0.8.0.tar.gz",
  "https://storage.googleapis.com/pub-packages/packages/trestle-0.9.0.tar.gz",
  "https://storage.googleapis.com/pub-packages/packages/web_server-2.0.0+1.tar.gz",
  "https://storage.googleapis.com/pub-packages/packages/web_server-2.0.0+2.tar.gz",
  "https://storage.googleapis.com/pub-packages/packages/web_server-2.0.0+3.tar.gz",
  "https://storage.googleapis.com/pub-packages/packages/web_server-2.0.0.tar.gz",
];
