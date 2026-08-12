// lib/core/utils/id_utils.dart

class IdUtils {
  /// Stable hash function to convert a String UUID to a 31-bit integer
  /// required for notification IDs. This is consistent across app restarts.
  static int stringToIntId(String id) {
    int hash = 0;
    for (int i = 0; i < id.length; i++) {
      hash = (31 * hash + id.codeUnitAt(i)) & 0x0FFFFFFF;
    }
    return hash;
  }
}
