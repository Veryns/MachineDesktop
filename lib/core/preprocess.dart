import 'dart:isolate';
import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// Hasil pra-pemrosesan: tensor mentah NHWC (piksel 0-255) + pratinjau PNG.
class Preprocessed {
  const Preprocessed(this.nhwc, this.previewPng);
  final Float32List nhwc;
  final Uint8List previewPng;
}

/// Meniru `standardize_image` di notebook: frame pertama, alpha di atas warna latar,
/// skala agar sisi terpanjang = size (letterbox), ditaruh di tengah kanvas size x size.
/// Berjalan di isolate terpisah supaya UI tidak macet saat memuat gambar besar.
///
/// Catatan: notebook memakai resize Lanczos; paket `image` tidak punya Lanczos, jadi dipakai
/// cubic. Selisih persentase kecil itu wajar (bandingkan dengan tools/parity_check.py).
Future<Preprocessed> preprocessImage(
  Uint8List bytes, {
  required int size,
  required List<int> bg,
}) =>
    Isolate.run(() => _preprocess(bytes, size, bg));

Preprocessed _preprocess(Uint8List bytes, int size, List<int> bg) {
  final decoded = img.decodeImage(bytes);
  if (decoded == null) {
    throw const FormatException('File bukan gambar yang valid.');
  }
  var src = decoded.convert(format: img.Format.uint8, numChannels: 4);

  // Gambar sangat besar: kecilkan dulu agar cepat (hasil akhirnya tetap size x size).
  final longest = src.width > src.height ? src.width : src.height;
  if (longest > 1024) {
    final s = 1024 / longest;
    src = img.copyResize(
      src,
      width: (src.width * s).round().clamp(1, 1024).toInt(),
      height: (src.height * s).round().clamp(1, 1024).toInt(),
      interpolation: img.Interpolation.average,
    );
  }

  // Alpha di atas warna latar -> RGB.
  final rgb = img.Image(width: src.width, height: src.height, numChannels: 3);
  for (var y = 0; y < src.height; y++) {
    for (var x = 0; x < src.width; x++) {
      final px = src.getPixel(x, y);
      final a = px.a / 255.0;
      rgb.setPixelRgb(
        x,
        y,
        (px.r * a + bg[0] * (1 - a)).round().clamp(0, 255).toInt(),
        (px.g * a + bg[1] * (1 - a)).round().clamp(0, 255).toInt(),
        (px.b * a + bg[2] * (1 - a)).round().clamp(0, 255).toInt(),
      );
    }
  }

  // Letterbox.
  final scale = size / (rgb.width > rgb.height ? rgb.width : rgb.height);
  final nw = (rgb.width * scale).round().clamp(1, size).toInt();
  final nh = (rgb.height * scale).round().clamp(1, size).toInt();
  final resized = img.copyResize(
    rgb,
    width: nw,
    height: nh,
    interpolation: img.Interpolation.cubic,
  );

  final out = Float32List(size * size * 3);
  for (var i = 0; i < size * size; i++) {
    out[i * 3] = bg[0].toDouble();
    out[i * 3 + 1] = bg[1].toDouble();
    out[i * 3 + 2] = bg[2].toDouble();
  }
  final ox = (size - nw) ~/ 2;
  final oy = (size - nh) ~/ 2;
  for (var y = 0; y < nh; y++) {
    for (var x = 0; x < nw; x++) {
      final px = resized.getPixel(x, y);
      final o = ((y + oy) * size + (x + ox)) * 3;
      out[o] = px.r.toDouble();
      out[o + 1] = px.g.toDouble();
      out[o + 2] = px.b.toDouble();
    }
  }

  final preview = img.Image(width: size, height: size, numChannels: 3);
  for (var y = 0; y < size; y++) {
    for (var x = 0; x < size; x++) {
      final o = (y * size + x) * 3;
      preview.setPixelRgb(x, y, out[o].round(), out[o + 1].round(), out[o + 2].round());
    }
  }
  return Preprocessed(out, Uint8List.fromList(img.encodePng(preview)));
}
