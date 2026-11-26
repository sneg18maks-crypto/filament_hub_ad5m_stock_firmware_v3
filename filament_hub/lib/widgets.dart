import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'models.dart';
import 'theme.dart';

void snack(BuildContext c, String m) {
  ScaffoldMessenger.of(c)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(m), behavior: SnackBarBehavior.floating));
}

Future<void> guard(BuildContext context, Future<void> Function() f) async {
  try {
    await f();
  } catch (e) {
    if (context.mounted) snack(context, 'Ошибка: ${e.toString().replaceFirst('Exception: ', '')}');
  }
}

Future<bool> confirm(BuildContext c, String title, String text, {String ok = 'Да', bool danger = false}) async {
  final r = await showDialog<bool>(
    context: c,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(text),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
        FilledButton(
          style: danger ? FilledButton.styleFrom(backgroundColor: Palette.red) : null,
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(ok),
        ),
      ],
    ),
  );
  return r ?? false;
}

String fmtDuration(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes % 60;
  return h > 0 ? '${h}ч ${m}м' : '${m}м';
}

String fmtDate(DateTime d) {
  final now = DateTime.now();
  final diff = now.difference(d);
  if (diff.inMinutes < 1) return 'только что';
  if (diff.inHours < 1) return '${diff.inMinutes} мин назад';
  if (diff.inDays < 1) return '${diff.inHours} ч назад';
  if (diff.inDays < 7) return '${diff.inDays} дн назад';
  return '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';
}

String statusLabel(PrinterStatus s) {
  if (!s.connected) return 'Не в сети';
  return switch (s.state) {
    'printing' => 'Печатает',
    'paused' => 'Пауза',
    'complete' => 'Готово',
    'error' => 'Ошибка',
    _ => 'Ожидание',
  };
}

Color statusColor(PrinterStatus s) {
  if (!s.connected) return Colors.grey;
  return switch (s.state) {
    'printing' => Palette.green,
    'paused' => Palette.orange,
    'complete' => Palette.blue,
    'error' => Palette.red,
    _ => Colors.grey,
  };
}

class StatusChip extends StatelessWidget {
  final PrinterStatus s;
  const StatusChip(this.s, {super.key});
  @override
  Widget build(BuildContext context) {
    final c = statusColor(s);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: c.withOpacity(0.15), borderRadius: BorderRadius.circular(20)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.circle, size: 9, color: c),
        const SizedBox(width: 6),
        Text(statusLabel(s), style: TextStyle(color: c, fontWeight: FontWeight.w600, fontSize: 12)),
      ]),
    );
  }
}

class Panel extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final EdgeInsets margin;
  final VoidCallback? onTap;
  final Color? color;
  const Panel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.margin = const EdgeInsets.only(bottom: 12),
    this.onTap,
    this.color,
  });
  @override
  Widget build(BuildContext context) => Padding(
        padding: margin,
        child: Material(
          color: color ?? panelColor(context),
          borderRadius: BorderRadius.circular(18),
          clipBehavior: Clip.antiAlias,
          child: InkWell(onTap: onTap, child: Padding(padding: padding, child: child)),
        ),
      );
}

class SectionTitle extends StatelessWidget {
  final String text;
  final Widget? trailing;
  const SectionTitle(this.text, {super.key, this.trailing});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(children: [
          Expanded(child: Text(text, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold))),
          if (trailing != null) trailing!,
        ]),
      );
}

// ── Кольцо прогресса ──
class _RingPainter extends CustomPainter {
  final double value, stroke;
  final Color color, track;
  _RingPainter(this.value, this.stroke, this.color, this.track);
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset(stroke / 2, stroke / 2) & Size(size.width - stroke, size.height - stroke);
    final bg = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = track;
    final fg = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = color;
    canvas.drawArc(rect, 0, math.pi * 2, false, bg);
    canvas.drawArc(rect, -math.pi / 2, math.pi * 2 * value.clamp(0.0, 1.0), false, fg);
  }

  @override
  bool shouldRepaint(covariant _RingPainter o) => o.value != value || o.color != color;
}

class ProgressRing extends StatelessWidget {
  final double value, size;
  final Color color;
  final Widget? child;
  const ProgressRing({super.key, required this.value, this.size = 96, this.color = Palette.green, this.child});
  @override
  Widget build(BuildContext context) => SizedBox(
        width: size,
        height: size,
        child: Stack(alignment: Alignment.center, children: [
          CustomPaint(
              size: Size.square(size),
              painter: _RingPainter(value, 9, color, isDark(context) ? Colors.white12 : Colors.black12)),
          if (child != null) child!,
        ]),
      );
}

// ── График температур ──
class _ChartPainter extends CustomPainter {
  final List<double> nozzle, bed;
  final bool dark;
  _ChartPainter(this.nozzle, this.bed, this.dark);
  @override
  void paint(Canvas canvas, Size size) {
    final grid = Paint()
      ..color = dark ? Colors.white10 : Colors.black12
      ..strokeWidth = 1;
    for (var i = 0; i <= 4; i++) {
      final y = size.height * i / 4;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }
    const maxV = 260.0;
    void line(List<double> d, Color c) {
      if (d.length < 2) return;
      final p = Path();
      for (var i = 0; i < d.length; i++) {
        final x = size.width * i / (d.length - 1);
        final y = size.height - (d[i] / maxV).clamp(0.0, 1.0) * size.height;
        if (i == 0) {
          p.moveTo(x, y);
        } else {
          p.lineTo(x, y);
        }
      }
      canvas.drawPath(
          p,
          Paint()
            ..color = c
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.5
            ..strokeJoin = StrokeJoin.round);
    }

    line(bed, Palette.blue);
    line(nozzle, Palette.orange);
  }

  @override
  bool shouldRepaint(covariant _ChartPainter o) => true;
}

class TempChart extends StatelessWidget {
  final List<double> nozzle, bed;
  final double height;
  const TempChart({super.key, required this.nozzle, required this.bed, this.height = 110});
  @override
  Widget build(BuildContext context) => SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(painter: _ChartPainter(nozzle, bed, isDark(context))));
}

// ── Иконка катушки ──
class SpoolIcon extends StatelessWidget {
  final Color color;
  final double size;
  const SpoolIcon({super.key, required this.color, this.size = 56});
  @override
  Widget build(BuildContext context) {
    Widget circle(double f, Color c, {Color? border}) => Container(
        width: size * f,
        height: size * f,
        decoration: BoxDecoration(shape: BoxShape.circle, color: c, border: border == null ? null : Border.all(color: border, width: size * 0.02)));
    return SizedBox(
      width: size,
      height: size,
      child: Stack(alignment: Alignment.center, children: [
        circle(1.0, const Color(0xFF2A2F35), border: Colors.white24),
        circle(0.86, color),
        circle(0.62, Colors.black.withOpacity(0.12)),
        circle(0.42, const Color(0xFF2A2F35)),
        circle(0.16, const Color(0xFF0F1214)),
      ]),
    );
  }
}

class GradientThumb extends StatelessWidget {
  final Color c1, c2;
  final IconData icon;
  final double iconSize;
  final BorderRadius radius;
  const GradientThumb({super.key, required this.c1, required this.c2, required this.icon, this.iconSize = 56, this.radius = BorderRadius.zero});
  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
            borderRadius: radius,
            gradient: LinearGradient(colors: [c1, c2], begin: Alignment.topLeft, end: Alignment.bottomRight)),
        child: Center(child: Icon(icon, size: iconSize, color: Colors.white.withOpacity(0.9))),
      );
}

class PlatePainter extends CustomPainter {
  final bool dark;
  PlatePainter(this.dark);
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = dark ? Colors.white12 : Colors.black12
      ..strokeWidth = 1;
    const n = 10;
    for (var i = 0; i <= n; i++) {
      final x = size.width * i / n;
      final y = size.height * i / n;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), p);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), p);
    }
  }

  @override
  bool shouldRepaint(covariant PlatePainter o) => false;
}
