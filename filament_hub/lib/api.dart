import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'models.dart';

/// Клиент Moonraker (Klipper). Для других принтеров делается свой класс с теми же методами.
class PrinterApi {
  final String host;
  final int port;
  PrinterApi(this.host, [this.port = 7125]);

  String get base => 'http://$host:$port';
  static double _d(dynamic v) => v is num ? v.toDouble() : 0.0;

  Future<bool> ping() async {
    try {
      final r = await http.get(Uri.parse('$base/server/info')).timeout(const Duration(seconds: 3));
      return r.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<PrinterStatus> status() async {
    final r = await http
        .get(Uri.parse('$base/printer/objects/query?extruder&heater_bed&print_stats&display_status&fan&gcode_move'))
        .timeout(const Duration(seconds: 3));
    if (r.statusCode != 200) throw Exception('HTTP ${r.statusCode}');
    final s = jsonDecode(r.body)['result']['status'] as Map;
    final ex = (s['extruder'] ?? {}) as Map;
    final bd = (s['heater_bed'] ?? {}) as Map;
    final ps = (s['print_stats'] ?? {}) as Map;
    final ds = (s['display_status'] ?? {}) as Map;
    final fn = (s['fan'] ?? {}) as Map;
    final gm = (s['gcode_move'] ?? {}) as Map;
    final info = (ps['info'] ?? {}) as Map;
    final progress = _d(ds['progress']);
    final elapsed = Duration(seconds: _d(ps['print_duration']).round());
    final remaining = progress > 0.01
        ? Duration(seconds: (elapsed.inSeconds * (1 - progress) / progress).round())
        : Duration.zero;
    final sf = _d(gm['speed_factor']);
    return PrinterStatus(
      connected: true,
      state: (ps['state'] ?? 'standby') as String,
      nozzle: _d(ex['temperature']),
      nozzleTarget: _d(ex['target']),
      bed: _d(bd['temperature']),
      bedTarget: _d(bd['target']),
      progress: progress,
      file: (ps['filename'] ?? '') as String,
      layer: (info['current_layer'] as num?)?.toInt() ?? 0,
      totalLayers: (info['total_layer'] as num?)?.toInt() ?? 0,
      speedPct: sf > 0 ? (sf * 100).round() : 100,
      elapsed: elapsed,
      remaining: remaining,
      fanPart: _d(fn['speed']),
    );
  }

  Future<void> _post(String path) async {
    final r = await http.post(Uri.parse('$base$path')).timeout(const Duration(seconds: 8));
    if (r.statusCode >= 400) throw Exception('Принтер ответил ${r.statusCode}: ${r.body}');
  }

  Future<void> pause() => _post('/printer/print/pause');
  Future<void> resume() => _post('/printer/print/resume');
  Future<void> cancel() => _post('/printer/print/cancel');
  Future<void> emergencyStop() => _post('/printer/emergency_stop');
  Future<void> startPrint(String name) =>
      _post('/printer/print/start?filename=${Uri.encodeQueryComponent(name)}');
  Future<void> gcode(String script) => _post('/printer/gcode/script?script=${Uri.encodeQueryComponent(script)}');
  Future<void> setNozzle(int t) => gcode('M104 S$t');
  Future<void> setBed(int t) => gcode('M140 S$t');
  Future<void> setSpeed(int pct) => gcode('M220 S$pct');
  Future<void> setFan(int i, double v) {
    final p = const [0, 2, 3][i.clamp(0, 2)];
    return gcode('M106 P$p S${(v * 255).round()}');
  }

  Future<void> home([String axes = '']) => gcode(axes.isEmpty ? 'G28' : 'G28 $axes');
  Future<void> motorsOff() => gcode('M84');
  Future<void> move(String axis, double d) =>
      gcode('G91\nG1 $axis$d F${axis == 'Z' ? 600 : 6000}\nG90');
  Future<void> extrude(double d) => gcode('M83\nG1 E$d F300');

  Future<List<GcodeFile>> listFiles() async {
    final r = await http.get(Uri.parse('$base/server/files/list?root=gcodes')).timeout(const Duration(seconds: 6));
    if (r.statusCode != 200) throw Exception('HTTP ${r.statusCode}');
    final list = jsonDecode(r.body)['result'] as List;
    final out = list
        .map((e) => GcodeFile(
              name: e['path'] as String,
              sizeMb: _d(e['size']) / 1048576,
              modified: DateTime.fromMillisecondsSinceEpoch((_d(e['modified']) * 1000).toInt()),
            ))
        .toList();
    out.sort((a, b) => b.modified.compareTo(a.modified));
    return out;
  }

  Future<void> deleteFile(String name) async {
    final r = await http
        .delete(Uri.parse('$base/server/files/gcodes/${Uri.encodeComponent(name)}'))
        .timeout(const Duration(seconds: 8));
    if (r.statusCode >= 400) throw Exception('Не удалось удалить (${r.statusCode})');
  }

  /// Загрузка G-code на принтер по Wi-Fi и (опционально) мгновенный старт печати.
  Future<void> upload(String name, List<int> bytes, {bool print = true}) async {
    final req = http.MultipartRequest('POST', Uri.parse('$base/server/files/upload'))
      ..fields['print'] = print ? 'true' : 'false'
      ..files.add(http.MultipartFile.fromBytes('file', bytes, filename: name));
    final res = await req.send().timeout(const Duration(minutes: 10));
    if (res.statusCode >= 300) {
      final body = await res.stream.bytesToString();
      throw Exception('Ошибка загрузки (${res.statusCode}): $body');
    }
  }

  /// Поиск Moonraker в локальной сети (сканирует подсеть телефона по порту).
  static Future<List<String>> discover({int port = 7125}) async {
    String? prefix;
    final ifaces = await NetworkInterface.list(type: InternetAddressType.IPv4);
    for (final i in ifaces) {
      for (final a in i.addresses) {
        final ip = a.address;
        if (!a.isLoopback && (ip.startsWith('192.168.') || ip.startsWith('10.') || ip.startsWith('172.'))) {
          final p = ip.split('.');
          prefix = '${p[0]}.${p[1]}.${p[2]}';
          break;
        }
      }
      if (prefix != null) break;
    }
    if (prefix == null) return [];
    final found = <String>[];
    await Future.wait(List.generate(254, (i) async {
      final ip = '$prefix.${i + 1}';
      try {
        final s = await Socket.connect(ip, port, timeout: const Duration(milliseconds: 500));
        s.destroy();
        found.add(ip);
      } catch (_) {}
    }));
    found.sort();
    return found;
  }
}

/// Клиент сервера нарезки (server/slicer_server.py на ПК или Raspberry Pi).
class SlicerClient {
  final String url;
  SlicerClient(String u) : url = u.trim().replaceAll(RegExp(r'/+$'), '');

  Future<bool> ping() async {
    try {
      final r = await http.get(Uri.parse('$url/health')).timeout(const Duration(seconds: 3));
      return r.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<Uint8List> slice(String name, Uint8List bytes, {double layer = 0.2, int infill = 15, bool supports = false}) async {
    final req = http.MultipartRequest('POST', Uri.parse('$url/slice'))
      ..fields['layer'] = layer.toString()
      ..fields['infill'] = infill.toString()
      ..fields['supports'] = supports ? '1' : '0'
      ..files.add(http.MultipartFile.fromBytes('file', bytes, filename: name));
    final res = await req.send().timeout(const Duration(minutes: 15));
    final body = await res.stream.toBytes();
    if (res.statusCode != 200) {
      throw Exception('Сервер нарезки: ${utf8.decode(body, allowMalformed: true)}');
    }
    return Uint8List.fromList(body);
  }
}


/// Клиент штатной LAN API FlashForge Adventurer 5M (без Moonraker).
/// Требует включённый LAN Only mode, IP, Serial Number и Check Code.
class FlashForgeAd5mApi {
  final String host;
  final String serialNumber;
  final String checkCode;
  final int port;
  FlashForgeAd5mApi(this.host, this.serialNumber, this.checkCode, [this.port = 8898]);

  String get base => 'http://$host:$port';
  Map<String, dynamic> get _auth => {'serialNumber': serialNumber, 'checkCode': checkCode};

  Future<Map<String, dynamic>> _postJson(String path, [Map<String, dynamic>? body]) async {
    final r = await http.post(
      Uri.parse('$base$path'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({..._auth, ...?body}),
    ).timeout(const Duration(seconds: 8));
    if (r.statusCode >= 400) throw Exception('FlashForge HTTP ${r.statusCode}: ${r.body}');
    final decoded = jsonDecode(r.body);
    if (decoded is Map<String, dynamic>) {
      final code = decoded['code'];
      if (code is num && code != 0) {
        throw Exception('FlashForge: ${decoded['message'] ?? 'ошибка авторизации/команды'} (код $code)');
      }
      return decoded;
    }
    throw Exception('Некорректный ответ принтера');
  }

  Future<bool> ping() async {
    try { await _postJson('/detail'); return true; } catch (_) { return false; }
  }

  double _num(dynamic v) => v is num ? v.toDouble() : double.tryParse('$v') ?? 0;
  String _str(Map m, String key, [String fallback = '']) => (m[key] ?? fallback).toString();

  Future<PrinterStatus> status() async {
    final d = await _postJson('/detail');
    final raw = d['detail'] is Map ? d['detail'] : d;
    final m = Map<String, dynamic>.from(raw as Map);
    final rawState = _str(m, 'status', 'ready').toLowerCase();
    final state = switch (rawState) {
      'printing' || 'heating' || 'sending' || 'downloading' => 'printing',
      'pause' || 'pausing' => 'paused',
      'completed' => 'complete',
      'error' => 'error',
      _ => 'standby',
    };
    final progress = _num(m['printProgress']).clamp(0.0, 1.0).toDouble();
    return PrinterStatus(
      connected: true,
      state: state,
      nozzle: _num(m['rightTemp']),
      nozzleTarget: _num(m['rightTargetTemp'] ?? m['rightTempTarget']),
      bed: _num(m['platTemp']),
      bedTarget: _num(m['platTargetTemp']),
      progress: progress,
      file: _str(m, 'printFileName'),
      layer: _num(m['printLayer']).round(),
      totalLayers: _num(m['totalLayer']).round(),
      speedPct: _num(m['speed']).round() == 0 ? 100 : _num(m['speed']).round(),
      elapsed: Duration(seconds: _num(m['printDuration']).round()),
      remaining: Duration(seconds: _num(m['estimatedTime']).round()),
      light: _str(m, 'lightStatus').toLowerCase() == 'open',
    );
  }

  Future<void> _control(String cmd, Map<String, dynamic> args) async {
    await _postJson('/control', {'payload': {'cmd': cmd, 'args': args}});
  }
  Future<void> pause() => _control('jobCtl_cmd', {'jobID': '', 'action': 'pause'});
  Future<void> resume() => _control('jobCtl_cmd', {'jobID': '', 'action': 'continue'});
  Future<void> cancel() => _control('jobCtl_cmd', {'jobID': '', 'action': 'cancel'});
  Future<void> setNozzle(int t) => _control('temperatureCtl_cmd', {'rightNozzle': t});
  Future<void> setBed(int t) => _control('temperatureCtl_cmd', {'platform': t});
  Future<void> setSpeed(int pct) => _control('printerCtl_cmd', {'speed': pct});

  Future<void> startPrint(String name) async {
    await _postJson('/printGcode', {'fileName': name, 'levelingBeforePrint': true});
  }

  Future<void> upload(String name, List<int> bytes, {bool print = true}) async {
    // AD5M stock firmware expects credentials as multipart request headers,
    // while file metadata is sent as regular multipart form fields.
    final req = http.MultipartRequest('POST', Uri.parse('$base/uploadGcode'))
      ..headers['serialNumber'] = serialNumber
      ..headers['checkCode'] = checkCode
      ..fields['fileSize'] = bytes.length.toString()
      ..fields['printNow'] = print ? 'true' : 'false'
      ..fields['levelingBeforePrint'] = 'true'
      ..files.add(http.MultipartFile.fromBytes('gcodeFile', bytes, filename: name));
    final res = await req.send().timeout(const Duration(minutes: 10));
    final body = await res.stream.bytesToString();
    if (res.statusCode >= 300) throw Exception('Ошибка загрузки FlashForge (${res.statusCode}): $body');
    try {
      final data = jsonDecode(body);
      if (data is Map && data['code'] is num && data['code'] != 0) {
        throw Exception('FlashForge: ${data['message'] ?? 'ошибка загрузки'} (код ${data['code']})');
      }
    } catch (e) {
      if (e.toString().startsWith('Exception: FlashForge')) rethrow;
    }
  }

  Future<List<GcodeFile>> listFiles() async {
    final d = await _postJson('/gcodeList');
    final raw = d['gcodeList'] ?? d['files'] ?? d['list'] ?? [];
    if (raw is! List) return [];
    return raw.map((e) {
      final m = Map<String, dynamic>.from(e as Map);
      final name = (m['fileName'] ?? m['name'] ?? m['path'] ?? '').toString();
      final size = _num(m['fileSize'] ?? m['size']);
      final stamp = _num(m['modifyTime'] ?? m['modified']);
      return GcodeFile(
        name: name, sizeMb: size / 1048576,
        modified: stamp > 0
          ? DateTime.fromMillisecondsSinceEpoch((stamp > 1000000000000 ? stamp : stamp * 1000).round())
          : DateTime.now(),
      );
    }).where((f) => f.name.isNotEmpty).toList();
  }

  Future<void> deleteFile(String name) async => throw Exception('Удаление файлов AD5M пока не подключено.');
  Future<void> setFan(int i, double v) async {
    if (i != 0) throw Exception('Этот вентилятор не поддерживается на AD5M.');
    await _control('printerCtl_cmd', {'coolingFan': (v * 100).round()});
  }
  Future<void> emergencyStop() async => throw Exception('Аварийная остановка из приложения не реализована для штатной прошивки.');
}
