import 'package:flutter/material.dart';
import '../api.dart';
import '../models.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets.dart';

class ConnectPage extends StatefulWidget {
  const ConnectPage({super.key});
  @override
  State<ConnectPage> createState() => _ConnectPageState();
}

class _ConnectPageState extends State<ConnectPage> {
  bool scanning = false, scanned = false;
  List<String> found = [];
  TextEditingController? slicerCtrl;

  Future<void> _scan() async {
    setState(() {
      scanning = true;
      scanned = true;
      found = [];
    });
    List<String> r = [];
    try {
      r = await PrinterApi.discover();
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      scanning = false;
      found = r;
    });
  }

  Future<void> _test(PrinterProfile p) async {
    snack(context, 'Проверяю ${p.host}…');
    final ok = p.kind == PrinterKind.flashforgeAd5m
        ? await FlashForgeAd5mApi(p.host, p.serialNumber, p.accessCode, p.port).ping()
        : p.kind == PrinterKind.moonraker
            ? await PrinterApi(p.host, p.port).ping()
            : false;
    if (mounted) snack(context, ok ? 'Принтер отвечает ✓' : 'Нет ответа. Проверь IP, LAN Only и код доступа.');
  }

  void _addDialog(AppState st) {
    final name = TextEditingController(text: 'Принтер ${st.printers.length + 1}');
    final host = TextEditingController();
    final port = TextEditingController(text: '7125');
    final code = TextEditingController();
    final serial = TextEditingController();
    var kind = PrinterKind.moonraker;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => Padding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + MediaQuery.of(ctx).viewInsets.bottom),
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Добавить принтер', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 14),
              TextField(controller: name, decoration: const InputDecoration(labelText: 'Название', border: OutlineInputBorder())),
              const SizedBox(height: 10),
              DropdownButtonFormField<PrinterKind>(
                value: kind,
                decoration: const InputDecoration(labelText: 'Тип', border: OutlineInputBorder()),
                items: [for (final k in PrinterKind.values) DropdownMenuItem(value: k, child: Text(kindLabel(k)))],
                onChanged: (v) => setS(() {
                  kind = v ?? kind;
                  port.text = kind == PrinterKind.flashforgeAd5m ? '8898' : kind == PrinterKind.octoprint ? '80' : '7125';
                }),
              ),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(flex: 3, child: TextField(controller: host, decoration: const InputDecoration(labelText: 'IP адрес', hintText: '192.168.1.50', border: OutlineInputBorder()))),
                const SizedBox(width: 10),
                Expanded(child: TextField(controller: port, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Порт', border: OutlineInputBorder()))),
              ]),
              if (kind == PrinterKind.flashforgeAd5m) ...[
                const SizedBox(height: 10),
                TextField(controller: serial, decoration: const InputDecoration(labelText: 'Serial Number', hintText: 'SNADVA5M…', border: OutlineInputBorder())),
                const SizedBox(height: 10),
                TextField(controller: code, decoration: const InputDecoration(labelText: 'Check Code', border: OutlineInputBorder())),
                const SizedBox(height: 6),
                const Text('На принтере включи LAN Only. IP, Serial Number и Check Code смотри в настройках сети принтера. Штатная прошивка, порт 8898.', style: TextStyle(fontSize: 12, color: Palette.green)),
              ],
              if (kind == PrinterKind.bambuLan) ...[
                const SizedBox(height: 10),
                TextField(controller: code, decoration: const InputDecoration(labelText: 'Access code', border: OutlineInputBorder())),
                const SizedBox(height: 6),
                const Text('Bambu (LAN): профиль сохранится, но отправка файлов для него пока не реализована.', style: TextStyle(fontSize: 12, color: Palette.orange)),
              ],
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    if (host.text.trim().isEmpty) return;
                    st.addPrinter(PrinterProfile(
                      id: DateTime.now().millisecondsSinceEpoch.toString(),
                      name: name.text.trim().isEmpty ? 'Принтер' : name.text.trim(),
                      host: host.text.trim(),
                      port: int.tryParse(port.text) ?? (kind == PrinterKind.flashforgeAd5m ? 8898 : 7125),
                      kind: kind,
                      accessCode: code.text.trim(),
                      serialNumber: serial.text.trim(),
                    ));
                    Navigator.pop(ctx);
                  },
                  child: const Text('Сохранить'),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final st = AppScope.of(context);
    slicerCtrl ??= TextEditingController(text: st.slicerUrl);
    return Scaffold(
      appBar: AppBar(title: const Text('Подключение')),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 24), children: [
        if (st.demoMode)
          Panel(
            color: Palette.orange.withOpacity(0.12),
            child: Row(children: [
              const Icon(Icons.science_outlined, color: Palette.orange),
              const SizedBox(width: 12),
              const Expanded(child: Text('Включён демо-режим: принтер симулируется.')),
              TextButton(onPressed: () => st.setDemo(false), child: const Text('Выключить')),
            ]),
          ),
        Panel(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const SectionTitle('Поиск в Wi-Fi сети'),
            Text('Автопоиск сейчас ищет Moonraker. FlashForge AD5M добавляется вручную по IP и данным LAN Only (порт 8898).', style: TextStyle(color: mutedColor(context), fontSize: 13)),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: scanning ? null : _scan,
              icon: scanning ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.radar),
              label: Text(scanning ? 'Сканирую…' : 'Найти принтеры'),
            ),
            if (scanned && !scanning && found.isEmpty)
              Padding(padding: const EdgeInsets.only(top: 10), child: Text('Ничего не найдено. Добавь принтер вручную по IP.', style: TextStyle(color: mutedColor(context)))),
            for (final ip in found)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.print, color: Palette.green),
                title: Text(ip),
                subtitle: const Text('Moonraker найден'),
                trailing: TextButton(
                  onPressed: () {
                    st.addPrinter(PrinterProfile(id: DateTime.now().millisecondsSinceEpoch.toString(), name: 'Принтер $ip', host: ip));
                    snack(context, 'Принтер добавлен');
                  },
                  child: const Text('Добавить'),
                ),
              ),
          ]),
        ),
        const SectionTitle('Мои принтеры'),
        for (final p in st.printers)
          Panel(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(12),
            onTap: () => st.setActive(p.id),
            child: Row(children: [
              Icon(p.id == st.activeId ? Icons.radio_button_checked : Icons.radio_button_unchecked, color: p.id == st.activeId ? Palette.green : mutedColor(context)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(p.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                  Text('${p.model.isEmpty ? kindLabel(p.kind) : p.model} • ${p.host}:${p.port}', style: TextStyle(color: mutedColor(context), fontSize: 12)),
                ]),
              ),
              PopupMenuButton<String>(
                onSelected: (v) {
                  if (v == 'test') _test(p);
                  if (v == 'delete') {
                    if (st.printers.length <= 1) {
                      snack(context, 'Нельзя удалить последний принтер');
                    } else {
                      st.removePrinter(p.id);
                    }
                  }
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'test', child: Text('Проверить связь')),
                  PopupMenuItem(value: 'delete', child: Text('Удалить')),
                ],
              ),
            ]),
          ),
        OutlinedButton.icon(onPressed: () => _addDialog(st), icon: const Icon(Icons.add), label: const Text('Добавить принтер вручную')),
        const SizedBox(height: 20),
        Panel(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const SectionTitle('Сервер нарезки (для STL и 3MF)'),
            Text('Нужен только для .stl и ненарезанных .3mf. Запусти server/slicer_server.py на ПК или Raspberry Pi в той же сети.',
                style: TextStyle(color: mutedColor(context), fontSize: 13)),
            const SizedBox(height: 12),
            TextField(
              controller: slicerCtrl,
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(labelText: 'Адрес сервера', hintText: 'http://192.168.1.20:8765', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 10),
            Row(children: [
              FilledButton(
                onPressed: () {
                  st.update(() => st.slicerUrl = slicerCtrl!.text.trim());
                  snack(context, 'Сохранено');
                },
                child: const Text('Сохранить'),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: () async {
                  final url = slicerCtrl!.text.trim();
                  if (url.isEmpty) return;
                  final ok = await SlicerClient(url).ping();
                  if (mounted) snack(context, ok ? 'Сервер нарезки отвечает ✓' : 'Нет ответа от сервера');
                },
                child: const Text('Проверить'),
              ),
            ]),
          ]),
        ),
        Panel(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Удалённый доступ (не из дома)', style: TextStyle(fontWeight: FontWeight.bold)),
              value: st.remoteEnabled,
              onChanged: (v) => st.update(() => st.remoteEnabled = v),
            ),
            if (st.remoteEnabled) ...[
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'vpn', label: Text('VPN')),
                  ButtonSegment(value: 'cloud', label: Text('Облако (скоро)')),
                ],
                selected: {st.remoteMode},
                onSelectionChanged: (s) => st.update(() => st.remoteMode = s.first),
              ),
              const SizedBox(height: 10),
              Text(
                st.remoteMode == 'vpn'
                    ? '1) Поставь Tailscale на телефон и на Raspberry Pi/ПК рядом с принтером.\n2) Укажи в профиле принтера его Tailscale-IP (100.x.x.x).\n3) Всё остальное работает как в домашней сети.'
                    : 'Собственное облако пока не реализовано.',
                style: TextStyle(color: mutedColor(context), fontSize: 13),
              ),
            ],
          ]),
        ),
      ]),
    );
  }
}
