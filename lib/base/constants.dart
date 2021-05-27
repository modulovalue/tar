import 'dart:typed_data';

// Magic values to help us identify the TAR header type.
const magicGnu = [$u, $s, $t, $a, $r, $space]; // 'ustar '
const versionGnu = [$space, 0]; // ' \x00'
const magicUstar = [$u, $s, $t, $a, $r, 0]; // 'ustar\x00'
const versionUstar = [$char0, $char0]; // '00'
const trailerStar = [$t, $a, $r, 0]; // 'tar\x00'

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
