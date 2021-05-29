import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:tarzan/simon_tar/impl/format.dart';
import 'package:tarzan/simon_tar/impl/header.dart';
import 'package:tarzan/simon_tar/impl/tar_decoder.dart';
import 'package:tarzan/simon_tar/interface/flags.dart';
import 'package:tarzan/simon_tar/interface/header.dart';
import 'package:tarzan/simon_tar/interface/tar_exception.dart';
import 'package:tarzan/simon_tar/util/ms_since_epoch.dart';
import 'package:tarzan/simon_tar/util/us_since_epoch.dart';
import 'package:test/test.dart';

void main() {
  group('POSIX.1-2001', () {
    test(
      'reads files',
      () => _testWith('reference/posix.tar'),
    );
    test(
      'reads large files',
      () => _testLargeFile('reference/headers/large_posix.tar'),
    );
  });
  test(
    '(new) GNU Tar format',
    () => _testWith('reference/gnu.tar'),
  );
  test(
    'ustar',
    () => _testWith('reference/ustar.tar'),
  );
  test(
    'v7',
    () => _testWith('reference/v7.tar', ignoreLongFileName: true),
  );
  test('can skip tar files', () async {
    final input = File('reference/posix.tar').openRead();
    final reader = TarDecoderImpl(input);
    expect(await reader.moveNext(), isTrue);
    expect(await reader.moveNext(), isTrue);
    expect(reader.current.name, 'reference/res/subdirectory_with_a_long_name/');
  });
  test('getters throw before moveNext() is called', () {
    final reader = TarDecoderImpl(const Stream<Never>.empty());
    expect(() => reader.current, throwsStateError);
  });
  test("can't use moveNext() concurrently", () {
    final reader = TarDecoderImpl(Stream.fromFuture(Future.delayed(const Duration(seconds: 2), () => <int>[])));
    expect(reader.moveNext(), completion(isFalse));
    expect(() => reader.moveNext(), throwsStateError);
    return reader.cancel();
  });
  test("can't use moveNext() while a stream is active", () async {
    final input = File('reference/posix.tar').openRead();
    final reader = TarDecoderImpl(input);
    expect(await reader.moveNext(), isTrue);
    reader.current.contents.listen((event) {}).pause();
    expect(() => reader.moveNext(), throwsStateError);
    await reader.cancel();
  });
  test("can't use moveNext() after canceling the reader", () async {
    final input = File('reference/posix.tar').openRead();
    final reader = TarDecoderImpl(input);
    await reader.cancel();
    expect(() => reader.moveNext(), throwsStateError);
  });
  group('the reader closes itself', () {
    test("at the end of a file", () async {
      // two zero blocks terminate a tar file
      final zeroBlock = Uint8List(512);
      final controller = StreamController<List<int>>();
      controller.onListen = () {
        controller..add(zeroBlock)..add(zeroBlock)..add(zeroBlock);
      };
      final reader = TarDecoderImpl(controller.stream);
      await expectLater(reader.moveNext(), completion(isFalse));
      expect(controller.hasListener, isFalse);
      await controller.close();
    });
    test('if the stream emits an error in headers', () async {
      final controller = StreamController<List<int>>();
      controller.onListen = () {
        controller.addError('foo');
      };
      final reader = TarDecoderImpl(controller.stream);
      await expectLater(reader.moveNext(), throwsA('foo'));
      expect(controller.hasListener, isFalse);
      await controller.close();
    });
    test('if the stream emits an error in content', () async {
      // Craft a stream that starts with a valid tar file, but then emits an
      // error in the middle of an entry. First 512 bytes are headers.
      final iterator = ChunkedStreamReader(File('reference/v7.tar').openRead());
      final controller = StreamController<List<int>>();
      controller.onListen = () async {
        // headers + 3 bytes of content
        await controller.addStream(iterator.readStream(515));
        controller.addError('foo');
      };
      final reader = TarDecoderImpl(controller.stream);
      await expectLater(reader.moveNext(), completion(isTrue));
      await expectLater(reader.current.contents, emitsThrough(emitsError('foo')));
      expect(controller.hasListener, isFalse);
      await iterator.cancel();
      await controller.close();
    });
  });
  group('disallowTrailingData: true', () {
    final emptyBlock = Uint8List(512);
    void closeLater(StreamController<Object?> controller) {
      controller.onCancel = () => fail('Should not cancel stream subscription');
      Timer.run(() {
        // Calling close() implicitly cancels the stream subscription, we only
        // want to ensure that the reader is not doing that.
        controller.onCancel = null;
        expect(controller.hasListener, isTrue, reason: 'Should have a listener');
        controller.close();
      });
    }

    test('throws for trailing data', () async {
      final input = StreamController<Uint8List>()
        ..add(emptyBlock)
        ..add(emptyBlock)
        // illegal content after end marker
        ..add(Uint8List.fromList([0, 1, 2, 3]));
      // The reader checks for empty data in chunks, so we timeout if the stream
      // goes stale.
      Timer.run(input.close);
      final reader = TarDecoderImpl(input.stream, disallowTrailingData: true);
      await expectLater(reader.moveNext(), throwsA(isA<TarException>()));
      expect(input.hasListener, isFalse, reason: 'Should have cancelled subscription after error.');
    });
    test('does not throw or cancel if the stream ends as expected', () {
      final input = StreamController<Uint8List>()..add(emptyBlock)..add(emptyBlock);
      closeLater(input);
      final reader = TarDecoderImpl(input.stream, disallowTrailingData: true);
      expectLater(reader.moveNext(), completion(isFalse));
    });
    test('does not throw or cancel when there are many empty blocks', () {
      final input = StreamController<Uint8List>();
      for (var i = 0; i < 100; i++) {
        input.add(emptyBlock);
      }
      closeLater(input);
      final reader = TarDecoderImpl(input.stream, disallowTrailingData: true);
      expectLater(reader.moveNext(), completion(isFalse));
    });
    test('does not throw or cancel if the stream ends without marker', () {
      final input = StreamController<Uint8List>();
      closeLater(input);
      final reader = TarDecoderImpl(input.stream, disallowTrailingData: true);
      expectLater(reader.moveNext(), completion(isFalse));
    });
  });
  group('tests from dart-neats PR', () {
    Stream<List<int>> open(String name) {
      return File('reference/neats_test/$name').openRead();
    }
    final tests = [
      {
        'file': 'gnu.tar',
        'headers': <TarHeader>[
          TarHeaderImpl(
            name: 'small.txt',
            mode: 436,
            userId: 1000,
            groupId: 1000,
            size: 3,
            modified: millisecondsSinceEpoch(1597755680000),
            typeFlag: TypeFlags.reg,
            userName: 'garett',
            groupName: 'garett',
            format: TarFormats.gnu,
          ),
          TarHeaderImpl(
            name: 'small2.txt',
            mode: 436,
            userId: 1000,
            groupId: 1000,
            size: 8,
            modified: millisecondsSinceEpoch(1597755958000),
            typeFlag: TypeFlags.reg,
            userName: 'garett',
            groupName: 'garett',
            format: TarFormats.gnu,
          )
        ],
      },
      {
        'file': 'sparse-formats.tar',
        'headers': <TarHeader>[
          TarHeaderImpl(
            name: 'sparse-gnu',
            mode: 420,
            userId: 1000,
            groupId: 1000,
            size: 200,
            modified: millisecondsSinceEpoch(1597756151000),
            typeFlag: TypeFlags.gnuSparse,
            userName: 'jonas',
            groupName: 'jonas',
            devMajor: 0,
            devMinor: 0,
            format: TarFormats.gnu,
          ),
          TarHeaderImpl(
            name: 'sparse-posix-v-0-0',
            mode: 420,
            userId: 1000,
            groupId: 1000,
            size: 200,
            modified: millisecondsSinceEpoch(1597756151000),
            typeFlag: TypeFlags.reg,
            userName: 'jonas',
            groupName: 'jonas',
            devMajor: 0,
            devMinor: 0,
            format: TarFormats.pax,
          ),
          TarHeaderImpl(
            name: 'sparse-posix-0-1',
            mode: 420,
            userId: 1000,
            groupId: 1000,
            size: 200,
            modified: millisecondsSinceEpoch(1597756151000),
            typeFlag: TypeFlags.reg,
            userName: 'jonas',
            groupName: 'jonas',
            devMajor: 0,
            devMinor: 0,
            format: TarFormats.pax,
          ),
          TarHeaderImpl(
            name: 'sparse-posix-1-0',
            mode: 420,
            userId: 1000,
            groupId: 1000,
            size: 200,
            modified: millisecondsSinceEpoch(1597756151000),
            typeFlag: TypeFlags.reg,
            userName: 'jonas',
            groupName: 'jonas',
            devMajor: 0,
            devMinor: 0,
            format: TarFormats.pax,
          ),
          TarHeaderImpl(
            name: 'end',
            mode: 420,
            userId: 1000,
            groupId: 1000,
            size: 4,
            modified: millisecondsSinceEpoch(1597756151000),
            typeFlag: TypeFlags.reg,
            userName: 'jonas',
            groupName: 'jonas',
            devMajor: 0,
            devMinor: 0,
            format: TarFormats.gnu,
          )
        ],
      },
      {
        'file': 'star.tar',
        'headers': [
          TarHeaderImpl(
            name: 'small.txt',
            mode: 416,
            userId: 1000,
            groupId: 1000,
            size: 3,
            modified: millisecondsSinceEpoch(1597755680000),
            typeFlag: TypeFlags.reg,
            userName: 'garett',
            groupName: 'garett',
            accessed: millisecondsSinceEpoch(1597755680000),
            changed: millisecondsSinceEpoch(1597755680000),
            format: TarFormats.star,
          ),
          TarHeaderImpl(
            name: 'small2.txt',
            mode: 416,
            userId: 1000,
            groupId: 1000,
            size: 7,
            modified: millisecondsSinceEpoch(1597755958000),
            typeFlag: TypeFlags.reg,
            userName: 'garett',
            groupName: 'garett',
            accessed: millisecondsSinceEpoch(1597755958000),
            changed: millisecondsSinceEpoch(1597755958000),
            format: TarFormats.star,
          )
        ]
      },
      {
        'file': 'v7.tar',
        'headers': [
          TarHeaderImpl(
            name: 'small.txt',
            mode: 436,
            userId: 1000,
            groupId: 1000,
            size: 3,
            modified: millisecondsSinceEpoch(1597755680000),
            typeFlag: TypeFlags.reg,
            format: TarFormats.v7,
          ),
          TarHeaderImpl(
            name: 'small2.txt',
            mode: 436,
            userId: 1000,
            groupId: 1000,
            size: 8,
            modified: millisecondsSinceEpoch(1597755958000),
            typeFlag: TypeFlags.reg,
            format: TarFormats.v7,
          )
        ],
      },
      {
        'file': 'ustar.tar',
        'headers': [
          TarHeaderImpl(
            name: 'small.txt',
            mode: 436,
            userId: 1000,
            groupId: 1000,
            size: 3,
            modified: millisecondsSinceEpoch(1597755680000),
            typeFlag: TypeFlags.reg,
            userName: 'garett',
            groupName: 'garett',
            format: TarFormats.ustar,
          ),
          TarHeaderImpl(
            name: 'small2.txt',
            mode: 436,
            userId: 1000,
            groupId: 1000,
            size: 8,
            modified: millisecondsSinceEpoch(1597755958000),
            typeFlag: TypeFlags.reg,
            userName: 'garett',
            groupName: 'garett',
            format: TarFormats.ustar,
          )
        ],
      },
      {
        'file': 'pax.tar',
        'headers': [
          TarHeaderImpl(
            name:
                'a/123456789101112131415161718192021222324252627282930313233343536373839404142434445464748495051525354555657585960616263646566676869707172737475767778798081828384858687888990919293949596979899100',
            mode: 436,
            userId: 1000,
            groupId: 1000,
            userName: 'jonas',
            groupName: 'fj',
            size: 7,
            modified: microsecondsSinceEpoch(1597823492427388),
            changed: microsecondsSinceEpoch(1597823492427388),
            accessed: microsecondsSinceEpoch(1597823492427388),
            typeFlag: TypeFlags.reg,
            format: TarFormats.pax,
          ),
          TarHeaderImpl(
            name: 'a/b',
            mode: 511,
            userId: 1000,
            groupId: 1000,
            userName: 'garett',
            groupName: 'tok',
            size: 0,
            modified: microsecondsSinceEpoch(1597823492427388),
            changed: microsecondsSinceEpoch(1597823492427388),
            accessed: microsecondsSinceEpoch(1597823492427388),
            typeFlag: TypeFlags.symlink,
            linkName:
                '123456789101112131415161718192021222324252627282930313233343536373839404142434445464748495051525354555657585960616263646566676869707172737475767778798081828384858687888990919293949596979899100',
            format: TarFormats.pax,
          ),
        ]
      },
      {
        // PAX record with bad record length.
        'file': 'pax-bad-record-length.tar',
        'error': true,
      },
      {
        // PAX record with non-numeric mtime
        'file': 'pax-bad-mtime.tar',
        'error': true,
      },
      {
        'file': 'pax-pos-size-file.tar',
        'headers': [
          TarHeaderImpl(
            name: 'bar',
            mode: 416,
            userId: 143077,
            groupId: 1000,
            size: 999,
            modified: millisecondsSinceEpoch(1597755680000),
            typeFlag: TypeFlags.reg,
            userName: 'jonasfj',
            groupName: 'jfj',
            format: TarFormats.pax,
          ),
        ],
      },
      {
        'file': 'pax-records.tar',
        'headers': [
          TarHeaderImpl(
            typeFlag: TypeFlags.reg,
            size: 0,
            name: 'pax-records',
            mode: 416,
            userName: 'walnut',
            modified: millisecondsSinceEpoch(0),
            format: TarFormats.pax,
          )
        ],
      },
      {
        'file': 'nil-gid-uid.tar',
        'headers': [
          TarHeaderImpl(
            name: 'nil-gid.txt',
            mode: 436,
            userId: 1000,
            groupId: 0,
            size: 3,
            modified: millisecondsSinceEpoch(1597755680000),
            typeFlag: TypeFlags.reg,
            userName: 'garett',
            groupName: 'garett',
            devMajor: 0,
            devMinor: 0,
            format: TarFormats.gnu,
          ),
          TarHeaderImpl(
            name: 'nil-uid.txt',
            mode: 436,
            userId: 0,
            groupId: 1000,
            size: 7,
            modified: millisecondsSinceEpoch(1597755958000),
            typeFlag: TypeFlags.reg,
            userName: 'garett',
            groupName: 'garett',
            devMajor: 0,
            devMinor: 0,
            format: TarFormats.gnu,
          )
        ]
      },
      {
        'file': 'xattrs.tar',
        'headers': [
          TarHeaderImpl(
            name: 'small.txt',
            mode: 420,
            userId: 1000,
            groupId: 10,
            size: 5,
            modified: microsecondsSinceEpoch(1597823492427388),
            typeFlag: TypeFlags.reg,
            userName: 'garett',
            groupName: 'tok',
            accessed: microsecondsSinceEpoch(1597823492427388),
            changed: microsecondsSinceEpoch(1597823492427388),
            format: TarFormats.pax,
          ),
          TarHeaderImpl(
            name: 'small2.txt',
            mode: 420,
            userId: 1000,
            groupId: 10,
            size: 11,
            modified: microsecondsSinceEpoch(1597823492427388),
            typeFlag: TypeFlags.reg,
            userName: 'garett',
            groupName: 'tok',
            accessed: microsecondsSinceEpoch(1597823492427388),
            changed: microsecondsSinceEpoch(1597823492427388),
            format: TarFormats.pax,
          )
        ]
      },
      {
        // Matches the behavior of GNU, BSD, and STAR tar utilities.
        'file': 'gnu-multi-hdrs.tar',
        'headers': [
          TarHeaderImpl(
            name: 'long-path-name',
            size: 0,
            linkName: 'long-linkpath-name',
            userId: 1000,
            groupId: 1000,
            modified: millisecondsSinceEpoch(1597756829000),
            typeFlag: TypeFlags.symlink,
            format: TarFormats.gnu,
          )
        ],
      },
      {
        // GNU tar 'file' with atime and ctime fields set.
        // Old GNU incremental backup.
        //
        // Created with the GNU tar v1.27.1.
        //	tar --incremental -S -cvf gnu-incremental.tar test2
        'file': 'gnu-incremental.tar',
        'headers': [
          TarHeaderImpl(
            name: 'incremental/',
            mode: 16877,
            userId: 1000,
            groupId: 1000,
            size: 14,
            modified: millisecondsSinceEpoch(1597755680000),
            typeFlag: TypeFlags.vendor,
            userName: 'fizz',
            groupName: 'foobar',
            accessed: millisecondsSinceEpoch(1597755680000),
            changed: millisecondsSinceEpoch(1597755033000),
            format: TarFormats.gnu,
          ),
          TarHeaderImpl(
            name: 'incremental/foo',
            mode: 33188,
            userId: 1000,
            groupId: 1000,
            size: 64,
            modified: millisecondsSinceEpoch(1597755688000),
            typeFlag: TypeFlags.reg,
            userName: 'fizz',
            groupName: 'foobar',
            accessed: millisecondsSinceEpoch(1597759641000),
            changed: millisecondsSinceEpoch(1597755793000),
            format: TarFormats.gnu,
          ),
          TarHeaderImpl(
            name: 'incremental/sparse',
            mode: 33188,
            userId: 1000,
            groupId: 1000,
            size: 536870912,
            modified: millisecondsSinceEpoch(1597755776000),
            typeFlag: TypeFlags.gnuSparse,
            userName: 'fizz',
            groupName: 'foobar',
            accessed: millisecondsSinceEpoch(1597755703000),
            changed: millisecondsSinceEpoch(1597755602000),
            format: TarFormats.gnu,
          )
        ]
      },
      {
        // Matches the behavior of GNU and BSD tar utilities.
        'file': 'pax-multi-hdrs.tar',
        'headers': [
          TarHeaderImpl(
            name: 'baz',
            size: 0,
            linkName: 'bzzt/bzzt/bzzt/bzzt/bzzt/baz',
            modified: millisecondsSinceEpoch(0),
            typeFlag: TypeFlags.symlink,
            format: TarFormats.pax,
          )
        ]
      },
      {
        // Both BSD and GNU tar truncate long names at first NUL even
        // if there is data following that NUL character.
        // This is reasonable as GNU long names are C-strings.
        'file': 'gnu-long-nul.tar',
        'headers': [
          TarHeaderImpl(
            name: '9876543210',
            size: 0,
            mode: 420,
            userId: 1000,
            groupId: 1000,
            modified: millisecondsSinceEpoch(1597755682000),
            typeFlag: TypeFlags.reg,
            format: TarFormats.gnu,
            userName: 'jensen',
            groupName: 'jensen',
          )
        ]
      },
      {
        // This archive was generated by Writer but is readable by both
        // GNU and BSD tar utilities.
        // The archive generated by GNU is nearly byte-for-byte identical
        // to the Go version except the Go version sets a negative devMinor
        // just to force the GNU format.
        'file': 'gnu-utf8.tar',
        'headers': [
          TarHeaderImpl(
            name: '🧸',
            size: 0,
            mode: 420,
            userId: 525,
            groupId: 600,
            modified: millisecondsSinceEpoch(0),
            typeFlag: TypeFlags.reg,
            userName: '🐻',
            groupName: '🥭',
            format: TarFormats.gnu,
          )
        ]
      },
      {
        'file': 'gnu-non-utf8-name.tar',
        'headers': [
          TarHeaderImpl(
            name: 'pub\x80\x81\x82\x83dev',
            size: 0,
            mode: 422,
            userId: 1234,
            groupId: 5678,
            modified: millisecondsSinceEpoch(0),
            typeFlag: TypeFlags.reg,
            userName: 'walnut',
            groupName: 'dust',
            format: TarFormats.gnu,
          )
        ]
      },
      {
        // BSD tar v3.1.2 and GNU tar v1.27.1 both rejects PAX records
        // with NULs in the key.
        'file': 'pax-nul-xattrs.tar',
        'error': true,
      },
      {
        // BSD tar v3.1.2 rejects a PAX path with NUL in the value, while
        // GNU tar v1.27.1 simply truncates at first NUL.
        // We emulate the behavior of BSD since it is strange doing NUL
        // truncations since PAX records are length-prefix strings instead
        // of NUL-terminated C-strings.
        'file': 'pax-nul-path.tar',
        'error': true,
      },
      {
        // Malformed sparse file
        'file': 'malformed-sparse-file.tar',
        'error': true,
      },
      {
        // PAX records that do not have a new line at the end.
        'file': 'invalid-pax-headers.tar',
        'error': true,
      },
      {
        // Invalid user id
        'file': 'invalid-uid.tar',
        'error': true,
      },
      {
        // USTAR archive with a regular entry with non-zero device numbers.
        'file': 'ustar-nonzero-device-numbers.tar',
        'headers': [
          TarHeaderImpl(
            name: 'file',
            size: 0,
            mode: 420,
            typeFlag: TypeFlags.reg,
            modified: millisecondsSinceEpoch(0),
            userName: 'Jonas',
            groupName: 'Google',
            devMajor: 1,
            devMinor: 1,
            format: TarFormats.ustar,
          )
        ]
      },
      {
        // Works on BSD tar v3.1.2 and GNU tar v.1.27.1.
        'file': 'gnu-nil-sparse-data.tar',
        'headers': [
          TarHeaderImpl(
            name: 'nil-sparse-data',
            typeFlag: TypeFlags.gnuSparse,
            userId: 1000,
            groupId: 1000,
            size: 1000,
            modified: millisecondsSinceEpoch(1597756076000),
            format: TarFormats.gnu,
          )
        ],
      },
      {
        // Works on BSD tar v3.1.2 and GNU tar v.1.27.1.
        'file': 'gnu-nil-sparse-hole.tar',
        'headers': [
          TarHeaderImpl(
            name: 'nil-sparse-hole',
            typeFlag: TypeFlags.gnuSparse,
            size: 1000,
            userId: 1000,
            groupId: 1000,
            modified: millisecondsSinceEpoch(1597756079000),
            format: TarFormats.gnu,
          )
        ]
      },
      {
        // Works on BSD tar v3.1.2 and GNU tar v.1.27.1.
        'file': 'pax-nil-sparse-data.tar',
        'headers': [
          TarHeaderImpl(
            name: 'sparse',
            typeFlag: TypeFlags.reg,
            size: 1000,
            userId: 1000,
            groupId: 1000,
            modified: millisecondsSinceEpoch(1597756076000),
            format: TarFormats.pax,
          )
        ]
      },
      {
        // Works on BSD tar v3.1.2 and GNU tar v.1.27.1.
        'file': 'pax-nil-sparse-hole.tar',
        'headers': [
          TarHeaderImpl(
            name: 'sparse.txt',
            typeFlag: TypeFlags.reg,
            size: 1000,
            userId: 1000,
            groupId: 1000,
            modified: millisecondsSinceEpoch(1597756077000),
            format: TarFormats.pax,
          )
        ]
      },
      {
        'file': 'trailing-slash.tar',
        'headers': [
          TarHeaderImpl(
            typeFlag: TypeFlags.dir,
            size: 0,
            name: '987654321/' * 30,
            modified: millisecondsSinceEpoch(0),
            format: TarFormats.pax,
          )
        ]
      },
      {
        'file': 'pax-non-ascii-name.tar',
        'headers': [
          TarHeaderImpl(
            name: 'æøå/',
            mode: 493,
            size: 0,
            userName: 'sigurdm',
            userId: 224757,
            groupId: 89939,
            groupName: 'primarygroup',
            format: TarFormats.pax,
            typeFlag: TypeFlags.dir,
            modified: DateTime.utc(2020, 10, 13, 13, 04, 32, 608, 662),
          ),
          TarHeaderImpl(
            name: 'æøå/æøå.dart',
            mode: 420,
            size: 1024,
            userName: 'sigurdm',
            userId: 224757,
            groupId: 89939,
            groupName: 'primarygroup',
            format: TarFormats.pax,
            typeFlag: TypeFlags.reg,
            modified: DateTime.utc(2020, 10, 13, 13, 05, 12, 105, 884),
          ),
        ]
      }
    ];
    Matcher matchesHeader(TarHeader expected) => isA<TarHeader>()
        .having((e) => e.name, 'name', expected.name)
        .having((e) => e.modified, 'modified', expected.modified)
        .having((e) => e.linkName, 'linkName', expected.linkName)
        .having((e) => e.mode, 'mode', expected.mode)
        .having((e) => e.size, 'size', expected.size)
        .having((e) => e.userName, 'userName', expected.userName)
        .having((e) => e.userId, 'userId', expected.userId)
        .having((e) => e.groupId, 'groupId', expected.groupId)
        .having((e) => e.groupName, 'groupName', expected.groupName)
        .having((e) => e.accessed, 'accessed', expected.accessed)
        .having((e) => e.changed, 'changed', expected.changed)
        .having((e) => e.devMajor, 'devMajor', expected.devMajor)
        .having((e) => e.devMinor, 'devMinor', expected.devMinor)
        .having((e) => e.format, 'format', expected.format)
        .having((e) => e.typeFlag, 'typeFlag', expected.typeFlag);
    for (final testInputs in tests) {
      test('${testInputs['file']}', () async {
        final tarReader = TarDecoderImpl(open(testInputs['file']! as String), maxSpecialFileSize: 16000);
        if (testInputs['error'] == true) {
          expect(tarReader.moveNext(), throwsFormatException);
        } else {
          final expectedHeaders = testInputs['headers']! as List<TarHeader>;
          for (var i = 0; i < expectedHeaders.length; i++) {
            expect(await tarReader.moveNext(), isTrue);
            expect(tarReader.current.header, matchesHeader(expectedHeaders[i]));
          }
          expect(await tarReader.moveNext(), isFalse);
        }
      });
    }
    test('reader procudes an empty stream if the entry has no size', () async {
      final reader = TarDecoderImpl(open('trailing-slash.tar'));
      while (await reader.moveNext()) {
        expect(await reader.current.contents.toList(), isEmpty);
      }
    });
  });
  test('does not read large headers', () {
    final reader = TarDecoderImpl(File('reference/headers/evil_large_header.tar').openRead());
    expect(
      reader.moveNext(),
      throwsA(
        isFormatException.having((e) => e.message, 'message', contains('hidden entry with an invalid size')),
      ),
    );
  });
  group('throws on unexpected EoF', () {
    test('at header', () {
      final reader = TarDecoderImpl(File('reference/bad/truncated_in_header.tar').openRead());
      expect(reader.moveNext(), throwsA(isA<TarExceptionHeaderUnexpectedEndOfFileImpl>()));
    });
    test('in content', () {
      final reader = TarDecoderImpl(File('reference/bad/truncated_in_body.tar').openRead());
      expect(reader.moveNext(), throwsA(isA<TarExceptionHeaderUnexpectedEndOfFileImpl>()));
    });
  });
  group('PAX headers', () {
    test('locals overrwrite globals', () {
      final header = PaxHeadersImpl({'foo': 'foo', 'bar': 'bar'}, {'foo': 'local'});
      expect(header.keys, containsAll(<String>['foo', 'bar']));
      expect(header.get('foo'), 'local');
    });
    group('parse', () {
      final mediumName = 'CD' * 50;
      final longName = 'AB' * 100;
      final tests = [
        ['6 k=v\n\n', 'k', 'v', true],
        ['19 path=/etc/hosts\n', 'path', '/etc/hosts', true],
        ['210 path=' + longName + '\nabc', 'path', longName, true],
        ['110 path=' + mediumName + '\n', 'path', mediumName, true],
        ['9 foo=ba\n', 'foo', 'ba', true],
        ['11 foo=bar\n\x00', 'foo', 'bar', true],
        ['18 foo=b=\nar=\n==\x00\n', 'foo', 'b=\nar=\n==\x00', true],
        ['27 foo=hello9 foo=ba\nworld\n', 'foo', 'hello9 foo=ba\nworld', true],
        ['27 ☺☻☹=日a本b語ç\n', '☺☻☹', '日a本b語ç', true],
        ['17 \x00hello=\x00world\n', '', '', false],
        ['1 k=1\n', '', '', false],
        ['6 k~1\n', '', '', false],
        ['6 k=1 ', '', '', false],
        ['632 k=1\n', '', '', false],
        ['16 longkeyname=hahaha\n', '', '', false],
        ['3 somelongkey=\n', '', '', false],
        ['50 tooshort=\n', '', '', false],
      ];
      for (var i = 0; i < tests.length; i++) {
        final input = tests[i];
        test('parsePax #$i', () {
          final headers = PaxHeadersImpl.empty();
          final raw = utf8.encode(input[0] as String);
          final key = input[1];
          final value = input[2];
          final isValid = input[3] as bool;
          if (isValid) {
            headers.readPaxHeaders(raw, false, false);
            expect(headers.keys, [key]);
            expect(headers.get(key), value);
          } else {
            expect(() => headers.readPaxHeaders(raw, false, true), throwsA(isA<TarException>()));
          }
        });
      }
    });
  });
}

Future<void> _testWith(String file, {bool ignoreLongFileName = false}) async {
  final entries = <String, Uint8List>{};
  await TarDecoderImpl.forEach(File(file).openRead(), (entry) async {
    entries[entry.name] = await entry.contents.readFully();
  });
  final testEntry = entries['reference/res/test.txt']!;
  expect(utf8.decode(testEntry), 'Test file content!\n');
  if (!ignoreLongFileName) {
    final longName = entries['reference/res/'
        'subdirectory_with_a_long_name/'
        'file_with_a_path_length_of_more_than_100_characters_so_that_it_gets_split.txt']!;
    expect(utf8.decode(longName), 'ditto');
  }
}

Future<void> _testLargeFile(String file) async {
  final reader = TarDecoderImpl(File(file).openRead());
  await reader.moveNext();
  expect(reader.current.size, 9663676416);
}

extension on Stream<List<int>> {
  Future<Uint8List> readFully() async {
    final builder = BytesBuilder();
    await forEach(builder.add);
    return builder.takeBytes();
  }
}