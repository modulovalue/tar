import '../interface/flag.dart';

abstract class TypeFlags {
  static TypeFlagReg get reg => const TypeFlagReg._();

  static TypeFlagRegA get regA => const TypeFlagRegA._();

  static TypeFlagLink get link => const TypeFlagLink._();

  static TypeFlagSymlink get symlink => const TypeFlagSymlink._();

  static TypeFlagChar get char => const TypeFlagChar._();

  static TypeFlagBlock get block => const TypeFlagBlock._();

  static TypeFlagDir get dir => const TypeFlagDir._();

  static TypeFlagFifo get fifo => const TypeFlagFifo._();

  static TypeFlagReserved get reserved => const TypeFlagReserved._();

  static TypeFlagXHeader get xHeader => const TypeFlagXHeader._();

  static TypeFlagXGlobalHeader get xGlobalHeader => const TypeFlagXGlobalHeader._();

  static TypeFlagGnuSparse get gnuSparse => const TypeFlagGnuSparse._();

  static TypeFlagGnuLongName get gnuLongName => const TypeFlagGnuLongName._();

  static TypeFlagGnuLongLink get gnuLongLink => const TypeFlagGnuLongLink._();

  static TypeFlagVendor get vendor => const TypeFlagVendor._();
}

/// [TypeFlagReg] indicates regular files.
///
/// Old tar implementations have a separate `TypeRegA` value. This library
/// will transparently read those as [].
class TypeFlagReg implements TypeFlag {
  static const int byte = 0x30;

  const TypeFlagReg._();

  @override
  int get flagByte => byte;

  @override
  bool get hasContent => true;
}

/// Legacy-version of [TypeFlagRegA] in old tar implementations.
///
/// This is only used internally.
class TypeFlagRegA implements TypeFlag {
  static const byte = 0x30;

  static const alternativeByte = 0;

  const TypeFlagRegA._();

  @override
  int get flagByte => byte;

  @override
  bool get hasContent => true;
}

/// Hard link - header-only, may not have a data body
class TypeFlagLink implements TypeFlag {
  static const int byte = 0x31;

  const TypeFlagLink._();

  @override
  int get flagByte => byte;

  @override
  bool get hasContent => false;
}

/// Symbolic link - header-only, may not have a data body
class TypeFlagSymlink implements TypeFlag {
  static const int byte = 0x32;

  const TypeFlagSymlink._();

  @override
  int get flagByte => byte;

  @override
  bool get hasContent => false;
}

/// Character device node - header-only, may not have a data body
class TypeFlagChar implements TypeFlag {
  static const int byte = 0x33;

  const TypeFlagChar._();

  @override
  int get flagByte => byte;

  @override
  bool get hasContent => false;
}

/// Block device node - header-only, may not have a data body
class TypeFlagBlock implements TypeFlag {
  static const int byte = 0x34;

  const TypeFlagBlock._();

  @override
  int get flagByte => byte;

  @override
  bool get hasContent => false;
}

/// Directory - header-only, may not have a data body
class TypeFlagDir implements TypeFlag {
  static const int byte = 0x35;

  const TypeFlagDir._();

  @override
  int get flagByte => byte;

  @override
  bool get hasContent => false;
}

/// FIFO node - header-only, may not have a data body
class TypeFlagFifo implements TypeFlag {
  static const int byte = 0x36;

  const TypeFlagFifo._();

  @override
  int get flagByte => byte;

  @override
  bool get hasContent => false;
}

/// Currently does not have any meaning, but is reserved for the future.
class TypeFlagReserved implements TypeFlag {
  static const int byte = 0x37;

  const TypeFlagReserved._();

  @override
  int get flagByte => byte;

  @override
  bool get hasContent => true;
}

/// Used by the PAX format to store key-value records that are only relevant
/// to the next file.
///
/// This package transparently handles these types.
class TypeFlagXHeader implements TypeFlag {
  static const int byte = 0x78;

  const TypeFlagXHeader._();

  @override
  int get flagByte => byte;

  @override
  bool get hasContent => true;
}

/// Used by the PAX format to store key-value records that are relevant to all
/// subsequent files.
///
/// This package only supports parsing and composing such headers,
/// but does not currently support persisting the global state across files.
class TypeFlagXGlobalHeader implements TypeFlag {
  static const int byte = 0x67;

  const TypeFlagXGlobalHeader._();

  @override
  int get flagByte => byte;

  @override
  bool get hasContent => true;
}

/// Indicates a sparse file in the GNU format
class TypeFlagGnuSparse implements TypeFlag {
  static const int byte = 0x53;

  const TypeFlagGnuSparse._();

  @override
  int get flagByte => byte;

  @override
  bool get hasContent => true;
}

/// Used by the GNU format for a meta file to store the path or link name for
/// the next file.
/// This package transparently handles these types.
class TypeFlagGnuLongName implements TypeFlag {
  static const int byte = 0x4c;

  const TypeFlagGnuLongName._();

  @override
  int get flagByte => byte;

  @override
  bool get hasContent => true;
}

/// Used by the GNU format for a meta file to store the path or link name for
/// the next file.
/// This package transparently handles these types.
class TypeFlagGnuLongLink implements TypeFlag {
  static const int byte = 0x4b;

  const TypeFlagGnuLongLink._();

  @override
  int get flagByte => byte;

  @override
  bool get hasContent => true;
}

/// Vendor specific typeflag, as defined in POSIX.1-1998. Seen as outdated but
/// may still exist on old files.
///
/// This library uses a single enum to catch them all.
class TypeFlagVendor implements TypeFlag {
  static const int minByteExclusive = 64;
  static const int maxByteExclusive = 91;

  const TypeFlagVendor._();

  @override
  int get flagByte => throw ArgumentError("Can't write vendor-specific type-flags");

  @override
  bool get hasContent => true;
}
