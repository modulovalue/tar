import 'dart:typed_data';

import '../interface/huffman_table.dart';

class HuffmanTableImpl implements HuffmanTable {
  @override
  final Uint32List table;
  @override
  final int maxCodeLength;
  @override
  final int minCodeLength;

  const HuffmanTableImpl(this.table, this.maxCodeLength, this.minCodeLength);

  static HuffmanTable build(List<int> lengths) {
    int maxCodeLength = 0;
    int minCodeLength = 0x7fffffff;
    final listSize = lengths.length;
    for (var i = 0; i < listSize; ++i) {
      if (lengths[i] > maxCodeLength) {
        maxCodeLength = lengths[i];
      }
      if (lengths[i] < minCodeLength) {
        minCodeLength = lengths[i];
      }
    }
    final size = 1 << maxCodeLength;
    final table = Uint32List(size);
    for (var bitLength = 1, code = 0, skip = 2; bitLength <= maxCodeLength;) {
      for (var i = 0; i < listSize; ++i) {
        if (lengths[i] == bitLength) {
          var reversed = 0;
          var rtemp = code;
          for (var j = 0; j < bitLength; ++j) {
            reversed = (reversed << 1) | (rtemp & 1);
            rtemp >>= 1;
          }
          for (var j = reversed; j < size; j += skip) {
            table[j] = (bitLength << 16) | i;
          }
          ++code;
        }
      }
      ++bitLength;
      code <<= 1;
      skip <<= 1;
    }
    return HuffmanTableImpl(table, maxCodeLength, minCodeLength);
  }
}
