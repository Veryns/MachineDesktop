import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'theme.dart';

/// Kotak dengan garis tepi tinta tebal khas desain Pokédex.
BoxDecoration inkBox({
  Color? color,
  Gradient? gradient,
  double radius = 8,
  BorderRadius? borderRadius,
  double border = 3,
  List<BoxShadow>? shadow,
}) =>
    BoxDecoration(
      color: color,
      gradient: gradient,
      borderRadius: borderRadius ?? BorderRadius.circular(radius),
      border: Border.all(color: kInk, width: border),
      boxShadow: shadow,
    );

class Dot extends StatelessWidget {
  const Dot({super.key, required this.size, required this.color, this.border = 2});
  final double size;
  final Color color;
  final double border;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color,
          border: border == 0 ? null : Border.all(color: kInk, width: border),
        ),
      );
}

/// Lensa biru besar di pojok kiri atas.
class DexLens extends StatelessWidget {
  const DexLens({super.key, this.ready = true});

  /// true = biru (model siap), false = merah (belum siap / error / memuat).
  final bool ready;

  @override
  Widget build(BuildContext context) => Container(
        width: 66,
        height: 66,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white,
          border: Border.all(color: kInk, width: 3.5),
          boxShadow: const [BoxShadow(color: Color(0x47000000), offset: Offset(0, 3))],
        ),
        child: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: kInk, width: 3),
            gradient: RadialGradient(
              center: const Alignment(-0.36, -0.4),
              radius: 0.95,
              colors: ready
                  ? const [Color(0xFF9CE8FF), kBlueLens, Color(0xFF076CA3)]
                  : const [Color(0xFFFF9A9A), Color(0xFFE5000F), Color(0xFF7A0008)],
              stops: const [0, 0.52, 1],
            ),
          ),
          child: Stack(children: [
            Positioned(
              top: 4,
              left: 7,
              child: Transform.rotate(
                angle: -0.44,
                child: Container(
                  width: 15,
                  height: 9,
                  decoration: const BoxDecoration(
                    color: Color(0xD9FFFFFF),
                    borderRadius: BorderRadius.all(Radius.elliptical(15, 9)),
                  ),
                ),
              ),
            ),
          ]),
        ),
      );
}

/// Tiga LED merah-kuning-hijau.
class Leds extends StatelessWidget {
  const Leds({super.key});

  Widget _led(Color c) => Container(
        width: 14,
        height: 14,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: kInk, width: 2.5),
          gradient: RadialGradient(
            center: const Alignment(-0.4, -0.4),
            radius: 0.9,
            colors: [Color.lerp(c, Colors.white, 0.65)!, c],
          ),
        ),
      );

  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        _led(const Color(0xFFFF2B2B)),
        const SizedBox(width: 8),
        _led(const Color(0xFFFFD400)),
        const SizedBox(width: 8),
        _led(const Color(0xFF29E05A)),
      ]);
}

/// Garis-garis tinta (speaker / grill).
class Lines extends StatelessWidget {
  const Lines({super.key, this.count = 3, this.width = 44, this.height = 3.5, this.gap = 3.5});
  final int count;
  final double width;
  final double height;
  final double gap;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: width,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          for (var i = 0; i < count; i++)
            Padding(
              padding: EdgeInsets.only(top: i == 0 ? 0 : gap),
              child: Container(
                height: height,
                decoration: BoxDecoration(color: kInk, borderRadius: BorderRadius.circular(2)),
              ),
            ),
        ]),
      );
}

/// Ikon pokéball kecil di tombol biru.
class PokeBallMark extends StatelessWidget {
  const PokeBallMark({super.key});

  @override
  Widget build(BuildContext context) {
    const w = Color(0xE0FFFFFF);
    return SizedBox(
      width: 28,
      height: 28,
      child: Stack(alignment: Alignment.center, children: [
        Container(decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: w, width: 2.5))),
        Container(height: 2.5, color: w),
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: kBlueKeyLo,
            border: Border.all(color: w, width: 2.5),
          ),
        ),
      ]),
    );
  }
}

class BlueKey extends StatelessWidget {
  const BlueKey({super.key, required this.height, this.thumb, this.active = false, this.onTap, this.tooltip});
  final double height;

  /// Gambar mini (slot riwayat). Null = slot kosong, tampil ikon Pokéball.
  final Uint8List? thumb;
  final bool active;
  final VoidCallback? onTap;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    Widget key = Container(
        height: height,
        alignment: Alignment.center,
        decoration: inkBox(
          radius: 10,
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [kBlueKeyHi, kBlueKey, kBlueKeyLo],
            stops: [0, 0.65, 1],
          ),
          shadow: const [BoxShadow(color: kRedDark, offset: Offset(0, 3))],
        ),
        child: thumb == null
            ? const PokeBallMark()
            : Container(
                margin: const EdgeInsets.all(5),
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: active ? kInk : Colors.white, width: active ? 3 : 2),
                ),
                child: SizedBox.expand(
                  child: Image.memory(thumb!,
                      fit: BoxFit.contain,
                      cacheHeight: 120,
                      gaplessPlayback: true,
                      errorBuilder: (context, error, stack) => const PokeBallMark()),
                ),
              ),
      );
    if (onTap != null) {
      key = MouseRegion(cursor: SystemMouseCursors.click, child: GestureDetector(onTap: onTap, child: key));
    }
    return tooltip == null ? key : Tooltip(message: tooltip!, child: key);
  }
}

/// Pokéball besar untuk keadaan kosong.
class PokeBallIcon extends StatelessWidget {
  const PokeBallIcon({super.key, this.size = 44});
  final double size;

  @override
  Widget build(BuildContext context) {
    const ink = Color(0xFF2B2F36);
    return Opacity(
      opacity: 0.65,
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: ink, width: 3),
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [kRed, kRed, Colors.white, Colors.white],
            stops: [0, 0.5, 0.5, 1],
          ),
        ),
        child: Container(height: 4, color: ink),
      ),
    );
  }
}

class TypeBadge extends StatelessWidget {
  const TypeBadge({super.key, required this.label});
  final String label;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 2),
        decoration: BoxDecoration(
          color: colorOfType(label),
          borderRadius: BorderRadius.circular(99),
          border: Border.all(color: kInk, width: 1.5),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11.5,
            fontWeight: FontWeight.w800,
            shadows: [Shadow(color: Colors.black45, offset: Offset(0, 1), blurRadius: 1)],
          ),
        ),
      );
}