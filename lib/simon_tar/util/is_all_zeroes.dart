bool isAllZeroes(List<int> list) {
  for (var i = 0; i < list.length; i++) {
    if (list[i] != 0) {
      return false;
    }
  }
  return true;
}
