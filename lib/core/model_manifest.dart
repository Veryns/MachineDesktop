/// Satu "kepala" model: berkas .onnx + berkas daftar kelasnya (relatif terhadap folder bundle).
class HeadSpec {
  const HeadSpec({required this.model, required this.classes});

  final String model;
  final String classes;

  static HeadSpec? tryParse(dynamic j, String label) {
    if (j == null) return null;
    if (j is! Map || j['model'] is! String || j['classes'] is! String) {
      throw FormatException(
          '"$label" harus berisi {"model": "....onnx", "classes": "....json"}.');
    }
    return HeadSpec(
        model: j['model'] as String, classes: j['classes'] as String);
  }
}

/// Isi manifest.json sebuah bundle model.
///
/// Kontrak input: model menerima float32 satu gambar (batch=1) RGB, ukuran
/// img_size x img_size, urutan `layout` (NHWC/NCHW), nilai piksel 0-255 dikali input_scale.
class ModelManifest {
  const ModelManifest({
    required this.name,
    required this.scope,
    required this.imgSize,
    required this.bgColor,
    required this.layout,
    required this.inputScale,
    required this.outputKind,
    required this.inputName,
    required this.typesFromSpecies,
    required this.type,
    required this.species,
    required this.infoFile,
  });

  final String name;
  final String scope;
  final int imgSize;
  final List<int> bgColor;
  final String layout; // NHWC | NCHW
  final double inputScale;
  final String outputKind; // auto | probs | logits
  final String? inputName; // opsional; bawaan: dibaca dari model

  /// true: label tipe di judul hasil diambil dari data Pokédex spesies teratas
  /// (kolom "types" di pokemon_info.json), bukan dari tebakan model tipe.
  final bool typesFromSpecies;
  final HeadSpec? type;
  final HeadSpec? species;
  final String? infoFile;

  factory ModelManifest.fromJson(Map<String, dynamic> j) {
    final type = HeadSpec.tryParse(j['type'], 'type');
    final species = HeadSpec.tryParse(j['species'], 'species');
    if (type == null && species == null) {
      throw const FormatException(
          'manifest.json harus punya "type" dan/atau "species".');
    }
    final size = (j['img_size'] as num?)?.toInt() ?? 224;
    if (size < 16 || size > 2048) {
      throw FormatException('img_size tidak masuk akal: $size');
    }
    final bgRaw = j['bg_color'];
    final List<int> bg = (bgRaw is List && bgRaw.length == 3)
        ? bgRaw.map((e) => (e as num).toInt().clamp(0, 255).toInt()).toList()
        : <int>[255, 255, 255];
    final layout = ((j['layout'] as String?) ?? 'NHWC').toUpperCase();
    if (layout != 'NHWC' && layout != 'NCHW') {
      throw FormatException('layout harus NHWC atau NCHW, bukan "$layout".');
    }
    final output = ((j['output'] as String?) ?? 'auto').toLowerCase();
    if (!const ['auto', 'probs', 'logits'].contains(output)) {
      throw FormatException('output harus auto/probs/logits, bukan "$output".');
    }
    return ModelManifest(
      name: (j['name'] as String?) ?? '',
      scope: (j['scope'] as String?) ?? '',
      imgSize: size,
      bgColor: bg,
      layout: layout,
      inputScale: (j['input_scale'] as num?)?.toDouble() ?? 1.0,
      outputKind: output,
      inputName: j['input_name'] as String?,
      typesFromSpecies: (j['types_from_species'] as bool?) ?? true,
      type: type,
      species: species,
      infoFile: j['info'] as String?,
    );
  }
}
