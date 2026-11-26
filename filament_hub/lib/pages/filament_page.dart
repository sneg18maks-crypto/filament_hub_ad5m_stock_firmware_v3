import 'package:flutter/material.dart';
import '../models.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets.dart';

class FilamentPage extends StatefulWidget {
  const FilamentPage({super.key});
  @override
  State<FilamentPage> createState() => _FilamentPageState();
}

class _FilamentPageState extends State<FilamentPage> {
  int sel = 0;

  String _humLabel(double h) {
    if (h < 20) return 'Отлично';
    if (h < 40) return 'Нормально';
    if (h < 60) return 'Повышенная — лучше просушить';
    return 'Высокая — нужна сушка';
  }

  Color _humColor(double h) => h < 20 ? Palette.green : (h < 40 ? Palette.blue : (h < 60 ? Palette.orange : Palette.red));

  Future<void> _scan(AppState st, int slot) async {
    final f = await showDialog<FilamentData>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _ScanDialog(st: st, slot: slot),
    );
    if (f != null && mounted) snack(context, 'Метка прочитана: ${f.type} ${f.colorName}');
  }

  @override
  Widget build(BuildContext context) {
    final st = AppScope.of(context);
    final f = st.slots[sel];
    return ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 24), children: [
      Row(children: [
        const Expanded(child: Text('Филамент', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold))),
        FilledButton.tonalIcon(onPressed: () => _scan(st, sel), icon: const Icon(Icons.nfc), label: const Text('Скан RFID')),
      ]),
      const SizedBox(height: 14),
      Row(children: [
        for (var i = 0; i < st.slots.length; i++)
          Expanded(child: _SlotCard(i: i, f: st.slots[i], selected: sel == i, loaded: st.activeSlot == i, onTap: () => setState(() => sel = i))),
      ]),
      const SizedBox(height: 12),
      if (f == null)
        Panel(
          padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
          child: Column(children: [
            Icon(Icons.nfc, size: 48, color: mutedColor(context)),
            const SizedBox(height: 10),
            Text('Слот ${sel + 1} пуст', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text('Поднеси катушку к RFID-ридеру или выбери из списка ниже', textAlign: TextAlign.center, style: TextStyle(color: mutedColor(context))),
            const SizedBox(height: 14),
            FilledButton.icon(onPressed: () => _scan(st, sel), icon: const Icon(Icons.nfc), label: const Text('Сканировать')),
          ]),
        )
      else ...[
        Panel(
          child: Column(children: [
            Row(children: [
              SpoolIcon(color: f.color, size: 86),
              const SizedBox(width: 16),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(f.title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Row(children: [
                    Container(width: 16, height: 16, decoration: BoxDecoration(color: f.color, shape: BoxShape.circle, border: Border.all(color: Colors.white38))),
                    const SizedBox(width: 6),
                    Text('${f.colorName}  ${f.hex}', style: TextStyle(color: mutedColor(context), fontSize: 13)),
                  ]),
                  if (f.weightG < 150)
                    Container(
                      margin: const EdgeInsets.only(top: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(color: Palette.orange.withOpacity(0.18), borderRadius: BorderRadius.circular(8)),
                      child: const Text('Мало пластика', style: TextStyle(color: Palette.orange, fontSize: 12, fontWeight: FontWeight.w600)),
                    ),
                ]),
              ),
            ]),
            const SizedBox(height: 16),
            _row(context, Icons.category, 'Тип пластика', f.type),
            _row(context, Icons.palette, 'Цвет', f.colorName),
            _row(context, Icons.water_drop, 'Влажность', '${f.humidity.round()} %'),
            Padding(
              padding: const EdgeInsets.only(left: 36, bottom: 8),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                LinearProgressIndicator(value: (f.humidity / 100).clamp(0.0, 1.0), minHeight: 6, borderRadius: BorderRadius.circular(3), color: _humColor(f.humidity)),
                const SizedBox(height: 4),
                Text(_humLabel(f.humidity), style: TextStyle(fontSize: 12, color: _humColor(f.humidity))),
              ]),
            ),
            _row(context, Icons.thermostat, 'Температура', '${f.tempC.round()} °C'),
            Padding(
              padding: const EdgeInsets.only(left: 36, bottom: 8),
              child: Text('Диапазон: ${f.minTemp}–${f.maxTemp} °C • стол ${f.bedTemp} °C', style: TextStyle(fontSize: 12, color: mutedColor(context))),
            ),
            _row(context, Icons.scale, 'Остаток', '${f.weightG.round()} г из ${f.totalG.round()} г'),
            Padding(
              padding: const EdgeInsets.only(left: 36, bottom: 4),
              child: LinearProgressIndicator(value: f.fraction, minHeight: 6, borderRadius: BorderRadius.circular(3), color: f.weightG < 150 ? Palette.orange : Palette.green),
            ),
          ]),
        ),
        Row(children: [
          Expanded(
            child: FilledButton.icon(
              onPressed: st.activeSlot == sel ? null : () {
                st.loadSlot(sel);
                snack(context, 'Слот ${sel + 1} выбран для печати');
              },
              icon: const Icon(Icons.download),
              label: Text(st.activeSlot == sel ? 'Загружен' : 'Загрузить'),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(child: OutlinedButton.icon(onPressed: () => _edit(st, sel, f), icon: const Icon(Icons.edit), label: const Text('Изменить'))),
          const SizedBox(width: 8),
          IconButton.outlined(
            onPressed: () {
              st.assignSlot(sel, null);
              snack(context, 'Катушка извлечена');
            },
            icon: const Icon(Icons.eject),
          ),
        ]),
      ],
      const SizedBox(height: 20),
      const SectionTitle('Мои катушки'),
      for (final s in st.library)
        Panel(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          onTap: () => _assign(st, s),
          child: Row(children: [
            SpoolIcon(color: s.color, size: 40),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${s.title} • ${s.colorName}', style: const TextStyle(fontWeight: FontWeight.w600)),
                Text('${s.weightG.round()} г • влажн. ${s.humidity.round()}%', style: TextStyle(color: mutedColor(context), fontSize: 12)),
              ]),
            ),
            Icon(Icons.add_circle_outline, color: mutedColor(context)),
          ]),
        ),
    ]);
  }

  Widget _row(BuildContext context, IconData i, String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(children: [
          Icon(i, size: 20, color: mutedColor(context)),
          const SizedBox(width: 16),
          Expanded(child: Text(k)),
          Flexible(child: Text(v, textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.w600))),
        ]),
      );

  void _assign(AppState st, FilamentData s) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Padding(padding: const EdgeInsets.all(16), child: Text('${s.title} ${s.colorName} → в слот', style: const TextStyle(fontWeight: FontWeight.bold))),
          for (var i = 0; i < st.slots.length; i++)
            ListTile(
              leading: CircleAvatar(radius: 14, child: Text('${i + 1}')),
              title: Text(st.slots[i] == null ? 'Пусто' : '${st.slots[i]!.type} ${st.slots[i]!.colorName}'),
              onTap: () {
                st.assignSlot(i, s);
                setState(() => sel = i);
                Navigator.pop(ctx);
              },
            ),
        ]),
      ),
    );
  }

  void _edit(AppState st, int slot, FilamentData f) {
    const types = ['PLA', 'PLA Silk', 'PETG', 'ABS', 'ASA', 'TPU', 'PA', 'PC'];
    const palette = [
      Color(0xFFFF7A00), Color(0xFF222222), Color(0xFFF2F2F2), Color(0xFF1E6BFF), Color(0xFF8A9096),
      Color(0xFFD4AF37), Color(0xFF2FBF71), Color(0xFFD62828), Color(0xFFBF5AF2), Color(0xFFFFD60A),
    ];
    var type = types.contains(f.type) ? f.type : 'PLA';
    var color = f.color;
    final name = TextEditingController(text: f.colorName);
    final weight = TextEditingController(text: f.weightG.round().toString());
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: const Text('Редактировать катушку'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              DropdownButtonFormField<String>(
                value: type,
                decoration: const InputDecoration(labelText: 'Тип', border: OutlineInputBorder()),
                items: [for (final t in types) DropdownMenuItem(value: t, child: Text(t))],
                onChanged: (v) => setS(() => type = v ?? type),
              ),
              const SizedBox(height: 12),
              TextField(controller: name, decoration: const InputDecoration(labelText: 'Название цвета', border: OutlineInputBorder())),
              const SizedBox(height: 12),
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final c in palette)
                  GestureDetector(
                    onTap: () => setS(() => color = c),
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(color: c, shape: BoxShape.circle, border: Border.all(color: color == c ? Palette.green : Colors.white24, width: color == c ? 3 : 1)),
                    ),
                  ),
              ]),
              const SizedBox(height: 12),
              TextField(controller: weight, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Остаток, г', border: OutlineInputBorder())),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Отмена')),
            FilledButton(
              onPressed: () {
                st.assignSlot(slot, f.copyWith(type: type, colorName: name.text.trim(), color: color, weightG: double.tryParse(weight.text) ?? f.weightG));
                Navigator.pop(ctx);
              },
              child: const Text('Сохранить'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SlotCard extends StatelessWidget {
  final int i;
  final FilamentData? f;
  final bool selected, loaded;
  final VoidCallback onTap;
  const _SlotCard({required this.i, required this.f, required this.selected, required this.loaded, required this.onTap});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
            decoration: BoxDecoration(
              color: panelColor(context),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: selected ? Palette.green : Colors.transparent, width: 2),
            ),
            child: Column(children: [
              Text('${i + 1}', style: TextStyle(fontSize: 11, color: mutedColor(context), fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              f == null
                  ? Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: lineColor(context), width: 2)),
                      child: Icon(Icons.add, color: mutedColor(context)),
                    )
                  : SpoolIcon(color: f!.color, size: 46),
              const SizedBox(height: 6),
              Text(f?.type ?? '—', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis),
              const SizedBox(height: 4),
              SizedBox(
                width: 40,
                child: LinearProgressIndicator(value: f?.fraction ?? 0, minHeight: 4, borderRadius: BorderRadius.circular(2), color: (f?.weightG ?? 1000) < 150 ? Palette.orange : Palette.green),
              ),
              const SizedBox(height: 4),
              Text(loaded ? '● в работе' : ' ', style: const TextStyle(fontSize: 10, color: Palette.green)),
            ]),
          ),
        ),
      );
}

class _ScanDialog extends StatefulWidget {
  final AppState st;
  final int slot;
  const _ScanDialog({required this.st, required this.slot});
  @override
  State<_ScanDialog> createState() => _ScanDialogState();
}

class _ScanDialogState extends State<_ScanDialog> with SingleTickerProviderStateMixin {
  late final AnimationController c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..repeat();

  @override
  void initState() {
    super.initState();
    // ДЕМО: здесь потом подключается реальный RFID-ридер
    widget.st.simulateScan(widget.slot).then((f) {
      if (mounted) Navigator.pop(context, f);
    });
  }

  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          SizedBox(
            width: 130,
            height: 130,
            child: AnimatedBuilder(
              animation: c,
              builder: (_, __) => Stack(alignment: Alignment.center, children: [
                for (final k in [0.0, 0.5])
                  Builder(builder: (_) {
                    final t = (c.value + k) % 1.0;
                    return Container(
                      width: 130 * t,
                      height: 130 * t,
                      decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Palette.green.withOpacity(1 - t), width: 3)),
                    );
                  }),
                const Icon(Icons.nfc, size: 48, color: Palette.green),
              ]),
            ),
          ),
          const SizedBox(height: 16),
          const Text('Поднеси катушку к RFID-ридеру', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          const Text('Поиск метки…'),
        ]),
      );
}
