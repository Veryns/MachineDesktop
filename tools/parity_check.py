#!/usr/bin/env python3
"""Jalankan sebuah bundle ONNX di Python (pra-pemrosesan sama dengan notebook) dan cetak top-k.

Gunanya:
  1. Mengecek bundle/model baru dari temanmu TANPA membuka aplikasi Flutter.
  2. Membandingkan hasilnya dengan yang tampil di aplikasi untuk gambar yang sama.
     (Selisih kecil di persentase wajar: Python memakai resize Lanczos, aplikasi memakai cubic.)

    pip install onnxruntime pillow numpy
    python tools/parity_check.py --bundle models/pokedex_v1 --image contoh.png --top-k 3
"""
import argparse
import json
import os
import sys

import numpy as np
from PIL import Image


def read_json(path):
    with open(path, encoding="utf-8-sig") as f:
        return json.load(f)


def standardize_image(path, size, bg):
    """Salinan setia dari pokedex_predictor.standardize_image (notebook)."""
    bg = tuple(bg)
    img = Image.open(path)
    try:
        img.seek(0)
    except (EOFError, AttributeError):
        pass
    img = img.convert("RGBA")
    img = Image.alpha_composite(Image.new("RGBA", img.size, bg + (255,)), img).convert("RGB")
    w, h = img.size
    scale = size / max(w, h)
    new_size = (max(1, round(w * scale)), max(1, round(h * scale)))
    img = img.resize(new_size, getattr(Image, "Resampling", Image).LANCZOS)
    canvas = Image.new("RGB", (size, size), bg)
    canvas.paste(img, ((size - new_size[0]) // 2, (size - new_size[1]) // 2))
    return canvas


def softmax(z):
    z = z - z.max()
    e = np.exp(z)
    return e / e.sum()


def normalize(scores, kind):
    if kind == "logits":
        return softmax(scores)
    if kind == "probs":
        return scores
    ok = (scores >= -1e-6).all() and (scores <= 1 + 1e-6).all() and abs(scores.sum() - 1) < 1e-2
    return scores if ok else softmax(scores)


def names_of(cj):
    if isinstance(cj, list):
        return cj, cj
    keys = cj["classes"]
    return keys, cj.get("display_names", keys)


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--bundle", required=True)
    ap.add_argument("--image", required=True)
    ap.add_argument("--top-k", type=int, default=3)
    a = ap.parse_args()

    import onnxruntime as ort

    mf = read_json(os.path.join(a.bundle, "manifest.json"))
    size, layout = int(mf.get("img_size", 224)), str(mf.get("layout", "NHWC")).upper()
    pil = standardize_image(a.image, size, mf.get("bg_color", [255, 255, 255]))
    x = np.asarray(pil, dtype="float32")[None] * float(mf.get("input_scale", 1.0))
    if layout == "NCHW":
        x = np.transpose(x, (0, 3, 1, 2))
    print(f"Bundle: {mf.get('name', a.bundle)} | input {x.shape} {layout}")

    shown = False
    for head in ("type", "species"):
        spec = mf.get(head)
        if not spec:
            continue
        sess = ort.InferenceSession(os.path.join(a.bundle, spec["model"]), providers=["CPUExecutionProvider"])
        inp = sess.get_inputs()[0]
        out = np.asarray(sess.run(None, {inp.name: np.ascontiguousarray(x)})[0]).reshape(-1)
        keys, disp = names_of(read_json(os.path.join(a.bundle, spec["classes"])))
        if len(keys) != len(out):
            print(f"[{head}] TIDAK COCOK: model {len(out)} keluaran vs {len(keys)} kelas di {spec['classes']}")
            sys.exit(2)
        p = normalize(out, str(mf.get("output", "auto")).lower())
        print(f"\n[{head}] top-{a.top_k}  (jumlah kelas {len(keys)}, jumlah prob {p.sum():.4f})")
        for i in np.argsort(p)[::-1][: a.top_k]:
            print(f"   {disp[i]:<20} {p[i] * 100:6.2f}%")
        shown = True
    if not shown:
        print("Manifest tidak punya kepala 'type' maupun 'species'.")
        sys.exit(2)


if __name__ == "__main__":
    main()
