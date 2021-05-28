/// Magic values to help us identify the TAR header type.
abstract class MagicValues {
  /// 'ustar '
  static const magicGnu = [$u, $s, $t, $a, $r, $space];
  /// ' \x00'
  static const versionGnu = [$space, 0];
  /// 'ustar\x00'
  static const magicUstar = [$u, $s, $t, $a, $r, 0];
  /// '00'
  static const versionUstar = [$char0, $char0];
  /// 'tar\x00'
  static const trailerStar = [$t, $a, $r, 0];
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

/// "Line feed" control character.
const int $lf = 0x0a;

/// Space character.
const int $space = 0x20;

/// Character `<`.
const int $equal = 0x3d;

/// Character `a`.
const int $a = 0x61;

/// Character `r`.
const int $r = 0x72;

/// Character `s`.
const int $s = 0x73;

/// Character `t`.
const int $t = 0x74;

/// Character `u`.
const int $u = 0x75;

/// Character `0`.
const int $char0 = 0x30;

/// Character `9`.
const int $char9 = 0x39;
