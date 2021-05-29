import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:tarzan/base/impl/archive.dart';
import 'package:tarzan/base/impl/file.dart';
import 'package:tarzan/gzip/impl/gzip_decoder.dart';
import 'package:tarzan/tar/impl/tar_decoder.dart';
import 'package:tarzan/tar/impl/tar_encoder.dart';
import 'package:tarzan/tar/impl/tar_file.dart';
import 'package:test/test.dart';

import '../test_utils.dart';

final tarTests = [
  {
    'file': 'res/tar/gnu.tar',
    'headers': [
      {
        'Name': 'small.txt',
        'Mode': int.parse('0640', radix: 8),
        'Uid': 73025,
        'Gid': 5000,
        'Size': 5,
        'ModTime': 1244428340,
        'Typeflag': '0',
        'Uname': 'dsymonds',
        'Gname': 'eng',
      },
      {
        'Name': 'small2.txt',
        'Mode': int.parse('0640', radix: 8),
        'Uid': 73025,
        'Gid': 5000,
        'Size': 11,
        'ModTime': 1244436044,
        'Typeflag': '0',
        'Uname': 'dsymonds',
        'Gname': 'eng',
      }
    ],
    'cksums': [
      'e38b27eaccb4391bdec553a7f3ae6b2f',
      'c65bd2e50a56a2138bf1716f2fd56fe9',
    ],
  },
  {
    'file': 'res/tar/star.tar',
    'headers': [
      {
        'Name': 'small.txt',
        'Mode': int.parse('0640', radix: 8),
        'Uid': 73025,
        'Gid': 5000,
        'Size': 5,
        'ModTime': 1244592783,
        'Typeflag': '0',
        'Uname': 'dsymonds',
        'Gname': 'eng',
        'AccessTime': 1244592783,
        'ChangeTime': 1244592783,
      },
      {
        'Name': 'small2.txt',
        'Mode': int.parse('0640', radix: 8),
        'Uid': 73025,
        'Gid': 5000,
        'Size': 11,
        'ModTime': 1244592783,
        'Typeflag': '0',
        'Uname': 'dsymonds',
        'Gname': 'eng',
        'AccessTime': 1244592783,
        'ChangeTime': 1244592783,
      },
    ],
  },
  {
    'file': 'res/tar/v7.tar',
    'headers': [
      {
        'Name': 'small.txt',
        'Mode': int.parse('0444', radix: 8),
        'Uid': 73025,
        'Gid': 5000,
        'Size': 5,
        'ModTime': 1244593104,
        'Typeflag': '',
      },
      {
        'Name': 'small2.txt',
        'Mode': int.parse('0444', radix: 8),
        'Uid': 73025,
        'Gid': 5000,
        'Size': 11,
        'ModTime': 1244593104,
        'Typeflag': '',
      },
    ],
  },
  /*{
    'file': 'res/tar/pax.tar',
    'headers': [
      {
        'Name':       'a/123456789101112131415161718192021222324252627282930313233343536373839404142434445464748495051525354555657585960616263646566676869707172737475767778798081828384858687888990919293949596979899100',
        'Mode':       int.parse('0664',radix: 8),
        'Uid':        1000,
        'Gid':        1000,
        'Uname':      'shane',
        'Gname':      'shane',
        'Size':       7,
        'ModTime':    1350244992,
        'ChangeTime': 1350244992,
        'AccessTime': 1350244992,
        'Typeflag':   TarFile.TYPE_NORMAL_FILE,
      },
      {
        'Name':       'a/b',
        'Mode':       int.parse('0777',radix: 8),
        'Uid':        1000,
        'Gid':        1000,
        'Uname':      'shane',
        'Gname':      'shane',
        'Size':       0,
        'ModTime':    1350266320,
        'ChangeTime': 1350266320,
        'AccessTime': 1350266320,
        'Typeflag':   TarFile.TYPE_SYMBOLIC_LINK,
        'Linkname':   '123456789101112131415161718192021222324252627282930313233343536373839404142434445464748495051525354555657585960616263646566676869707172737475767778798081828384858687888990919293949596979899100',
      },
    ],
  },*/
  {
    'file': 'res/tar/nil-uid.tar',
    'headers': [
      <String, dynamic>{
        'Name': 'P1050238.JPG.log',
        'Mode': int.parse('0664', radix: 8),
        'Uid': 0,
        'Gid': 0,
        'Size': 14,
        'ModTime': 1365454838,
        'Typeflag': TarFileImpl.TYPE_NORMAL_FILE,
        'Linkname': '',
        'Uname': 'eyefi',
        'Gname': 'eyefi',
        'Devmajor': 0,
        'Devminor': 0,
      },
    ],
  },
];

void main() {
  const tar = TarDecoderImpl();
  const  tarEncoder = TarEncoderImpl();
  test('tar invalid archive', () {
    try {
      const TarDecoderImpl().decodeBytes([1, 2, 3]);
      assert(false, "must fail");
      // ignore: avoid_catches_without_on_clauses
    } catch (e) {
      // pass
    }
  });
  test('tar file', () {
    const TarEncoderImpl().encode(ArchiveImpl()..addFile(ArchiveFileImpl('file.txt', 1, [100])));
  });
  test('long file name', () {
    final file = File(p.join(testDirPath, 'res/tar/x.tar'));
    final bytes = file.readAsBytesSync();
    final archive = tar.decodeBytes(bytes, verify: true);
    expect(archive.numberOfFiles(), equals(1));
    var x = '';
    for (var i = 0; i < 150; ++i) {
      // ignore: use_string_buffers
      x += 'x';
    }
    x += '.txt';
    expect(archive.first.name, equals(x));
  });
  test('symlink', () {
    final file = File(p.join(testDirPath, 'res/tar/symlink_tar.tar'));
    final List<int> bytes = file.readAsBytesSync();
    final archive = tar.decodeBytes(bytes, verify: true);
    expect(archive.numberOfFiles(), equals(4));
    expect(archive[1].isSymbolicLink, equals(true));
    expect(archive[1].nameOfLinkedFile, equals('b/b.txt'));
  });
  test('decode test2.tar', () {
    final file = File(p.join(testDirPath, 'res/test2.tar'));
    final List<int> bytes = file.readAsBytesSync();
    final archive = tar.decodeBytes(bytes, verify: true);
    final expected_files = <File>[];
    listDir(expected_files, Directory(p.join(testDirPath, 'res/test2')));
    expect(archive.numberOfFiles(), equals(4));
  });
  test('decode test2.tar.gz', () {
    final file = File(p.join(testDirPath, 'res/test2.tar.gz'));
    List<int> bytes = file.readAsBytesSync();
    bytes = const GZipDecoderImpl().decodeBytes(bytes, verify: true);
    final archive = tar.decodeBytes(bytes, verify: true);
    final expected_files = <File>[];
    listDir(expected_files, Directory(p.join(testDirPath, 'res/test2')));
    expect(archive.numberOfFiles(), equals(4));
  });
  test('decode/encode', () {
    final a_bytes = a_txt.codeUnits;
    final b = File(p.join(testDirPath, 'res/cat.jpg'));
    final List<int> b_bytes = b.readAsBytesSync();
    final file = File(p.join(testDirPath, 'res/test.tar'));
    final List<int> bytes = file.readAsBytesSync();
    final archive = tar.decodeBytes(bytes, verify: true);
    expect(archive.numberOfFiles(), equals(2));
    var t_file = archive.fileName(0);
    expect(t_file, equals('a.txt'));
    var t_bytes = archive.fileData(0);
    compare_bytes(t_bytes, a_bytes);
    t_file = archive.fileName(1);
    expect(t_file, equals('cat.jpg'));
    t_bytes = archive.fileData(1);
    compare_bytes(t_bytes, b_bytes);
    final encoded = tarEncoder.encode(archive);
    final out = File(p.join(testDirPath, 'out/test.tar'));
    out.createSync(recursive: true);
    out.writeAsBytesSync(encoded);
    // Test round-trip
    final archive2 = tar.decodeBytes(encoded, verify: true);
    expect(archive2.numberOfFiles(), equals(2));
    t_file = archive2.fileName(0);
    expect(t_file, equals('a.txt'));
    t_bytes = archive2.fileData(0);
    compare_bytes(t_bytes, a_bytes);
    t_file = archive2.fileName(1);
    expect(t_file, equals('cat.jpg'));
    t_bytes = archive2.fileData(1);
    compare_bytes(t_bytes, b_bytes);
  });
  for (final Map<String, dynamic> t in tarTests) {
    test('untar ${t['file']}', () {
      final file = File(p.join(testDirPath, t['file'] as String));
      final bytes = file.readAsBytesSync();
      /*Archive archive =*/
      final decoded = tar.decodeBytes(bytes, verify: true);
      // ignore: avoid_dynamic_calls
      expect(decoded.iterable.length, equals(t['headers'].length));
      for (var i = 0; i < decoded.iterable.length; ++i) {
        final file = decoded[i];
        // ignore: avoid_dynamic_calls
        final hdr = t['headers'][i] as Map<String, dynamic>;
        if (hdr.containsKey('Name')) {
          expect(file.tarFile.filename, equals(hdr['Name']));
        }
        if (hdr.containsKey('Mode')) {
          expect(file.mode, equals(hdr['Mode']));
        }
        if (hdr.containsKey('Uid')) {
          expect(file.ownerId, equals(hdr['Uid']));
        }
        if (hdr.containsKey('Gid')) {
          expect(file.groupId, equals(hdr['Gid']));
        }
        if (hdr.containsKey('Size')) {
          expect(file.tarFile.fileSize, equals(hdr['Size']));
        }
        if (hdr.containsKey('ModTime')) {
          expect(file.lastModTime, equals(hdr['ModTime']));
        }
        if (hdr.containsKey('Typeflag')) {
          expect(file.tarFile.typeFlag, equals(hdr['Typeflag']));
        }
        if (hdr.containsKey('Uname')) {
          expect(file.tarFile.ownerUserName, equals(hdr['Uname']));
        }
        if (hdr.containsKey('Gname')) {
          expect(file.tarFile.ownerGroupName, equals(hdr['Gname']));
        }
      }
    });
  }
}
