import '../base/constants.dart';

int numBlocks(int fileSize) {
  if (fileSize % blockSize == 0) {
    return fileSize ~/ blockSize;
  } else {
    return fileSize ~/ blockSize + 1;
  }
}
