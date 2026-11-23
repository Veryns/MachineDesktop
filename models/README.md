# Folder `models/` — satu subfolder = satu model (bundle)

Aplikasi memindai folder ini saat dibuka dan setiap kali tombol **Muat ulang** ditekan.
Mengganti model = menaruh subfolder baru di sini. Tidak perlu membangun ulang aplikasi.

```
models/
  pokedex_v1/                  <- nama folder bebas
    manifest.json              <- WAJIB
    type_model.onnx            \  kepala "type"    (opsional, tapi minimal satu kepala)
    class_names_type.json      /
    species_model.onnx         \  kepala "species" (opsional)
    class_names_species.json   /
    pokemon_info.json          <- opsional (info Pokédex per spesies)
```

## manifest.json

```json
{
  "name": "Pokedex v1 (MobileNetV2)",
  "scope": "Gen 1-3, top-150, 150 kelas",
  "img_size": 224,
  "bg_color": [255, 255, 255],
  "layout": "NHWC",
  "input_scale": 1.0,
  "output": "auto",
  "type":    { "model": "type_model.onnx",    "classes": "class_names_type.json" },
  "species": { "model": "species_model.onnx", "classes": "class_names_species.json" },
  "info": "pokemon_info.json"
}
```

| Kunci | Arti | Bawaan |
|---|---|---|
| `name` | nama di dropdown | nama folder |
| `img_size` | sisi gambar input (persegi) | 224 |
| `bg_color` | warna latar untuk letterbox & alpha | `[255,255,255]` |
| `layout` | urutan tensor input: `NHWC` (Keras) atau `NCHW` | `NHWC` |
| `input_scale` | piksel 0-255 dikali angka ini sebelum masuk model (mis. `0.00392156` untuk 0-1) | `1.0` |
| `output` | `probs` (sudah softmax), `logits` (aplikasi menerapkan softmax), `auto` (deteksi) | `auto` |
| `input_name` | nama input ONNX, bila perlu dipaksa | dibaca dari model |
| `type` / `species` | berkas model + daftar kelas; boleh salah satu saja | — |

Model yang dilatih dengan kode notebook saat ini memakai nilai di atas (preprocessing ada di dalam model).
Kalau temanmu mengubah `IMG_SIZE`, cukup sesuaikan `img_size`. Jika normalisasi dipindah keluar model,
sesuaikan `input_scale`.

## class_names

```json
{ "classes": ["bug", "dark"], "display_names": ["Bug", "Dark"] }
```
atau daftar polos `["bug", "dark"]`. Jumlah kelas HARUS sama dengan jumlah keluaran model; kalau tidak,
aplikasi menolak model itu dengan pesan yang jelas (bukan menampilkan hasil ngawur).

## Membuat bundle

- Dari model Keras hasil notebook: `python tools/convert_to_onnx.py --export-dir <pokedex_export> --out models/<nama>`
- Untuk tes tanpa model asli: `python tools/make_demo_bundle.py` (model acak, hasilnya bukan prediksi nyata)
- Cek bundle tanpa membuka aplikasi: `python tools/parity_check.py --bundle models/<nama> --image gambar.png`
