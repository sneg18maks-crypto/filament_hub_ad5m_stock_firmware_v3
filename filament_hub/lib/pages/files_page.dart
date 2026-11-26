import 'package:flutter/material.dart';
import '../models.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets.dart';
import 'send_page.dart';

class FilesPage extends StatelessWidget {
  const FilesPage({super.key});
  @override
  Widget build(BuildContext context) {
    final st = AppScope.of(context);
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Файлы'),
          bottom: const TabBar(
            labelColor: Palette.green,
            indicatorColor: Palette.green,
            tabs: [Tab(text: 'Память принтера'), Tab(text: 'История')],
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          backgroundColor: Palette.green,
          foregroundColor: Colors.white,
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SendPage())),
          icon: const Icon(Icons.upload_file),
          label: const Text('Отправить файл'),
        ),
        body: TabBarView(children: [_FilesTab(st: st), _HistoryTab(st: st)]),
      ),
    );
  }
}

Color _hashColor(String s) {
  final colors = [Palette.green, Palette.blue, Palette.orange, const Color(0xFFBF5AF2), const Color(0xFFFF375F)];
  return colors[s.codeUnits.fold(0, (a, b) => a + b) % colors.length];
}

class _FilesTab extends StatelessWidget {
  final AppState st;
  const _FilesTab({required this.st});
  @override
  Widget build(BuildContext context) {
    final files = st.files;
    return RefreshIndicator(
      onRefresh: st.refreshFiles,
      child: files.isEmpty
          ? ListView(children: [
              const SizedBox(height: 120),
              Icon(Icons.folder_open, size: 56, color: mutedColor(context)),
              const SizedBox(height: 12),
              Center(child: Text('Файлов нет', style: TextStyle(color: mutedColor(context)))),
            ])
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 90),
              itemCount: files.length,
              itemBuilder: (context, i) {
                final f = files[i];
                final c = _hashColor(f.name);
                return Panel(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(12),
                  onTap: () => _print(context, f),
                  child: Row(children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(color: c.withOpacity(0.18), borderRadius: BorderRadius.circular(14)),
                      child: Icon(Icons.view_in_ar, color: c),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(f.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
                        const SizedBox(height: 2),
                        Text(
                          [
                            '${f.sizeMb.toStringAsFixed(1)} МБ',
                            if (f.est > Duration.zero) fmtDuration(f.est),
                            if (f.grams > 0) '${f.grams.round()} г',
                            fmtDate(f.modified),
                          ].join(' • '),
                          style: TextStyle(color: mutedColor(context), fontSize: 12),
                        ),
                      ]),
                    ),
                    PopupMenuButton<String>(
                      onSelected: (v) async {
                        if (v == 'print') _print(context, f);
                        if (v == 'delete') {
                          if (await confirm(context, 'Удалить файл?', f.name, ok: 'Удалить', danger: true)) {
                            if (context.mounted) guard(context, () => st.deleteFile(f.name));
                          }
                        }
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: 'print', child: Text('Печать')),
                        PopupMenuItem(value: 'delete', child: Text('Удалить')),
                      ],
                    ),
                  ]),
                );
              },
            ),
    );
  }

  Future<void> _print(BuildContext context, GcodeFile f) async {
    if (st.status.hasJob) {
      snack(context, 'Принтер занят печатью');
      return;
    }
    if (await confirm(context, 'Начать печать?', f.name, ok: 'Печатать')) {
      if (!context.mounted) return;
      await guard(context, () => st.startPrint(f.name, est: f.est > Duration.zero ? f.est : null, grams: f.grams));
      st.setTab(0);
    }
  }
}

class _HistoryTab extends StatelessWidget {
  final AppState st;
  const _HistoryTab({required this.st});
  @override
  Widget build(BuildContext context) {
    final h = st.history;
    final ok = h.where((e) => e.success).length;
    final hours = h.fold<double>(0, (a, e) => a + e.duration.inMinutes / 60);
    final grams = h.fold<double>(0, (a, e) => a + e.grams);
    Widget stat(String v, String l) => Expanded(
          child: Column(children: [
            Text(v, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 2),
            Text(l, style: TextStyle(fontSize: 11, color: mutedColor(context))),
          ]),
        );
    return ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 90), children: [
      Panel(
        child: Row(children: [
          stat('${h.length}', 'печатей'),
          stat(h.isEmpty ? '—' : '${(ok * 100 / h.length).round()}%', 'успешных'),
          stat(hours.toStringAsFixed(1), 'часов'),
          stat(grams >= 1000 ? '${(grams / 1000).toStringAsFixed(2)} кг' : '${grams.round()} г', 'пластика'),
        ]),
      ),
      for (final r in h)
        Panel(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(12),
          child: Row(children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(color: r.color, shape: BoxShape.circle, border: Border.all(color: Colors.white24, width: 2)),
              child: Icon(r.success ? Icons.check : Icons.close, color: textOn(r.color)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(r.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
                Text('${r.type} • ${fmtDuration(r.duration)} • ${r.grams.round()} г • ${fmtDate(r.date)}',
                    style: TextStyle(color: mutedColor(context), fontSize: 12)),
              ]),
            ),
            Text(r.success ? 'Успех' : 'Сбой', style: TextStyle(color: r.success ? Palette.green : Palette.red, fontSize: 12, fontWeight: FontWeight.w600)),
          ]),
        ),
    ]);
  }
}
