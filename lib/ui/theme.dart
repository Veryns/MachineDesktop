import 'package:flutter/material.dart';

// Palet mengikuti desain web (style.css): perangkat Pokédex merah.
const kRed = Color(0xFFE60012);
const kRedBright = Color(0xFFFF1E2D);
const kRedDark = Color(0xFFA8000C);
const kInk = Color(0xFF111114);
const kBezel = Color(0xFFF8F9FA);
const kGreyFrame = Color(0xFFC8CCD0);
const kGreyScreen = Color(0xFFB7BCBF);
const kBlueLens = Color(0xFF26B7F7);
const kBlueKey = Color(0xFF9CC8EC);
const kBlueKeyHi = Color(0xFFB9DBF6);
const kBlueKeyLo = Color(0xFF75AEDC);
const kOk = Color(0xFF27C95C);
const kWarn = Color(0xFFFFAA00);

const typeColors = <String, Color>{
  'Normal': Color(0xFFA8A77A),
  'Fire': Color(0xFFEE8130),
  'Water': Color(0xFF6390F0),
  'Electric': Color(0xFFF7D02C),
  'Grass': Color(0xFF7AC74C),
  'Ice': Color(0xFF96D9D6),
  'Fighting': Color(0xFFC22E28),
  'Poison': Color(0xFFA33EA1),
  'Ground': Color(0xFFE2BF65),
  'Flying': Color(0xFFA98FF3),
  'Psychic': Color(0xFFF95587),
  'Bug': Color(0xFFA6B91A),
  'Rock': Color(0xFFB6A136),
  'Ghost': Color(0xFF735797),
  'Dragon': Color(0xFF6F35FC),
  'Dark': Color(0xFF705746),
  'Steel': Color(0xFFB7B7CE),
  'Fairy': Color(0xFFD685AD),
};

/// Warna tipe; tidak peka huruf besar/kecil ("fire" = "Fire").
Color colorOfType(String label) {
  if (label.isEmpty) return const Color(0xFF777777);
  final key = '${label[0].toUpperCase()}${label.substring(1).toLowerCase()}';
  return typeColors[key] ?? const Color(0xFF777777);
}

ThemeData buildTheme() => ThemeData(
      useMaterial3: true,
      colorSchemeSeed: kRed,
      scaffoldBackgroundColor: kRed,
    );
