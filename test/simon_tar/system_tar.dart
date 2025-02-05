// Wrapper around the `tar` command, for testing.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:tarzan/simon_tar/impl/tar_encoder.dart';
import 'package:tarzan/simon_tar/interface/entry.dart';
import 'package:tarzan/simon_tar/interface/tar_encoder.dart';
import 'package:test/test.dart';

Future<Process> startTar(List<String> args, {String? baseDir}) {
  return Process.start('tar', args, workingDirectory: baseDir).then((proc) {
    expect(
      proc.exitCode,
      completion(0),
      reason: 'tar ${args.join(' ')} should complete normally',
    );
    // Attach stderr listener, we don't expect any output on that
    late List<int> data;
    final sink = ByteConversionSink.withCallback((result) => data = result);
    proc.stderr.forEach(sink.add).then((Object? _) {
      sink.close();
      const LineSplitter().convert(utf8.decode(data)).forEach(stderr.writeln);
    });
    return proc;
  });
}

Stream<List<int>> createTarStream(Iterable<String> files, {String archiveFormat = 'gnu', String? sparseVersion, String? baseDir}) async* {
  final args = [
    '--format=$archiveFormat',
    '--create',
    ...files,
  ];
  if (sparseVersion != null) {
    args..add('--sparse')..add('--sparse-version=$sparseVersion');
  }
  final tar = await startTar(args, baseDir: baseDir);
  yield* tar.stdout;
}

Future<Process> writeToTar(List<String> args, Stream<TarEntry> entries, {OutputFormat format = OutputFormat.pax}) async {
  final proc = await startTar(args);
  await entries.pipe(TarEncoderSinkImpl(proc.stdin, format));
  return proc;
}

extension ProcessUtils on Process {
  Stream<String> get lines => this.stdout.transform(utf8.decoder).transform(const LineSplitter());
}
