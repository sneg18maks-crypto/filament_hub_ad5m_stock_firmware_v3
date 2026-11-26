import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../send.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets.dart';
import 'connect_page.dart';

/// Экран «Отправить файл на принтер»: .gcode / .3mf / .stl
class SendPage extends StatefulWidget {
  const SendPage({super.key});
  @override
  State<SendPage> createState() => _SendPageState();
}

class _SendPageState extends State<SendPage> {
  String? name;
  Uint8List? bytes;
  InspectResult? info;
  final opts = SendOptions();
  bool loading = false;
  bool sending = false;
  bool done = false;
  int step = 0;
  String? error;

  Future<void> _pick() async {
    setState(() {
      loading = true;
      error = null;
      done = false;
    });
    try {
      final r = await FilePicker.platform.pickFiles(type: FileType.any, withData: true);
      if (r == null) {
        setState(() => loading = false);
        return;
      }
      final f = r.files.single;
      Uint8List? data = f.bytes;
      if (data == null && f.path != null) data = await File(f.path!).readAsBytes();
      if (data == null) throw Exception('Не удалось прочитать файл');
      final res = await inspectFile(f.name, data);
      setState(() {
        name = f.name;
        bytes = data;
        info = res;
        loading = false;
      });
    } catch (e) {
      setState(() {
        loading = false;
        error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _send(AppState st) async {
    setState(() {
      sending = true;
      done = false;
      error = null;
      step = 0;
    });
    try {
      await st.sendFile(
        name: name!,
        bytes: bytes!,
        info: info!,
        o: opts,
        onStep: (s, m) {
          if (mounted) setState(() => step = s);
        },
      );
      if (mounted) setState(() => done = true);
    } catch (e) {
      if (mounted) setState(() => error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

  IconData _icon(String n) {
    final l = n.toLowerCase();
    if (l.endsWith('.stl')) return Icons.view_in_ar;
    if (l.endsWith('.3mf')) return Icons.layers;
    return Icons.code;
  }

  @override
  Widget build(BuildContext context) {
    final st = AppScope.of(context);
    final needs = info?.needsSlicing ?? false;
    final noServer = needs && st.slicerUrl.trim().isEmpty && !st.demoMode;
    final canSend = info != null && info!.supported && !noServer && !sending;
    final steps = <(int, String)>[
      (0, 'Анализ файла'),
      if (needs) (1, 'Нарезка на сервере'),
      (2, 'Загрузка на принтер по Wi-Fi'),
      if (opts.startNow) (3, 'Запуск печати'),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Отправить на печать')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        if (name == null)
          Panel(
            padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
            child: Column(children: [
              Icon(Icons.upload_file, size: 56, color: mutedColor(context)),
              const SizedBox(height: 12),
              const Text('Выбери файл модели', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Text('.gcode, .3mf или .stl', style: TextStyle(color: mutedColor(context))),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: loading ? null : _pick,
                icon: loading
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.folder_open),
                label: const Text('Выбрать файл'),
              ),
            ]),
          )
        else ...[
          Panel(
            child: Row(children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(color: Palette.green.withOpacity(0.15), borderRadius: BorderRadius.circular(14)),
                child: Icon(_icon(name!), color: Palette.green),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(name!, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold)),
                  Text('${(bytes!.length / 1048576).toStringAsFixed(2)} МБ', style: TextStyle(color: mutedColor(context), fontSize: 12)),
                ]),
              ),
              IconButton(onPressed: sending ? null : _pick, icon: const Icon(Icons.swap_horiz)),
            ]),
          ),
          Panel(
            color: (info!.supported ? (needs ? Palette.orange : Palette.green) : Palette.red).withOpacity(0.12),
            child: Row(children: [
              Icon(info!.supported ? (needs ? Icons.info_outline : Icons.check_circle_outline) : Icons.error_outline,
                  color: info!.supported ? (needs ? Palette.orange : Palette.green) : Palette.red),
              const SizedBox(width: 12),
              Expanded(child: Text(info!.label)),
            ]),
          ),
          if (needs) ...[
            Panel(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const SectionTitle('Параметры нарезки'),
                const Text('Высота слоя, мм'),
                const SizedBox(height: 6),
                Wrap(spacing: 8, children: [
                  for (final v in [0.12, 0.16, 0.2, 0.28])
                    ChoiceChip(
                        label: Text(v.toString()),
                        selected: opts.layer == v,
                        onSelected: sending ? null : (_) => setState(() => opts.layer = v)),
                ]),
                const SizedBox(height: 12),
                Text('Заполнение: ${opts.infill}%'),
                Slider(
                    value: opts.infill.toDouble(),
                    min: 5,
                    max: 100,
                    divisions: 19,
                    onChanged: sending ? null : (v) => setState(() => opts.infill = v.round())),
                SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Поддержки'),
                    value: opts.supports,
                    onChanged: sending ? null : (v) => setState(() => opts.supports = v)),
              ]),
            ),
            if (noServer)
              Panel(
                color: Palette.orange.withOpacity(0.12),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ConnectPage())),
                child: const Row(children: [
                  Icon(Icons.dns_outlined, color: Palette.orange),
                  SizedBox(width: 12),
                  Expanded(child: Text('Сервер нарезки не настроен. Нажми, чтобы указать адрес (server/slicer_server.py).')),
                  Icon(Icons.chevron_right),
                ]),
              ),
          ],
          Panel(
            child: SwitchListTile(
              contentPadding: EdgeInsets.zero,
              secondary: const Icon(Icons.play_circle_outline),
              title: const Text('Сразу начать печать'),
              subtitle: const Text('Выключи, чтобы только загрузить файл в память'),
              value: opts.startNow,
              onChanged: sending ? null : (v) => setState(() => opts.startNow = v),
            ),
          ),
          if (sending || done || error != null)
            Panel(
              child: Column(children: [
                for (final s in steps)
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: _stepIcon(s.$1),
                    title: Text(s.$2),
                  ),
                if (error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(error!, style: const TextStyle(color: Palette.red)),
                  ),
                if (done)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: FilledButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        st.setTab(0);
                      },
                      icon: const Icon(Icons.print),
                      label: const Text('К принтеру'),
                    ),
                  ),
              ]),
            ),
          if (!done)
            FilledButton.icon(
              style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
              onPressed: canSend ? () => _send(st) : null,
              icon: const Icon(Icons.send),
              label: Text(error != null ? 'Повторить' : 'Отправить на принтер'),
            ),
          if (st.demoMode)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text('Включён демо-режим: отправка симулируется. Выключи его в «Я» для реальной работы.',
                  style: TextStyle(color: mutedColor(context), fontSize: 12)),
            ),
        ],
        if (name == null && error != null)
          Padding(padding: const EdgeInsets.only(top: 8), child: Text(error!, style: const TextStyle(color: Palette.red))),
      ]),
    );
  }

  Widget _stepIcon(int code) {
    if (error != null && step == code) return const Icon(Icons.error, color: Palette.red);
    if (done || step > code) return const Icon(Icons.check_circle, color: Palette.green);
    if (sending && step == code) {
      return const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5));
    }
    return const Icon(Icons.radio_button_unchecked, color: Colors.grey);
  }
}
