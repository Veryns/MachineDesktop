import 'package:flutter/material.dart';

import '../app_controller.dart';
import '../core/prediction.dart';
import 'theme.dart';
import 'widgets.dart';

const _confThreshold = 0.5;
const _skipInfoKeys = {'name_key', 'types_list', 'in_species_scope'};
const _textDark = Color(0xFF2B2F36);
const _textMuted = Color(0xFF363B42);

/// Isi layar abu-abu (POKECHAT · DATA): memilih tampilan sesuai status.
class ResultView extends StatelessWidget {
  const ResultView({super.key, required this.c});
  final AppController c;

  @override
  Widget build(BuildContext context) {
    if (c.loadingModel) return const _Msg(text: 'Memuat model…', spinner: true);
    if (c.modelError != null) return _ErrorBox(title: 'Model tidak bisa dipakai', message: c.modelError!);
    if (c.engine == null) return const _Msg(text: 'Pilih model di modul merah di atas.');
    if (c.predictError != null) return _ErrorBox(title: 'Prediksi gagal', message: c.predictError!);
    if (c.imageBytes == null) {
      return const _Msg(text: 'Belum ada gambar.\nUnggah Pokémon di layar kiri.');
    }
    final r = c.result;
    if (r == null) return const _Msg(text: 'Menganalisis gambar…', spinner: true);
    return _Content(r: r);
  }
}

class _Msg extends StatelessWidget {
  const _Msg({required this.text, this.spinner = false});
  final String text;
  final bool spinner;

  @override
  Widget build(BuildContext context) => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          if (spinner)
            const SizedBox(width: 32, height: 32, child: CircularProgressIndicator(strokeWidth: 3.5, color: kRed))
          else
            const PokeBallIcon(),
          const SizedBox(height: 10),
          Text(text, textAlign: TextAlign.center, style: const TextStyle(color: _textDark, fontSize: 13, fontWeight: FontWeight.w700)),
        ]),
      );
}

class _ErrorBox extends StatelessWidget {
  const _ErrorBox({required this.title, required this.message});
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        child: Container(
          padding: const EdgeInsets.all(9),
          decoration: inkBox(color: const Color(0xFFFFA39E), radius: 6, border: 2),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(color: Color(0xFF5C0000), fontWeight: FontWeight.w900, fontSize: 13)),
            const SizedBox(height: 4),
            SelectableText(message, style: const TextStyle(color: Color(0xFF5C0000), fontSize: 12, fontWeight: FontWeight.w600)),
          ]),
        ),
      );
}

String _pct(double v) => '${(v * 100).toStringAsFixed(1)}%';

String _pretty(String k) => k
    .replaceAll('_', ' ')
    .split(' ')
    .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
    .join(' ');

Widget _h3(String text) => Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 5),
      child: Text(text.toUpperCase(), style: const TextStyle(fontSize: 11.8, fontWeight: FontWeight.w900, letterSpacing: 0.6, color: kInk)),
    );

class _Content extends StatelessWidget {
  const _Content({required this.r});
  final PredictionResult r;

  @override
  Widget build(BuildContext context) {
    final topSp = r.species.isEmpty ? null : r.species.first;
    final topType = r.types.isEmpty ? null : r.types.first;
    final dataTypes = r.typesFromData;
    final badges = topSp == null
        ? <String>[]
        : (dataTypes ?? (topType == null ? <String>[] : [topType.label]));
    final title = topSp?.label ?? topType?.label ?? '—';
    final conf = [
      if (topSp != null) 'Spesies ${_pct(topSp.confidence)}',
      if (dataTypes != null) 'Tipe dari data Pokédex' else if (topType != null) 'Tipe (model) ${_pct(topType.confidence)}',
    ].join(' · ');
    final low = topSp != null && topSp.confidence < _confThreshold;
    final info = (r.info ?? const <String, dynamic>{})
        .entries
        .where((e) =>
            !_skipInfoKeys.contains(e.key) &&
            e.value != null &&
            '${e.value}'.isNotEmpty &&
            '${e.value}'.toLowerCase() != 'nan')
        .toList();

    final lists = <Widget>[
      if (r.types.isNotEmpty)
        _BarsBlock(
          title: dataTypes != null ? 'Tipe · model' : 'Tipe',
          items: r.types,
          colorFor: (s) => colorOfType(s.label),
        ),
      if (r.species.isNotEmpty) _BarsBlock(title: 'Spesies', items: r.species, colorFor: (_) => kRed),
    ];

    return SingleChildScrollView(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        // ---- hero
        Container(
          padding: const EdgeInsets.all(8),
          decoration: inkBox(color: const Color(0x8CFFFFFF), radius: 8, border: 2),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, height: 1.1, color: kInk)),
                if (badges.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 5, bottom: 3),
                    child: Wrap(spacing: 4, runSpacing: 4, children: [for (final b in badges) TypeBadge(label: b)]),
                  ),
                Text(conf, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: _textMuted)),
              ]),
            ),
            const SizedBox(width: 8),
            Column(children: [
              Container(
                width: 54,
                height: 54,
                clipBehavior: Clip.antiAlias,
                decoration: inkBox(color: Colors.white, radius: 6, border: 2),
                child: Image.memory(r.processedPng, fit: BoxFit.contain, filterQuality: FilterQuality.medium),
              ),
              const SizedBox(height: 2),
              const Text('Input Model', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: _textMuted)),
            ]),
          ]),
        ),
        // ---- peringatan
        if (low)
          Container(
            margin: const EdgeInsets.only(top: 8),
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
            decoration: inkBox(color: const Color(0xFFFFE58F), radius: 6, border: 2),
            child: const Text(
              'Keyakinan rendah. Pokémon ini mungkin di luar cakupan model atau gambarnya berbeda dari data latih.',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF4D3800)),
            ),
          ),
        // ---- tipe & spesies
        if (lists.length == 2)
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: lists[0]),
            const SizedBox(width: 8),
            Expanded(child: lists[1]),
          ])
        else
          ...lists,
        // ---- info
        if (info.isNotEmpty) ...[
          _h3('Info Pokédex'),
          LayoutBuilder(builder: (context, box) {
            final w = (box.maxWidth - 6) / 2;
            return Wrap(spacing: 6, runSpacing: 6, children: [
              for (final e in info) SizedBox(width: w, child: _InfoItem(label: _pretty(e.key), value: '${e.value}')),
            ]);
          }),
        ],
      ]),
    );
  }
}

class _BarsBlock extends StatelessWidget {
  const _BarsBlock({required this.title, required this.items, required this.colorFor});
  final String title;
  final List<Scored> items;
  final Color Function(Scored) colorFor;

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _h3(title),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
          decoration: BoxDecoration(
            color: const Color(0x73FFFFFF),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: const Color(0x59111114), width: 1.5),
          ),
          child: Column(children: [
            for (var i = 0; i < items.length; i++)
              Padding(
                padding: EdgeInsets.only(top: i == 0 ? 0 : 6),
                child: _BarRow(label: items[i].label, value: items[i].confidence, color: colorFor(items[i])),
              ),
          ]),
        ),
      ]);
}

class _BarRow extends StatelessWidget {
  const _BarRow({required this.label, required this.value, required this.color});
  final String label;
  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final v = value.clamp(0.0, 1.0).toDouble();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        Expanded(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11.8, fontWeight: FontWeight.w800, color: kInk))),
        const SizedBox(width: 6),
        Text(_pct(value), style: const TextStyle(fontSize: 11.8, fontWeight: FontWeight.w800, color: kInk)),
      ]),
      const SizedBox(height: 2),
      Container(
        height: 7,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: const Color(0x33000000),
          borderRadius: BorderRadius.circular(99),
          border: Border.all(color: kInk, width: 1),
        ),
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: v),
          duration: const Duration(milliseconds: 650),
          curve: Curves.easeOutCubic,
          builder: (context, t, _) => Align(
            alignment: Alignment.centerLeft,
            child: FractionallySizedBox(
              widthFactor: t < 0.015 ? 0.015 : t,
              heightFactor: 1,
              child: DecoratedBox(decoration: BoxDecoration(color: color)),
            ),
          ),
        ),
      ),
    ]);
  }
}

class _InfoItem extends StatelessWidget {
  const _InfoItem({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
        decoration: inkBox(color: const Color(0x99FFFFFF), radius: 6, border: 1.5),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label.toUpperCase(), style: const TextStyle(fontSize: 9.9, fontWeight: FontWeight.w900, color: Color(0xFF464B54))),
          const SizedBox(height: 1),
          Text(value, style: const TextStyle(fontSize: 12.2, fontWeight: FontWeight.w800, color: kInk)),
        ]),
      );
}
