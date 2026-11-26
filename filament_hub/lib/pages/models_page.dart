import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../mock.dart';
import '../models.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets.dart';

class ModelsPage extends StatelessWidget {
  const ModelsPage({super.key});
  @override
  Widget build(BuildContext context) => DefaultTabController(
        length: 3,
        child: Scaffold(
          appBar: AppBar(
            title: const Text('Модели'),
            bottom: const TabBar(
              labelColor: Palette.green,
              indicatorColor: Palette.green,
              tabs: [Tab(text: 'Каталог'), Tab(text: 'Избранное'), Tab(text: 'Сайты')],
            ),
          ),
          body: const TabBarView(
            physics: NeverScrollableScrollPhysics(),
            children: [_GridTab(favOnly: false), _GridTab(favOnly: true), _SitesTab()],
          ),
        ),
      );
}

class _GridTab extends StatefulWidget {
  final bool favOnly;
  const _GridTab({required this.favOnly});
  @override
  State<_GridTab> createState() => _GridTabState();
}

class _GridTabState extends State<_GridTab> {
  String q = '';
  String cat = 'Все';

  @override
  Widget build(BuildContext context) {
    final st = AppScope.of(context);
    final list = mockModels.where((m) {
      if (widget.favOnly && !st.favorites.contains(m.id)) return false;
      if (cat != 'Все' && m.category != cat) return false;
      if (q.isNotEmpty && !(m.title.toLowerCase().contains(q) || m.author.toLowerCase().contains(q))) return false;
      return true;
    }).toList();
    return CustomScrollView(slivers: [
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: TextField(
            onChanged: (v) => setState(() => q = v.trim().toLowerCase()),
            decoration: InputDecoration(
              hintText: 'Поиск моделей',
              prefixIcon: const Icon(Icons.search),
              filled: true,
              fillColor: panelColor(context),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
            ),
          ),
        ),
      ),
      SliverToBoxAdapter(
        child: SizedBox(
          height: 48,
          child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 12), children: [
            for (final c in modelCategories)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                child: ChoiceChip(label: Text(c), selected: cat == c, onSelected: (_) => setState(() => cat = c)),
              ),
          ]),
        ),
      ),
      if (list.isEmpty)
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(child: Text(widget.favOnly ? 'Пока нет избранного' : 'Ничего не найдено', style: TextStyle(color: mutedColor(context)))),
        )
      else
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: 0.78),
            delegate: SliverChildBuilderDelegate((context, i) => _ModelCard(m: list[i]), childCount: list.length),
          ),
        ),
    ]);
  }
}

class _ModelCard extends StatelessWidget {
  final ModelItem m;
  const _ModelCard({required this.m});
  @override
  Widget build(BuildContext context) {
    final st = AppScope.of(context);
    final fav = st.favorites.contains(m.id);
    return Material(
      color: panelColor(context),
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ModelDetailPage(m: m))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: Stack(children: [
              Positioned.fill(child: GradientThumb(c1: m.c1, c2: m.c2, icon: m.icon)),
              Positioned(
                top: 6,
                right: 6,
                child: InkWell(
                  onTap: () => st.toggleFav(m.id),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: const BoxDecoration(color: Colors.black38, shape: BoxShape.circle),
                    child: Icon(fav ? Icons.favorite : Icons.favorite_border, size: 18, color: fav ? Palette.red : Colors.white),
                  ),
                ),
              ),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(m.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold)),
              Text(m.author, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: mutedColor(context))),
              const SizedBox(height: 6),
              Row(children: [
                Icon(Icons.favorite, size: 13, color: mutedColor(context)),
                const SizedBox(width: 3),
                Text(_k(m.likes), style: TextStyle(fontSize: 12, color: mutedColor(context))),
                const SizedBox(width: 10),
                Icon(Icons.download, size: 13, color: mutedColor(context)),
                const SizedBox(width: 3),
                Text(_k(m.downloads), style: TextStyle(fontSize: 12, color: mutedColor(context))),
              ]),
            ]),
          ),
        ]),
      ),
    );
  }
}

String _k(int n) => n >= 1000 ? '${(n / 1000).toStringAsFixed(n >= 10000 ? 0 : 1)}k' : '$n';

// ───────────── Страница модели ─────────────
class ModelDetailPage extends StatelessWidget {
  final ModelItem m;
  const ModelDetailPage({super.key, required this.m});
  @override
  Widget build(BuildContext context) {
    final st = AppScope.of(context);
    final fav = st.favorites.contains(m.id);
    Widget stat(IconData i, String v, String l) => Expanded(
          child: Column(children: [
            Icon(i, size: 22, color: Palette.green),
            const SizedBox(height: 4),
            Text(v, style: const TextStyle(fontWeight: FontWeight.bold)),
            Text(l, style: TextStyle(fontSize: 11, color: mutedColor(context))),
          ]),
        );
    return Scaffold(
      appBar: AppBar(title: const Text('Модель'), actions: [
        IconButton(onPressed: () => st.toggleFav(m.id), icon: Icon(fav ? Icons.favorite : Icons.favorite_border, color: fav ? Palette.red : null)),
      ]),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 24), children: [
        SizedBox(height: 220, child: GradientThumb(c1: m.c1, c2: m.c2, icon: m.icon, iconSize: 100, radius: BorderRadius.circular(20))),
        const SizedBox(height: 16),
        Text(m.title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        Text('${m.author} • ${m.category}', style: TextStyle(color: mutedColor(context))),
        const SizedBox(height: 14),
        Panel(
          child: Row(children: [
            stat(Icons.schedule, fmtDuration(Duration(minutes: (m.hours * 60).round())), 'время'),
            stat(Icons.scale, '${m.grams.round()} г', 'пластик'),
            stat(Icons.favorite, _k(m.likes), 'лайки'),
            stat(Icons.download, _k(m.downloads), 'загрузки'),
          ]),
        ),
        Panel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const SectionTitle('Описание'),
          Text(m.description),
        ])),
        Panel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const SectionTitle('Рекомендации'),
          Wrap(spacing: 8, runSpacing: 8, children: [
            Chip(avatar: const Icon(Icons.album, size: 16), label: Text(m.material)),
            const Chip(avatar: Icon(Icons.layers, size: 16), label: Text('Слой 0.2 мм')),
            const Chip(avatar: Icon(Icons.grid_4x4, size: 16), label: Text('Заполнение 15%')),
          ]),
        ])),
        Row(children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => snack(context, 'Скачивание из каталога появится позже. Пока отправляй свои файлы через «Отправить файл».'),
              icon: const Icon(Icons.download),
              label: const Text('Скачать'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 2,
            child: FilledButton.icon(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => SlicerPage(m: m))),
              icon: const Icon(Icons.print),
              label: const Text('Подготовить печать'),
            ),
          ),
        ]),
      ]),
    );
  }
}

// ───────────── Подготовка печати (демо-оценка) ─────────────
class SlicerPage extends StatefulWidget {
  final ModelItem m;
  const SlicerPage({super.key, required this.m});
  @override
  State<SlicerPage> createState() => _SlicerPageState();
}

class _SlicerPageState extends State<SlicerPage> {
  double layer = 0.2;
  double infill = 15;
  bool supports = false, brim = false;
  int? slot;
  bool busy = false;
  Duration? est;
  double? grams;
  int? layers;

  void _reset() => setState(() {
        est = null;
        grams = null;
      });

  Future<void> _slice() async {
    setState(() => busy = true);
    await Future.delayed(const Duration(milliseconds: 1800));
    final m = widget.m;
    final lf = 0.2 / layer;
    final inf = 0.8 + infill / 100;
    final sup = supports ? 1.12 : 1.0;
    setState(() {
      busy = false;
      est = Duration(minutes: (m.hours * 60 * lf * inf * sup).round());
      grams = m.grams * (0.85 + infill / 100) * sup;
      layers = ((m.hours * 10 + 20) / layer).round();
    });
  }

  @override
  Widget build(BuildContext context) {
    final st = AppScope.of(context);
    final m = widget.m;
    final s = slot ?? st.activeSlot;
    return Scaffold(
      appBar: AppBar(title: const Text('Подготовка печати')),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 24), children: [
        Container(
          height: 190,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(color: panelColor(context), borderRadius: BorderRadius.circular(18)),
          child: Stack(alignment: Alignment.center, children: [
            Positioned.fill(child: CustomPaint(painter: PlatePainter(isDark(context)))),
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(18), gradient: LinearGradient(colors: [m.c1, m.c2])),
              child: Icon(m.icon, size: 52, color: Colors.white),
            ),
            Positioned(bottom: 8, child: Text(m.title, style: TextStyle(color: mutedColor(context), fontSize: 12))),
          ]),
        ),
        const SizedBox(height: 12),
        Panel(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const SectionTitle('Филамент'),
            DropdownButtonFormField<int>(
              value: s,
              decoration: const InputDecoration(border: OutlineInputBorder()),
              items: [
                for (var i = 0; i < st.slots.length; i++)
                  DropdownMenuItem(value: i, child: Text(st.slots[i] == null ? 'Слот ${i + 1}: пусто' : 'Слот ${i + 1}: ${st.slots[i]!.type} ${st.slots[i]!.colorName}')),
              ],
              onChanged: (v) {
                slot = v;
                _reset();
              },
            ),
          ]),
        ),
        Panel(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const SectionTitle('Качество'),
            Wrap(spacing: 8, children: [
              for (final v in [0.12, 0.16, 0.2, 0.28])
                ChoiceChip(label: Text('$v мм'), selected: layer == v, onSelected: (_) {
                  layer = v;
                  _reset();
                }),
            ]),
            const SizedBox(height: 12),
            Text('Заполнение: ${infill.round()}%'),
            Slider(value: infill, min: 5, max: 100, divisions: 19, onChanged: (v) {
              infill = v;
              _reset();
            }),
            SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('Поддержки'), value: supports, onChanged: (v) {
              supports = v;
              _reset();
            }),
            SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('Кайма (brim)'), value: brim, onChanged: (v) {
              brim = v;
              _reset();
            }),
          ]),
        ),
        if (est == null)
          FilledButton.icon(
            style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
            onPressed: busy ? null : _slice,
            icon: busy ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.auto_fix_high),
            label: Text(busy ? 'Нарезка…' : 'Нарезать (оценка)'),
          )
        else ...[
          Panel(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const SectionTitle('Результат (приблизительно)'),
              Row(children: [
                Expanded(child: _kv(context, 'Время', fmtDuration(est!))),
                Expanded(child: _kv(context, 'Пластик', '${grams!.round()} г')),
                Expanded(child: _kv(context, 'Слоёв', '$layers')),
              ]),
            ]),
          ),
          Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => snack(context, 'Экспорт G-code из приложения: используй сервер нарезки в «Отправить файл» (STL/3MF).'),
                icon: const Icon(Icons.code),
                label: const Text('Экспорт G-code'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton.icon(
                onPressed: () async {
                  if (!st.demoMode) {
                    snack(context, 'Каталог пока демонстрационный. Для реальной печати используй «Отправить файл».');
                    return;
                  }
                  st.loadSlot(s);
                  await guard(context, () => st.startPrint('${m.title}.gcode', est: est, grams: grams ?? 0));
                  if (context.mounted) {
                    Navigator.of(context).popUntil((r) => r.isFirst);
                    st.setTab(0);
                  }
                },
                icon: const Icon(Icons.print),
                label: const Text('Печать'),
              ),
            ),
          ]),
        ],
      ]),
    );
  }

  Widget _kv(BuildContext c, String k, String v) => Column(children: [
        Text(v, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        Text(k, style: TextStyle(fontSize: 12, color: mutedColor(c))),
      ]);
}

// ───────────── Сайты в WebView ─────────────
class _SitesTab extends StatefulWidget {
  const _SitesTab();
  @override
  State<_SitesTab> createState() => _SitesTabState();
}

class _SitesTabState extends State<_SitesTab> with AutomaticKeepAliveClientMixin {
  static const sites = {
    'Printables': 'https://www.printables.com',
    'Thingiverse': 'https://www.thingiverse.com',
    'MakerWorld': 'https://makerworld.com',
    'Cults': 'https://cults3d.com',
  };
  late final WebViewController ctrl;
  String current = 'Printables';

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    ctrl = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..loadRequest(Uri.parse(sites[current]!));
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Column(children: [
      SizedBox(
        height: 52,
        child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.all(8), children: [
          IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () async {
              if (await ctrl.canGoBack()) ctrl.goBack();
            },
          ),
          IconButton(icon: const Icon(Icons.refresh), onPressed: () => ctrl.reload()),
          for (final e in sites.entries)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: ChoiceChip(
                label: Text(e.key),
                selected: current == e.key,
                onSelected: (_) {
                  setState(() => current = e.key);
                  ctrl.loadRequest(Uri.parse(e.value));
                },
              ),
            ),
        ]),
      ),
      Expanded(child: WebViewWidget(controller: ctrl)),
    ]);
  }
}
