import 'dart:async';
import 'dart:typed_data';

import 'package:tar/entry/impl/entry.dart';
import 'package:tar/entry/interface/entry.dart';
import 'package:tar/header/impl/header.dart';
import 'package:tar/writer.dart';
import 'package:test/test.dart';

import 'system_tar.dart';

const oneMbSize = 1024 * 1024;
const tenGbSize = oneMbSize * 1024 * 10;

void main() {
  group('writes long file names', () {
    for (final style in OutputFormat.values) {
      test(style.toString(), () async {
        final name = '${'very' * 30} long name.txt';
        final withLongName = TarEntryImpl(
          TarHeaderImpl(name: name, mode: 0, size: 0),
          Stream.value([]),
        );
        final proc = await writeToTar(
          ['--list'],
          Stream.value(withLongName),
          format: style,
        );
        expect(proc.lines, emits(contains(name)));
      });
    }
  }, testOn: '!windows');
  test('writes headers', () async {
    final date = DateTime.parse('2020-12-30 12:34');
    final entry = TarEntryImpl(
      TarHeaderImpl(
        name: 'hello_dart.txt',
        mode: int.parse('744', radix: 8),
        size: 0,
        userId: 3,
        groupId: 4,
        userName: 'my_user',
        groupName: 'long group that exceeds 32 characters',
        modified: date,
      ),
      Stream.value([]),
    );
    final proc = await writeToTar(['--list', '--verbose'], Stream.value(entry));
    expect(
      proc.lines,
      emits(
        allOf(
          contains('-rwxr--r--'),
          contains('my_user'),
          contains('long group that exceeds 32 characters'),
          contains('12:34'),
        ),
      ),
    );
  }, testOn: '!windows');
  test('writes huge files', () async {
    final oneMb = Uint8List(oneMbSize);
    const count = tenGbSize ~/ oneMbSize;
    final entry = TarEntryImpl(
      TarHeaderImpl(
        name: 'file.blob',
        mode: 0,
        size: tenGbSize,
      ),
      Stream<List<int>>.fromIterable(Iterable.generate(count, (i) => oneMb)),
    );
    final proc = await writeToTar(['--list', '--verbose'], Stream.value(entry));
    expect(proc.lines, emits(contains(tenGbSize.toString())));
  }, testOn: '!windows');
  group('refuses to write files with OutputFormat.gnu', () {
    void shouldThrow(TarEntry entry) {
      final output = tarWritingSink(_NullStreamSink(), format: OutputFormat.gnuLongName);
      expect(Stream.value(entry).pipe(output), throwsA(isUnsupportedError));
    }

    test('when they are too large', () {
      final oneMb = Uint8List(oneMbSize);
      const count = tenGbSize ~/ oneMbSize;
      final entry = TarEntryImpl(
        TarHeaderImpl(
          name: 'file.blob',
          mode: 0,
          size: tenGbSize,
        ),
        Stream<List<int>>.fromIterable(Iterable.generate(count, (i) => oneMb)),
      );
      shouldThrow(entry);
    });
    test('when they use long user names', () {
      shouldThrow(
        TarEntryImpl(
          TarHeaderImpl(name: 'file.txt', userName: 'this name is longer than 32 chars, which is not allowed', size: 0),
          Stream.value([]),
        ),
      );
    });
  });
}

class _NullStreamSink<T> extends StreamSink<T> {
  _NullStreamSink();

  @override
  void add(T event) {}

  @override
  void addError(Object error, [StackTrace? stackTrace]) {
    // ignore: only_throw_errors
    throw error;
  }

  @override
  Future<void> addStream(Stream<T> stream) => stream.forEach(add);

  @override
  Future<void> close() async {}

  @override
  Future<void> get done => close();
}
