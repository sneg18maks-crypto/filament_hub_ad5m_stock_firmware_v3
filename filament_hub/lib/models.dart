import 'package:flutter/material.dart';

enum PrinterKind { moonraker, bambuLan, octoprint, flashforgeAd5m }

String kindLabel(PrinterKind k) => switch (k) {
      PrinterKind.moonraker => 'Klipper / Moonraker',
      PrinterKind.flashforgeAd5m => 'FlashForge Adventurer 5M (штатная прошивка)',
      PrinterKind.bambuLan => 'Bambu Lab (LAN)',
      PrinterKind.octoprint => 'OctoPrint',
    };

class PrinterProfile {
  final String id, name, model, host, accessCode, serialNumber;
  final int port;
  final PrinterKind kind;
  const PrinterProfile({
    required this.id,
    required this.name,
    this.model = '',
    required this.host,
    this.port = 7125,
    this.kind = PrinterKind.moonraker,
    this.accessCode = '',
    this.serialNumber = '',
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'model': model,
        'host': host,
        'port': port,
        'kind': kind.index,
        'code': accessCode,
        'serialNumber': serialNumber,
      };

  factory PrinterProfile.fromJson(Map<String, dynamic> j) => PrinterProfile(
        id: j['id'] as String,
        name: j['name'] as String,
        model: (j['model'] ?? '') as String,
        host: (j['host'] ?? '') as String,
        port: (j['port'] ?? 7125) as int,
        kind: PrinterKind.values[(j['kind'] ?? 0) as int],
        accessCode: (j['code'] ?? '') as String,
        serialNumber: (j['serialNumber'] ?? '') as String,
      );
}

/// Данные с RFID-метки катушки.
/// Позже заполняются из реального ридера: FilamentData.fromJson(...)
class FilamentData {
  final String id, type, brand, colorName;
  final Color color;
  final double humidity; // %
  final double weightG; // остаток, г
  final double totalG;
  final double tempC; // рабочая температура сопла
  final int minTemp, maxTemp, bedTemp;

  const FilamentData({
    required this.id,
    required this.type,
    this.brand = 'Generic',
    required this.colorName,
    required this.color,
    required this.humidity,
    required this.weightG,
    this.totalG = 1000,
    required this.tempC,
    this.minTemp = 190,
    this.maxTemp = 230,
    this.bedTemp = 60,
  });

  double get fraction => (weightG / totalG).clamp(0.0, 1.0);
  String get hex => '#${(color.value & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';
  String get title => '$brand $type';

  FilamentData copyWith({
    String? type,
    String? brand,
    String? colorName,
    Color? color,
    double? humidity,
    double? weightG,
    double? tempC,
    int? minTemp,
    int? maxTemp,
    int? bedTemp,
  }) =>
      FilamentData(
        id: id,
        type: type ?? this.type,
        brand: brand ?? this.brand,
        colorName: colorName ?? this.colorName,
        color: color ?? this.color,
        humidity: humidity ?? this.humidity,
        weightG: weightG ?? this.weightG,
        totalG: totalG,
        tempC: tempC ?? this.tempC,
        minTemp: minTemp ?? this.minTemp,
        maxTemp: maxTemp ?? this.maxTemp,
        bedTemp: bedTemp ?? this.bedTemp,
      );

  factory FilamentData.fromJson(Map<String, dynamic> j) => FilamentData(
        id: (j['id'] ?? DateTime.now().microsecondsSinceEpoch.toString()) as String,
        type: (j['type'] ?? '—') as String,
        brand: (j['brand'] ?? 'Generic') as String,
        colorName: (j['color_name'] ?? '—') as String,
        color: Color(int.parse((j['color_hex'] ?? 'FFFFFF') as String, radix: 16) | 0xFF000000),
        humidity: ((j['humidity'] ?? 0) as num).toDouble(),
        weightG: ((j['weight'] ?? 0) as num).toDouble(),
        totalG: ((j['total'] ?? 1000) as num).toDouble(),
        tempC: ((j['temp'] ?? 0) as num).toDouble(),
      );
}

class PrinterStatus {
  final bool connected;
  final String state; // standby / printing / paused / complete / error
  final double nozzle, nozzleTarget, bed, bedTarget, chamber, progress;
  final String file;
  final int layer, totalLayers, speedPct;
  final Duration elapsed, remaining;
  final double fanPart, fanAux, fanChamber;
  final bool light;

  const PrinterStatus({
    this.connected = false,
    this.state = 'offline',
    this.nozzle = 0,
    this.nozzleTarget = 0,
    this.bed = 0,
    this.bedTarget = 0,
    this.chamber = 0,
    this.progress = 0,
    this.file = '',
    this.layer = 0,
    this.totalLayers = 0,
    this.speedPct = 100,
    this.elapsed = Duration.zero,
    this.remaining = Duration.zero,
    this.fanPart = 0,
    this.fanAux = 0,
    this.fanChamber = 0,
    this.light = false,
  });

  bool get isPrinting => state == 'printing';
  bool get isPaused => state == 'paused';
  bool get hasJob => isPrinting || isPaused;

  PrinterStatus copyWith({
    bool? connected,
    String? state,
    double? nozzle,
    double? nozzleTarget,
    double? bed,
    double? bedTarget,
    double? chamber,
    double? progress,
    String? file,
    int? layer,
    int? totalLayers,
    int? speedPct,
    Duration? elapsed,
    Duration? remaining,
    double? fanPart,
    double? fanAux,
    double? fanChamber,
    bool? light,
  }) =>
      PrinterStatus(
        connected: connected ?? this.connected,
        state: state ?? this.state,
        nozzle: nozzle ?? this.nozzle,
        nozzleTarget: nozzleTarget ?? this.nozzleTarget,
        bed: bed ?? this.bed,
        bedTarget: bedTarget ?? this.bedTarget,
        chamber: chamber ?? this.chamber,
        progress: progress ?? this.progress,
        file: file ?? this.file,
        layer: layer ?? this.layer,
        totalLayers: totalLayers ?? this.totalLayers,
        speedPct: speedPct ?? this.speedPct,
        elapsed: elapsed ?? this.elapsed,
        remaining: remaining ?? this.remaining,
        fanPart: fanPart ?? this.fanPart,
        fanAux: fanAux ?? this.fanAux,
        fanChamber: fanChamber ?? this.fanChamber,
        light: light ?? this.light,
      );
}

class PrintRecord {
  final String name, type;
  final DateTime date;
  final Duration duration;
  final double grams;
  final bool success;
  final Color color;
  const PrintRecord({
    required this.name,
    required this.date,
    required this.duration,
    required this.grams,
    required this.success,
    required this.color,
    required this.type,
  });
}

class ModelItem {
  final String id, title, author, category, description, material;
  final int likes, downloads;
  final double hours, grams;
  final Color c1, c2;
  final IconData icon;
  const ModelItem({
    required this.id,
    required this.title,
    required this.author,
    required this.category,
    required this.description,
    this.material = 'PLA',
    required this.likes,
    required this.downloads,
    required this.hours,
    required this.grams,
    required this.c1,
    required this.c2,
    required this.icon,
  });
}

class GcodeFile {
  final String name;
  final double sizeMb;
  final DateTime modified;
  final Duration est;
  final double grams;
  const GcodeFile({
    required this.name,
    required this.sizeMb,
    required this.modified,
    this.est = Duration.zero,
    this.grams = 0,
  });
}

class AppNotification {
  final String title, body, kind; // done / error / warn / info
  final DateTime time;
  bool read;
  AppNotification({required this.title, required this.body, required this.kind, required this.time, this.read = false});
}
