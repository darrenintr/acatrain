import 'package:acatrain/expressive.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('spring settle times are short and ordered by stiffness', () {
    final fast = AcatrainSprings.settle(AcatrainSprings.spatialFast);
    final slow = AcatrainSprings.settle(AcatrainSprings.spatialSlow);
    final effects = AcatrainSprings.settle(AcatrainSprings.effectsDefault);
    expect(effects, lessThan(fast));
    expect(fast, lessThan(slow));
    expect(slow, lessThan(const Duration(seconds: 1)));
  });

  test('spring curves start at 0, end at 1 and effects never overshoot', () {
    for (final curve in [
      AcatrainSprings.spatialFastCurve,
      AcatrainSprings.spatialDefaultCurve,
      AcatrainSprings.spatialSlowCurve,
      AcatrainSprings.effectsDefaultCurve,
    ]) {
      expect(curve.transform(0), 0);
      expect(curve.transform(1), 1);
    }
    for (var i = 0; i <= 100; i++) {
      final v = AcatrainSprings.effectsDefaultCurve.transform(i / 100);
      expect(v, inInclusiveRange(0, 1));
    }
    // Spatial springs are underdamped, so they overshoot before settling.
    final peak = List.generate(
      101,
      (i) => AcatrainSprings.spatialFastCurve.transform(i / 100),
    ).reduce((a, b) => a > b ? a : b);
    expect(peak, greaterThan(1));
  });

  testWidgets('reduce motion resolves springs instantly', (tester) async {
    late Duration normal;
    late Duration reduced;
    await tester.pumpWidget(
      Builder(
        builder: (context) {
          normal = AcatrainSprings.durationOf(
            context,
            AcatrainSprings.spatialDefault,
          );
          return MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: Builder(
              builder: (context) {
                reduced = AcatrainSprings.durationOf(
                  context,
                  AcatrainSprings.spatialDefault,
                );
                return const SizedBox();
              },
            ),
          );
        },
      ),
    );
    expect(normal, greaterThan(Duration.zero));
    expect(reduced, Duration.zero);
  });
}
