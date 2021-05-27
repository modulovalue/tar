import 'format.dart';

/// This library only supports the V7, USTAR, PAX, GNU, and STAR formats.
abstract class TarFormats {
  /// Original Unix Version 7 (V7) AT&T tar tool prior to standardization.
  ///
  /// The structure of the V7 Header consists of the following:
  ///
  /// Start | End | Field
  /// =========================================================================
  /// 0     | 100 | Path name, stored as null-terminated string.
  /// 100   | 108 | File mode, stored as an octal number in ASCII.
  /// 108   | 116 | User id of owner, as octal number in ASCII.
  /// 116   | 124 | Group id of owner, as octal number in ASCII.
  /// 124   | 136 | Size of file, as octal number in ASCII.
  /// 136   | 148 | Modification time of file, number of seconds from epoch,
  ///               stored as an octal number in ASCII.
  /// 148   | 156 | Header checksum, stored as an octal number in ASCII.
  /// 156   | 157 | Link flag, determines the kind of header.
  /// 157   | 257 | Link name, stored as a string.
  /// 257   | 512 | NUL pad.
  ///
  /// Unused bytes are set to NUL ('\x00')s
  ///
  /// Reference:
  /// https://www.freebsd.org/cgi/man.cgi?query=tar&sektion=5&format=html
  /// https://www.gnu.org/software/tar/manual/html_chapter/tar_15.html#SEC188
  /// http://cdrtools.sourceforge.net/private/man/star/star.4.html
  static const v7 = TarFormatImpl(1);

  /// USTAR (Unix Standard TAR) header format defined in POSIX.1-1988.
  ///
  /// The structure of the USTAR Header consists of the following:
  ///
  /// Start | End | Field
  /// =========================================================================
  /// 0     | 100 | Path name, stored as null-terminated string.
  /// 100   | 108 | File mode, stored as an octal number in ASCII.
  /// 108   | 116 | User id of owner, as octal number in ASCII.
  /// 116   | 124 | Group id of owner, as octal number in ASCII.
  /// 124   | 136 | Size of file, as octal number in ASCII.
  /// 136   | 148 | Modification time of file, number of seconds from epoch,
  ///               stored as an octal number in ASCII.
  /// 148   | 156 | Header checksum, stored as an octal number in ASCII.
  /// 156   | 157 | Type flag, determines the kind of header.
  ///               Note that the meaning of the size field depends on the type.
  /// 157   | 257 | Link name, stored as a string.
  /// 257   | 263 | Contains the magic value "ustar\x00" to indicate that this is
  ///               the USTAR format. Full compliance requires user name and
  ///               group name fields to be set.
  /// 263   | 265 | Version. "00" for POSIX standard archives.
  /// 265   | 297 | User name, as null-terminated ASCII string.
  /// 297   | 329 | Group name, as null-terminated ASCII string.
  /// 329   | 337 | Major number for character or block device entry.
  /// 337   | 345 | Minor number for character or block device entry.
  /// 345   | 500 | Prefix. If the pathname is too long to fit in the 100 bytes
  ///               provided at the start, it can be split at any / character
  ///               with the first portion going here.
  /// 500   | 512 | NUL pad.
  ///
  /// Unused bytes are set to NUL ('\x00')s
  ///
  /// User and group names should be used in preference to uid/gid values when
  /// they are set and the corresponding names exist on the system.
  ///
  /// While this format is compatible with most tar readers, the format has
  /// several limitations making it unsuitable for some usages. Most notably, it
  /// cannot support sparse files, files larger than 8GiB, filenames larger than
  /// 256 characters, and non-ASCII filenames.
  ///
  /// Reference:
  /// https://www.freebsd.org/cgi/man.cgi?query=tar&sektion=5&format=html
  /// https://www.gnu.org/software/tar/manual/html_chapter/tar_15.html#SEC188
  ///	http://pubs.opengroup.org/onlinepubs/9699919799/utilities/pax.html#tag_20_92_13_06
  static const ustar = TarFormatImpl(2);

  /// PAX header format defined in POSIX.1-2001.
  ///
  /// PAX extends USTAR by writing a special file with either the `x` or `g`
  /// type flags to allow for attributes that are not conveniently stored in a
  /// POSIX ustar archive to be held.
  ///
  /// Some newer formats add their own extensions to PAX by defining their
  /// own keys and assigning certain semantic meaning to the associated values.
  /// For example, sparse file support in PAX is implemented using keys
  /// defined by the GNU manual (e.g., "GNU.sparse.map").
  ///
  /// Reference:
  /// https://www.freebsd.org/cgi/man.cgi?query=tar&sektion=5&format=html
  /// https://www.gnu.org/software/tar/manual/html_chapter/tar_15.html#SEC188
  /// http://cdrtools.sourceforge.net/private/man/star/star.4.html
  ///	http://pubs.opengroup.org/onlinepubs/009695399/utilities/pax.html
  static const pax = TarFormatImpl(4);

  /// GNU header format.
  ///
  /// The GNU header format is older than the USTAR and PAX standards and
  /// is not compatible with them. The GNU format supports
  /// arbitrary file sizes, filenames of arbitrary encoding and length,
  /// sparse files, and other features.
  ///
  /// Start | End | Field
  /// =========================================================================
  /// 0     | 100 | Path name, stored as null-terminated string.
  /// 100   | 108 | File mode, stored as an octal number in ASCII.
  /// 108   | 116 | User id of owner, as octal number in ASCII.
  /// 116   | 124 | Group id of owner, as octal number in ASCII.
  /// 124   | 136 | Size of file, as octal number in ASCII.
  /// 136   | 148 | Modification time of file, number of seconds from epoch,
  ///               stored as an octal number in ASCII.
  /// 148   | 156 | Header checksum, stored as an octal number in ASCII.
  /// 156   | 157 | Type flag, determines the kind of header.
  ///               Note that the meaning of the size field depends on the type.
  /// 157   | 257 | Link name, stored as a string.
  /// 257   | 263 | Contains the magic value "ustar " to indicate that this is
  ///               the GNU format.
  /// 263   | 265 | Version. " \x00" for POSIX standard archives.
  /// 265   | 297 | User name, as null-terminated ASCII string.
  /// 297   | 329 | Group name, as null-terminated ASCII string.
  /// 329   | 337 | Major number for character or block device entry.
  /// 337   | 345 | Minor number for character or block device entry.
  /// 345   | 357 | Last Access time of file, number of seconds from epoch,
  ///               stored as an octal number in ASCII.
  /// 357   | 369 | Last Changed time of file, number of seconds from epoch,
  ///               stored as an octal number in ASCII.
  /// 369   | 381 | Offset - not used.
  /// 381   | 385 | Longnames - deprecated
  /// 385   | 386 | Unused.
  /// 386   | 482 | Sparse data - 4 sets of (offset, numbytes) stored as
  ///               octal numbers in ASCII.
  /// 482   | 483 | isExtended - if this field is non-zero, this header is
  ///               followed by  additional sparse records, which are in the
  ///               same format as above.
  /// 483   | 495 | Binary representation of the file's complete size, inclusive
  ///               of the sparse data.
  /// 495   | 512 | NUL pad.
  ///
  /// It is recommended that PAX be chosen over GNU unless the target
  /// application can only parse GNU formatted archives.
  ///
  /// Reference:
  ///	https://www.gnu.org/software/tar/manual/html_node/Standard.html
  static const gnu = TarFormatImpl(8);

  /// Schily's TAR format, which is incompatible with USTAR.
  /// This does not cover STAR extensions to the PAX format; these fall under
  /// the PAX format.
  ///
  /// Start | End | Field
  /// =========================================================================
  /// 0     | 100 | Path name, stored as null-terminated string.
  /// 100   | 108 | File mode, stored as an octal number in ASCII.
  /// 108   | 116 | User id of owner, as octal number in ASCII.
  /// 116   | 124 | Group id of owner, as octal number in ASCII.
  /// 124   | 136 | Size of file, as octal number in ASCII.
  /// 136   | 148 | Modification time of file, number of seconds from epoch,
  ///               stored as an octal number in ASCII.
  /// 148   | 156 | Header checksum, stored as an octal number in ASCII.
  /// 156   | 157 | Type flag, determines the kind of header.
  ///               Note that the meaning of the size field depends on the type.
  /// 157   | 257 | Link name, stored as a string.
  /// 257   | 263 | Contains the magic value "ustar\x00" to indicate that this is
  ///               the GNU format.
  /// 263   | 265 | Version. "00" for STAR archives.
  /// 265   | 297 | User name, as null-terminated ASCII string.
  /// 297   | 329 | Group name, as null-terminated ASCII string.
  /// 329   | 337 | Major number for character or block device entry.
  /// 337   | 345 | Minor number for character or block device entry.
  /// 345   | 476 | Prefix. If the pathname is too long to fit in the 100 bytes
  ///               provided at the start, it can be split at any / character
  ///               with the first portion going here.
  /// 476   | 488 | Last Access time of file, number of seconds from epoch,
  ///               stored as an octal number in ASCII.
  /// 488   | 500 | Last Changed time of file, number of seconds from epoch,
  ///               stored as an octal number in ASCII.
  /// 500   | 508 | NUL pad.
  /// 508   | 512 | Trailer - "tar\x00".
  ///
  /// Reference:
  /// http://cdrtools.sourceforge.net/private/man/star/star.4.html
  static const star = TarFormatImpl(16);
}
