import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

/// Material 3 Expressive motion springs. Damping here is the damping
/// *ratio*; [SpringDescription.withDampingRatio] converts it to the
/// absolute damping coefficient these physics simulations expect.
abstract final class AcatrainSprings {
  static final spatialFast =
      SpringDescription.withDampingRatio(mass: 1, stiffness: 800, ratio: 0.6);
  static final spatialDefault =
      SpringDescription.withDampingRatio(mass: 1, stiffness: 380, ratio: 0.8);
  static final spatialSlow =
      SpringDescription.withDampingRatio(mass: 1, stiffness: 200, ratio: 0.8);
  static final effectsDefault = SpringDescription.withDampingRatio(
      mass: 1, stiffness: 1600, ratio: 1.0);
}

/// Runs a single spring simulation from [begin] to [end] once, on mount.
/// When [disabled] (reduce-motion), the end value applies immediately.
class AcatrainSpringIn extends StatefulWidget {
  const AcatrainSpringIn({
    super.key,
    required this.builder,
    this.spring,
    this.begin = 0.0,
    this.end = 1.0,
    this.disabled = false,
  });

  final Widget Function(BuildContext context, double value) builder;
  final SpringDescription? spring;
  final double begin;
  final double end;
  final bool disabled;

  @override
  State<AcatrainSpringIn> createState() => _AcatrainSpringInState();
}

class _AcatrainSpringInState extends State<AcatrainSpringIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController.unbounded(
      vsync: this,
      value: widget.disabled ? 1 : 0,
    );
    if (!widget.disabled) {
      _controller.animateWith(
        SpringSimulation(
          widget.spring ?? AcatrainSprings.spatialDefault,
          0,
          1,
          0,
        ),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _controller,
        builder: (context, _) => widget.builder(
          context,
          ui.lerpDouble(widget.begin, widget.end, _controller.value)!,
        ),
      );
}

/// Material 3 Expressive "cookie"/"flower" polar shapes.
enum ExpressiveShape { cookie9, cookie12, clover4, flower6, sunny }

extension on ExpressiveShape {
  (int n, double a) get _params => switch (this) {
        ExpressiveShape.cookie9 => (9, 0.075),
        ExpressiveShape.cookie12 => (12, 0.05),
        ExpressiveShape.clover4 => (4, 0.16),
        ExpressiveShape.flower6 => (6, 0.13),
        ExpressiveShape.sunny => (8, 0.045),
      };
}

const _expressiveShapeSamples = 240;

Path buildExpressiveShapePath(ExpressiveShape shape, Rect rect) {
  final (n, a) = shape._params;
  final center = rect.center;
  final radius = math.min(rect.width, rect.height) / 2;
  final path = Path();
  for (var i = 0; i <= _expressiveShapeSamples; i++) {
    final theta = 2 * math.pi * i / _expressiveShapeSamples;
    final r = radius * (1 + a * math.cos(n * theta)) / (1 + a);
    final angle = theta - math.pi / 2;
    final point = Offset(
      center.dx + r * math.cos(angle),
      center.dy + r * math.sin(angle),
    );
    if (i == 0) {
      path.moveTo(point.dx, point.dy);
    } else {
      path.lineTo(point.dx, point.dy);
    }
  }
  path.close();
  return path;
}

/// A shape-filled box with a centred child, used for the logo, subject
/// avatars, metric icon plates and the hero/complete-screen counts.
class ExpressiveBadge extends StatelessWidget {
  const ExpressiveBadge({
    super.key,
    required this.shape,
    required this.size,
    required this.color,
    this.child,
  });

  final ExpressiveShape shape;
  final double size;
  final Color color;
  final Widget? child;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: size,
        height: size,
        child: CustomPaint(
          painter: _ExpressiveShapePainter(shape: shape, color: color),
          child: child == null ? null : Center(child: child),
        ),
      );
}

class _ExpressiveShapePainter extends CustomPainter {
  _ExpressiveShapePainter({required this.shape, required this.color});
  final ExpressiveShape shape;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final path = buildExpressiveShapePath(shape, Offset.zero & size);
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _ExpressiveShapePainter oldDelegate) =>
      oldDelegate.shape != shape || oldDelegate.color != color;
}

/// Maps a study set's subject to an expressive shape, colour pair and icon,
/// with a deterministic fallback for subjects the design doesn't name.
class SubjectStyle {
  const SubjectStyle({
    required this.shape,
    required this.fill,
    required this.onFill,
    required this.container,
    required this.onContainer,
    required this.icon,
  });

  final ExpressiveShape shape;
  final Color fill;
  final Color onFill;
  final Color container;
  final Color onContainer;
  final IconData icon;

  static SubjectStyle of(BuildContext context, String subject) {
    final colors = Theme.of(context).colorScheme;
    switch (subject) {
      case 'Economics':
        return SubjectStyle(
          shape: ExpressiveShape.cookie9,
          fill: colors.primary,
          onFill: colors.onPrimary,
          container: colors.primaryContainer,
          onContainer: colors.onPrimaryContainer,
          icon: Icons.storefront_rounded,
        );
      case 'Mathematics':
        return SubjectStyle(
          shape: ExpressiveShape.clover4,
          fill: colors.tertiary,
          onFill: colors.onTertiary,
          container: colors.tertiaryContainer,
          onContainer: colors.onTertiaryContainer,
          icon: Icons.functions_rounded,
        );
      case 'English':
        return SubjectStyle(
          shape: ExpressiveShape.flower6,
          fill: colors.secondary,
          onFill: colors.onSecondary,
          container: colors.secondaryContainer,
          onContainer: colors.onSecondaryContainer,
          icon: Icons.translate_rounded,
        );
      default:
        const shapes = [
          ExpressiveShape.cookie9,
          ExpressiveShape.clover4,
          ExpressiveShape.flower6,
          ExpressiveShape.sunny,
        ];
        final triples = [
          (colors.primary, colors.onPrimary, colors.primaryContainer, colors.onPrimaryContainer),
          (colors.tertiary, colors.onTertiary, colors.tertiaryContainer, colors.onTertiaryContainer),
          (colors.secondary, colors.onSecondary, colors.secondaryContainer, colors.onSecondaryContainer),
        ];
        var hash = 0;
        for (final unit in subject.codeUnits) {
          hash = (hash * 31 + unit) & 0x7fffffff;
        }
        final shape = shapes[hash % shapes.length];
        final triple = triples[(hash ~/ shapes.length) % triples.length];
        return SubjectStyle(
          shape: shape,
          fill: triple.$1,
          onFill: triple.$2,
          container: triple.$3,
          onContainer: triple.$4,
          icon: Icons.bookmark_rounded,
        );
    }
  }
}

/// The wavy (sine) progress indicator used for session progress, the set
/// page's practice bar and library/desktop tile progress.
class WavyProgress extends StatefulWidget {
  const WavyProgress({
    super.key,
    required this.value,
    this.color,
    this.trackColor,
    this.height = 12,
    this.animate = false,
    this.semanticsLabel,
  });

  /// Progress in `[0, 1]`.
  final double value;
  final Color? color;
  final Color? trackColor;
  final double height;

  /// Lets the wave phase drift slowly, e.g. while a study session is open.
  final bool animate;
  final String? semanticsLabel;

  @override
  State<WavyProgress> createState() => _WavyProgressState();
}

class _WavyProgressState extends State<WavyProgress>
    with SingleTickerProviderStateMixin {
  late final AnimationController _phase;

  @override
  void initState() {
    super.initState();
    _phase = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    );
    if (widget.animate) _phase.repeat();
  }

  @override
  void dispose() {
    _phase.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    final active = widget.color ?? theme.colorScheme.primary;
    final track = widget.trackColor ?? theme.colorScheme.surfaceContainerHighest;
    final value = widget.value.clamp(0.0, 1.0);
    final drift = widget.animate && !reduceMotion;
    if (drift && !_phase.isAnimating) {
      _phase.repeat();
    } else if (!drift && _phase.isAnimating) {
      _phase.stop();
    }

    Widget paint(double phase) => CustomPaint(
          painter: _WavyProgressPainter(
            value: value,
            activeColor: active,
            trackColor: track,
            phase: phase,
          ),
        );

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth.isFinite ? constraints.maxWidth : 200.0;
        return Semantics(
          value: widget.semanticsLabel,
          child: SizedBox(
            width: width,
            height: widget.height,
            child: drift
                ? AnimatedBuilder(
                    animation: _phase,
                    builder: (context, _) => paint(_phase.value * 2 * math.pi),
                  )
                : paint(0),
          ),
        );
      },
    );
  }
}

class _WavyProgressPainter extends CustomPainter {
  _WavyProgressPainter({
    required this.value,
    required this.activeColor,
    required this.trackColor,
    required this.phase,
  });

  final double value;
  final double phase;
  final Color activeColor;
  final Color trackColor;

  static const _amplitude = 2.6;
  static const _wavelength = 20.0;
  static const _gap = 6.0;
  static const _strokeWidth = 4.0;

  @override
  void paint(Canvas canvas, Size size) {
    final midY = size.height / 2;
    final dotPaint = Paint()..color = activeColor;
    final trackPaint = Paint()
      ..color = trackColor
      ..strokeWidth = _strokeWidth
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    if (value <= 0 || size.width <= 0) {
      canvas.drawLine(Offset(0, midY), Offset(size.width, midY), trackPaint);
      canvas.drawCircle(Offset(size.width - 2, midY), 2, dotPaint);
      return;
    }

    final activeWidth = size.width * value;
    final activePaint = Paint()
      ..color = activeColor
      ..strokeWidth = _strokeWidth
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final activePath = Path();
    const step = 2.0;
    var started = false;
    for (var x = 0.0; x <= activeWidth; x += step) {
      final y = midY + _amplitude * math.sin((x / _wavelength) * 2 * math.pi + phase);
      if (!started) {
        activePath.moveTo(x, y);
        started = true;
      } else {
        activePath.lineTo(x, y);
      }
    }
    if (started) canvas.drawPath(activePath, activePaint);

    final trackStart = (activeWidth + _gap).clamp(0.0, size.width);
    if (trackStart < size.width) {
      canvas.drawLine(Offset(trackStart, midY), Offset(size.width, midY), trackPaint);
    }
    canvas.drawCircle(Offset(size.width - 2, midY), 2, dotPaint);
  }

  @override
  bool shouldRepaint(covariant _WavyProgressPainter oldDelegate) =>
      oldDelegate.value != value ||
      oldDelegate.activeColor != activeColor ||
      oldDelegate.trackColor != trackColor ||
      oldDelegate.phase != phase;
}

/// The flat 2-segment bar used in the Today list rows (96×4 by default).
class AcatrainFlatBar extends StatelessWidget {
  const AcatrainFlatBar({
    super.key,
    required this.value,
    this.color,
    this.trackColor,
    this.width = 96,
    this.height = 4,
  });

  final double value;
  final Color? color;
  final Color? trackColor;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final active = color ?? theme.colorScheme.primary;
    final track = trackColor ?? theme.colorScheme.surfaceContainerHighest;
    final v = value.clamp(0.0, 1.0);
    const gap = 3.0;
    final activeWidth = v <= 0 ? 0.0 : math.max(0.0, (width - gap) * v);
    final trackWidth = math.max(0.0, width - (activeWidth > 0 ? gap : 0) - activeWidth);
    return SizedBox(
      width: width,
      height: height,
      child: Row(
        children: [
          if (activeWidth > 0)
            Container(
              width: activeWidth,
              height: height,
              decoration: BoxDecoration(
                color: active,
                borderRadius: BorderRadius.circular(height),
              ),
            ),
          if (activeWidth > 0) SizedBox(width: gap),
          if (trackWidth > 0)
            Container(
              width: trackWidth,
              height: height,
              decoration: BoxDecoration(
                color: track,
                borderRadius: BorderRadius.circular(height),
              ),
            ),
        ],
      ),
    );
  }
}

/// Two extra tones the design pulls from `primaryContainer`, exposed as a
/// theme extension so screens never hard-code them.
@immutable
class AcatrainTones extends ThemeExtension<AcatrainTones> {
  const AcatrainTones({required this.heroAccent, required this.heroBody});

  /// Fills the hero's secondary action and the flashcard "Answer" chip.
  final Color heroAccent;

  /// The hero card's supporting text colour.
  final Color heroBody;

  static const light = AcatrainTones(
    heroAccent: Color(0xFF93D5AE),
    heroBody: Color(0xFF1E4A34),
  );

  static AcatrainTones dark(ColorScheme colors) => AcatrainTones(
        heroAccent: colors.primary,
        heroBody: colors.onPrimaryContainer,
      );

  @override
  AcatrainTones copyWith({Color? heroAccent, Color? heroBody}) => AcatrainTones(
        heroAccent: heroAccent ?? this.heroAccent,
        heroBody: heroBody ?? this.heroBody,
      );

  @override
  AcatrainTones lerp(ThemeExtension<AcatrainTones>? other, double t) {
    if (other is! AcatrainTones) return this;
    return AcatrainTones(
      heroAccent: Color.lerp(heroAccent, other.heroAccent, t)!,
      heroBody: Color.lerp(heroBody, other.heroBody, t)!,
    );
  }
}
