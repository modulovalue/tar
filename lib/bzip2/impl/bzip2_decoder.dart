import 'dart:typed_data';

import '../../base/impl/byte_order_constants.dart';
import '../../base/impl/exception.dart';
import '../../base/impl/input_stream.dart';
import '../../base/impl/output_stream.dart';
import '../../base/interface/input_stream.dart';
import '../../base/interface/output_stream.dart';
import '../interface/bz2_bit_reader.dart';
import '../interface/bzip2_decoder.dart';
import 'bz2_bit_reader.dart';
import 'bzip2_constants.dart';

class BZip2DecoderImpl implements BZip2Decoder {
  static const int BZ_N_GROUPS = 6;
  static const int BZ_G_SIZE = 50;
  static const int BZ_N_ITERS = 4;
  static const int BZ_MAX_ALPHA_SIZE = 258;
  static const int BZ_MAX_CODE_LEN = 23;
  static const int BZ_MAX_SELECTORS = 2 + (900000 ~/ BZ_G_SIZE);
  static const int MTFA_SIZE = 4096;
  static const int MTFL_SIZE = 16;
  static const int BZ_RUNA = 0;
  static const int BZ_RUNB = 1;
  static const int BLOCK_COMPRESSED = 0;
  static const int BLOCK_EOS = 2;
  static const List<int> BZ2_rNums = [
    619,
    720,
    127,
    481,
    931,
    816,
    813,
    233,
    566,
    247,
    985,
    724,
    205,
    454,
    863,
    491,
    741,
    242,
    949,
    214,
    733,
    859,
    335,
    708,
    621,
    574,
    73,
    654,
    730,
    472,
    419,
    436,
    278,
    496,
    867,
    210,
    399,
    680,
    480,
    51,
    878,
    465,
    811,
    169,
    869,
    675,
    611,
    697,
    867,
    561,
    862,
    687,
    507,
    283,
    482,
    129,
    807,
    591,
    733,
    623,
    150,
    238,
    59,
    379,
    684,
    877,
    625,
    169,
    643,
    105,
    170,
    607,
    520,
    932,
    727,
    476,
    693,
    425,
    174,
    647,
    73,
    122,
    335,
    530,
    442,
    853,
    695,
    249,
    445,
    515,
    909,
    545,
    703,
    919,
    874,
    474,
    882,
    500,
    594,
    612,
    641,
    801,
    220,
    162,
    819,
    984,
    589,
    513,
    495,
    799,
    161,
    604,
    958,
    533,
    221,
    400,
    386,
    867,
    600,
    782,
    382,
    596,
    414,
    171,
    516,
    375,
    682,
    485,
    911,
    276,
    98,
    553,
    163,
    354,
    666,
    933,
    424,
    341,
    533,
    870,
    227,
    730,
    475,
    186,
    263,
    647,
    537,
    686,
    600,
    224,
    469,
    68,
    770,
    919,
    190,
    373,
    294,
    822,
    808,
    206,
    184,
    943,
    795,
    384,
    383,
    461,
    404,
    758,
    839,
    887,
    715,
    67,
    618,
    276,
    204,
    918,
    873,
    777,
    604,
    560,
    951,
    160,
    578,
    722,
    79,
    804,
    96,
    409,
    713,
    940,
    652,
    934,
    970,
    447,
    318,
    353,
    859,
    672,
    112,
    785,
    645,
    863,
    803,
    350,
    139,
    93,
    354,
    99,
    820,
    908,
    609,
    772,
    154,
    274,
    580,
    184,
    79,
    626,
    630,
    742,
    653,
    282,
    762,
    623,
    680,
    81,
    927,
    626,
    789,
    125,
    411,
    521,
    938,
    300,
    821,
    78,
    343,
    175,
    128,
    250,
    170,
    774,
    972,
    275,
    999,
    639,
    495,
    78,
    352,
    126,
    857,
    956,
    358,
    619,
    580,
    124,
    737,
    594,
    701,
    612,
    669,
    112,
    134,
    694,
    363,
    992,
    809,
    743,
    168,
    974,
    944,
    375,
    748,
    52,
    600,
    747,
    642,
    182,
    862,
    81,
    344,
    805,
    988,
    739,
    511,
    655,
    814,
    334,
    249,
    515,
    897,
    955,
    664,
    981,
    649,
    113,
    974,
    459,
    893,
    228,
    433,
    837,
    553,
    268,
    926,
    240,
    102,
    654,
    459,
    51,
    686,
    754,
    806,
    760,
    493,
    403,
    415,
    394,
    687,
    700,
    946,
    670,
    656,
    610,
    738,
    392,
    760,
    799,
    887,
    653,
    978,
    321,
    576,
    617,
    626,
    502,
    894,
    679,
    243,
    440,
    680,
    879,
    194,
    572,
    640,
    724,
    926,
    56,
    204,
    700,
    707,
    151,
    457,
    449,
    797,
    195,
    791,
    558,
    945,
    679,
    297,
    59,
    87,
    824,
    713,
    663,
    412,
    693,
    342,
    606,
    134,
    108,
    571,
    364,
    631,
    212,
    174,
    643,
    304,
    329,
    343,
    97,
    430,
    751,
    497,
    314,
    983,
    374,
    822,
    928,
    140,
    206,
    73,
    263,
    980,
    736,
    876,
    478,
    430,
    305,
    170,
    514,
    364,
    692,
    829,
    82,
    855,
    953,
    676,
    246,
    369,
    970,
    294,
    750,
    807,
    827,
    150,
    790,
    288,
    923,
    804,
    378,
    215,
    828,
    592,
    281,
    565,
    555,
    710,
    82,
    896,
    831,
    547,
    261,
    524,
    462,
    293,
    465,
    502,
    56,
    661,
    821,
    976,
    991,
    658,
    869,
    905,
    758,
    745,
    193,
    768,
    550,
    608,
    933,
    378,
    286,
    215,
    979,
    792,
    961,
    61,
    688,
    793,
    644,
    986,
    403,
    106,
    366,
    905,
    644,
    372,
    567,
    466,
    434,
    645,
    210,
    389,
    550,
    919,
    135,
    780,
    773,
    635,
    389,
    707,
    100,
    626,
    958,
    165,
    504,
    920,
    176,
    193,
    713,
    857,
    265,
    203,
    50,
    668,
    108,
    645,
    990,
    626,
    197,
    510,
    357,
    358,
    850,
    858,
    364,
    936,
    638
  ];
  late int _blockSize100k;
  late Uint32List _tt;
  late Uint8List _inUse16;
  late Uint8List _inUse;
  late Uint8List _seqToUnseq;
  late Uint8List _mtfa;
  late Int32List _mtfbase;
  late Uint8List _selectorMtf;
  late Uint8List _selector;
  late List<Int32List> _limit;
  late List<Int32List> _base;
  late List<Int32List> _perm;
  late Int32List _minLens;
  late Int32List _unzftab;
  late int _numSelectors;
  int _groupPos = 0;
  int _groupNo = -1;
  int _gSel = 0;
  int _gMinlen = 0;
  late Int32List _gLimit;
  late Int32List _gPerm;
  late Int32List _gBase;
  late Int32List _cftab;
  late List<Uint8List> _len;
  int _numInUse = 0;

  BZip2DecoderImpl();

  @override
  Uint8List decodeBytes(
    List<int> data, {
    bool verify = false,
  }) =>
      decodeBuffer(InputStreamImpl(data, byteOrder: BIG_ENDIAN), verify: verify);

  @override
  Uint8List decodeBuffer(
    InputStream _input, {
    bool verify = false,
    OutputStream? output,
  }) {
    output ??= OutputStreamImpl();
    final br = Bz2BitReaderImpl(_input);
    _groupPos = 0;
    _groupNo = 0;
    _gSel = 0;
    _gMinlen = 0;
    if (br.readByte() != BZip2Constants.BZH_SIGNATURE[0] ||
        br.readByte() != BZip2Constants.BZH_SIGNATURE[1] ||
        br.readByte() != BZip2Constants.BZH_SIGNATURE[2]) {
      throw const ArchiveExceptionImpl('Invalid Signature');
    }
    _blockSize100k = br.readByte() - BZip2Constants.HDR_0;
    if (_blockSize100k < 0 || _blockSize100k > 9) {
      throw const ArchiveExceptionImpl('Invalid BlockSize');
    }
    _tt = Uint32List(_blockSize100k * 100000);
    var combinedCrc = 0;
    for (;;) {
      final type = _readBlockType(br);
      if (type == BLOCK_COMPRESSED) {
        var storedBlockCrc = 0;
        storedBlockCrc = (storedBlockCrc << 8) | br.readByte();
        storedBlockCrc = (storedBlockCrc << 8) | br.readByte();
        storedBlockCrc = (storedBlockCrc << 8) | br.readByte();
        storedBlockCrc = (storedBlockCrc << 8) | br.readByte();
        var blockCrc = _readCompressed(br, output);
        blockCrc = BZip2Constants.finalizeCrc(blockCrc);
        if (verify && blockCrc != storedBlockCrc) {
          throw const ArchiveExceptionImpl('Invalid block checksum.');
        }
        combinedCrc = ((combinedCrc << 1) | (combinedCrc >> 31)) & 0xffffffff;
        combinedCrc ^= blockCrc;
      } else if (type == BLOCK_EOS) {
        var storedCrc = 0;
        storedCrc = (storedCrc << 8) | br.readByte();
        storedCrc = (storedCrc << 8) | br.readByte();
        storedCrc = (storedCrc << 8) | br.readByte();
        storedCrc = (storedCrc << 8) | br.readByte();
        if (verify && storedCrc != combinedCrc) {
          throw ArchiveExceptionImpl('Invalid combined checksum: ${combinedCrc} : ${storedCrc}');
        } else {
          if (output is! OutputStreamImpl) {
            return Uint8List(0);
          } else {
            return output.getBytes();
          }
        }
      }
    }
  }

  int _readBlockType(Bz2BitReader br) {
    var eos = true;
    var compressed = true;
    // .eos_magic:48        0x177245385090 (BCD sqrt(pi))
    // .compressed_magic:48 0x314159265359 (BCD (pi))
    for (var i = 0; i < 6; ++i) {
      final b = br.readByte();
      if (b != BZip2Constants.COMPRESSED_MAGIC[i]) {
        compressed = false;
      }
      if (b != BZip2Constants.EOS_MAGIC[i]) {
        eos = false;
      }
      if (!eos && !compressed) {
        throw const ArchiveExceptionImpl('Invalid Block Signature');
      }
    }
    return compressed ? BLOCK_COMPRESSED : BLOCK_EOS;
  }

  int _readCompressed(Bz2BitReader br, OutputStream output) {
    final blockRandomized = br.readBits(1);
    var origPtr = br.readBits(8);
    origPtr = (origPtr << 8) | br.readBits(8);
    origPtr = (origPtr << 8) | br.readBits(8);
    // Receive the mapping table
    _inUse16 = Uint8List(16);
    for (var i = 0; i < 16; ++i) {
      _inUse16[i] = br.readBits(1);
    }
    _inUse = Uint8List(256);
    for (var i = 0, k = 0; i < 16; ++i, k += 16) {
      if (_inUse16[i] != 0) {
        for (var j = 0; j < 16; ++j) {
          _inUse[k + j] = br.readBits(1);
        }
      }
    }
    _makeMaps();
    if (_numInUse == 0) {
      throw const ArchiveExceptionImpl('Data error');
    }
    final alphaSize = _numInUse + 2;
    // Now the selectors
    final numGroups = br.readBits(3);
    if (numGroups < 2 || numGroups > 6) {
      throw const ArchiveExceptionImpl('Data error');
    }
    _numSelectors = br.readBits(15);
    if (_numSelectors < 1) {
      throw const ArchiveExceptionImpl('Data error');
    }
    _selectorMtf = Uint8List(BZ_MAX_SELECTORS);
    _selector = Uint8List(BZ_MAX_SELECTORS);
    for (var i = 0; i < _numSelectors; ++i) {
      var j = 0;
      for (;;) {
        final b = br.readBits(1);
        if (b == 0) {
          break;
        }
        j++;
        if (j >= numGroups) {
          throw const ArchiveExceptionImpl('Data error');
        }
      }
      _selectorMtf[i] = j;
    }
    // Undo the MTF values for the selectors.
    final pos = Uint8List(BZ_N_GROUPS);
    for (var i = 0; i < numGroups; ++i) {
      pos[i] = i;
    }
    for (var i = 0; i < _numSelectors; ++i) {
      var v = _selectorMtf[i];
      final tmp = pos[v];
      while (v > 0) {
        pos[v] = pos[v - 1];
        v--;
      }
      pos[0] = tmp;
      _selector[i] = tmp;
    }
    // Now the coding tables
    _len = List<Uint8List>.filled(BZ_N_GROUPS, BZip2Constants.emptyUint8List);
    for (var t = 0; t < numGroups; ++t) {
      _len[t] = Uint8List(BZ_MAX_ALPHA_SIZE);
      var c = br.readBits(5);
      for (var i = 0; i < alphaSize; ++i) {
        for (;;) {
          if (c < 1 || c > 20) {
            throw const ArchiveExceptionImpl('Data error');
          }
          var b = br.readBits(1);
          if (b == 0) {
            break;
          }
          b = br.readBits(1);
          if (b == 0) {
            c++;
          } else {
            c--;
          }
        }
        _len[t][i] = c;
      }
    }
    // Create the Huffman decoding tables
    _limit = List<Int32List>.filled(BZ_N_GROUPS, BZip2Constants.emptyInt32List);
    _base = List<Int32List>.filled(BZ_N_GROUPS, BZip2Constants.emptyInt32List);
    _perm = List<Int32List>.filled(BZ_N_GROUPS, BZip2Constants.emptyInt32List);
    _minLens = Int32List(BZ_N_GROUPS);
    for (var t = 0; t < numGroups; t++) {
      _limit[t] = Int32List(BZ_MAX_ALPHA_SIZE);
      _base[t] = Int32List(BZ_MAX_ALPHA_SIZE);
      _perm[t] = Int32List(BZ_MAX_ALPHA_SIZE);
      var minLen = 32;
      var maxLen = 0;
      for (var i = 0; i < alphaSize; ++i) {
        if (_len[t][i] > maxLen) {
          maxLen = _len[t][i];
        }
        if (_len[t][i] < minLen) {
          minLen = _len[t][i];
        }
      }
      _hbCreateDecodeTables(_limit[t], _base[t], _perm[t], _len[t], minLen, maxLen, alphaSize);
      _minLens[t] = minLen;
    }
    // Now the MTF values
    final EOB = _numInUse + 1;
    final nblockMAX = 100000 * _blockSize100k;
    _unzftab = Int32List(256);
    // MTF init
    _mtfa = Uint8List(MTFA_SIZE);
    _mtfbase = Int32List(256 ~/ MTFL_SIZE);
    var kk = MTFA_SIZE - 1;
    for (var ii = 256 ~/ MTFL_SIZE - 1; ii >= 0; ii--) {
      for (var jj = MTFL_SIZE - 1; jj >= 0; jj--) {
        _mtfa[kk] = ii * MTFL_SIZE + jj;
        kk--;
      }
      _mtfbase[ii] = kk + 1;
    }
    var nblock = 0;
    _groupPos = 0;
    _groupNo = -1;
    var nextSym = _getMtfVal(br);
    var uc = 0;
    for (;;) {
      if (nextSym == EOB) {
        break;
      }
      if (nextSym == BZ_RUNA || nextSym == BZ_RUNB) {
        var es = -1;
        var N = 1;
        do {
          // Check that N doesn't get too big, so that es doesn't
          // go negative.  The maximum value that can be
          // RUNA/RUNB encoded is equal to the block size (post
          // the initial RLE), viz, 900k, so bounding N at 2
          // million should guard against overflow without
          // rejecting any legitimate inputs.
          if (N >= 2 * 1024 * 1024) {
            throw const ArchiveExceptionImpl('Data error');
          }
          if (nextSym == BZ_RUNA) {
            es = es + (0 + 1) * N;
          } else if (nextSym == BZ_RUNB) {
            es = es + (1 + 1) * N;
          }
          N = N * 2;
          nextSym = _getMtfVal(br);
        } while (nextSym == BZ_RUNA || nextSym == BZ_RUNB);
        es++;
        uc = _seqToUnseq[_mtfa[_mtfbase[0]]];
        _unzftab[uc] += es;
        while (es > 0) {
          if (nblock >= nblockMAX) {
            throw const ArchiveExceptionImpl('Data error');
          }
          _tt[nblock] = uc;
          nblock++;
          es--;
        }
      } else {
        if (nblock >= nblockMAX) {
          throw const ArchiveExceptionImpl('Data error');
        }
        // uc = MTF ( nextSym-1 )
        var nn = nextSym - 1;
        if (nn < MTFL_SIZE) {
          // avoid general-case expense
          final pp = _mtfbase[0];
          uc = _mtfa[pp + nn];
          while (nn > 3) {
            final z = pp + nn;
            _mtfa[z] = _mtfa[z - 1];
            _mtfa[z - 1] = _mtfa[z - 2];
            _mtfa[z - 2] = _mtfa[z - 3];
            _mtfa[z - 3] = _mtfa[z - 4];
            nn -= 4;
          }
          while (nn > 0) {
            _mtfa[(pp + nn)] = _mtfa[(pp + nn) - 1];
            nn--;
          }
          _mtfa[pp] = uc;
        } else {
          // general case
          var lno = nn ~/ MTFL_SIZE;
          final off = nn % MTFL_SIZE;
          var pp = _mtfbase[lno] + off;
          uc = _mtfa[pp];
          while (pp > _mtfbase[lno]) {
            _mtfa[pp] = _mtfa[pp - 1];
            pp--;
          }
          _mtfbase[lno]++;
          while (lno > 0) {
            _mtfbase[lno]--;
            _mtfa[_mtfbase[lno]] = _mtfa[_mtfbase[lno - 1] + MTFL_SIZE - 1];
            lno--;
          }
          _mtfbase[0]--;
          _mtfa[_mtfbase[0]] = uc;
          if (_mtfbase[0] == 0) {
            kk = MTFA_SIZE - 1;
            for (var ii = 256 ~/ MTFL_SIZE - 1; ii >= 0; ii--) {
              for (var jj = MTFL_SIZE - 1; jj >= 0; jj--) {
                _mtfa[kk] = _mtfa[_mtfbase[ii] + jj];
                kk--;
              }
              _mtfbase[ii] = kk + 1;
            }
          }
        }
        // end uc = MTF ( nextSym-1 )
        _unzftab[_seqToUnseq[uc]]++;
        _tt[nblock] = _seqToUnseq[uc];
        nblock++;
        nextSym = _getMtfVal(br);
      }
    }
    // Now we know what nblock is, we can do a better sanity
    // check on s->origPtr.
    if (origPtr < 0 || origPtr >= nblock) {
      throw const ArchiveExceptionImpl('Data error');
    }
    // Set up cftab to facilitate generation of T^(-1)
    // Check: unzftab entries in range.
    for (var i = 0; i <= 255; i++) {
      if (_unzftab[i] < 0 || _unzftab[i] > nblock) {
        throw const ArchiveExceptionImpl('Data error');
      }
    }
    // Actually generate cftab.
    _cftab = Int32List(257);
    _cftab[0] = 0;
    for (var i = 1; i <= 256; i++) {
      _cftab[i] = _unzftab[i - 1];
    }
    for (var i = 1; i <= 256; i++) {
      _cftab[i] += _cftab[i - 1];
    }
    // Check: cftab entries in range.
    for (var i = 0; i <= 256; i++) {
      if (_cftab[i] < 0 || _cftab[i] > nblock) {
        // s->cftab[i] can legitimately be == nblock
        throw const ArchiveExceptionImpl('Data error');
      }
    }
    // Check: cftab entries non-descending.
    for (var i = 1; i <= 256; i++) {
      if (_cftab[i - 1] > _cftab[i]) {
        throw const ArchiveExceptionImpl('Data error');
      }
    }
    // compute the T^(-1) vector
    for (var i = 0; i < nblock; i++) {
      uc = _tt[i] & 0xff;
      _tt[_cftab[uc]] |= i << 8;
      _cftab[uc]++;
    }
    var blockCrc = BZip2Constants.INITIAL_CRC;
    var tPos = _tt[origPtr] >> 8;
    var numBlockUsed = 0;
    int k0;
    var rNToGo = 0;
    var rTPos = 0;
    if (blockRandomized != 0) {
      rNToGo = 0;
      rTPos = 0;
      if (tPos >= 100000 * _blockSize100k) {
        throw const ArchiveExceptionImpl('Data error');
      }
      tPos = _tt[tPos];
      k0 = tPos & 0xff;
      tPos >>= 8;
      numBlockUsed++;
      if (rNToGo == 0) {
        rNToGo = BZ2_rNums[rTPos];
        rTPos++;
        if (rTPos == 512) {
          rTPos = 0;
        }
      }
      rNToGo--;
      k0 ^= (rNToGo == 1) ? 1 : 0;
    } else {
      // c_tPos is unsigned, hence test < 0 is pointless.
      if (tPos >= 100000 * _blockSize100k) {
        return blockCrc;
      }
      tPos = _tt[tPos];
      k0 = tPos & 0xff;
      tPos >>= 8;
      numBlockUsed++;
    }
    // UnRLE to output
    var c_state_out_len = 0;
    var c_state_out_ch = 0;
    final s_save_nblockPP = nblock + 1;
    var c_nblock_used = numBlockUsed;
    var c_k0 = k0;
    int k1;
    if (blockRandomized != 0) {
      for (;;) {
        // try to finish existing run
        for (;;) {
          if (c_state_out_len == 0) {
            break;
          }
          output.writeByte(c_state_out_ch);
          blockCrc = BZip2Constants.updateCrc(c_state_out_ch, blockCrc);
          c_state_out_len--;
        }
        // can a run be started?
        if (c_nblock_used == s_save_nblockPP) {
          return blockCrc;
        }
        // Only caused by corrupt data stream?
        if (c_nblock_used > s_save_nblockPP) {
          throw const ArchiveExceptionImpl('Data error.');
        }
        c_state_out_len = 1;
        c_state_out_ch = k0;
        tPos = _tt[tPos];
        k1 = tPos & 0xff;
        tPos >>= 8;
        if (rNToGo == 0) {
          rNToGo = BZ2_rNums[rTPos];
          rTPos++;
          if (rTPos == 512) {
            rTPos = 0;
          }
        }
        rNToGo--;
        k1 ^= (rNToGo == 1) ? 1 : 0;
        c_nblock_used++;
        if (c_nblock_used != s_save_nblockPP) {
          if (k1 != k0) {
            k0 = k1;
            continue;
          } else {
            c_state_out_len = 2;
            tPos = _tt[tPos];
            k1 = tPos & 0xff;
            tPos >>= 8;
            if (rNToGo == 0) {
              rNToGo = BZ2_rNums[rTPos];
              rTPos++;
              if (rTPos == 512) {
                rTPos = 0;
              }
            }
            k1 ^= (rNToGo == 1) ? 1 : 0;
            c_nblock_used++;
            if (c_nblock_used != s_save_nblockPP) {
              if (k1 != k0) {
                k0 = k1;
              } else {
                c_state_out_len = 3;
                tPos = _tt[tPos];
                k1 = tPos & 0xff;
                tPos >>= 8;
                if (rNToGo == 0) {
                  rNToGo = BZ2_rNums[rTPos];
                  rTPos++;
                  if (rTPos == 512) {
                    rTPos = 0;
                  }
                }
                k1 ^= (rNToGo == 1) ? 1 : 0;
                c_nblock_used++;
                if (c_nblock_used != s_save_nblockPP) {
                  if (k1 != k0) {
                    k0 = k1;
                  } else {
                    tPos = _tt[tPos];
                    k1 = tPos & 0xff;
                    tPos >>= 8;
                    if (rNToGo == 0) {
                      rNToGo = BZ2_rNums[rTPos];
                      rTPos++;
                      if (rTPos == 512) {
                        rTPos = 0;
                      }
                    }
                    k1 ^= (rNToGo == 1) ? 1 : 0;
                    c_nblock_used++;
                    c_state_out_len = k1 + 4;
                    tPos = _tt[tPos];
                    k0 = tPos & 0xff;
                    tPos >>= 8;
                    if (rNToGo == 0) {
                      rNToGo = BZ2_rNums[rTPos];
                      rTPos++;
                      if (rTPos == 512) {
                        rTPos = 0;
                      }
                    }
                    k0 ^= (rNToGo == 1) ? 1 : 0;
                    c_nblock_used++;
                  }
                }
              }
            }
          }
        }
      }
    } else {
      for (;;) {
        // try to finish existing run
        if (c_state_out_len > 0) {
          for (;;) {
            if (c_state_out_len == 1) {
              break;
            }
            output.writeByte(c_state_out_ch);
            blockCrc = BZip2Constants.updateCrc(c_state_out_ch, blockCrc);
            c_state_out_len--;
          }
          output.writeByte(c_state_out_ch);
          blockCrc = BZip2Constants.updateCrc(c_state_out_ch, blockCrc);
        }
        // Only caused by corrupt data stream?
        if (c_nblock_used > s_save_nblockPP) {
          throw const ArchiveExceptionImpl('Data error');
        }
        // can a run be started?
        if (c_nblock_used == s_save_nblockPP) {
          c_state_out_len = 0;
          return blockCrc;
        }
        c_state_out_ch = c_k0;
        int k1;
        if (tPos >= 100000 * _blockSize100k) {
          throw const ArchiveExceptionImpl('Data Error');
        }
        tPos = _tt[tPos];
        k1 = tPos & 0xff;
        tPos >>= 8;
        c_nblock_used++;
        if (k1 != c_k0) {
          c_k0 = k1;
          output.writeByte(c_state_out_ch);
          blockCrc = BZip2Constants.updateCrc(c_state_out_ch, blockCrc);
          c_state_out_len = 0;
        } else {
          if (c_nblock_used == s_save_nblockPP) {
            output.writeByte(c_state_out_ch);
            blockCrc = BZip2Constants.updateCrc(c_state_out_ch, blockCrc);
            c_state_out_len = 0;
          } else {
            c_state_out_len = 2;
            if (tPos >= 100000 * _blockSize100k) {
              throw const ArchiveExceptionImpl('Data Error');
            }
            tPos = _tt[tPos];
            k1 = tPos & 0xff;
            tPos >>= 8;
            c_nblock_used++;
            if (c_nblock_used != s_save_nblockPP) {
              if (k1 != c_k0) {
                c_k0 = k1;
              } else {
                c_state_out_len = 3;
                if (tPos >= 100000 * _blockSize100k) {
                  throw const ArchiveExceptionImpl('Data Error');
                }
                tPos = _tt[tPos];
                k1 = tPos & 0xff;
                tPos >>= 8;
                c_nblock_used++;
                if (c_nblock_used != s_save_nblockPP) {
                  if (k1 != c_k0) {
                    c_k0 = k1;
                  } else {
                    if (tPos >= 100000 * _blockSize100k) {
                      throw const ArchiveExceptionImpl('Data Error');
                    }
                    tPos = _tt[tPos];
                    k1 = tPos & 0xff;
                    tPos >>= 8;
                    c_nblock_used++;
                    c_state_out_len = k1 + 4;
                    if (tPos >= 100000 * _blockSize100k) {
                      throw const ArchiveExceptionImpl('Data Error');
                    }
                    tPos = _tt[tPos];
                    c_k0 = tPos & 0xff;
                    tPos >>= 8;
                    c_nblock_used++;
                  }
                }
              }
            }
          }
        }
      }
    }
    return blockCrc; // ignore: dead_code
  }

  int _getMtfVal(Bz2BitReader br) {
    if (_groupPos == 0) {
      _groupNo++;
      if (_groupNo >= _numSelectors) {
        throw const ArchiveExceptionImpl('Data error');
      }
      _groupPos = BZ_G_SIZE;
      _gSel = _selector[_groupNo];
      _gMinlen = _minLens[_gSel];
      _gLimit = _limit[_gSel];
      _gPerm = _perm[_gSel];
      _gBase = _base[_gSel];
    }
    _groupPos--;
    var zn = _gMinlen;
    var zvec = br.readBits(zn);
    for (;;) {
      if (zn > 20) {
        throw const ArchiveExceptionImpl('Data error');
      } else {
        if (zvec <= _gLimit[zn]) {
          break;
        } else {
          zn++;
          final zj = br.readBits(1);
          zvec = (zvec << 1) | zj;
        }
      }
    }
    if (zvec - _gBase[zn] < 0 || zvec - _gBase[zn] >= BZ_MAX_ALPHA_SIZE) {
      throw const ArchiveExceptionImpl('Data error');
    } else {
      return _gPerm[zvec - _gBase[zn]];
    }
  }

  void _hbCreateDecodeTables(Int32List limit, Int32List base, Int32List perm, Uint8List length, int minLen, int maxLen, int alphaSize) {
    var pp = 0;
    for (var i = minLen; i <= maxLen; i++) {
      for (var j = 0; j < alphaSize; j++) {
        if (length[j] == i) {
          perm[pp] = j;
          pp++;
        }
      }
    }
    for (var i = 0; i < BZ_MAX_CODE_LEN; i++) {
      base[i] = 0;
    }
    for (var i = 0; i < alphaSize; i++) {
      base[length[i] + 1]++;
    }
    for (var i = 1; i < BZ_MAX_CODE_LEN; i++) {
      base[i] += base[i - 1];
    }
    for (var i = 0; i < BZ_MAX_CODE_LEN; i++) {
      limit[i] = 0;
    }
    var vec = 0;
    for (var i = minLen; i <= maxLen; i++) {
      vec += base[i + 1] - base[i];
      limit[i] = vec - 1;
      vec <<= 1;
    }
    for (var i = minLen + 1; i <= maxLen; i++) {
      base[i] = ((limit[i - 1] + 1) << 1) - base[i];
    }
  }

  void _makeMaps() {
    _numInUse = 0;
    _seqToUnseq = Uint8List(256);
    for (var i = 0; i < 256; ++i) {
      if (_inUse[i] != 0) {
        _seqToUnseq[_numInUse++] = i;
      }
    }
  }
}
