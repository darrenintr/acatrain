import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/scheduler.dart';

import 'expressive.dart';

/// Material 3 Expressive-style indeterminate loading indicator: a shape
/// that springs from one expressive shape to the next while it spins.
///
/// ```dart
/// const AcatrainLoadingIndicator()                 // 48dp, primary
/// const AcatrainLoadingIndicator(contained: true)  // on a primaryContainer disc
/// ```
///
/// With reduce-motion on, the shape holds still and gently pulses instead.
class AcatrainLoadingIndicator extends StatefulWidget {
  const AcatrainLoadingIndicator({
    super.key,
    this.size = 48,
    this.contained = false,
    this.color,
    this.containerColor,
    this.semanticsLabel = 'Loading',
  });

  /// Outer size; the shape itself is 38/48 of this, as in the M3 spec.
  final double size;

  /// Draws a circular container behind the shape.
  final bool contained;

  /// Shape colour. Defaults to `primary`, or `onPrimaryContainer` when
  /// [contained].
  final Color? color;

  /// Container colour when [contained]. Defaults to `primaryContainer`.
  final Color? containerColor;

  final String? semanticsLabel;

  @override
  State<AcatrainLoadingIndicator> createState() =>
      _AcatrainLoadingIndicatorState();
}

class _AcatrainLoadingIndicatorState extends State<AcatrainLoadingIndicator>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  final _elapsed = ValueNotifier<Duration>(Duration.zero);

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((elapsed) => _elapsed.value = elapsed)..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _elapsed.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    final color = widget.color ??
        (widget.contained ? colors.onPrimaryContainer : colors.primary);
    final containerColor = widget.containerColor ?? colors.primaryContainer;
    return Semantics(
      label: widget.semanticsLabel,
      child: SizedBox.square(
        dimension: widget.size,
        child: RepaintBoundary(
          child: CustomPaint(
            painter: _LoadingShapePainter(
              elapsed: _elapsed,
              color: color,
              containerColor: widget.contained ? containerColor : null,
              reduceMotion: reduceMotion,
            ),
          ),
        ),
      ),
    );
  }
}

class _LoadingShapePainter extends CustomPainter {
  _LoadingShapePainter({
    required this.elapsed,
    required this.color,
    required this.containerColor,
    required this.reduceMotion,
  }) : super(repaint: elapsed);

  final ValueListenable<Duration> elapsed;
  final Color color;
  final Color? containerColor;
  final bool reduceMotion;

  static const _shapes = [
    ExpressiveShape.cookie9,
    ExpressiveShape.flower6,
    ExpressiveShape.clover4,
    ExpressiveShape.sunny,
    ExpressiveShape.cookie12,
  ];

  /// Time per shape-to-shape morph (M3 Expressive uses 650ms).
  static const _stepSeconds = 0.65;

  /// One extra full turn every ~4.7s on top of the per-morph quarter turns.
  static const _spinPeriodSeconds = 4.666;

  /// Bouncy spatial spring; settles well inside one step.
  static final _morph = SpringSimulation(
    SpringDescription.withDampingRatio(mass: 1, stiffness: 200, ratio: 0.6),
    0,
    1,
    0,
  );

  @override
  void paint(Canvas canvas, Size size) {
    final seconds = elapsed.value.inMicroseconds / Duration.microsecondsPerSecond;
    final center = size.center(Offset.zero);
    final outer = size.shortestSide / 2;
    if (containerColor != null) {
      canvas.drawCircle(center, outer, Paint()..color = containerColor!);
    }
    final rect = Rect.fromCircle(center: center, radius: outer * 38 / 48);

    if (reduceMotion) {
      final pulse = 0.5 + 0.5 * math.cos(seconds * 2 * math.pi / 1.6);
      final alpha = (0.45 + 0.55 * pulse) * color.a;
      canvas.drawPath(
        buildExpressiveMorphPath(_shapes.first, _shapes.first, 0, rect),
        Paint()..color = color.withValues(alpha: alpha),
      );
      return;
    }

    final stepFloat = seconds / _stepSeconds;
    final step = stepFloat.floor();
    final t = _morph.x((stepFloat - step) * _stepSeconds);
    final from = _shapes[step % _shapes.length];
    final to = _shapes[(step + 1) % _shapes.length];
    final rotation = seconds * 2 * math.pi / _spinPeriodSeconds +
        (step + t) * math.pi / 2;
    canvas.drawPath(
      buildExpressiveMorphPath(from, to, t, rect, rotation: rotation),
      Paint()
        ..color = color
        ..isAntiAlias = true,
    );
  }

  @override
  bool shouldRepaint(covariant _LoadingShapePainter oldDelegate) =>
      oldDelegate.elapsed != elapsed ||
      oldDelegate.color != color ||
      oldDelegate.containerColor != containerColor ||
      oldDelegate.reduceMotion != reduceMotion;
}

/// A centred loading state for a page or panel: the indicator plus an
/// optional message. It waits [delay] before appearing so fast loads never
/// flash a spinner.
class AcatrainLoadingPane extends StatefulWidget {
  const AcatrainLoadingPane({
    super.key,
    this.message,
    this.delay = const Duration(milliseconds: 200),
    this.contained = false,
    this.size = 48,
  });

  final String? message;
  final Duration delay;
  final bool contained;
  final double size;

  @override
  State<AcatrainLoadingPane> createState() => _AcatrainLoadingPaneState();
}

class _AcatrainLoadingPaneState extends State<AcatrainLoadingPane> {
  Timer? _timer;
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    if (widget.delay == Duration.zero) {
      _visible = true;
    } else {
      _timer = Timer(widget.delay, () {
        if (mounted) setState(() => _visible = true);
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    return Center(
      child: AnimatedOpacity(
        opacity: _visible ? 1 : 0,
        duration: reduceMotion ? Duration.zero : const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AcatrainLoadingIndicator(
              size: widget.size,
              contained: widget.contained,
              semanticsLabel: widget.message ?? 'Loading',
            ),
            if (widget.message != null) ...[
              const SizedBox(height: 16),
              ExcludeSemantics(
                child: Text(
                  widget.message!,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
