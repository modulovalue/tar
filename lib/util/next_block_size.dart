import '../base/constants.dart';
import 'num_blocks.dart';

int nextBlockSize(int fileSize) => numBlocks(fileSize) * blockSize;
