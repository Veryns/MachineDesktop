import 'dart:typed_data';

import 'class_names.dart';
import 'model_manifest.dart';
import 'model_registry.dart';
import 'onnx_head.dart';
import 'prediction.dart';
import 'preprocess.dart';

/// Memuat satu bundle model (tipe dan/atau spesies) dan menjalankan prediksi.
/// Semua yang bergantung pada model dibaca dari manifest, jadi mengganti model = mengganti folder.
class PokedexEngine {
  PokedexEngine._(this.bundle, this._typeHead, this._speciesHead,
      this.typeNames, this.speciesNames, this._info);

  final ModelBundle bundle;
  final OnnxHead? _typeHead;
  final OnnxHead? _speciesHead;
  final ClassNames? typeNames;
  final ClassNames? speciesNames;
  final Map<String, Map<String, dynamic>> _info;

  ModelManifest get manifest => bundle.manifest;

  static Future<PokedexEngine> load(ModelBundle b) async {
    final m = b.manifest;
    OnnxHead? th, sh;
    ClassNames? tn, sn;
    try {
      if (m.type != null) {
        tn = ClassNames.fromJson(await readJsonFile(b.path(m.type!.classes)));
        th = await OnnxHead.load(b.path(m.type!.model), inputName: m.inputName);
        await _verify(th, tn, m, 'type');
      }
      if (m.species != null) {
        sn = ClassNames.fromJson(await readJsonFile(b.path(m.species!.classes)));
        sh = await OnnxHead.load(b.path(m.species!.model), inputName: m.inputName);
        await _verify(sh, sn, m, 'species');
      }
      final info = <String, Map<String, dynamic>>{};
      if (m.infoFile != null) {
        try {
          final raw = await readJsonFile(b.path(m.infoFile!));
          if (raw is List) {
            for (final r in raw) {
              if (r is Map && r['name_key'] != null) {
                info[r['name_key'].toString()] = Map<String, dynamic>.from(r);
              }
            }
          }
        } catch (_) {
          // info bersifat opsional; abaikan bila hilang/rusak
        }
      }
      return PokedexEngine._(b, th, sh, tn, sn, info);
    } catch (_) {
      th?.dispose();
      sh?.dispose();
      rethrow;
    }
  }

  static List<int> _shape(ModelManifest m) => m.layout == 'NCHW'
      ? [1, 3, m.imgSize, m.imgSize]
      : [1, m.imgSize, m.imgSize, 3];

  /// Jalankan sekali dengan input nol: memastikan model bisa jalan & jumlah kelas cocok,
  /// sehingga model yang salah (mis. jumlah kelas beda) ditolak dengan pesan jelas di awal.
  static Future<void> _verify(OnnxHead head, ClassNames names, ModelManifest m, String label) async {
    final out = await head.run(Float32List(m.imgSize * m.imgSize * 3), _shape(m));
    if (out.length != names.length) {
      throw ModelMismatchException(
          'Model "$label" menghasilkan ${out.length} keluaran, tetapi class names berisi '
          '${names.length} kelas. Pastikan class_names_$label.json berasal dari model yang sama.');
    }
  }

  Float32List _buildInput(Float32List nhwc) {
    final m = manifest;
    final scale = m.inputScale;
    if (m.layout == 'NHWC') {
      if (scale == 1.0) return nhwc;
      return Float32List.fromList([for (final v in nhwc) v * scale]);
    }
    final plane = m.imgSize * m.imgSize;
    final out = Float32List(nhwc.length);
    for (var i = 0; i < plane; i++) {
      for (var c = 0; c < 3; c++) {
        out[c * plane + i] = nhwc[i * 3 + c] * scale;
      }
    }
    return out;
  }

  List<Scored> _top(List<double> probs, ClassNames names, int k, {bool withInfo = false}) {
    final idx = List<int>.generate(probs.length, (i) => i)
      ..sort((a, b) => probs[b].compareTo(probs[a]));
    return [
      for (final i in idx.take(k < probs.length ? k : probs.length))
        Scored(
          key: names.keys[i],
          label: names.display[i],
          confidence: probs[i],
          info: withInfo ? _info[names.keys[i]] : null,
        ),
    ];
  }

  Future<PredictionResult> predict(Uint8List imageBytes, {int topK = 3}) async {
    final sw = Stopwatch()..start();
    final m = manifest;
    final pre = await preprocessImage(imageBytes, size: m.imgSize, bg: m.bgColor);
    final input = _buildInput(pre.nhwc);
    final shape = _shape(m);

    var types = <Scored>[];
    var species = <Scored>[];
    final th = _typeHead;
    final sh = _speciesHead;
    if (th != null && typeNames != null) {
      final scores = normalizeScores(await th.run(input, shape), m.outputKind);
      types = _top(scores, typeNames!, topK);
    }
    if (sh != null && speciesNames != null) {
      final scores = normalizeScores(await sh.run(input, shape), m.outputKind);
      species = _top(scores, speciesNames!, topK, withInfo: true);
    }
    List<String>? fromData;
    if (m.typesFromSpecies && species.isNotEmpty) {
      final raw = species.first.info?['types'];
      final parts = raw is List
          ? raw.map((e) => e.toString())
          : (raw is String ? raw.split(RegExp(r'[|,;/]')) : const <String>[]);
      final cleaned = parts.map((e) => e.trim()).where((e) => e.isNotEmpty).map(_titleCase).toList();
      if (cleaned.isNotEmpty) fromData = cleaned;
    }
    sw.stop();
    return PredictionResult(
      types: types,
      species: species,
      processedPng: pre.previewPng,
      elapsed: sw.elapsed,
      typesFromData: fromData,
    );
  }

  static String _titleCase(String s) =>
      s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1).toLowerCase()}';

  void dispose() {
    _typeHead?.dispose();
    _speciesHead?.dispose();
  }
}
