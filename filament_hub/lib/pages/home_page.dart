import 'package:flutter/material.dart';
import '../models.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets.dart';
import 'profile_page.dart';
import 'send_page.dart';

class DevicesPage extends StatelessWidget {
  const DevicesPage({super.key});
  @override
  Widget build(BuildContext context) {
    final st = AppScope.of(context);
    return RefreshIndicator(
      onRefresh: st.refreshAll,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: const [
          _Header(),
          _Camera(),
          _JobPanel(),
          _FilamentRow(),
          _TempPanel(),
          _SpeedPanel(),
          _ControlsPanel(),
          _MotionLink(),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();
  @override
  Widget build(BuildContext context) {
    final st = AppScope.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(children: [
        Expanded(
          child: PopupMenuButton<String>(
            onSelected: st.setActive,
            itemBuilder: (_) => [for (final p in st.printers) PopupMenuItem(value: p.id, child: Text(p.name))],
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Flexible(
                  child: Text(st.active?.name ?? 'Нет принтера',
                      overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold))),
              const Icon(Icons.keyboard_arrow_down),
            ]),
          ),
        ),
        StatusChip(st.status),
        IconButton(
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsPage())),
          icon: Badge(
              isLabelVisible: st.unread > 0,
              label: Text('${st.unread}'),
              child: const Icon(Icons.notifications_outlined)),
        ),
      ]),
    );
  }
}

class _Camera extends StatelessWidget {
  const _Camera();
  @override
  Widget build(BuildContext context) {
    final st = AppScope.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: const LinearGradient(
                colors: [Color(0xFF14181C), Color(0xFF0A0C0E)], begin: Alignment.topLeft, end: Alignment.bottomRight),
          ),
          child: Stack(children: [
            Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.videocam_off_outlined, size: 44, color: Colors.white38),
                const SizedBox(height: 8),
                const Text('Камера не подключена', style: TextStyle(color: Colors.white54)),
                TextButton(onPressed: () => _dialog(context, st), child: const Text('Настроить')),
              ]),
            ),
            Positioned(
              top: 10,
              left: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(6)),
                child: const Text('OFFLINE', style: TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.bold)),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  void _dialog(BuildContext context, AppState st) {
    final ctrl = TextEditingController(text: st.cameraUrl);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Камера'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
              controller: ctrl,
              decoration: const InputDecoration(labelText: 'URL потока (MJPEG)', hintText: 'http://192.168.1.50/webcam/?action=stream', border: OutlineInputBorder())),
          const SizedBox(height: 8),
          const Text('Адрес сохранится. Показ видео будет добавлен в следующей версии.', style: TextStyle(fontSize: 12)),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Закрыть')),
          FilledButton(
              onPressed: () {
                st.update(() => st.cameraUrl = ctrl.text.trim());
                Navigator.pop(ctx);
              },
              child: const Text('Сохранить')),
        ],
      ),
    );
  }
}

class _JobPanel extends StatelessWidget {
  const _JobPanel();
  @override
  Widget build(BuildContext context) {
    final st = AppScope.of(context);
    final s = st.status;
    if (s.hasJob) {
      return Panel(
        child: Row(children: [
          ProgressRing(
              value: s.progress,
              color: s.isPaused ? Palette.orange : Palette.green,
              child: Text('${(s.progress * 100).round()}%', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold))),
          const SizedBox(width: 16),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(s.file, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              const SizedBox(height: 4),
              Text('Слой ${s.layer} / ${s.totalLayers}', style: TextStyle(color: mutedColor(context))),
              Text('Прошло ${fmtDuration(s.elapsed)} • осталось ${fmtDuration(s.remaining)}',
                  style: TextStyle(color: mutedColor(context), fontSize: 12)),
              const SizedBox(height: 10),
              Row(children: [
                FilledButton.tonalIcon(
                  onPressed: () => guard(context, s.isPaused ? st.resume : st.pause),
                  icon: Icon(s.isPaused ? Icons.play_arrow : Icons.pause),
                  label: Text(s.isPaused ? 'Продолжить' : 'Пауза'),
                ),
                const SizedBox(width: 8),
                IconButton.outlined(
                  onPressed: () async {
                    if (await confirm(context, 'Остановить печать?', 'Текущая печать будет отменена.', ok: 'Остановить', danger: true)) {
                      if (context.mounted) guard(context, st.cancel);
                    }
                  },
                  icon: const Icon(Icons.stop, color: Palette.red),
                ),
              ]),
            ]),
          ),
        ]),
      );
    }
    final done = s.state == 'complete';
    return Panel(
      child: Column(children: [
        Icon(done ? Icons.check_circle : Icons.inbox_outlined, size: 40, color: done ? Palette.blue : mutedColor(context)),
        const SizedBox(height: 8),
        Text(done ? 'Печать завершена' : (s.connected ? 'Нет активной печати' : 'Принтер не в сети'),
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        if (done) Text(s.file, style: TextStyle(color: mutedColor(context))),
        const SizedBox(height: 12),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          FilledButton.icon(
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SendPage())),
            icon: const Icon(Icons.upload_file),
            label: const Text('Отправить файл'),
          ),
          const SizedBox(width: 8),
          OutlinedButton(onPressed: () => st.setTab(3), child: const Text('Из памяти')),
        ]),
      ]),
    );
  }
}

class _FilamentRow extends StatelessWidget {
  const _FilamentRow();
  @override
  Widget build(BuildContext context) {
    final st = AppScope.of(context);
    final f = st.slots[st.activeSlot];
    return Panel(
      onTap: () => st.setTab(1),
      child: Row(children: [
        SpoolIcon(color: f?.color ?? Colors.grey, size: 44),
        const SizedBox(width: 14),
        Expanded(
          child: f == null
              ? const Text('Катушка не выбрана')
              : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${f.type} • ${f.colorName}', style: const TextStyle(fontWeight: FontWeight.bold)),
                  Text('${f.weightG.round()} г осталось • ${f.humidity.round()}% влажность',
                      style: TextStyle(color: mutedColor(context), fontSize: 12)),
                ]),
        ),
        Icon(Icons.chevron_right, color: mutedColor(context)),
      ]),
    );
  }
}

class _TempTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final double cur, target;
  final Color color;
  final VoidCallback? onTap;
  const _TempTile(this.icon, this.label, this.cur, this.target, this.color, this.onTap);
  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(14)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [Icon(icon, size: 16, color: color), const SizedBox(width: 6), Text(label, style: const TextStyle(fontSize: 12))]),
            const SizedBox(height: 6),
            Text('${cur.toStringAsFixed(0)}°', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            Text(target > 0 ? '→ ${target.toStringAsFixed(0)}°' : 'выкл', style: TextStyle(color: mutedColor(context), fontSize: 12)),
          ]),
        ),
      );
}

class _TempPanel extends StatelessWidget {
  const _TempPanel();
  @override
  Widget build(BuildContext context) {
    final st = AppScope.of(context);
    final s = st.status;
    return Panel(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const SectionTitle('Температуры'),
        Row(children: [
          Expanded(
              child: _TempTile(Icons.local_fire_department, 'Сопло', s.nozzle, s.nozzleTarget, Palette.orange,
                  () => _edit(context, 'Сопло', 300, s.nozzleTarget, st.setNozzle, const [('PLA', 215), ('PETG', 240), ('ABS', 255), ('Выкл', 0)]))),
          const SizedBox(width: 8),
          Expanded(
              child: _TempTile(Icons.grid_on, 'Стол', s.bed, s.bedTarget, Palette.blue,
                  () => _edit(context, 'Стол', 120, s.bedTarget, st.setBed, const [('PLA', 60), ('PETG', 80), ('ABS', 100), ('Выкл', 0)]))),
          const SizedBox(width: 8),
          Expanded(child: _TempTile(Icons.air, 'Камера', s.chamber, 0, Palette.green, null)),
        ]),
        const SizedBox(height: 14),
        TempChart(nozzle: st.nozzleHist, bed: st.bedHist),
        const SizedBox(height: 6),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.circle, size: 8, color: Palette.orange),
          const SizedBox(width: 4),
          Text('Сопло', style: TextStyle(fontSize: 12, color: mutedColor(context))),
          const SizedBox(width: 16),
          const Icon(Icons.circle, size: 8, color: Palette.blue),
          const SizedBox(width: 4),
          Text('Стол', style: TextStyle(fontSize: 12, color: mutedColor(context))),
        ]),
      ]),
    );
  }

  Future<void> _edit(BuildContext context, String title, int max, double current, Future<void> Function(int) onSet,
      List<(String, int)> presets) async {
    final ctrl = TextEditingController(text: current.round().toString());
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Температура: $title'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
              controller: ctrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(suffixText: '°C', helperText: '0 – $max', border: const OutlineInputBorder())),
          const SizedBox(height: 12),
          Wrap(spacing: 8, children: [
            for (final p in presets) ActionChip(label: Text(p.$1), onPressed: () => ctrl.text = p.$2.toString()),
          ]),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Отмена')),
          FilledButton(
              onPressed: () {
                final t = int.tryParse(ctrl.text);
                Navigator.pop(ctx);
                if (t != null && t >= 0 && t <= max) guard(context, () => onSet(t));
              },
              child: const Text('Установить')),
        ],
      ),
    );
  }
}

class _SpeedPanel extends StatelessWidget {
  const _SpeedPanel();
  static const modes = [
    ('Тихий', 50, Icons.bedtime),
    ('Стандарт', 100, Icons.speed),
    ('Спорт', 124, Icons.bolt),
    ('Турбо', 166, Icons.local_fire_department),
  ];
  @override
  Widget build(BuildContext context) {
    final st = AppScope.of(context);
    final cur = st.status.speedPct;
    return Panel(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SectionTitle('Скорость', trailing: Text('$cur%', style: TextStyle(color: mutedColor(context)))),
        Row(children: [
          for (final m in modes)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => guard(context, () => st.setSpeed(m.$2)),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: cur == m.$2 ? Palette.green.withOpacity(0.2) : lineColor(context).withOpacity(0.05),
                      border: Border.all(color: cur == m.$2 ? Palette.green : Colors.transparent),
                    ),
                    child: Column(children: [
                      Icon(m.$3, size: 20, color: cur == m.$2 ? Palette.green : mutedColor(context)),
                      const SizedBox(height: 4),
                      Text(m.$1, style: const TextStyle(fontSize: 11)),
                    ]),
                  ),
                ),
              ),
            ),
        ]),
      ]),
    );
  }
}

class _ControlsPanel extends StatelessWidget {
  const _ControlsPanel();
  @override
  Widget build(BuildContext context) {
    final st = AppScope.of(context);
    final s = st.status;
    Widget fan(int i, String name, double v) => Row(children: [
          SizedBox(width: 110, child: Text(name, style: const TextStyle(fontSize: 13))),
          Expanded(
              child: Slider(
                  value: v.clamp(0.0, 1.0),
                  onChanged: (x) => st.setFanLocal(i, x),
                  onChangeEnd: (x) => guard(context, () => st.setFan(i, x)))),
          SizedBox(width: 38, child: Text('${(v * 100).round()}%', style: TextStyle(fontSize: 12, color: mutedColor(context)))),
        ]);
    return Panel(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const SectionTitle('Управление'),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          secondary: const Icon(Icons.lightbulb_outline),
          title: const Text('Подсветка камеры'),
          value: s.light,
          onChanged: (_) => guard(context, st.toggleLight),
        ),
        fan(0, 'Обдув детали', s.fanPart),
        fan(1, 'Доп. вентилятор', s.fanAux),
        fan(2, 'Вент. камеры', s.fanChamber),
      ]),
    );
  }
}

class _MotionLink extends StatelessWidget {
  const _MotionLink();
  @override
  Widget build(BuildContext context) => Panel(
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MotionPage())),
        child: Row(children: [
          const Icon(Icons.open_with),
          const SizedBox(width: 14),
          const Expanded(child: Text('Ручное управление осями', style: TextStyle(fontWeight: FontWeight.w600))),
          Icon(Icons.chevron_right, color: mutedColor(context)),
        ]),
      );
}

class MotionPage extends StatefulWidget {
  const MotionPage({super.key});
  @override
  State<MotionPage> createState() => _MotionPageState();
}

class _MotionPageState extends State<MotionPage> {
  double step = 10;

  @override
  Widget build(BuildContext context) {
    final st = AppScope.of(context);
    void mv(String axis, double sign) => guard(context, () => st.move(axis, sign * step));
    Widget pad(IconData i, VoidCallback f, {Color? color}) => Padding(
          padding: const EdgeInsets.all(4),
          child: Material(
            color: (color ?? Palette.green).withOpacity(0.15),
            shape: const CircleBorder(),
            child: InkWell(customBorder: const CircleBorder(), onTap: f, child: SizedBox(width: 56, height: 56, child: Icon(i, color: color ?? Palette.green))),
          ),
        );
    return Scaffold(
      appBar: AppBar(title: const Text('Ручное управление')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Panel(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const SectionTitle('Шаг, мм'),
            Wrap(spacing: 8, children: [
              for (final v in [0.1, 1.0, 10.0, 50.0])
                ChoiceChip(label: Text(v.toString()), selected: step == v, onSelected: (_) => setState(() => step = v)),
            ]),
          ]),
        ),
        Panel(
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
            Column(children: [
              const Text('X / Y'),
              pad(Icons.keyboard_arrow_up, () => mv('Y', 1)),
              Row(mainAxisSize: MainAxisSize.min, children: [
                pad(Icons.keyboard_arrow_left, () => mv('X', -1)),
                pad(Icons.home, () => guard(context, () => st.home('X Y')), color: Palette.blue),
                pad(Icons.keyboard_arrow_right, () => mv('X', 1)),
              ]),
              pad(Icons.keyboard_arrow_down, () => mv('Y', -1)),
            ]),
            Column(children: [
              const Text('Z'),
              pad(Icons.keyboard_arrow_up, () => mv('Z', 1)),
              pad(Icons.home, () => guard(context, () => st.home('Z')), color: Palette.blue),
              pad(Icons.keyboard_arrow_down, () => mv('Z', -1)),
            ]),
          ]),
        ),
        Panel(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const SectionTitle('Экструдер'),
            const Text('Сопло должно быть нагрето', style: TextStyle(fontSize: 12)),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: OutlinedButton.icon(onPressed: () => guard(context, () => st.extrude(-step.clamp(1.0, 50.0))), icon: const Icon(Icons.arrow_upward), label: const Text('Втянуть'))),
              const SizedBox(width: 8),
              Expanded(child: FilledButton.icon(onPressed: () => guard(context, () => st.extrude(step.clamp(1.0, 50.0))), icon: const Icon(Icons.arrow_downward), label: const Text('Выдавить'))),
            ]),
          ]),
        ),
        Panel(
          child: Wrap(spacing: 8, runSpacing: 8, children: [
            FilledButton.tonalIcon(onPressed: () => guard(context, () => st.home()), icon: const Icon(Icons.home), label: const Text('Home все оси')),
            OutlinedButton.icon(onPressed: () => guard(context, st.motorsOff), icon: const Icon(Icons.power_off), label: const Text('Отключить моторы')),
          ]),
        ),
      ]),
    );
  }
}
