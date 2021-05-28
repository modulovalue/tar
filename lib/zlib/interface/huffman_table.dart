import 'dart:typed_data';

/// Build huffman table from length list.
abstract class HuffmanTable {
  Uint32List get table;

  int get maxCodeLength;

  int get minCodeLength;
}
