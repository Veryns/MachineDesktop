import 'dart:io';

import 'package:flutter/foundation.dart';

import 'core/model_registry.dart';
import 'core/pokedex_engine.dart';
import 'core/prediction.dart';

/// Status aplikasi: daftar model, model terpilih, gambar, dan hasil prediksi.
/// Satu slot riwayat: gambar yang pernah dites + hasil prediksinya (bila sudah ada untuk model aktif).
class HistoryEntry {
  HistoryEntry(this.bytes, this.name);
  final Uint8List bytes;
  final String name;
  PredictionResult? result;
}

class AppController extends ChangeNotifier {
  static const historySize = 6;

  /// 6 slot riwayat. Gambar baru mengisi slot berikutnya; setelah penuh, slot terlama ditimpa.
  final List<HistoryEntry?> history = List<HistoryEntry?>.filled(historySize, null);
  int? activeSlot;
  int _nextSlot = 0;

  List<ModelBundle> bundles = const [];
  List<String> problems = const [];
  List<String> roots = const [];
  ModelBundle? selected;
  PokedexEngine? engine;

  bool scanning = true; // true sampai pemindaian folder models pertama selesai
  bool loadingModel = false;
  bool predicting = false;
  String? modelError;
  String? predictError;

  Uint8List? imageBytes;
  String? imageName;
  PredictionResult? result;
  final int topK = 5; // selalu tampilkan 5 kandidat teratas

  final List<ModelBundle> _custom = []; // folder yang dipilih manual lewat dialog
  bool _pending = false;

  bool get busy => loadingModel || predicting;

  Future<void> init() => rescan();

  /// Pindai ulang folder `models` (mis. setelah menyalin model baru). Pilihan model dipertahankan.
  Future<void> rescan() async {
    if (busy) return;
    final keep = selected;
    final res = await ModelRegistry.scan();
    bundles = [
      ...res.bundles,
      ..._custom.where((c) => !res.bundles.contains(c)),
    ];
    problems = res.problems;
    roots = res.roots;
    scanning = false;
    final next = (keep != null && bundles.contains(keep))
        ? bundles.firstWhere((b) => b == keep)
        : (bundles.isNotEmpty ? bundles.first : null);
    await select(next, force: true);
  }

  Future<void> select(ModelBundle? b, {bool force = false}) async {
    if (!force && (busy || (b != null && b == selected && engine != null))) return;
    final old = engine;
    engine = null;
    old?.dispose();
    result = null;
    for (final h in history) {
      h?.result = null; // hasil lama milik model sebelumnya
    }
    predictError = null;
    modelError = null;
    selected = b;
    if (b == null) {
      notifyListeners();
      return;
    }
    loadingModel = true;
    notifyListeners();
    try {
      engine = await PokedexEngine.load(b);
    } catch (e) {
      modelError = e.toString();
      engine = null;
    }
    loadingModel = false;
    notifyListeners();
    if (engine != null && imageBytes != null) await _predict();
  }

  /// Buka folder bundle di lokasi mana pun (tanpa menyalinnya ke `models`).
  Future<void> openFolder(String path) async {
    try {
      final b = await ModelRegistry.loadBundleDir(Directory(path));
      _custom.removeWhere((c) => c == b);
      _custom.add(b);
      bundles = [...bundles.where((x) => x != b), b];
      await select(b, force: true);
    } catch (e) {
      modelError = 'Folder "$path" bukan bundle model yang valid: $e';
      notifyListeners();
    }
  }

  Future<void> setImage(Uint8List bytes, String name) async {
    final slot = _nextSlot;
    _nextSlot = (_nextSlot + 1) % historySize;
    history[slot] = HistoryEntry(bytes, name);
    activeSlot = slot;
    imageBytes = bytes;
    imageName = name;
    result = null;
    predictError = null;
    notifyListeners();
    await _predict();
  }

  /// Buka lagi gambar dari slot riwayat.
  Future<void> selectSlot(int i) async {
    final e = history[i];
    if (e == null) return;
    activeSlot = i;
    imageBytes = e.bytes;
    imageName = e.name;
    result = e.result;
    predictError = null;
    notifyListeners();
    if (e.result == null) await _predict();
  }

  void clearImage() {
    imageBytes = null;
    imageName = null;
    result = null;
    activeSlot = null;
    predictError = null;
    notifyListeners();
  }

  Future<void> _predict() async {
    if (predicting) {
      _pending = true; // ulangi sekali lagi setelah yang berjalan selesai
      return;
    }
    final eng = engine;
    final bytes = imageBytes;
    if (eng == null || bytes == null) return;
    predicting = true;
    predictError = null;
    notifyListeners();
    final slot = activeSlot;
    try {
      final r = await eng.predict(bytes, topK: topK);
      if (identical(imageBytes, bytes)) result = r;
      if (slot != null && identical(history[slot]?.bytes, bytes)) history[slot]!.result = r;
    } catch (e) {
      predictError = e.toString();
      result = null;
    }
    predicting = false;
    notifyListeners();
    if (_pending) {
      _pending = false;
      await _predict();
    }
  }

  @override
  void dispose() {
    engine?.dispose();
    super.dispose();
  }
}