import '../../base/impl/exception.dart';
import '../../base/impl/input_stream.dart';
import '../interface/directory.dart';
import '../interface/header.dart';
import 'header.dart';

class ZipDirectoryImpl implements ZipDirectory {
  // End of Central Directory Record
  static const int SIGNATURE = 0x06054b50;
  static const int ZIP64_EOCD_LOCATOR_SIGNATURE = 0x07064b50;
  static const int ZIP64_EOCD_LOCATOR_SIZE = 20;
  static const int ZIP64_EOCD_SIGNATURE = 0x06064b50;
  static const int ZIP64_EOCD_SIZE = 56;

  @override
  int filePosition = -1;
  @override
  int numberOfThisDisk = 0;
  @override
  int diskWithTheStartOfTheCentralDirectory = 0;
  @override
  int totalCentralDirectoryEntriesOnThisDisk = 0;
  @override
  int totalCentralDirectoryEntries = 0;
  @override
  late int centralDirectorySize;
  @override
  late int centralDirectoryOffset;
  @override
  String zipFileComment = '';
  @override
  List<ZipFileHeader> fileHeaders = [];

  ZipDirectoryImpl();

  ZipDirectoryImpl.read(InputStreamImpl input, {String? password}) {
    filePosition = _findSignature(input);
    input.offset = filePosition;
    final signature = input.readUint32(); // ignore: unused_local_variable
    numberOfThisDisk = input.readUint16();
    diskWithTheStartOfTheCentralDirectory = input.readUint16();
    totalCentralDirectoryEntriesOnThisDisk = input.readUint16();
    totalCentralDirectoryEntries = input.readUint16();
    centralDirectorySize = input.readUint32();
    centralDirectoryOffset = input.readUint32();
    final len = input.readUint16();
    if (len > 0) {
      zipFileComment = input.readString(size: len);
    }
    _readZip64Data(input);
    final dirContent = input.subset(centralDirectoryOffset, centralDirectorySize);
    while (!dirContent.isEOS) {
      final fileSig = dirContent.readUint32();
      if (fileSig != ZipFileHeaderImpl.SIGNATURE) {
        break;
      }
      fileHeaders.add(ZipFileHeaderImpl(dirContent, input, password));
    }
  }

  void _readZip64Data(InputStreamImpl input) {
    final ip = input.offset;
    // Check for zip64 data.
    // Zip64 end of central directory locator
    // signature                       4 bytes  (0x07064b50)
    // number of the disk with the
    // start of the zip64 end of
    // central directory               4 bytes
    // relative offset of the zip64
    // end of central directory record 8 bytes
    // total number of disks           4 bytes
    final locPos = filePosition - ZIP64_EOCD_LOCATOR_SIZE;
    if (locPos < 0) {
      return;
    } else {
      final zip64 = input.subset(locPos, ZIP64_EOCD_LOCATOR_SIZE);
      var sig = zip64.readUint32();
      // If this ins't the signature we're looking for, nothing more to do.
      if (sig != ZIP64_EOCD_LOCATOR_SIGNATURE) {
        input.offset = ip;
      } else {
        final startZip64Disk = zip64.readUint32(); // ignore: unused_local_variable
        final zip64DirOffset = zip64.readUint64();
        final numZip64Disks = zip64.readUint32(); // ignore: unused_local_variable
        input.offset = zip64DirOffset;
        // Zip64 end of central directory record
        // signature                       4 bytes  (0x06064b50)
        // size of zip64 end of central
        // directory record                8 bytes
        // version made by                 2 bytes
        // version needed to extract       2 bytes
        // number of this disk             4 bytes
        // number of the disk with the
        // start of the central directory  4 bytes
        // total number of entries in the
        // central directory on this disk  8 bytes
        // total number of entries in the
        // central directory               8 bytes
        // size of the central directory   8 bytes
        // offset of start of central
        // directory with respect to
        // the starting disk number        8 bytes
        // zip64 extensible data sector    (variable size)
        sig = input.readUint32();
        if (sig != ZIP64_EOCD_SIGNATURE) {
          input.offset = ip;
          return;
        } else {
          final zip64EOCDSize = input.readUint64(); // ignore: unused_local_variable
          final zip64Version = input.readUint16(); // ignore: unused_local_variable
          // ignore: unused_local_variable
          final zip64VersionNeeded = input.readUint16();
          final zip64DiskNumber = input.readUint32();
          final zip64StartDisk = input.readUint32();
          final zip64NumEntriesOnDisk = input.readUint64();
          final zip64NumEntries = input.readUint64();
          final dirSize = input.readUint64();
          final dirOffset = input.readUint64();
          numberOfThisDisk = zip64DiskNumber;
          diskWithTheStartOfTheCentralDirectory = zip64StartDisk;
          totalCentralDirectoryEntriesOnThisDisk = zip64NumEntriesOnDisk;
          totalCentralDirectoryEntries = zip64NumEntries;
          centralDirectorySize = dirSize;
          centralDirectoryOffset = dirOffset;
          input.offset = ip;
        }
      }
    }
  }

  int _findSignature(InputStreamImpl input) {
    final pos = input.offset;
    final length = input.length;
    // The directory and archive contents are written to the end of the zip
    // file.  We need to search from the end to find these structures,
    // starting with the 'End of central directory' record (EOCD).
    for (var ip = length - 4; ip >= 0; --ip) {
      input.offset = ip;
      final sig = input.readUint32();
      if (sig == SIGNATURE) {
        input.offset = pos;
        return ip;
      }
    }
    throw const ArchiveExceptionImpl('Could not find End of Central Directory Record');
  }
}
