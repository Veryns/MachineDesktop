import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'model_manifest.dart';

/// Membaca JSON (toleran terhadap BOM UTF-8 yang kadang ditambahkan editor Windows).
Future<dynamic> readJsonFile(String path) async {
  final text = await File(path).readAsString();
  return jsonDecode(text.replaceFirst('﻿', ''));
}

/// Folder yang berisi manifest.json + berkas model.
class ModelBundle {
  const ModelBundle(this.dir, this.manifest);

  final Directory dir;
  final ModelManifest manifest;

  String get id => p.basename(dir.path);
  String get title => manifest.name.isEmpty ? id : manifest.name;
  String path(String relative) => p.join(dir.path, relative);

  @override
  bool operator ==(Object other) =>
      other is ModelBundle && other.dir.path == dir.path;

  @override
  int get hashCode => dir.path.hashCode;
}

class ScanResult {
  const ScanResult(this.bundles, this.problems, this.roots);
  final List<ModelBundle> bundles;
  final List<String> problems;
  final List<String> roots;
}

class ModelRegistry {
  static const manifestName = 'manifest.json';

  /// Folder `models` yang dicari (yang ada saja, tanpa duplikat):
  /// 1) $POKEDEX_MODELS_DIR  2) ./models  3) `<folder exe>/models`  4) naik beberapa level dari exe
  /// (nomor 4 membuat `flutter run` menemukan `<proyek>/models` tanpa penyalinan).
  static List<Directory> candidateRoots() {
    final seen = <String>{};
    final out = <Directory>[];
    void add(String path) {
      final d = Directory(path);
      final key = p.normalize(d.absolute.path).toLowerCase();
      if (d.existsSync() && seen.add(key)) out.add(d);
    }

    final env = Platform.environment['POKEDEX_MODELS_DIR'];
    if (env != null && env.isNotEmpty) add(env);
    add(p.join(Directory.current.path, 'models'));
    var dir = File(Platform.resolvedExecutable).parent;
    for (var i = 0; i < 6; i++) {
      add(p.join(dir.path, 'models'));
      final parent = dir.parent;
      if (parent.path == dir.path) break;
      dir = parent;
    }
    return out;
  }

  /// Baca satu folder sebagai bundle. Melempar exception dengan pesan yang jelas bila tidak valid.
  static Future<ModelBundle> loadBundleDir(Directory dir) async {
    final mf = File(p.join(dir.path, manifestName));
    if (!await mf.exists()) {
      throw FormatException('tidak ada $manifestName di ${dir.path}');
    }
    final raw = await readJsonFile(mf.path);
    if (raw is! Map) throw const FormatException('manifest.json bukan objek JSON.');
    final manifest = ModelManifest.fromJson(Map<String, dynamic>.from(raw));
    return ModelBundle(dir, manifest);
  }

  static Future<ScanResult> scan([List<Directory>? roots]) async {
    final rs = roots ?? candidateRoots();
    final bundles = <ModelBundle>[];
    final problems = <String>[];

    Future<void> tryAdd(Directory d) async {
      try {
        final b = await loadBundleDir(d);
        if (!bundles.contains(b)) bundles.add(b);
      } catch (e) {
        problems.add('${p.basename(d.path)}: $e');
      }
    }

    for (final root in rs) {
      if (await File(p.join(root.path, manifestName)).exists()) {
        await tryAdd(root); // root itu sendiri adalah satu bundle
        continue;
      }
      await for (final e in root.list(followLinks: false)) {
        if (e is Directory && await File(p.join(e.path, manifestName)).exists()) {
          await tryAdd(e);
        }
      }
    }
    bundles.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
    return ScanResult(bundles, problems, rs.map((d) => d.path).toList());
  }
}
