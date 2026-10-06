import 'package:flutter/material.dart';

/// Nutriq's logo palette. The fruit mark is also used to render launcher icons.
abstract final class NutriqBrand {
  static const sage = Color(0xFF8BD8A0);
  static const graphite = Color(0xFF0F1012);
  static const amber = Color(0xFFF0B357);
  static const cream = Color(0xFFFFF5E9);
  static const orange = Color(0xFFFF9B2F);
}

/// Nutriq's fruit-and-camera mark.
///
/// The icon keeps the original warm fruit artwork: a soft apple silhouette,
/// detached leaf, and the overlapping camera shape on its lower-right side.
class NutriqMark extends StatelessWidget {
  const NutriqMark({super.key, this.size = 72, this.withBackground = false, this.color = NutriqBrand.sage});

  final double size;
  final bool withBackground;

  /// Fruit and leaf fill. The camera detail keeps the brand's warm gradient.
  final Color color;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: CustomPaint(
      painter: NutriqMarkPainter(withBackground: withBackground, color: color),
    ),
  );
}

class NutriqMarkPainter extends CustomPainter {
  const NutriqMarkPainter({this.withBackground = false, this.color = NutriqBrand.sage});

  final bool withBackground;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final unit = size.shortestSide;
    final left = (size.width - unit) / 2;
    final top = (size.height - unit) / 2;
    final rect = Rect.fromLTWH(left, top, unit, unit);

    if (withBackground) {
      canvas.drawRect(
        rect,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment(-0.78, -1),
            end: Alignment(0.68, 1),
            colors: [Color(0xFFFFCE55), Color(0xFFFFA12B), Color(0xFFFF5A20)],
            stops: [0, 0.53, 1],
          ).createShader(rect),
      );
    }

    Offset p(double x, double y) => Offset(left + unit * x, top + unit * y);

    _drawScanCorners(canvas, p, unit);

    final fruit = Path()
      ..moveTo(p(.487, .407).dx, p(.487, .407).dy)
      ..cubicTo(
        p(.460, .390).dx,
        p(.460, .390).dy,
        p(.472, .346).dx,
        p(.472, .346).dy,
        p(.430, .327).dx,
        p(.430, .327).dy,
      )
      ..cubicTo(
        p(.384, .306).dx,
        p(.384, .306).dy,
        p(.337, .316).dx,
        p(.337, .316).dy,
        p(.300, .345).dx,
        p(.300, .345).dy,
      )
      ..cubicTo(
        p(.248, .385).dx,
        p(.248, .385).dy,
        p(.218, .450).dx,
        p(.218, .450).dy,
        p(.211, .526).dx,
        p(.211, .526).dy,
      )
      ..cubicTo(
        p(.199, .652).dx,
        p(.199, .652).dy,
        p(.258, .759).dx,
        p(.258, .759).dy,
        p(.359, .804).dx,
        p(.359, .804).dy,
      )
      ..cubicTo(
        p(.420, .835).dx,
        p(.420, .835).dy,
        p(.650, .835).dx,
        p(.650, .835).dy,
        p(.715, .756).dx,
        p(.715, .756).dy,
      )
      ..cubicTo(
        p(.762, .707).dx,
        p(.762, .707).dy,
        p(.789, .634).dx,
        p(.789, .634).dy,
        p(.780, .559).dx,
        p(.780, .559).dy,
      )
      ..cubicTo(
        p(.773, .487).dx,
        p(.773, .487).dy,
        p(.739, .423).dx,
        p(.739, .423).dy,
        p(.680, .395).dx,
        p(.680, .395).dy,
      )
      ..cubicTo(
        p(.631, .372).dx,
        p(.631, .372).dy,
        p(.583, .383).dx,
        p(.583, .383).dy,
        p(.539, .400).dx,
        p(.539, .400).dy,
      )
      ..cubicTo(
        p(.519, .407).dx,
        p(.519, .407).dy,
        p(.502, .410).dx,
        p(.502, .410).dy,
        p(.487, .407).dx,
        p(.487, .407).dy,
      )
      ..close();

    final leaf = Path()
      ..moveTo(p(.510, .353).dx, p(.510, .353).dy)
      ..cubicTo(
        p(.511, .288).dx,
        p(.511, .288).dy,
        p(.583, .199).dx,
        p(.583, .199).dy,
        p(.699, .163).dx,
        p(.699, .163).dy,
      )
      ..cubicTo(
        p(.731, .153).dx,
        p(.731, .153).dy,
        p(.752, .153).dx,
        p(.752, .153).dy,
        p(.752, .174).dx,
        p(.752, .174).dy,
      )
      ..cubicTo(
        p(.751, .264).dx,
        p(.751, .264).dy,
        p(.688, .337).dx,
        p(.688, .337).dy,
        p(.568, .374).dx,
        p(.568, .374).dy,
      )
      ..cubicTo(
        p(.535, .384).dx,
        p(.535, .384).dy,
        p(.510, .376).dx,
        p(.510, .376).dy,
        p(.510, .353).dx,
        p(.510, .353).dy,
      )
      ..close();

    final camera = Path()
      ..moveTo(p(.404, .568).dx, p(.404, .568).dy)
      ..cubicTo(
        p(.492, .560).dx,
        p(.492, .560).dy,
        p(.602, .538).dx,
        p(.602, .538).dy,
        p(.687, .519).dx,
        p(.687, .519).dy,
      )
      ..cubicTo(
        p(.744, .507).dx,
        p(.744, .507).dy,
        p(.783, .533).dx,
        p(.783, .533).dy,
        p(.785, .590).dx,
        p(.785, .590).dy,
      )
      ..cubicTo(
        p(.790, .663).dx,
        p(.790, .663).dy,
        p(.749, .718).dx,
        p(.749, .718).dy,
        p(.684, .749).dx,
        p(.684, .749).dy,
      )
      ..cubicTo(
        p(.615, .780).dx,
        p(.615, .780).dy,
        p(.545, .758).dx,
        p(.545, .758).dy,
        p(.486, .721).dx,
        p(.486, .721).dy,
      )
      ..cubicTo(
        p(.431, .686).dx,
        p(.431, .686).dy,
        p(.393, .632).dx,
        p(.393, .632).dy,
        p(.393, .594).dx,
        p(.393, .594).dy,
      )
      ..cubicTo(
        p(.393, .577).dx,
        p(.393, .577).dy,
        p(.397, .570).dx,
        p(.397, .570).dy,
        p(.404, .568).dx,
        p(.404, .568).dy,
      )
      ..close();

    final fruitRect = fruit.getBounds();
    final fruitFill = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color.lerp(color, Colors.white, .08)!, color, Color.lerp(color, const Color(0xFFFFE7D2), .05)!],
        stops: const [0, .56, 1],
      ).createShader(fruitRect);
    canvas.drawPath(fruit, fruitFill);
    canvas.drawPath(leaf, Paint()..color = color);

    canvas.drawPath(
      camera,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFFC94C), Color(0xFFFF8C25), Color(0xFFF3481D)],
          stops: [0, .48, 1],
        ).createShader(camera.getBounds()),
    );
  }

  @override
  bool shouldRepaint(NutriqMarkPainter old) => old.withBackground != withBackground || old.color != color;
}

void _drawScanCorners(Canvas canvas, Offset Function(double, double) point, double unit) {
  const inset = .13;
  const far = 1 - inset;
  const leg = .105;
  final inner = inset + leg;
  final innerFar = far - leg;
  final corners = Path()
    ..moveTo(point(inset, inner).dx, point(inset, inner).dy)
    ..lineTo(point(inset, inset).dx, point(inset, inset).dy)
    ..lineTo(point(inner, inset).dx, point(inner, inset).dy)
    ..moveTo(point(innerFar, inset).dx, point(innerFar, inset).dy)
    ..lineTo(point(far, inset).dx, point(far, inset).dy)
    ..lineTo(point(far, inner).dx, point(far, inner).dy)
    ..moveTo(point(inset, innerFar).dx, point(inset, innerFar).dy)
    ..lineTo(point(inset, far).dx, point(inset, far).dy)
    ..lineTo(point(inner, far).dx, point(inner, far).dy)
    ..moveTo(point(innerFar, far).dx, point(innerFar, far).dy)
    ..lineTo(point(far, far).dx, point(far, far).dy)
    ..lineTo(point(far, innerFar).dx, point(far, innerFar).dy);

  canvas.drawPath(
    corners,
    Paint()
      ..color = const Color(0x738A3F23)
      ..style = PaintingStyle.stroke
      ..strokeWidth = unit * .011
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round,
  );
}

/// Which parts of the launcher icon to draw.
enum NutriqIconLayer {
  /// Full-bleed square: gradient plus artwork (iOS and legacy Android icons).
  full,

  /// Gradient only (Android adaptive background).
  background,

  /// Artwork only on transparent (Android adaptive foreground).
  foreground,
}

/// The Nutriq launcher icon: a yellow-to-red gradient, four bold cream scan
/// corners, and the cream fruit with its leaf and the camera shape cut into
/// its lower right.
///
/// The geometry is measured from the reference artwork
/// (`ChatGPT Image Oct 6, 2026, 11_56_27 PM.png`). Outlines are closed cubic
/// B-splines fitted to the reference by least squares: smooth, and within
/// about 3 px of it at 1254 px (0.2 %). The four corners share one shape, mirrored, so
/// they're exactly symmetric. Everything is in fractions of the icon's side,
/// so it renders crisply at any size.
class NutriqAppIconPainter extends CustomPainter {
  const NutriqAppIconPainter({this.layer = NutriqIconLayer.full, this.artworkScale = 1, this.gradientScale = 1});

  final NutriqIconLayer layer;

  /// Shrinks the artwork about the centre, e.g. to keep it inside Android's
  /// adaptive-icon safe zone.
  final double artworkScale;

  /// Compresses the gradient toward the centre, e.g. so an Android adaptive
  /// background (whose outer third is masked away) still shows the full
  /// yellow-to-red range.
  final double gradientScale;

  static const cream = Color(0xFFFDFAF5);
  static const gradient = [Color(0xFFFDD726), Color(0xFFFC8D1C), Color(0xFFFA4423)];
  static const cameraGradient = [Color(0xFFFCCD27), Color(0xFFFC891A), Color(0xFFF83B20)];

  @override
  void paint(Canvas canvas, Size size) {
    final unit = size.shortestSide;
    final origin = Offset((size.width - unit) / 2, (size.height - unit) / 2);
    final square = origin & Size.square(unit);

    if (layer != NutriqIconLayer.foreground) {
      // Measured: colour is constant along lines perpendicular to a ~43° axis
      // from the top-left corner to the bottom-right corner.
      canvas.drawRect(
        square,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment(-1.030 * gradientScale, -0.968 * gradientScale),
            end: Alignment(1.030 * gradientScale, 0.968 * gradientScale),
            colors: gradient,
          ).createShader(square),
      );
    }
    if (layer == NutriqIconLayer.background) return;

    canvas.save();
    canvas.translate(origin.dx + unit / 2, origin.dy + unit / 2);
    canvas.scale(artworkScale);
    canvas.translate(-unit / 2, -unit / 2);
    Offset at((double, double) p) => Offset(p.$1 * unit, p.$2 * unit);

    canvas.drawPath(
      _scanCorners(unit),
      Paint()
        ..color = cream
        ..style = PaintingStyle.stroke
        ..strokeWidth = _Frame.stroke * unit
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    final fill = Paint()..color = cream;
    canvas.drawPath(_bSplinePath(_fruit.map(at).toList()), fill);
    canvas.drawPath(_bSplinePath(_leaf.map(at).toList()), fill);

    final camera = _bSplinePath(_camera.map(at).toList());
    canvas.drawPath(
      camera,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: cameraGradient,
          stops: [0, .42, 1],
        ).createShader(camera.getBounds()),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(NutriqAppIconPainter old) =>
      old.layer != layer || old.artworkScale != artworkScale || old.gradientScale != gradientScale;
}

/// Scan-corner geometry (stroke centre line), as fractions of the icon side.
abstract final class _Frame {
  static const stroke = 0.0312;
  static const insetX = 0.1600;
  static const insetTop = 0.1482;
  static const insetBottom = 0.1568;
  static const radius = 0.0908;

  /// Where the horizontal arm ends, measured from the near edge.
  static const armX = 0.3631;

  /// Length of the vertical arm from the horizontal stroke.
  static const armY = 0.1737;
}

/// Four identical rounded corners, mirrored into place.
Path _scanCorners(double unit) {
  final path = Path();
  for (final (sx, sy) in const [(1.0, 1.0), (-1.0, 1.0), (1.0, -1.0), (-1.0, -1.0)]) {
    final x0 = sx > 0 ? _Frame.insetX : 1 - _Frame.insetX;
    final y0 = sy > 0 ? _Frame.insetTop : 1 - _Frame.insetBottom;
    final xEnd = sx > 0 ? _Frame.armX : 1 - _Frame.armX;
    Offset q(double x, double y) => Offset(x * unit, y * unit);
    path
      ..moveTo(q(x0, y0 + sy * _Frame.armY).dx, q(x0, y0 + sy * _Frame.armY).dy)
      ..lineTo(q(x0, y0 + sy * _Frame.radius).dx, q(x0, y0 + sy * _Frame.radius).dy)
      ..arcToPoint(
        q(x0 + sx * _Frame.radius, y0),
        radius: Radius.circular(_Frame.radius * unit),
        clockwise: sx * sy > 0,
      )
      ..lineTo(q(xEnd, y0).dx, q(xEnd, y0).dy);
  }
  return path;
}

/// Closed uniform cubic B-spline with control points [q], drawn as cubic
/// Béziers. B-splines are curvature-continuous, so outlines stay smooth (no
/// wobble) while following the fitted shape.
Path _bSplinePath(List<Offset> q) {
  final n = q.length;
  Offset at(int i) => q[(i % n + n) % n];
  Offset start(int i) => (at(i - 1) + at(i) * 4 + at(i + 1)) / 6;
  final first = start(0);
  final path = Path()..moveTo(first.dx, first.dy);
  for (var i = 0; i < n; i++) {
    final c1 = (at(i) * 2 + at(i + 1)) / 3;
    final c2 = (at(i) + at(i + 1) * 2) / 3;
    final end = start(i + 1);
    path.cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, end.dx, end.dy);
  }
  return path..close();
}

// B-spline control points fitted (least squares) to the reference outlines,
// as fractions of the icon side.
const _fruit = <(double, double)>[
  (0.4054, 0.3300),
  (0.3788, 0.3374),
  (0.3550, 0.3511),
  (0.3339, 0.3699),
  (0.3166, 0.3921),
  (0.3032, 0.4158),
  (0.2935, 0.4407),
  (0.2871, 0.4671),
  (0.2841, 0.4952),
  (0.2851, 0.5239),
  (0.2893, 0.5515),
  (0.2959, 0.5777),
  (0.3051, 0.6029),
  (0.3171, 0.6270),
  (0.3325, 0.6499),
  (0.3513, 0.6711),
  (0.3730, 0.6892),
  (0.3963, 0.7033),
  (0.4210, 0.7136),
  (0.4476, 0.7197),
  (0.4758, 0.7222),
  (0.5044, 0.7223),
  (0.5324, 0.7197),
  (0.5593, 0.7143),
  (0.5849, 0.7059),
  (0.6091, 0.6945),
  (0.6321, 0.6797),
  (0.6536, 0.6609),
  (0.6722, 0.6393),
  (0.6868, 0.6161),
  (0.6979, 0.5918),
  (0.7059, 0.5661),
  (0.7106, 0.5386),
  (0.7106, 0.5102),
  (0.7061, 0.4827),
  (0.6989, 0.4567),
  (0.6880, 0.4319),
  (0.6716, 0.4092),
  (0.6502, 0.3909),
  (0.6257, 0.3789),
  (0.5986, 0.3731),
  (0.5705, 0.3726),
  (0.5429, 0.3777),
  (0.5156, 0.3892),
  (0.4907, 0.3899),
  (0.4756, 0.3663),
  (0.4593, 0.3419),
  (0.4340, 0.3306),
];

const _leaf = <(double, double)>[
  (0.6285, 0.2354),
  (0.6084, 0.2396),
  (0.5906, 0.2448),
  (0.5741, 0.2516),
  (0.5582, 0.2603),
  (0.5428, 0.2709),
  (0.5284, 0.2836),
  (0.5164, 0.2983),
  (0.5070, 0.3139),
  (0.5003, 0.3309),
  (0.4955, 0.3506),
  (0.4992, 0.3684),
  (0.5166, 0.3734),
  (0.5370, 0.3701),
  (0.5548, 0.3649),
  (0.5711, 0.3578),
  (0.5870, 0.3489),
  (0.6022, 0.3378),
  (0.6162, 0.3244),
  (0.6281, 0.3096),
  (0.6375, 0.2942),
  (0.6448, 0.2774),
  (0.6499, 0.2575),
  (0.6460, 0.2397),
];

const _camera = <(double, double)>[
  (0.6155, 0.4650),
  (0.6401, 0.4641),
  (0.6639, 0.4683),
  (0.6826, 0.4817),
  (0.6930, 0.5030),
  (0.6964, 0.5271),
  (0.6945, 0.5512),
  (0.6882, 0.5734),
  (0.6780, 0.5939),
  (0.6633, 0.6130),
  (0.6452, 0.6291),
  (0.6252, 0.6410),
  (0.6037, 0.6489),
  (0.5807, 0.6532),
  (0.5565, 0.6531),
  (0.5331, 0.6492),
  (0.5113, 0.6422),
  (0.4910, 0.6321),
  (0.4714, 0.6187),
  (0.4535, 0.6023),
  (0.4386, 0.5839),
  (0.4261, 0.5642),
  (0.4157, 0.5417),
  (0.4148, 0.5184),
  (0.4326, 0.5055),
  (0.4573, 0.5009),
  (0.4801, 0.4956),
  (0.5021, 0.4900),
  (0.5246, 0.4844),
  (0.5470, 0.4790),
  (0.5695, 0.4735),
  (0.5921, 0.4685),
];
