#!/usr/bin/env python3
"""Ubah folder `pokedex_export` (model Keras dari notebook) menjadi *bundle ONNX*
yang bisa dibaca aplikasi Flutter (folder `models/<nama>/`).

Contoh:
    python tools/convert_to_onnx.py --export-dir ../pokedex_export --out models/pokedex_v1

Syarat (di lingkungan yang bisa memuat model .keras, mis. venv proyek atau Kaggle/Colab):
    pip install tensorflow tf2onnx onnx onnxruntime

Urutan metode (--method auto):
    1. keras     : model.export(format="onnx")            (Keras 3)
    2. savedmodel: model.export(SavedModel) + tf2onnx     (jalur yang sama dgn ekspor TFLite di notebook)
    3. tflite    : tf2onnx --tflite  (memakai file *.tflite di pokedex_export)
Setiap hasil DIVERIFIKASI (bisa dijalankan onnxruntime, jumlah keluaran = jumlah kelas,
dan cocok dengan keluaran Keras) sebelum dipakai.
"""
import argparse
import json
import os
import shutil
import subprocess
import sys
import tempfile

import numpy as np

TASKS = ("type", "species")


def log(*a):
    print(*a, flush=True)


# ----------------------------------------------------------------- metadata
def read_json(path):
    with open(path, encoding="utf-8-sig") as f:
        return json.load(f)


def n_classes_of(classes_json):
    if isinstance(classes_json, list):
        return len(classes_json)
    return len(classes_json["classes"])


def write_manifest(out_dir, cfg, layout, name, methods):
    manifest = {
        "name": name,
        "scope": cfg.get("species_scope", ""),
        "img_size": int(cfg["img_size"]),
        "bg_color": list(cfg.get("bg_color", [255, 255, 255])),
        "layout": layout,            # NHWC (default Keras) atau NCHW
        "input_scale": 1.0,          # piksel mentah 0-255; normalisasi ada di dalam model
        "output": "auto",            # auto | probs | logits
        "info": "pokemon_info.json",
        "source": {"best_models": cfg.get("best_models"), "converted_with": methods},
    }
    for t in TASKS:
        if os.path.isfile(os.path.join(out_dir, f"{t}_model.onnx")):
            manifest[t] = {"model": f"{t}_model.onnx", "classes": f"class_names_{t}.json"}
    with open(os.path.join(out_dir, "manifest.json"), "w", encoding="utf-8") as f:
        json.dump(manifest, f, ensure_ascii=False, indent=2)
    return manifest


# ----------------------------------------------------------------- konversi
def load_keras(export_dir, path):
    sys.path.insert(0, export_dir)
    try:
        import pokedex_predictor  # noqa: F401  (mendaftarkan layer kustom ResNetPreprocess bila ada)
    except Exception as e:  # noqa: BLE001
        log(f"   (info) pokedex_predictor tidak diimpor: {type(e).__name__}: {e}")
    import keras
    return keras.models.load_model(path, compile=False)


def run_tf2onnx(src_args, out_path, opset):
    cmd = [sys.executable, "-m", "tf2onnx.convert", *src_args, "--opset", str(opset), "--output", out_path]
    log("   $", " ".join(cmd))
    subprocess.run(cmd, check=True)


def conv_keras(ctx, out_path, opset):
    ctx["model"]().export(out_path, format="onnx", opset_version=opset)


def conv_savedmodel(ctx, out_path, opset):
    with tempfile.TemporaryDirectory() as td:
        sm = os.path.join(td, "saved_model")
        ctx["model"]().export(sm)
        run_tf2onnx(["--saved-model", sm], out_path, opset)


def conv_tflite(ctx, out_path, opset):
    if not os.path.isfile(ctx["tflite"]):
        raise FileNotFoundError(ctx["tflite"])
    run_tf2onnx(["--tflite", ctx["tflite"]], out_path, opset)


METHODS = {"keras": conv_keras, "savedmodel": conv_savedmodel, "tflite": conv_tflite}


def detect_layout(shape, size):
    dims = [d if isinstance(d, int) else None for d in shape]
    if len(dims) == 4 and dims[3] == 3:
        return "NHWC"
    if len(dims) == 4 and dims[1] == 3:
        return "NCHW"
    raise ValueError(f"Bentuk input ONNX tidak dikenal: {shape} (harapan: [N,{size},{size},3] atau [N,3,{size},{size}])")


def verify(onnx_path, size, n_classes, keras_getter):
    import onnxruntime as ort

    sess = ort.InferenceSession(onnx_path, providers=["CPUExecutionProvider"])
    inp = sess.get_inputs()[0]
    layout = detect_layout(inp.shape, size)
    x = np.random.RandomState(0).randint(0, 256, (1, size, size, 3)).astype("float32")
    feed = x if layout == "NHWC" else np.transpose(x, (0, 3, 1, 2))
    out = sess.run(None, {inp.name: feed})[0]
    if out.ndim != 2 or out.shape[1] != n_classes:
        raise ValueError(f"Keluaran ONNX {out.shape} tidak cocok dengan {n_classes} kelas di class_names.")
    info = {"layout": layout, "input_name": inp.name, "sum": round(float(out.sum()), 4)}
    try:
        ref = np.asarray(keras_getter()(x, training=False))
        diff = float(np.abs(ref - out).max())
        info["max_diff_vs_keras"] = diff
        if diff > 1e-3:
            raise ValueError(f"Keluaran ONNX berbeda dari Keras (selisih maks {diff:.5f}).")
    except ValueError:
        raise
    except Exception as e:  # noqa: BLE001
        info["keras_compare"] = f"dilewati ({type(e).__name__})"
    return info


def convert_task(task, export_dir, out_dir, cfg, classes_json, methods, opset):
    size = int(cfg["img_size"])
    keras_path = os.path.join(export_dir, cfg[f"{task}_model"])
    cache = {}

    def model():
        if "m" not in cache:
            cache["m"] = load_keras(export_dir, keras_path)
        return cache["m"]

    ctx = {"model": model, "tflite": os.path.join(export_dir, f"{task}_model.tflite")}
    out_path = os.path.join(out_dir, f"{task}_model.onnx")
    errors = []
    for m in methods:
        log(f"[{task}] mencoba metode: {m}")
        try:
            if os.path.exists(out_path):
                os.remove(out_path)
            METHODS[m](ctx, out_path, opset)
            info = verify(out_path, size, n_classes_of(classes_json), model if os.path.isfile(keras_path) else (lambda: None))
            log(f"[{task}] OK via '{m}': {info}")
            info["method"] = m
            return info
        except Exception as e:  # noqa: BLE001
            errors.append(f"{m}: {type(e).__name__}: {str(e)[:300]}")
            log(f"[{task}] gagal via '{m}': {type(e).__name__}: {str(e)[:300]}")
    if os.path.exists(out_path):
        os.remove(out_path)
    raise RuntimeError(f"Semua metode gagal untuk '{task}':\n  - " + "\n  - ".join(errors))


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--export-dir", required=True, help="folder pokedex_export dari notebook")
    ap.add_argument("--out", required=True, help="folder bundle tujuan, mis. models/pokedex_v1")
    ap.add_argument("--name", default=None, help="nama yang tampil di aplikasi")
    ap.add_argument("--tasks", nargs="+", default=list(TASKS), choices=TASKS)
    ap.add_argument("--method", default="auto", choices=["auto", *METHODS])
    ap.add_argument("--opset", type=int, default=17)
    args = ap.parse_args()

    export_dir = os.path.abspath(args.export_dir)
    out_dir = os.path.abspath(args.out)
    cfg = read_json(os.path.join(export_dir, "app_config.json"))
    os.makedirs(out_dir, exist_ok=True)
    methods = list(METHODS) if args.method == "auto" else [args.method]

    done, layouts = {}, set()
    for t in args.tasks:
        cls_file = cfg.get(f"{t}_classes")
        if not cls_file or not os.path.isfile(os.path.join(export_dir, cls_file)):
            log(f"[{t}] dilewati: class names tidak ada")
            continue
        classes_json = read_json(os.path.join(export_dir, cls_file))
        shutil.copy2(os.path.join(export_dir, cls_file), os.path.join(out_dir, f"class_names_{t}.json"))
        try:
            info = convert_task(t, export_dir, out_dir, cfg, classes_json, methods, args.opset)
        except RuntimeError as e:
            log(f"\nGAGAL: {e}")
            continue
        done[t] = info["method"]
        layouts.add(info["layout"])

    if not done:
        log("\nTidak ada model yang berhasil dikonversi. Saran: jalankan skrip ini di lingkungan tempat model dilatih "
            "(Kaggle/Colab) setelah `pip install tf2onnx onnx onnxruntime`, atau lihat README bagian 'Konversi gagal'.")
        sys.exit(1)
    if len(layouts) > 1:
        log(f"\nGAGAL: layout input kedua model berbeda {layouts}; konversi ulang salah satunya.")
        sys.exit(1)

    info_src = os.path.join(export_dir, cfg.get("info_json", "pokemon_info.json"))
    if os.path.isfile(info_src):
        shutil.copy2(info_src, os.path.join(out_dir, "pokemon_info.json"))
    manifest = write_manifest(out_dir, cfg, layouts.pop(), args.name or os.path.basename(out_dir), done)
    log(f"\nSelesai. Bundle: {out_dir}")
    log("Isi:", sorted(os.listdir(out_dir)))
    missing = [t for t in args.tasks if t not in done]
    if missing:
        log(f"PERINGATAN: {missing} tidak ikut (aplikasi tetap jalan dengan kepala yang ada).")
    log("Manifest:", json.dumps({k: manifest[k] for k in ('name', 'img_size', 'layout')}, ensure_ascii=False))


if __name__ == "__main__":
    main()
