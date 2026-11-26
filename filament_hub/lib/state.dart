import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api.dart';
import 'mock.dart';
import 'models.dart';
import 'send.dart';

class AppScope extends InheritedNotifier<AppState> {
  AppScope({super.key, required AppState state, required Widget child}) : super(notifier: state, child: child);
  static AppState of(BuildContext c) => c.dependOnInheritedWidgetOfExactType<AppScope>()!.notifier!;
}

class AppState extends ChangeNotifier {
  // ── навигация и настройки ──
  int tab = 0;
  bool demoMode = true;
  final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.dark);
  bool notifyDone = true, notifyError = true, notifyLow = true, notifyHumidity = false;
  bool remoteEnabled = false;
  String remoteMode = 'vpn';
  String cameraUrl = '';
  String slicerUrl = '';

  // ── принтеры ──
  List<PrinterProfile> printers = [
    const PrinterProfile(id: 'demo', name: 'Мой принтер', model: 'Voron 2.4 (демо)', host: '192.168.1.50'),
  ];
  String activeId = 'demo';

  PrinterProfile? get active {
    for (final p in printers) {
      if (p.id == activeId) return p;
    }
    return null;
  }

  dynamic get api {
    final p = active;
    if (p == null || p.host.isEmpty) return null;
    if (p.kind == PrinterKind.moonraker) return PrinterApi(p.host, p.port);
    if (p.kind == PrinterKind.flashforgeAd5m) {
      return FlashForgeAd5mApi(p.host, p.serialNumber, p.accessCode, p.port);
    }
    return null;
  }

  // ── статус ──
  PrinterStatus status = const PrinterStatus();
  Duration _jobTotal = const Duration(hours: 3, minutes: 20);
  double _jobGrams = 96;
  final List<double> nozzleHist = List<double>.generate(60, (i) => 214.0 + sin(i / 5.0));
  final List<double> bedHist = List<double>.generate(60, (i) => 59.5 + cos(i / 7.0) * 0.5);

  // ── филамент ──
  List<FilamentData?> slots = [mockSpools[0], mockSpools[1], mockSpools[2], null];
  int activeSlot = 0;
  List<FilamentData> library = List.of(mockSpools);

  // ── данные ──
  List<PrintRecord> history = mockHistory();
  List<GcodeFile> files = mockFiles();
  List<AppNotification> notifications = mockNotifications();
  Set<String> favorites = {'m1', 'm3'};

  Timer? _timer;
  int _n = 0;

  AppState() {
    _resetDemo();
  }

  void setTab(int i) {
    tab = i;
    notifyListeners();
  }

  void update(VoidCallback f) {
    f();
    notifyListeners();
    _save();
  }

  // ───────── сохранение ─────────
  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    demoMode = p.getBool('demo') ?? true;
    themeNotifier.value = (p.getBool('dark') ?? true) ? ThemeMode.dark : ThemeMode.light;
    notifyDone = p.getBool('nDone') ?? true;
    notifyError = p.getBool('nErr') ?? true;
    notifyLow = p.getBool('nLow') ?? true;
    notifyHumidity = p.getBool('nHum') ?? false;
    remoteEnabled = p.getBool('remote') ?? false;
    remoteMode = p.getString('remoteMode') ?? 'vpn';
    cameraUrl = p.getString('cam') ?? '';
    slicerUrl = p.getString('slicer') ?? '';
    favorites = (p.getStringList('fav') ?? favorites.toList()).toSet();
    final raw = p.getString('printers');
    if (raw != null) {
      try {
        final l = (jsonDecode(raw) as List)
            .map((e) => PrinterProfile.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
        if (l.isNotEmpty) printers = l;
      } catch (_) {}
    }
    activeId = p.getString('active') ?? printers.first.id;
    if (active == null) activeId = printers.first.id;
    if (!demoMode) {
      status = const PrinterStatus();
      refreshAll();
    }
    notifyListeners();
    _timer ??= Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  Future<void> _save() async {
    final p = await SharedPreferences.getInstance();
    await p.setBool('demo', demoMode);
    await p.setBool('dark', themeNotifier.value == ThemeMode.dark);
    await p.setBool('nDone', notifyDone);
    await p.setBool('nErr', notifyError);
    await p.setBool('nLow', notifyLow);
    await p.setBool('nHum', notifyHumidity);
    await p.setBool('remote', remoteEnabled);
    await p.setString('remoteMode', remoteMode);
    await p.setString('cam', cameraUrl);
    await p.setString('slicer', slicerUrl);
    await p.setStringList('fav', favorites.toList());
    await p.setString('printers', jsonEncode(printers.map((e) => e.toJson()).toList()));
    await p.setString('active', activeId);
  }

  @override
  void dispose() {
    _timer?.cancel();
    themeNotifier.dispose();
    super.dispose();
  }

  void setDark(bool v) {
    themeNotifier.value = v ? ThemeMode.dark : ThemeMode.light;
    notifyListeners();
    _save();
  }

  void setDemo(bool v) {
    demoMode = v;
    if (v) {
      _resetDemo();
      files = mockFiles();
    } else {
      status = const PrinterStatus();
      files = [];
      refreshAll();
    }
    notifyListeners();
    _save();
  }

  // ───────── опрос / симуляция ─────────
  void _tick() {
    if (demoMode) {
      _simTick();
    } else {
      _n++;
      if (_n % 2 == 0) refresh();
    }
  }

  void _pushHist() {
    nozzleHist.add(status.nozzle);
    bedHist.add(status.bed);
    if (nozzleHist.length > 60) nozzleHist.removeAt(0);
    if (bedHist.length > 60) bedHist.removeAt(0);
  }

  Future<void> refreshAll() async {
    await refresh();
    await refreshFiles();
  }

  Future<void> refresh() async {
    if (demoMode) return;
    final a = api;
    if (a == null) {
      status = const PrinterStatus();
      notifyListeners();
      return;
    }
    try {
      final prev = status.state;
      status = await a.status();
      if (prev == 'printing' && status.state == 'complete' && notifyDone) {
        addNotification('Печать завершена', status.file, 'done');
      }
      if (prev != 'error' && status.state == 'error' && notifyError) {
        addNotification('Ошибка печати', status.file, 'error');
      }
      _pushHist();
    } catch (_) {
      status = const PrinterStatus();
    }
    notifyListeners();
  }

  Future<void> refreshFiles() async {
    if (demoMode) return;
    final a = api;
    if (a == null) {
      files = [];
      notifyListeners();
      return;
    }
    try {
      files = await a.listFiles();
    } catch (_) {}
    notifyListeners();
  }

  void _resetDemo() {
    _jobTotal = const Duration(hours: 3, minutes: 20);
    _jobGrams = 96;
    status = PrinterStatus(
      connected: true,
      state: 'printing',
      nozzle: 214.6,
      nozzleTarget: 215.0,
      bed: 59.8,
      bedTarget: 60.0,
      chamber: 36.0,
      progress: 0.42,
      file: 'Gridfinity_baseplate_4x4.gcode',
      layer: 126,
      totalLayers: 300,
      speedPct: 100,
      elapsed: _jobTotal * 0.42,
      remaining: _jobTotal * 0.58,
      fanPart: 0.7,
      fanAux: 0.3,
      fanChamber: 0.5,
      light: true,
    );
  }

  void _simTick() {
    final s = status;
    final rnd = Random();
    double ease(double cur, double target, double rate, double rest) {
      final goal = target > 0 ? target : rest;
      return cur + (goal - cur) * rate + (rnd.nextDouble() - 0.5) * 0.25;
    }

    var st = s.state;
    var progress = s.progress;
    var layer = s.layer;
    var nt = s.nozzleTarget;
    var bt = s.bedTarget;
    final nozzle = ease(s.nozzle, nt, 0.1, 24.0);
    final bed = ease(s.bed, bt, 0.05, 24.0);
    final chamber = ease(s.chamber, st == 'printing' ? 38.0 : 24.0, 0.02, 24.0);
    if (st == 'printing') {
      progress = min(1.0, progress + 0.0008);
      layer = (progress * s.totalLayers).round();
      _consume(0.12);
      if (progress >= 1.0) {
        st = 'complete';
        nt = 0;
        bt = 0;
        _finishJob(s.file);
      }
    }
    status = s.copyWith(
      state: st,
      progress: progress,
      layer: layer,
      nozzle: nozzle,
      bed: bed,
      chamber: chamber,
      nozzleTarget: nt,
      bedTarget: bt,
      elapsed: _jobTotal * progress,
      remaining: _jobTotal * (1 - progress),
    );
    _pushHist();
    notifyListeners();
  }

  void _consume(double g) {
    final f = slots[activeSlot];
    if (f == null) return;
    final nw = max(0.0, f.weightG - g);
    slots[activeSlot] = f.copyWith(weightG: nw);
    if (f.weightG >= 100 && nw < 100 && notifyLow) {
      addNotification('Мало пластика', '${f.title} ${f.colorName}: осталось ${nw.round()} г', 'warn');
    }
  }

  void _finishJob(String name) {
    final f = slots[activeSlot];
    history.insert(
        0,
        PrintRecord(
          name: name,
          date: DateTime.now(),
          duration: _jobTotal,
          grams: _jobGrams,
          success: true,
          color: f?.color ?? Colors.grey,
          type: f?.type ?? 'PLA',
        ));
    if (notifyDone) addNotification('Печать завершена', name, 'done');
  }

  // ───────── команды принтеру ─────────
  Future<void> _cmd(Future<void> Function(dynamic a) real, PrinterStatus Function(PrinterStatus s) demo) async {
    if (demoMode) {
      status = demo(status);
      notifyListeners();
      return;
    }
    final a = api;
    if (a == null) throw Exception('Принтер не подключён или тип принтера пока не поддерживается');
    await real(a);
    await refresh();
  }

  Future<void> pause() => _cmd((a) => a.pause(), (s) => s.copyWith(state: 'paused'));
  Future<void> resume() => _cmd((a) => a.resume(), (s) => s.copyWith(state: 'printing'));
  Future<void> cancel() => _cmd(
      (a) => a.cancel(),
      (s) => s.copyWith(
          state: 'standby',
          progress: 0,
          file: '',
          layer: 0,
          nozzleTarget: 0,
          bedTarget: 0,
          elapsed: Duration.zero,
          remaining: Duration.zero));
  Future<void> emergencyStop() => _cmd((a) => a.emergencyStop(),
      (s) => s.copyWith(state: 'error', nozzleTarget: 0, bedTarget: 0));
  Future<void> setNozzle(int t) => _cmd((a) => a.setNozzle(t), (s) => s.copyWith(nozzleTarget: t.toDouble()));
  Future<void> setBed(int t) => _cmd((a) => a.setBed(t), (s) => s.copyWith(bedTarget: t.toDouble()));
  Future<void> setSpeed(int pct) => _cmd((a) => a.setSpeed(pct), (s) => s.copyWith(speedPct: pct));
  Future<void> home([String axes = '']) => _cmd((a) => a.home(axes), (s) => s);
  Future<void> motorsOff() => _cmd((a) => a.motorsOff(), (s) => s);
  Future<void> move(String axis, double d) => _cmd((a) => a.move(axis, d), (s) => s);
  Future<void> extrude(double d) => _cmd((a) => a.extrude(d), (s) => s);

  void setFanLocal(int i, double v) {
    status = status.copyWith(
      fanPart: i == 0 ? v : null,
      fanAux: i == 1 ? v : null,
      fanChamber: i == 2 ? v : null,
    );
    notifyListeners();
  }

  Future<void> setFan(int i, double v) async {
    if (demoMode) return;
    final a = api;
    if (a == null) throw Exception('Принтер не подключён');
    await a.setFan(i, v);
  }

  Future<void> toggleLight() async {
    if (!demoMode) throw Exception('Управление светом зависит от макросов принтера — пока не настроено');
    status = status.copyWith(light: !status.light);
    notifyListeners();
  }

  Future<void> startPrint(String name, {Duration? est, double grams = 0}) async {
    if (demoMode) {
      final f = slots[activeSlot];
      _jobTotal = est ?? const Duration(hours: 1, minutes: 30);
      _jobGrams = grams;
      status = status.copyWith(
        state: 'printing',
        progress: 0,
        file: name,
        layer: 0,
        totalLayers: 240,
        elapsed: Duration.zero,
        remaining: _jobTotal,
        nozzleTarget: f?.tempC ?? 215.0,
        bedTarget: (f?.bedTemp ?? 60).toDouble(),
      );
      addNotification('Печать начата', name, 'info');
      return;
    }
    final a = api;
    if (a == null) throw Exception('Принтер не подключён или тип принтера пока не поддерживается');
    await a.startPrint(name);
    await refresh();
  }

  // ───────── отправка файла на принтер ─────────
  Future<void> sendFile({
    required String name,
    required Uint8List bytes,
    required InspectResult info,
    required SendOptions o,
    required void Function(int step, String msg) onStep,
  }) async {
    Uint8List gcode;
    String gname;
    switch (info.kind) {
      case FileKind.gcode:
        gcode = bytes;
        gname = name.split('/').last;
        break;
      case FileKind.threeMfSliced:
        gcode = info.gcode!;
        gname = info.gcodeName!;
        break;
      case FileKind.threeMfRaw:
      case FileKind.stl:
        if (slicerUrl.trim().isEmpty && !demoMode) {
          throw Exception('Для STL и ненарезанного 3MF нужен сервер нарезки. Укажи его в «Подключение».');
        }
        onStep(1, 'Нарезка на сервере…');
        gname = '${baseName(name)}.gcode';
        if (demoMode) {
          await Future.delayed(const Duration(seconds: 2));
          gcode = Uint8List(0);
        } else {
          gcode = await SlicerClient(slicerUrl).slice(name, bytes, layer: o.layer, infill: o.infill, supports: o.supports);
        }
        break;
      case FileKind.unknown:
        throw Exception('Неподдерживаемый формат файла');
    }

    onStep(2, 'Загрузка на принтер по Wi-Fi…');
    if (demoMode) {
      await Future.delayed(const Duration(milliseconds: 1500));
      files.insert(
          0,
          GcodeFile(
              name: gname,
              sizeMb: (gcode.isEmpty ? bytes.length : gcode.length) / 1048576,
              modified: DateTime.now(),
              est: const Duration(hours: 1, minutes: 30)));
      notifyListeners();
    } else {
      final a = api;
      if (a == null) throw Exception('Принтер не подключён или тип принтера пока не поддерживается');
      await a.upload(gname, gcode, print: o.startNow);
      await refreshFiles();
    }

    if (o.startNow) {
      onStep(3, 'Запуск печати…');
      if (demoMode) {
        await Future.delayed(const Duration(milliseconds: 600));
        await startPrint(gname, est: const Duration(hours: 1, minutes: 30));
      } else {
        await Future.delayed(const Duration(seconds: 1));
        await refresh();
      }
    }
    onStep(4, 'Готово');
  }

  // ───────── файлы ─────────
  Future<void> deleteFile(String name) async {
    if (demoMode) {
      files.removeWhere((f) => f.name == name);
      notifyListeners();
      return;
    }
    final a = api;
    if (a == null) throw Exception('Принтер не подключён');
    await a.deleteFile(name);
    await refreshFiles();
  }

  // ───────── филамент ─────────
  Future<FilamentData> simulateScan(int slot) async {
    await Future.delayed(const Duration(milliseconds: 2400));
    final free = library.where((f) => !slots.any((s) => s?.id == f.id)).toList();
    final pool = free.isEmpty ? library : free;
    final pick = pool[Random().nextInt(pool.length)];
    slots[slot] = pick;
    notifyListeners();
    return pick;
  }

  void assignSlot(int i, FilamentData? f) {
    slots[i] = f;
    notifyListeners();
  }

  void loadSlot(int i) {
    activeSlot = i;
    notifyListeners();
  }

  // ───────── принтеры ─────────
  void addPrinter(PrinterProfile p) {
    printers.add(p);
    activeId = p.id;
    notifyListeners();
    _save();
    if (!demoMode) refreshAll();
  }

  void removePrinter(String id) {
    if (printers.length <= 1) return;
    printers.removeWhere((p) => p.id == id);
    if (activeId == id) activeId = printers.first.id;
    notifyListeners();
    _save();
  }

  void setActive(String id) {
    activeId = id;
    notifyListeners();
    _save();
    if (!demoMode) refreshAll();
  }

  // ───────── прочее ─────────
  void toggleFav(String id) {
    if (!favorites.remove(id)) favorites.add(id);
    notifyListeners();
    _save();
  }

  void addNotification(String title, String body, String kind) {
    notifications.insert(0, AppNotification(title: title, body: body, kind: kind, time: DateTime.now()));
    notifyListeners();
  }

  int get unread => notifications.where((n) => !n.read).length;
}
