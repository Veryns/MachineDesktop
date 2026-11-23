import 'dart:typed_data';

/// Satu kandidat hasil klasifikasi (tipe atau spesies).
class Scored {
  const Scored({
    required this.key,
    required this.label,
    required this.confidence,
    this.info,
  });

  final String key;
  final String label;
  final double confidence;
  final Map<String, dynamic>? info;
}

class PredictionResult {
  const PredictionResult({
    required this.types,
    required this.species,
    required this.processedPng,
    required this.elapsed,
    this.typesFromData,
  });

  final List<Scored> types;
  final List<Scored> species;

  /// Tipe sebenarnya dari data Pokédex untuk spesies teratas (mis. ["Grass","Poison"]),
  /// atau null bila tidak tersedia / dimatikan (`types_from_species: false`).
  final List<String>? typesFromData;

  /// Gambar 'seperti yang dilihat model' (setelah letterbox + latar), format PNG.
  final Uint8List processedPng;
  final Duration elapsed;

  Map<String, dynamic>? get info => species.isEmpty ? null : species.first.info;
}

/// Model dan class_names tidak cocok (mis. jumlah kelas beda) atau model tak bisa dijalankan.
class ModelMismatchException implements Exception {
  ModelMismatchException(this.message);
  final String message;

  @override
  String toString() => message;
}
