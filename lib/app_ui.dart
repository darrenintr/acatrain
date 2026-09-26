import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

import 'expressive.dart';

enum AcatrainWindowClass { compact, medium, expanded }

class AcatrainLayout {
  static AcatrainWindowClass classOf(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (width < 600) return AcatrainWindowClass.compact;
    if (width < 1024) return AcatrainWindowClass.medium;
    return AcatrainWindowClass.expanded;
  }

  static EdgeInsets pagePadding(BuildContext context) {
    return switch (classOf(context)) {
      AcatrainWindowClass.compact => const EdgeInsets.fromLTRB(16, 12, 16, 24),
      AcatrainWindowClass.medium => const EdgeInsets.fromLTRB(24, 18, 24, 32),
      AcatrainWindowClass.expanded => const EdgeInsets.fromLTRB(32, 24, 32, 40),
    };
  }

  static double maxContentWidth(BuildContext context) {
    return switch (classOf(context)) {
      AcatrainWindowClass.compact => 720,
      AcatrainWindowClass.medium => 1080,
      AcatrainWindowClass.expanded => 1320,
    };
  }

  static bool isCompact(BuildContext context) =>
      classOf(context) == AcatrainWindowClass.compact;
}

/// Softens the edge where scrolling content passes under a fixed header.
/// The fade grows with the first few pixels of scrolling, so content is fully
/// visible when the page is at the top.
class ScrollTopFade extends StatefulWidget {
  const ScrollTopFade({super.key, required this.builder});

  final Widget Function(ScrollController controller) builder;

  @override
  State<ScrollTopFade> createState() => _ScrollTopFadeState();
}

class _ScrollTopFadeState extends State<ScrollTopFade> {
  static const _fadeExtent = 32.0;
  late final ScrollController _controller = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _controller,
    child: widget.builder(_controller),
    builder: (context, child) {
      final offset = _controller.hasClients ? _controller.offset : 0.0;
      final strength = (offset / _fadeExtent).clamp(0.0, 1.0);
      return ShaderMask(
        blendMode: BlendMode.dstIn,
        shaderCallback:
            (bounds) => LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.white.withValues(alpha: 1 - strength),
                Colors.white,
              ],
              stops: [0, (_fadeExtent / bounds.height).clamp(0.0, 1.0)],
            ).createShader(bounds),
        child: child,
      );
    },
  );
}

class FadingListView extends StatelessWidget {
  const FadingListView({super.key, required this.children, this.padding});

  final List<Widget> children;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) => ScrollTopFade(
    builder: (controller) => ListView(
      controller: controller,
      padding: padding,
      children: children,
    ),
  );
}

class FadingSingleChildScrollView extends StatelessWidget {
  const FadingSingleChildScrollView({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => ScrollTopFade(
    builder: (controller) => SingleChildScrollView(
      controller: controller,
      child: child,
    ),
  );
}

const acatrainFastMotion = Duration(milliseconds: 180);
const acatrainMediumMotion = Duration(milliseconds: 320);
const acatrainHeroMotion = Duration(milliseconds: 420);

/// Nearest standard [FontWeight] for a Material 3 Expressive variable
/// weight (e.g. 550, 650, 750) that `FontWeight` itself doesn't have a
/// named constant for.
FontWeight acatrainWeight(double weight) {
  const steps = [100, 200, 300, 400, 500, 600, 700, 800, 900];
  final nearest = steps.reduce(
    (a, b) => (weight - a).abs() < (weight - b).abs() ? a : b,
  );
  return FontWeight.values[(nearest ~/ 100) - 1];
}

/// The Material 3 Expressive shape scale, in dp.
abstract final class AcatrainRadii {
  static const xs = 4.0;
  static const s = 8.0;
  static const m = 12.0;
  static const l = 16.0;
  static const lPlus = 20.0;
  static const xl = 28.0;
  static const xlPlus = 32.0;
  static const xxl = 48.0;
  static const full = 999.0;
}

/// Corner radii for one row of a segmented (grouped) list: large outer
/// corners, small inner corners, per the Material 3 Expressive list style.
BorderRadius segmentRadius(
  int index,
  int count, {
  double outer = AcatrainRadii.lPlus,
  double inner = AcatrainRadii.xs,
}) {
  if (count <= 1) return BorderRadius.circular(outer);
  final outerR = Radius.circular(outer);
  final innerR = Radius.circular(inner);
  if (index == 0) {
    return BorderRadius.only(
      topLeft: outerR,
      topRight: outerR,
      bottomLeft: innerR,
      bottomRight: innerR,
    );
  }
  if (index == count - 1) {
    return BorderRadius.only(
      topLeft: innerR,
      topRight: innerR,
      bottomLeft: outerR,
      bottomRight: outerR,
    );
  }
  return BorderRadius.circular(inner);
}

/// Adds a subtle press response while retaining the child's InkWell
/// semantics. The scale rides the expressive fast spatial spring, so it
/// settles with a small bounce on release; reduce-motion skips it.
class AcatrainPressScale extends StatefulWidget {
  const AcatrainPressScale({
    super.key,
    required this.child,
    this.pressedScale = 0.985,
  });
  final Widget child;
  final double pressedScale;

  @override
  State<AcatrainPressScale> createState() => _AcatrainPressScaleState();
}

class _AcatrainPressScaleState extends State<AcatrainPressScale>
    with SingleTickerProviderStateMixin {
  late final AnimationController _scale = AnimationController.unbounded(
    vsync: this,
    value: 1,
  );

  void _springTo(double target) {
    if (MediaQuery.of(context).disableAnimations) {
      _scale.value = 1;
      return;
    }
    _scale.animateWith(
      SpringSimulation(
        AcatrainSprings.spatialFast,
        _scale.value,
        target,
        _scale.velocity,
      ),
    );
  }

  @override
  void dispose() {
    _scale.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (_) => _springTo(widget.pressedScale),
      onPointerUp: (_) => _springTo(1),
      onPointerCancel: (_) => _springTo(1),
      child: ScaleTransition(scale: _scale, child: widget.child),
    );
  }
}

String studySetHeroTag(String setId) => 'study-set:$setId';

class StudySetHero extends StatelessWidget {
  const StudySetHero({super.key, required this.setId, required this.child});

  final String setId;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Hero(
      tag: studySetHeroTag(setId),
      transitionOnUserGestures: true,
      createRectTween:
          (begin, end) => MaterialRectArcTween(begin: begin, end: end),
      child: child,
    );
  }
}

class AcatrainPageRoute<T> extends PageRouteBuilder<T> {
  AcatrainPageRoute({required WidgetBuilder builder, super.settings})
    : super(
        transitionDuration: acatrainMediumMotion,
        reverseTransitionDuration: const Duration(milliseconds: 280),
        pageBuilder:
            (context, animation, secondaryAnimation) => builder(context),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final curved = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
            reverseCurve: Curves.easeInCubic,
          );
          final offset = Tween<Offset>(
            begin: const Offset(0, 0.025),
            end: Offset.zero,
          ).animate(curved);
          return FadeTransition(
            opacity: curved,
            child: SlideTransition(position: offset, child: child),
          );
        },
      );
}
