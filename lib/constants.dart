import 'dart:typed_data';

import 'tar_exception.dart';

// Magic values to help us identify the TAR header type.
const magicGnu = [$u, $s, $t, $a, $r, $space]; // 'ustar '
const versionGnu = [$space, 0]; // ' \x00'
const magicUstar = [$u, $s, $t, $a, $r, 0]; // 'ustar\x00'
const versionUstar = [$char0, $char0]; // '00'
const trailerStar = [$t, $a, $r, 0]; // 'tar\x00'

/// The type flag of a header indicates the kind of file associated with the
/// entry. This enum contains the various type flags over the different TAR
/// formats, and users should be careful that the type flag corresponds to the
/// TAR format they are working with.
enum TypeFlag {
  /// [reg] indicates regular files.
  ///
  /// Old tar implementations have a seperate `TypeRegA` value. This library
  /// will transparently read those as [regA].
  reg,

  /// Legacy-version of [reg] in old tar implementations.
  ///
  /// This is only used internally.
  regA,

  /// Hard link - header-only, may not have a data body
  link,

  /// Symbolic link - header-only, may not have a data body
  symlink,

  /// Character device node - header-only, may not have a data body
  char,

  /// Block device node - header-only, may not have a data body
  block,

  /// Directory - header-only, may not have a data body
  dir,

  /// FIFO node - header-only, may not have a data body
  fifo,

  /// Currently does not have any meaning, but is reserved for the future.
  reserved,

  /// Used by the PAX format to store key-value records that are only relevant
  /// to the next file.
  ///
  /// This package transparently handles these types.
  xHeader,

  /// Used by the PAX format to store key-value records that are relevant to all
  /// subsequent files.
  ///
  /// This package only supports parsing and composing such headers,
  /// but does not currently support persisting the global state across files.
  xGlobalHeader,

  /// Indiates a sparse file in the GNU format
  gnuSparse,

  /// Used by the GNU format for a meta file to store the path or link name for
  /// the next file.
  /// This package transparently handles these types.
  gnuLongName,
  gnuLongLink,

  /// Vendor specific typeflag, as defined in POSIX.1-1998. Seen as outdated but
  /// may still exist on old files.
  ///
  /// This library uses a single enum to catch them all.
  vendor
}

/// Generates the corresponding [TypeFlag] associated with [byte].
TypeFlag typeflagFromByte(int byte) {
  switch (byte) {
    case $char0:
      return TypeFlag.reg;
    case 0:

      /// https://github.com/simolus3/tar/issues/15
      return TypeFlag.regA;
    case $char1:
      return TypeFlag.link;
    case $char2:
      return TypeFlag.symlink;
    case $char3:
      return TypeFlag.char;
    case $char4:
      return TypeFlag.block;
    case $char5:
      return TypeFlag.dir;
    case $char6:
      return TypeFlag.fifo;
    case $char7:
      return TypeFlag.reserved;
    case $x:
      return TypeFlag.xHeader;
    case $g:
      return TypeFlag.xGlobalHeader;
    case $S:
      return TypeFlag.gnuSparse;
    case $L:
      return TypeFlag.gnuLongName;
    case $K:
      return TypeFlag.gnuLongLink;
    default:
      if (64 < byte && byte < 91) {
        return TypeFlag.vendor;
      } else {
        throw TarExceptionInvalidTypeflagImpl._('Invalid typeflag value $byte');
      }
  }
}

class TarExceptionInvalidTypeflagImpl extends FormatException implements TarException {
  const TarExceptionInvalidTypeflagImpl._(String message) : super(message);
}

int typeflagToByte(TypeFlag flag) {
  switch (flag) {
    case TypeFlag.reg:
    case TypeFlag.regA:
      return $char0;
    case TypeFlag.link:
      return $char1;
    case TypeFlag.symlink:
      return $char2;
    case TypeFlag.char:
      return $char3;
    case TypeFlag.block:
      return $char4;
    case TypeFlag.dir:
      return $char5;
    case TypeFlag.fifo:
      return $char6;
    case TypeFlag.reserved:
      return $char7;
    case TypeFlag.xHeader:
      return $x;
    case TypeFlag.xGlobalHeader:
      return $g;
    case TypeFlag.gnuSparse:
      return $S;
    case TypeFlag.gnuLongName:
      return $L;
    case TypeFlag.gnuLongLink:
      return $K;
    case TypeFlag.vendor:
      throw ArgumentError("Can't write vendor-specific type-flags");
  }
}

/// Keywords for PAX extended header records.
const paxPath = 'path';
const paxLinkpath = 'linkpath';
const paxSize = 'size';
const paxUid = 'uid';
const paxGid = 'gid';
const paxUname = 'uname';
const paxGname = 'gname';
const paxMtime = 'mtime';
const paxAtime = 'atime';
const paxCtime = 'ctime'; // Removed from later revision of PAX spec, but was valid
const paxComment = 'comment';
const paxSchilyXattr = 'SCHILY.xattr.';

/// Keywords for GNU sparse files in a PAX extended header.
const paxGNUSparse = 'GNU.sparse.';
const paxGNUSparseNumBlocks = 'GNU.sparse.numblocks';
const paxGNUSparseOffset = 'GNU.sparse.offset';
const paxGNUSparseNumBytes = 'GNU.sparse.numbytes';
const paxGNUSparseMap = 'GNU.sparse.map';
const paxGNUSparseName = 'GNU.sparse.name';
const paxGNUSparseMajor = 'GNU.sparse.major';
const paxGNUSparseMinor = 'GNU.sparse.minor';
const paxGNUSparseSize = 'GNU.sparse.size';
const paxGNUSparseRealSize = 'GNU.sparse.realsize';

/// A set of pax header keys supported by this library.
///
/// The reader will ignore pax headers not listed in this map.
const supportedPaxHeaders = {
  paxPath,
  paxLinkpath,
  paxSize,
  paxUid,
  paxGid,
  paxUname,
  paxGname,
  paxMtime,
  paxAtime,
  paxCtime,
  paxComment,
  paxSchilyXattr,
  paxGNUSparse,
  paxGNUSparseNumBlocks,
  paxGNUSparseOffset,
  paxGNUSparseNumBytes,
  paxGNUSparseMap,
  paxGNUSparseName,
  paxGNUSparseMajor,
  paxGNUSparseMinor,
  paxGNUSparseSize,
  paxGNUSparseRealSize
};

/// User ID bit
const c_ISUID = 2048;

/// Group ID bit
const c_ISGID = 1024;

/// Sticky bit
const c_ISVTX = 512;

/// **********************
///  Convenience constants
/// **********************
/// 64-bit integer max and min values
const int64MaxValue = 9223372036854775807;
const int64MinValue = -9223372036854775808;

/// Constants to determine file modes.
const modeType = 2401763328;
const modeSymLink = 134217728;
const modeDevice = 67108864;
const modeCharDevice = 2097152;
const modeNamedPipe = 33554432;
const modeSocket = 1677216;
const modeSetUid = 8388608;
const modeSetGid = 4194304;
const modeSticky = 1048576;
const modeDirectory = 2147483648;

/// The offset of the checksum in the header
const checksumOffset = 148;
const checksumLength = 8;
const magicOffset = 257;
const versionOffset = 263;
const starTrailerOffset = 508;

/// Size constants from various TAR specifications.
/// Size of each block in a TAR stream.
const blockSize = 512;
const blockSizeLog2 = 9;
const maxIntFor12CharOct = 0x1ffffffff; // 777 7777 7777 in oct

const defaultSpecialLength = 4 * blockSize;

/// Max length of the name field in USTAR format.
const nameSize = 100;

/// Max length of the prefix field in USTAR format.
const prefixSize = 155;

/// A full TAR block of zeros.
final zeroBlock = Uint8List(blockSize);

/// "Line feed" control character.
const int $lf = 0x0a;

/// Space character.
const int $space = 0x20;

/// Character `0`.
const int $char0 = 0x30;

/// Character `1`.
const int $char1 = 0x31;

/// Character `2`.
const int $char2 = 0x32;

/// Character `3`.
const int $char3 = 0x33;

/// Character `4`.
const int $char4 = 0x34;

/// Character `5`.
const int $char5 = 0x35;

/// Character `6`.
const int $char6 = 0x36;

/// Character `7`.
const int $char7 = 0x37;

/// Character `8`.
const int $char8 = 0x38;

/// Character `9`.
const int $char9 = 0x39;

/// Character `<`.
const int $equal = 0x3d;

/// Character `A`.
const int $A = 0x41;

/// Character `K`.
const int $K = 0x4b;

/// Character `L`.
const int $L = 0x4c;

/// Character `S`.
const int $S = 0x53;

/// Character `a`.
const int $a = 0x61;

/// Character `g`.
const int $g = 0x67;

/// Character `r`.
const int $r = 0x72;

/// Character `s`.
const int $s = 0x73;

/// Character `t`.
const int $t = 0x74;

/// Character `u`.
const int $u = 0x75;

/// Character `x`.
const int $x = 0x78;
