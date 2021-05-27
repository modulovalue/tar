import '../interface/flag.dart';
import 'flags.dart';

/// Generates the corresponding [TypeFlag] associated with [byte].
TypeFlag? tryParseTypeFlag(int byte) {
  switch (byte) {
    case TypeFlagReg.byte:
      return TypeFlags.reg;
    case TypeFlagRegA.alternativeByte:
      return TypeFlags.regA;
    case TypeFlagLink.byte:
      return TypeFlags.link;
    case TypeFlagSymlink.byte:
      return TypeFlags.symlink;
    case TypeFlagChar.byte:
      return TypeFlags.char;
    case TypeFlagBlock.byte:
      return TypeFlags.block;
    case TypeFlagDir.byte:
      return TypeFlags.dir;
    case TypeFlagFifo.byte:
      return TypeFlags.fifo;
    case TypeFlagReserved.byte:
      return TypeFlags.reserved;
    case TypeFlagXHeader.byte:
      return TypeFlags.xHeader;
    case TypeFlagXGlobalHeader.byte:
      return TypeFlags.xGlobalHeader;
    case TypeFlagGnuSparse.byte:
      return TypeFlags.gnuSparse;
    case TypeFlagGnuLongName.byte:
      return TypeFlags.gnuLongName;
    case TypeFlagGnuLongLink.byte:
      return TypeFlags.gnuLongLink;
  }
  if (TypeFlagVendor.minByteExclusive < byte && byte < TypeFlagVendor.maxByteExclusive) {
    return TypeFlags.vendor;
  } else {
    return null;
  }
}
