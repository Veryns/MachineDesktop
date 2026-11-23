import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:onnxruntime/onnxruntime.dart';

import 'prediction.dart';

/// Pembungkus satu sesi ONNX Runtime (satu "kepala" model: tipe atau spesies).
class OnnxHead {
  OnnxHead._(this._session, this._options, this.inputName);

  final OrtSession _session;
  final OrtSessionOptions _options;
  final String inputName;

  static bool _envReady = false;

  static Future<OnnxHead> load(String modelPath, {String? inputName}) async {
    if (!_envReady) {
      OrtEnv.instance.init();
      _envReady = true;
    }
    final bytes = await File(modelPath).readAsBytes();
    final options = OrtSessionOptions();
    final OrtSession session;
    try {
      session = OrtSession.fromBuffer(bytes, options);
    } catch (e) {
      options.release();
      throw ModelMismatchException('Gagal membuka model ONNX "$modelPath": $e');
    }

    var name = inputName ?? 'input';
    if (inputName == null) {
      // Dibaca secara dinamis supaya tetap bisa dikompilasi walau nama anggota API
      // berbeda antarversi paket. Jika gagal: isi "input_name" di manifest.json.
      try {
        final names = (session as dynamic).inputNames as List;
        if (names.isNotEmpty) name = names.first.toString();
      } catch (_) {}
    }
    return OnnxHead._(session, options, name);
  }

  /// Jalankan inferensi. [data] sudah berurutan sesuai [shape] (batch = 1).
  /// Mengembalikan vektor keluaran (jumlah kelas) sebagai daftar double.
  Future<List<double>> run(Float32List data, List<int> shape) async {
    final input = OrtValueTensor.createTensorWithDataList(data, shape);
    final runOptions = OrtRunOptions();
    List<OrtValue?>? outputs;
    try {
      outputs = await _session.runAsync(runOptions, {inputName: input});
      final first = (outputs == null || outputs.isEmpty) ? null : outputs.first;
      if (first == null) {
        throw ModelMismatchException('Model tidak mengembalikan keluaran.');
      }
      return _flatten((first as dynamic).value);
    } finally {
      input.release();
      runOptions.release();
      outputs?.forEach((o) => o?.release());
    }
  }

  void dispose() {
    _session.release();
    _options.release();
  }
}

List<double> _flatten(dynamic v) {
  if (v is num) return [v.toDouble()];
  if (v is List) return [for (final e in v) ..._flatten(e)];
  throw ModelMismatchException('Tipe keluaran tak dikenal: ${v.runtimeType}');
}

/// Ubah keluaran mentah menjadi probabilitas.
/// kind: 'probs' (dipakai apa adanya), 'logits' (softmax), 'auto' (deteksi otomatis).
List<double> normalizeScores(List<double> raw, String kind) {
  bool softmaxNeeded;
  if (kind == 'probs') {
    softmaxNeeded = false;
  } else if (kind == 'logits') {
    softmaxNeeded = true;
  } else {
    final sum = raw.fold<double>(0, (a, b) => a + b);
    final inRange = raw.every((v) => v >= -1e-6 && v <= 1 + 1e-6);
    softmaxNeeded = !(inRange && (sum - 1).abs() < 1e-2);
  }
  if (!softmaxNeeded) return raw;
  final maxV = raw.reduce(math.max);
  final exps = [for (final v in raw) math.exp(v - maxV)];
  final total = exps.fold<double>(0, (a, b) => a + b);
  return [for (final e in exps) e / total];
}
