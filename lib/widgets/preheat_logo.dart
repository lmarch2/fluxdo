import 'package:flutter/material.dart';

import '../providers/app_icon_provider.dart';

/// 启动页"绘制 logo"动画组件
///
/// 入场时用主题色细线沿轮廓逐段描出 logo,随后各色块依次淡入、
/// 描边线淡出,终态与 assets 中的 SVG 完全一致(直接用 CustomPainter
/// 复刻几何,无需切换回 SVG)。绘制完成后保持光晕缓慢呼吸。
class PreheatLogo extends StatefulWidget {
  final AppIconStyle style;
  final double size;

  const PreheatLogo({super.key, required this.style, this.size = 108});

  @override
  State<PreheatLogo> createState() => _PreheatLogoState();
}

class _PreheatLogoState extends State<PreheatLogo>
    with TickerProviderStateMixin {
  late final AnimationController _entry = AnimationController(
    duration: const Duration(milliseconds: 2200),
    vsync: this,
  );
  late final AnimationController _glow = AnimationController(
    duration: const Duration(milliseconds: 2400),
    vsync: this,
  );

  List<_LogoShape> _shapes = const [];
  Brightness? _brightness;

  @override
  void initState() {
    super.initState();
    _entry
      ..addStatusListener((status) {
        // 绘制完成后才开始光晕呼吸
        if (status == AnimationStatus.completed) {
          _glow.repeat(reverse: true);
        }
      })
      ..forward();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final brightness = Theme.of(context).brightness;
    if (_brightness != brightness) {
      _brightness = brightness;
      _rebuildShapes();
    }
  }

  @override
  void didUpdateWidget(covariant PreheatLogo oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.style != widget.style) {
      _rebuildShapes();
    }
  }

  void _rebuildShapes() {
    _shapes = widget.style == AppIconStyle.modern
        ? _buildModernShapes()
        : _buildClassicShapes();
  }

  @override
  void dispose() {
    _entry.dispose();
    _glow.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    const viewSize = 1024.0;

    return AnimatedBuilder(
      animation: Listenable.merge([_entry, _glow]),
      builder: (context, _) {
        // 光晕随填充出现而渐亮,之后跟随 _glow 缓慢呼吸
        final glowIn = _segment(_entry.value, 0.45, 1.0, Curves.easeIn);
        final breathe = Curves.easeInOutSine.transform(_glow.value);
        final glowAlpha = glowIn * (0.12 + 0.10 * breathe);
        final glowBlur = 36.0 + 16.0 * breathe;

        return Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: colorScheme.primary.withValues(alpha: glowAlpha),
                blurRadius: glowBlur,
              ),
            ],
          ),
          child: RepaintBoundary(
            child: CustomPaint(
              size: Size.square(widget.size),
              painter: _LogoPainter(
                shapes: _shapes,
                t: _entry.value,
                strokeColor: colorScheme.primary,
                viewSize: viewSize,
              ),
            ),
          ),
        );
      },
    );
  }
}

/// 将整体进度 [t] 映射到 [start, end] 区间内的局部进度并应用曲线
double _segment(double t, double start, double end,
    [Curve curve = Curves.easeInOutCubic]) {
  return curve.transform(((t - start) / (end - start)).clamp(0.0, 1.0));
}

/// logo 的一个组成形状:填充路径 + 可选的描边路径与裁剪
class _LogoShape {
  final Path fillPath;
  final Color fill;

  /// 描边动画走的路径,可与填充轮廓不同(如经典 logo 用分界弦线)
  final Path? strokePath;

  /// 填充时的裁剪范围(经典 logo 三条色带裁剪在内圆中)
  final Path? clip;

  final double strokeStart;
  final double strokeEnd;
  final double fillStart;
  final double fillEnd;

  const _LogoShape({
    required this.fillPath,
    required this.fill,
    this.strokePath,
    this.clip,
    this.strokeStart = 0,
    this.strokeEnd = 1,
    required this.fillStart,
    required this.fillEnd,
  });
}

class _LogoPainter extends CustomPainter {
  final List<_LogoShape> shapes;
  final double t;
  final Color strokeColor;

  /// viewBox 边长,绘制时统一缩放到组件尺寸
  final double viewSize;

  /// 描边线在该进度后整体淡出
  static const double _strokeFadeStart = 0.84;

  const _LogoPainter({
    required this.shapes,
    required this.t,
    required this.strokeColor,
    required this.viewSize,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.shortestSide / viewSize;
    canvas.save();
    canvas.scale(scale);

    for (final shape in shapes) {
      final fillT = _segment(t, shape.fillStart, shape.fillEnd, Curves.easeInOut);
      if (fillT <= 0) continue;
      canvas.save();
      if (shape.clip != null) {
        canvas.clipPath(shape.clip!);
      }
      canvas.drawPath(
        shape.fillPath,
        Paint()..color = shape.fill.withValues(alpha: fillT),
      );
      canvas.restore();
    }

    final strokeAlpha = 1.0 - _segment(t, _strokeFadeStart, 1.0, Curves.easeOut);
    if (strokeAlpha > 0) {
      final strokePaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5 / scale
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = strokeColor.withValues(alpha: strokeAlpha);
      for (final shape in shapes) {
        final strokePath = shape.strokePath;
        if (strokePath == null) continue;
        final strokeT =
            _segment(t, shape.strokeStart, shape.strokeEnd, Curves.easeInOutCubic);
        if (strokeT <= 0) continue;
        for (final metric in strokePath.computeMetrics()) {
          canvas.drawPath(
            metric.extractPath(0, metric.length * strokeT),
            strokePaint,
          );
        }
      }
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _LogoPainter oldDelegate) {
    return oldDelegate.t != t ||
        oldDelegate.shapes != shapes ||
        oldDelegate.strokeColor != strokeColor;
  }
}

/// IDC Flare 标志：品牌红圆、IF 字标与六边形句点。
List<_LogoShape> _buildClassicShapes() {
  const center = Offset(512, 512);
  final circle = Path()
    ..addOval(Rect.fromCircle(center: center, radius: 480));
  final letters = Path()
    ..addRect(const Rect.fromLTWH(214, 274, 142, 476))
    ..addRect(const Rect.fromLTWH(455, 274, 142, 476))
    ..addRect(const Rect.fromLTWH(455, 274, 345, 103))
    ..addRect(const Rect.fromLTWH(455, 431, 314, 101));
  final dot = Path()
    ..moveTo(750, 635)
    ..lineTo(800, 664)
    ..lineTo(800, 722)
    ..lineTo(750, 751)
    ..lineTo(700, 722)
    ..lineTo(700, 664)
    ..close();

  return [
    _LogoShape(
      fillPath: circle,
      fill: const Color(0xFFB1161A),
      strokePath: circle,
      strokeStart: 0.0,
      strokeEnd: 0.45,
      fillStart: 0.45,
      fillEnd: 0.68,
    ),
    _LogoShape(
      fillPath: letters,
      fill: Colors.white,
      strokePath: letters,
      strokeStart: 0.20,
      strokeEnd: 0.56,
      fillStart: 0.56,
      fillEnd: 0.80,
    ),
    _LogoShape(
      fillPath: dot,
      fill: Colors.white,
      strokePath: dot,
      strokeStart: 0.42,
      strokeEnd: 0.68,
      fillStart: 0.66,
      fillEnd: 0.86,
    ),
  ];
}

List<_LogoShape> _buildModernShapes() => _buildClassicShapes();
