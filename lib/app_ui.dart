import 'package:flutter/material.dart';

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

const acatrainFastMotion = Duration(milliseconds: 180);
const acatrainMediumMotion = Duration(milliseconds: 320);
const acatrainHeroMotion = Duration(milliseconds: 420);

String studySetHeroTag(String setId) => 'study-set:$setId';

class StudySetHero extends StatelessWidget {
  const StudySetHero({
    super.key,
    required this.setId,
    required this.child,
  });

  final String setId;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Hero(
      tag: studySetHeroTag(setId),
      transitionOnUserGestures: true,
      createRectTween: (begin, end) =>
          MaterialRectArcTween(begin: begin, end: end),
      child: child,
    );
  }
}

class AcatrainPageRoute<T> extends PageRouteBuilder<T> {
  AcatrainPageRoute({
    required WidgetBuilder builder,
    super.settings,
  }) : super(
          transitionDuration: acatrainMediumMotion,
          reverseTransitionDuration: const Duration(milliseconds: 280),
          pageBuilder: (context, animation, secondaryAnimation) =>
              builder(context),
          transitionsBuilder:
              (context, animation, secondaryAnimation, child) {
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
