import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';

enum FileKind { gcode, threeMfSliced, threeMfRaw, stl, unknown }

class SendOptions {
  double layer;
  int infill;
  bool supports;
  bool startNow;
  SendOptions({this.layer = 0.2, this.infill = 15, this.supports = false, this.startNow = true});
}

class InspectResult {
  final FileKind kind;
  final String? gcodeName;
  final Uint8List? gcode;
  const InspectResult(this.kind, {this.gcodeName, this.gcode});

  bool get needsSlicing => kind == FileKind.threeMfRaw || kind == FileKind.stl;
  bool get supported => kind != FileKind.unknown;

  String get label => switch (kind) {
        FileKind.gcode => 'G-code — готов к печати',
        FileKind.threeMfSliced => '3MF с готовым G-code внутри — извлеку и отправлю',
        FileKind.threeMfRaw => '3MF без нарезки — нужен сервер нарезки',
        FileKind.stl => 'STL — нужен сервер нарезки',
        FileKind.unknown => 'Формат не поддерживается',
      };
}

String baseName(String n) {
  var s = n.split('/').last;
  s = s.replaceAll(RegExp(r'\.gcode\.3mf$', caseSensitive: false), '');
  final i = s.lastIndexOf('.');
  return i > 0 ? s.substring(0, i) : s;
}

Map<String, dynamic>? _findGcode(Uint8List b) {
  final arc = ZipDecoder().decodeBytes(b);
  ArchiveFile? best;
  for (final f in arc.files) {
    if (!f.isFile) continue;
    final n = f.name.toLowerCase();
    if (n.endsWith('.gcode')) {
      if (best == null || n.contains('plate_1')) best = f;
    }
  }
  if (best == null) return null;
  return {'bytes': Uint8List.fromList(best.content as List<int>)};
}

Future<InspectResult> inspectFile(String name, Uint8List bytes) async {
  final n = name.toLowerCase();
  if (n.endsWith('.gcode') || n.endsWith('.gco') || n.endsWith('.g')) {
    return const InspectResult(FileKind.gcode);
  }
  if (n.endsWith('.stl')) return const InspectResult(FileKind.stl);
  if (n.endsWith('.3mf')) {
    try {
      final r = await compute(_findGcode, bytes);
      if (r != null) {
        return InspectResult(FileKind.threeMfSliced,
            gcodeName: '${baseName(name)}.gcode', gcode: r['bytes'] as Uint8List);
      }
      return const InspectResult(FileKind.threeMfRaw);
    } catch (_) {
      return const InspectResult(FileKind.unknown);
    }
  }
  return const InspectResult(FileKind.unknown);
}
