/// Daftar nama kelas satu model.
///
/// Format yang diterima (sama dengan keluaran notebook):
///   {"classes": ["a","b"], "display_names": ["A","B"]}   // display_names opsional
///   ["a","b"]                                            // daftar polos
class ClassNames {
  const ClassNames(this.keys, this.display);

  final List<String> keys;
  final List<String> display;

  int get length => keys.length;

  factory ClassNames.fromJson(dynamic j) {
    if (j is List) {
      final k = j.map((e) => e.toString()).toList();
      return ClassNames(k, k);
    }
    if (j is Map && j['classes'] is List) {
      final k = (j['classes'] as List).map((e) => e.toString()).toList();
      final d = j['display_names'] is List
          ? (j['display_names'] as List).map((e) => e.toString()).toList()
          : k;
      if (d.length != k.length) {
        throw FormatException(
            'display_names (${d.length}) tidak sama panjang dengan classes (${k.length}).');
      }
      return ClassNames(k, d);
    }
    throw const FormatException(
        'Format class names tidak dikenal (harus {"classes": [...]} atau daftar).');
  }
}
