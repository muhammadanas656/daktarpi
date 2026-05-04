extension ListFingerprintExt on List<dynamic> {
  /// Generates a unique string based on the exact items and their exact order.
  String get dataFingerprint {
    if (isEmpty) return 'empty_list';

    return map((item) {
      if (item is Map) {
        return item['id']?.toString() ?? item.hashCode.toString();
      }
      return item.hashCode.toString();
    }).join('_');
  }
}
