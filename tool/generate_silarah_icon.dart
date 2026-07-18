import 'dart:io';
import 'dart:math' as math;

import 'package:image/image.dart' as img;

const _size = 2048;

void main() {
  final canvas = img.Image(width: _size, height: _size, numChannels: 4);
  const center = _size / 2;
  final maxDistance = math.sqrt(2) * center;

  for (var y = 0; y < _size; y++) {
    for (var x = 0; x < _size; x++) {
      final distance = math.sqrt(
        math.pow(x - center, 2) + math.pow(y - center, 2),
      );
      final vignette = (1 - distance / maxDistance).clamp(0.0, 1.0);
      final warmth = math.exp(-distance * distance / 620000) * 10;
      canvas.setPixelRgba(
        x,
        y,
        7 + (vignette * 5 + warmth).round(),
        8 + (vignette * 5 + warmth * .72).round(),
        13 + (vignette * 7 + warmth * .3).round(),
        255,
      );
    }
  }

  _roundedBorder(canvas, inset: 92, radius: 215, thickness: 18);

  final path = <math.Point<double>>[];
  _cubic(
    path,
    const math.Point(1435, 500),
    const math.Point(1080, 245),
    const math.Point(575, 430),
    const math.Point(675, 790),
  );
  _cubic(
    path,
    const math.Point(675, 790),
    const math.Point(760, 1080),
    const math.Point(1420, 970),
    const math.Point(1380, 1325),
  );
  _cubic(
    path,
    const math.Point(1380, 1325),
    const math.Point(1335, 1695),
    const math.Point(790, 1815),
    const math.Point(565, 1510),
  );

  _stroke(canvas, path, 255, img.ColorRgba8(57, 34, 9, 210));
  _stroke(canvas, path, 222, img.ColorRgb8(151, 94, 24));
  _stroke(canvas, path, 184, img.ColorRgb8(224, 168, 68));
  _stroke(canvas, path, 140, img.ColorRgb8(249, 207, 112));

  final highlight =
      path.map((point) => math.Point(point.x - 18, point.y - 16)).toList();
  _stroke(canvas, highlight, 34, img.ColorRgba8(255, 241, 185, 185));

  for (final endpoint in [path.first, path.last]) {
    img.fillCircle(
      canvas,
      x: endpoint.x.round(),
      y: endpoint.y.round(),
      radius: 92,
      color: img.ColorRgb8(246, 202, 103),
      antialias: true,
    );
    img.fillCircle(
      canvas,
      x: endpoint.x.round() - 18,
      y: endpoint.y.round() - 18,
      radius: 27,
      color: img.ColorRgba8(255, 244, 197, 210),
      antialias: true,
    );
  }

  final output = img.copyResize(
    canvas,
    width: 1024,
    height: 1024,
    interpolation: img.Interpolation.cubic,
  );
  File('assets/icon/app_icon.png').writeAsBytesSync(img.encodePng(output));
}

void _cubic(
  List<math.Point<double>> output,
  math.Point<double> p0,
  math.Point<double> p1,
  math.Point<double> p2,
  math.Point<double> p3,
) {
  for (var i = 0; i <= 90; i++) {
    final t = i / 90;
    final mt = 1 - t;
    output.add(math.Point(
      mt * mt * mt * p0.x +
          3 * mt * mt * t * p1.x +
          3 * mt * t * t * p2.x +
          t * t * t * p3.x,
      mt * mt * mt * p0.y +
          3 * mt * mt * t * p1.y +
          3 * mt * t * t * p2.y +
          t * t * t * p3.y,
    ));
  }
}

void _stroke(
  img.Image canvas,
  List<math.Point<double>> points,
  num thickness,
  img.Color color,
) {
  final radius = (thickness / 2).round();
  for (final point in points) {
    img.fillCircle(
      canvas,
      x: point.x.round(),
      y: point.y.round(),
      radius: radius,
      color: color,
      antialias: true,
    );
  }
}

void _roundedBorder(
  img.Image canvas, {
  required int inset,
  required int radius,
  required num thickness,
}) {
  final color = img.ColorRgb8(225, 171, 75);
  final left = inset;
  final top = inset;
  final right = _size - inset;
  final bottom = _size - inset;
  img.drawLine(canvas,
      x1: left + radius,
      y1: top,
      x2: right - radius,
      y2: top,
      color: color,
      thickness: thickness,
      antialias: true);
  img.drawLine(canvas,
      x1: left + radius,
      y1: bottom,
      x2: right - radius,
      y2: bottom,
      color: color,
      thickness: thickness,
      antialias: true);
  img.drawLine(canvas,
      x1: left,
      y1: top + radius,
      x2: left,
      y2: bottom - radius,
      color: color,
      thickness: thickness,
      antialias: true);
  img.drawLine(canvas,
      x1: right,
      y1: top + radius,
      x2: right,
      y2: bottom - radius,
      color: color,
      thickness: thickness,
      antialias: true);

  for (var degree = 0; degree <= 90; degree++) {
    final angle = degree * math.pi / 180;
    final dx = (math.cos(angle) * radius).round();
    final dy = (math.sin(angle) * radius).round();
    for (final point in [
      math.Point(right - radius + dx, top + radius - dy),
      math.Point(left + radius - dx, top + radius - dy),
      math.Point(right - radius + dx, bottom - radius + dy),
      math.Point(left + radius - dx, bottom - radius + dy),
    ]) {
      img.fillCircle(canvas,
          x: point.x,
          y: point.y,
          radius: (thickness / 2).round(),
          color: color,
          antialias: true);
    }
  }
}
