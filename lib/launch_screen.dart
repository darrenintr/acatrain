import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

import 'expressive.dart';
import 'loading_indicator.dart';

/// App-open animation that sits in front of [child] until [ready] finishes.
///
/// 1. Intro: the logo springs in, morphing from a flower into the cookie
///    logo shape while it untwists; the icon pops in, then the wordmark
///    rises into place.
/// 2. Waiting: if [ready] is still running once the intro ends, an
///    [AcatrainLoadingIndicator] fades in under the wordmark.
/// 3. Exit: the logo swells and the app is revealed through a growing
///    cookie-shaped window from the centre of the screen.
///
/// [child] is mounted (hidden) as soon as [ready] completes, so its first
/// build happens before the reveal. Reduce-motion swaps all of this for a
/// short fade.
///
/// ```dart
/// MaterialApp(
///   home: AcatrainLaunchScreen(
///     ready: store.load(),
///     child: const HomeShell(),
///   ),
/// )
/// ```
class AcatrainLaunchScreen extends StatefulWidget {
  const AcatrainLaunchScreen({
    super.key,
    required this.child,
    this.ready,
    this.title = 'Acatrain',
    this.subtitle,
    this.icon = Icons.school_rounded,
    this.onFinished,
  });

  /// The app to reveal.
  final Widget child;

  /// Work to wait for before revealing [child]. Errors are reported to
  /// [FlutterError] and the app is revealed anyway, so it can show its own
  /// error state.
  final Future<void>? ready;

  final String title;
  final String? subtitle;
  final IconData icon;

  /// Called once the reveal has finished and the splash is gone.
  final VoidCallback? onFinished;

  @override
  State<AcatrainLaunchScreen> createState() => _AcatrainLaunchScreenState();
}

class _AcatrainLaunchScreenState extends State<AcatrainLaunchScreen>
    with TickerProviderStateMixin {
  static const _logoSize = 112.0;
  static const _logoShape = ExpressiveShape.cookie9;
  static const _introShape = ExpressiveShape.flower6;
  static const _introDuration = Duration(milliseconds: 1150);
  static const _exitDuration = Duration(milliseconds: 800);
  static const _loaderDelay = Duration(milliseconds: 300);

  late final AnimationController _intro =
      AnimationController(vsync: this, duration: _introDuration);
  late final AnimationController _exit =
      AnimationController(vsync: this, duration: _exitDuration);

  /// Logo scale: a bouncy spring with a visible overshoot.
  final _logoSpring = SpringSimulation(
    SpringDescription.withDampingRatio(mass: 1, stiffness: 240, ratio: 0.62),
    0,
    1,
    0,
  );
  final _textSpring = SpringSimulation(AcatrainSprings.spatialDefault, 0, 1, 0);

  bool _started = false;
  bool _reduceMotion = false;
  bool _ready = false;
  bool _introDone = false;
  bool _showLoader = false;
  bool _done = false;
  Timer? _loaderTimer;

  @override
  void initState() {
    super.initState();
    _intro.addStatusListener(_onIntroStatus);
    _exit.addStatusListener(_onExitStatus);
    _awaitReady();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _reduceMotion = MediaQuery.of(context).disableAnimations;
    if (_reduceMotion) {
      _intro.duration = const Duration(milliseconds: 250);
      _exit.duration = const Duration(milliseconds: 220);
    }
    _intro.forward();
  }

  Future<void> _awaitReady() async {
    try {
      await widget.ready;
    } catch (error, stack) {
      FlutterError.reportError(FlutterErrorDetails(
        exception: error,
        stack: stack,
        library: 'acatrain',
        context: ErrorDescription('while waiting behind the launch screen'),
      ));
    }
    if (!mounted) return;
    setState(() => _ready = true);
    _maybeExit();
  }

  void _onIntroStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed) return;
    _introDone = true;
    if (_ready) {
      _maybeExit();
    } else {
      _loaderTimer = Timer(_loaderDelay, () {
        if (mounted && !_ready) setState(() => _showLoader = true);
      });
    }
  }

  void _onExitStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed) return;
    setState(() => _done = true);
    widget.onFinished?.call();
  }

  void _maybeExit() {
    if (!_ready || !_introDone || _exit.isAnimating || _exit.isCompleted) {
      return;
    }
    _loaderTimer?.cancel();
    // Give the freshly mounted app one frame to lay out before revealing.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_exit.isAnimating && !_exit.isCompleted) {
        _exit.forward();
      }
    });
  }

  @override
  void dispose() {
    _loaderTimer?.cancel();
    _intro.dispose();
    _exit.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_intro, _exit]),
      builder: (context, _) {
        final reveal = _reduceMotion
            ? _exit.value
            : Curves.easeInOutCubicEmphasized.transform(_exit.value);
        // Keyed so the app keeps its state when the splash is removed.
        return Stack(
          fit: StackFit.expand,
          children: [
            if (!_done)
              KeyedSubtree(
                key: const ValueKey('launch-splash'),
                child: _buildSplash(context, reveal),
              ),
            if (_ready)
              KeyedSubtree(
                key: const ValueKey('launch-app'),
                child: _buildApp(reveal),
              ),
          ],
        );
      },
    );
  }

  Widget _buildApp(double reveal) {
    final clipping = !_done && !_reduceMotion;
    final opacity = _done
        ? 1.0
        : _reduceMotion
            ? reveal
            : (reveal / 0.3).clamp(0.0, 1.0);
    return IgnorePointer(
      ignoring: !_done,
      child: ClipPath(
        clipBehavior: clipping ? Clip.antiAlias : Clip.none,
        clipper: clipping
            ? _RevealClipper(progress: reveal, shape: _logoShape)
            : null,
        child: Opacity(opacity: opacity, child: widget.child),
      ),
    );
  }

  Widget _buildSplash(BuildContext context, double reveal) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final screen = MediaQuery.sizeOf(context);
    final seconds =
        _intro.value * _introDuration.inMicroseconds / Duration.microsecondsPerSecond;

    // Intro values.
    final double logo;
    final double morph;
    final double iconIn;
    final double textIn;
    final double subtitleIn;
    if (_reduceMotion) {
      logo = morph = iconIn = textIn = subtitleIn = 1;
    } else {
      logo = _logoSpring.x(seconds);
      morph = Curves.easeOutCubic.transform((seconds / 0.55).clamp(0.0, 1.0));
      iconIn = Curves.easeOutBack.transform(((seconds - 0.28) / 0.35).clamp(0.0, 1.0));
      textIn = seconds < 0.34 ? 0.0 : _textSpring.x(seconds - 0.34);
      subtitleIn = seconds < 0.46 ? 0.0 : _textSpring.x(seconds - 0.46);
    }

    // Exit values: logo grows past the screen edge, foreground fades.
    final fadeOut = _reduceMotion ? 1.0 : 1 - (reveal / 0.25).clamp(0.0, 1.0);
    final cover = _RevealClipper.coverRadius(screen, _logoShape);
    final logoRadius = _logoSize / 2 * logo +
        (cover * 1.2 - _logoSize / 2) * (_reduceMotion ? 0 : reveal);
    final rotation = (1 - morph) * -math.pi * 0.6 +
        (_reduceMotion ? 0 : reveal * math.pi / 4);

    final wordmarkStyle = theme.textTheme.displaySmall?.copyWith(
      color: colors.onSurface,
      fontWeight: FontWeight.w700,
      fontVariations: const [FontVariation('wght', 720)],
      letterSpacing: -0.5,
    );

    return Material(
      color: colors.surface,
      child: Opacity(
        opacity: _reduceMotion ? _intro.value : 1,
        child: Stack(
          fit: StackFit.expand,
          children: [
            CustomPaint(
              painter: _LogoPainter(
                radius: logoRadius,
                from: _introShape,
                to: _logoShape,
                morph: morph,
                rotation: rotation,
                color: colors.primary,
              ),
            ),
            Center(
              child: Opacity(
                opacity: (iconIn.clamp(0.0, 1.0) * fadeOut),
                child: Transform.scale(
                  scale: 0.4 + 0.6 * iconIn,
                  child: Icon(widget.icon, size: 52, color: colors.onPrimary),
                ),
              ),
            ),
            Positioned(
              left: 24,
              right: 24,
              top: screen.height / 2 + _logoSize / 2 + 28,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Opacity(
                    opacity: (textIn.clamp(0.0, 1.0) * fadeOut),
                    child: Transform.translate(
                      offset: Offset(0, (1 - textIn) * 20),
                      child: Text(
                        widget.title,
                        textAlign: TextAlign.center,
                        style: wordmarkStyle,
                      ),
                    ),
                  ),
                  if (widget.subtitle != null) ...[
                    const SizedBox(height: 8),
                    Opacity(
                      opacity: (subtitleIn.clamp(0.0, 1.0) * fadeOut),
                      child: Transform.translate(
                        offset: Offset(0, (1 - subtitleIn) * 16),
                        child: Text(
                          widget.subtitle!,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 32),
                  AnimatedOpacity(
                    opacity: _showLoader && reveal == 0 ? 1 : 0,
                    duration: _reduceMotion
                        ? Duration.zero
                        : const Duration(milliseconds: 240),
                    child: _showLoader
                        ? const AcatrainLoadingIndicator(size: 40)
                        : const SizedBox.square(dimension: 40),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LogoPainter extends CustomPainter {
  _LogoPainter({
    required this.radius,
    required this.from,
    required this.to,
    required this.morph,
    required this.rotation,
    required this.color,
  });

  final double radius;
  final ExpressiveShape from;
  final ExpressiveShape to;
  final double morph;
  final double rotation;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (radius <= 0) return;
    final rect = Rect.fromCircle(center: size.center(Offset.zero), radius: radius);
    canvas.drawPath(
      buildExpressiveMorphPath(from, to, morph, rect, rotation: rotation),
      Paint()..color = color,
    );
  }

  @override
  bool shouldRepaint(covariant _LogoPainter oldDelegate) =>
      oldDelegate.radius != radius ||
      oldDelegate.from != from ||
      oldDelegate.to != to ||
      oldDelegate.morph != morph ||
      oldDelegate.rotation != rotation ||
      oldDelegate.color != color;
}

/// Clips the app to a shape growing from the screen centre until it covers
/// the whole screen at `progress == 1`.
class _RevealClipper extends CustomClipper<Path> {
  _RevealClipper({required this.progress, required this.shape});

  final double progress;
  final ExpressiveShape shape;

  /// Outer radius at which [shape]'s valleys still clear every corner.
  static double coverRadius(Size size, ExpressiveShape shape) {
    final halfDiagonal = math.sqrt(size.width * size.width + size.height * size.height) / 2;
    return halfDiagonal / expressiveShapeInnerRadius(shape) + 2;
  }

  @override
  Path getClip(Size size) {
    final radius = coverRadius(size, shape) * progress;
    if (radius <= 0) return Path();
    return buildExpressiveMorphPath(
      shape,
      shape,
      0,
      Rect.fromCircle(center: size.center(Offset.zero), radius: radius),
      rotation: progress * math.pi / 4,
    );
  }

  @override
  bool shouldReclip(covariant _RevealClipper oldClipper) =>
      oldClipper.progress != progress || oldClipper.shape != shape;
}
