import 'dart:io';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pasteboard/pasteboard.dart';

import '../app_controller.dart';
import '../core/model_registry.dart';
import 'result_panel.dart';
import 'theme.dart';
import 'widgets.dart';

Future<void> pickModelFolder(AppController c) async {
  final dir = await FilePicker.platform
      .getDirectoryPath(dialogTitle: 'Pilih folder bundle model (berisi manifest.json)');
  if (dir != null) await c.openFolder(dir);
}

Future<void> pickImageInto(AppController c) async {
  final r = await FilePicker.platform.pickFiles(type: FileType.image, withData: true);
  final f = (r == null || r.files.isEmpty) ? null : r.files.first;
  if (f == null) return;
  final bytes = f.bytes ?? (f.path != null ? await File(f.path!).readAsBytes() : null);
  if (bytes != null) await c.setImage(bytes, f.name);
}

/// Tempel gambar dari clipboard: file gambar yang di-copy di Explorer, atau gambar hasil screenshot/copy image.
Future<void> pasteImageInto(AppController c) async {
  if (c.engine == null) return;
  const exts = ['.png', '.jpg', '.jpeg', '.gif', '.webp', '.bmp'];
  try {
    final files = await Pasteboard.files();
    for (final path in files) {
      if (exts.any((e) => path.toLowerCase().endsWith(e))) {
        final name = path.split(RegExp(r'[\\/]')).last;
        await c.setImage(await File(path).readAsBytes(), name);
        return;
      }
    }
    final bytes = await Pasteboard.image;
    if (bytes != null && bytes.isNotEmpty) {
      await c.setImage(bytes, 'tempel.png');
    }
  } catch (_) {
    // clipboard tidak berisi gambar yang bisa dibaca: abaikan
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key, required this.c});
  final AppController c;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: c,
      builder: (context, _) {
        final Widget body;
        if (c.scanning) {
          body = const Center(child: CircularProgressIndicator(color: Colors.white));
        } else if (c.bundles.isEmpty && !c.loadingModel && c.modelError == null) {
          body = NoModels(c: c);
        } else {
          body = DexLayout(c: c);
        }
        return CallbackShortcuts(
          bindings: {
            const SingleActivator(LogicalKeyboardKey.f5): () => c.rescan(),
            const SingleActivator(LogicalKeyboardKey.keyV, control: true): () => pasteImageInto(c),
            const SingleActivator(LogicalKeyboardKey.keyO, control: true): () {
              if (c.engine != null) pickImageInto(c);
            },
          },
          child: Focus(autofocus: true, child: Scaffold(backgroundColor: kRed, body: body)),
        );
      },
    );
  }
}

/// Susunan utama: layar kiri + panel kanan (lebar) atau ditumpuk (sempit).
class DexLayout extends StatelessWidget {
  const DexLayout({super.key, required this.c});
  final AppController c;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, box) {
      if (box.maxWidth >= 960) {
        final rightW = (box.maxWidth * 0.36).clamp(420.0, 760.0);
        return Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Expanded(child: LeftScreen(c: c)),
          Container(width: 4, color: kInk),
          SizedBox(width: rightW, child: RightPanel(c: c)),
        ]);
      }
      return SingleChildScrollView(
        child: Column(children: [
          SizedBox(height: 480, child: LeftScreen(c: c)),
          Container(height: 4, color: kInk),
          SizedBox(height: 700, child: RightPanel(c: c)),
        ]),
      );
    });
  }
}

// ======================================================= KIRI
class LeftScreen extends StatelessWidget {
  const LeftScreen({super.key, required this.c});
  final AppController c;

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Padding(padding: const EdgeInsets.fromLTRB(18, 12, 18, 10), child: _TopBar(c: c)),
      Container(height: 3.5, color: kInk),
      Expanded(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 16),
          child: _Bezel(c: c),
        ),
      ),
    ]);
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.c});
  final AppController c;

  @override
  Widget build(BuildContext context) {
    const shadow = [Shadow(color: kRedDark, offset: Offset(0, 2))];
    final ready = c.engine != null && c.modelError == null;
    return Row(children: [
      DexLens(ready: ready),
      const SizedBox(width: 12),
      Expanded(
        child: SizedBox(
          height: 66,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Padding(padding: EdgeInsets.only(top: 4), child: Leds()),
            const Spacer(),
            _ModelInfo(c: c),
          ]),
        ),
      ),
      const SizedBox(width: 12),
      const Text('POKÉDEX AI',
          style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w900, letterSpacing: 1.2, shadows: shadow)),
    ]);
  }
}

Widget _dropdownBox({required Widget child}) => Container(
      height: 30,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        color: kInk,
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: Colors.white, width: 2),
      ),
      child: DropdownButtonHideUnderline(child: child),
    );

/// Status model di bawah LED: teks status + (hanya bila perlu) pilihan model.
class _ModelInfo extends StatelessWidget {
  const _ModelInfo({required this.c});
  final AppController c;

  @override
  Widget build(BuildContext context) {
    const white = TextStyle(
      color: Colors.white,
      fontSize: 12.5,
      fontWeight: FontWeight.w800,
      shadows: [Shadow(color: kRedDark, offset: Offset(0, 1.5))],
    );
    final m = c.engine?.manifest;
    final String label;
    if (c.modelError != null) {
      label = 'Model error';
    } else if (c.loadingModel) {
      label = 'Memuat model…';
    } else if (c.engine != null) {
      label = (m == null || m.scope.isEmpty) ? 'Model siap' : 'Model siap · ${m.scope}';
    } else {
      label = 'Belum ada model';
    }
    final showPicker = c.bundles.length > 1 || c.modelError != null;
    return SizedBox(
      height: 30,
      child: Row(children: [
        if (showPicker) ...[
          const SizedBox(width: 10),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 200),
            child: _dropdownBox(
              child: DropdownButton<ModelBundle>(
                value: c.selected,
                isExpanded: true,
                isDense: true,
                hint: Text('(pilih model)', style: white.copyWith(color: Colors.white70)),
                dropdownColor: kInk,
                iconEnabledColor: Colors.white,
                iconDisabledColor: Colors.white38,
                style: white,
                items: [
                  for (final b in c.bundles)
                    DropdownMenuItem(value: b, child: Text(b.title, overflow: TextOverflow.ellipsis)),
                ],
                onChanged: c.busy ? null : (b) => c.select(b),
              ),
            ),
          ),
          _MiniIcon(icon: Icons.refresh, tip: 'Muat ulang daftar model (F5)', onTap: c.busy ? null : c.rescan),
          _MiniIcon(icon: Icons.folder_open, tip: 'Buka folder model…', onTap: c.busy ? null : () => pickModelFolder(c)),
        ],
        if (c.problems.isNotEmpty) ...[
          const SizedBox(width: 6),
          GestureDetector(
            onTap: () => showDialog<void>(
              context: context,
              builder: (dialogContext) => AlertDialog(
                title: const Text('Bundle bermasalah'),
                content: SelectableText(c.problems.join('\n\n')),
                actions: [TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Tutup'))],
              ),
            ),
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: Text('${c.problems.length} dilewati',
                  style: white.copyWith(fontSize: 11, decoration: TextDecoration.underline)),
            ),
          ),
        ],
      ]),
    );
  }
}

class _Bezel extends StatelessWidget {
  const _Bezel({required this.c});
  final AppController c;

  @override
  Widget build(BuildContext context) {
    final has = c.imageBytes != null;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
      decoration: BoxDecoration(
        color: kBezel,
        border: Border.all(color: kInk, width: 3.5),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(14),
          topRight: Radius.circular(14),
          bottomRight: Radius.circular(14),
          bottomLeft: Radius.circular(36),
        ),
      ),
      child: Column(children: [
        const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Dot(size: 9, color: kRed),
          SizedBox(width: 14),
          Dot(size: 9, color: kRed),
        ]),
        const SizedBox(height: 6),
        Expanded(child: _DropZone(c: c)),
        const SizedBox(height: 10),
        _HistoryStrip(c: c),
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 30),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              if (has)
                GestureDetector(
                  onTap: c.clearImage,
                  child: MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
                      decoration: inkBox(color: kRed, radius: 99, border: 2.5, shadow: const [BoxShadow(color: kInk, offset: Offset(0, 2))]),
                      child: const Text('✕ Hapus Gambar', style: TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w800)),
                    ),
                  ),
                )
              else
                const Dot(size: 20, color: kRed, border: 2.5),
              const Lines(),
            ]),
          ),
        ),
      ]),
    );
  }
}

class _DropZone extends StatefulWidget {
  const _DropZone({required this.c});
  final AppController c;

  @override
  State<_DropZone> createState() => _DropZoneState();
}

class _DropZoneState extends State<_DropZone> {
  bool _drag = false;
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final c = widget.c;
    final has = c.imageBytes != null;
    final active = _drag || _hover;
    return DropTarget(
      onDragEntered: (_) => setState(() => _drag = true),
      onDragExited: (_) => setState(() => _drag = false),
      onDragDone: (d) async {
        setState(() => _drag = false);
        if (d.files.isEmpty) return;
        final f = d.files.first;
        await c.setImage(await f.readAsBytes(), f.name);
      },
      child: MouseRegion(
        cursor: c.engine == null ? MouseCursor.defer : SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          onTap: c.engine == null ? null : () => pickImageInto(c),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: active ? const Color(0xFFF2F9FF) : Colors.white,
              border: Border.all(color: active ? kBlueLens : kInk, width: 3),
              borderRadius: BorderRadius.circular(8),
            ),
            child: has
                ? Padding(
                    padding: const EdgeInsets.all(14),
                    child: SizedBox.expand(
                      child: Image.memory(
                        c.imageBytes!,
                        fit: BoxFit.contain,
                        filterQuality: FilterQuality.medium,
                        errorBuilder: (context, error, stack) => const Center(
                          child: Text('Gambar tidak bisa ditampilkan.', style: TextStyle(color: Colors.black54)),
                        ),
                      ),
                    ),
                  )
                : Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Container(
                          width: 56,
                          height: 56,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: kRed,
                            border: Border.all(color: kInk, width: 3),
                            boxShadow: const [BoxShadow(color: kInk, offset: Offset(0, 3))],
                          ),
                          child: const Icon(Icons.upload, color: Colors.white, size: 28),
                        ),
                        const SizedBox(height: 10),
                        const Text('Seret atau Klik untuk Pilih Gambar Pokémon',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: kInk, fontSize: 18, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 6),
                        Text(c.engine == null ? 'Tunggu model selesai dimuat…' : 'Atau tekan Ctrl + V untuk menempel gambar dari clipboard',
                            textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF444952))),
                        const SizedBox(height: 6),
                        const Text('PNG, JPG, GIF, WEBP · Dilatih pada sprite/ilustrasi Pokémon',
                            textAlign: TextAlign.center, style: TextStyle(color: Color(0xFF6C727D), fontSize: 12.5)),
                      ]),
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

// ======================================================= KANAN
class RightPanel extends StatelessWidget {
  const RightPanel({super.key, required this.c});
  final AppController c;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 16),
      child: Column(children: [
        Expanded(child: GreyModule(c: c)),
      ]),
    );
  }
}

/// Riwayat gambar: 6 slot besar di bawah layar kiri, memenuhi lebarnya.
class _HistoryStrip extends StatelessWidget {
  const _HistoryStrip({required this.c});
  final AppController c;

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];
    for (var i = 0; i < AppController.historySize; i++) {
      final e = c.history[i];
      if (i > 0) children.add(const SizedBox(width: 10));
      children.add(Expanded(
        child: BlueKey(
          height: 104,
          thumb: e?.bytes,
          active: c.activeSlot == i,
          tooltip: e?.name,
          onTap: e == null ? null : () => c.selectSlot(i),
        ),
      ));
    }
    return Padding(padding: const EdgeInsets.only(bottom: 3), child: Row(children: children));
  }
}

class _MiniIcon extends StatelessWidget {
  const _MiniIcon({required this.icon, required this.tip, required this.onTap});
  final IconData icon;
  final String tip;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => IconButton(
        onPressed: onTap,
        tooltip: tip,
        icon: Icon(icon),
        iconSize: 19,
        color: Colors.white,
        disabledColor: Colors.white38,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints.tightFor(width: 30, height: 30),
      );
}

class GreyModule extends StatelessWidget {
  const GreyModule({super.key, required this.c});
  final AppController c;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 6, 10, 10),
      decoration: inkBox(color: kGreyFrame, radius: 10),
      child: Column(children: [
        const ExcludeSemantics(
          child: Row(children: [
            Dot(size: 12, color: kBlueLens),
            SizedBox(width: 6),
            Dot(size: 5, color: kRed, border: 0),
            SizedBox(width: 3),
            Dot(size: 5, color: kRed, border: 0),
            SizedBox(width: 3),
            Dot(size: 5, color: kRed, border: 0),
            SizedBox(width: 6),
            Text('POKECHAT · DATA', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w900, letterSpacing: 0.8, color: kInk)),
          ]),
        ),
        const SizedBox(height: 5),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(10),
            clipBehavior: Clip.antiAlias,
            decoration: inkBox(color: kGreyScreen, radius: 8),
            child: ResultView(c: c),
          ),
        ),
      ]),
    );
  }
}

// ======================================================= BELUM ADA MODEL
class NoModels extends StatelessWidget {
  const NoModels({super.key, required this.c});
  final AppController c;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: inkBox(color: kBezel, radius: 14, border: 3.5),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const PokeBallIcon(size: 64),
              const SizedBox(height: 14),
              const Text('Belum ada model', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: kInk)),
              const SizedBox(height: 10),
              const Text(
                'Taruh folder bundle model (berisi manifest.json) di dalam folder "models" di samping aplikasi, '
                'lalu tekan Muat ulang. Atau pilih folder bundle secara manual.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFF363B42)),
              ),
              if (c.roots.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text('Folder yang dipindai:\n${c.roots.join('\n')}',
                    textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF6C727D), fontSize: 12)),
              ],
              if (c.problems.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text('Bundle bermasalah:\n${c.problems.join('\n')}',
                    textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF9B1C1C), fontSize: 12)),
              ],
              const SizedBox(height: 18),
              Wrap(spacing: 12, runSpacing: 8, alignment: WrapAlignment.center, children: [
                FilledButton.icon(
                  style: FilledButton.styleFrom(backgroundColor: kRed),
                  onPressed: () => pickModelFolder(c),
                  icon: const Icon(Icons.folder_open),
                  label: const Text('Pilih folder model…'),
                ),
                OutlinedButton.icon(onPressed: c.rescan, icon: const Icon(Icons.refresh), label: const Text('Muat ulang')),
              ]),
            ]),
          ),
        ),
      ),
    );
  }
}