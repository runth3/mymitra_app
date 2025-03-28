int compareVersions(String current, String min) {
  List<int> currentParts = current.split('.').map(int.parse).toList();
  List<int> minParts = min.split('.').map(int.parse).toList();
  for (int i = 0; i < minParts.length; i++) {
    if (i >= currentParts.length || currentParts[i] < minParts[i]) return -1;
    if (currentParts[i] > minParts[i]) return 1;
  }
  return 0;
}