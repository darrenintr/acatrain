# Acatrain: haptics and UX system (v4)

This builds on `expressive-v3.md`, which still wins for layout and motion values.

New canvas boards:

- **UX system:** interaction states, a feedback map, system states, screen flow and ergonomics.
- **Haptics system:** 12 patterns, each with a waveform and platform specs.

New screens: **Review** and **Settings**. Reference markup is in `docs/design/expressive/*.dc.html`.

## 1. Haptic architecture (Flutter)

Flutter's `HapticFeedback` only gives coarse presets, so add a small platform channel:

```dart
enum AcHaptic { tick, tap, flip, confirm, again, reject, celebrate, streak, toggleOn, toggleOff, done, error, threshold }

abstract final class Haptics {
  static const _ch = MethodChannel('acatrain/haptics');

  static Future<void> play(AcHaptic h) async {
    final level = HapticPrefs.level; // 0 off, 1 subtle (×0.6), 2 standard
    if (level == 0 || kIsWeb || !(Platform.isAndroid || Platform.isIOS)) return;
    try {
      await _ch.invokeMethod('play', {'id': h.name, 'scale': level == 1 ? 0.6 : 1.0});
    } on PlatformException {
      _fallback(h);
    }
  }

  static void _fallback(AcHaptic h) => switch (h) {
        AcHaptic.tick || AcHaptic.toggleOn || AcHaptic.toggleOff => HapticFeedback.selectionClick(),
        AcHaptic.reject || AcHaptic.error => HapticFeedback.heavyImpact(),
        AcHaptic.confirm || AcHaptic.celebrate || AcHaptic.streak => HapticFeedback.mediumImpact(),
        _ => HapticFeedback.lightImpact(),
      };
}
```

**Android (Kotlin)**

- If `vibrator.areAllPrimitivesSupported(...)` is true (API 30+), build a `VibrationEffect.startComposition()` from the token's primitives. Multiply each primitive's scale by `scale`.
- Play it with `VibrationAttributes.USAGE_TOUCH` on API 33+, so the system's touch-feedback setting applies.
- Otherwise call `view.performHapticFeedback(<fallback constant>)`. It respects the system setting on its own.
- Guard primitives by API level: `LOW_TICK`, `THUD` and `SPIN` need API 31. `SEGMENT_TICK`, `TOGGLE_ON`/`TOGGLE_OFF` and `GESTURE_THRESHOLD_ACTIVATE` need API 34.

**iOS (Swift)**

- Keep one prepared `CHHapticEngine`. Use it only if `CHHapticEngine.capabilitiesForHardware().supportsHaptics` is true.
- Build each pattern from the listed events. Multiply `hapticIntensity` by `scale`.
- On failure, fall back to the listed `UIFeedbackGenerator`. Call `prepare()` on generators when a screen that uses them appears.

**Everything else** (web, desktop, devices without a motor): do nothing. Never play a sound as a substitute.

## 2. Tokens

Timings are ms from the trigger. Intensity and sharpness run from 0 to 1. Android primitives are listed as scale @ delay.

| Token | Fires on | Android composition | Android fallback | iOS (Core Haptics / generator) |
| --- | --- | --- | --- | --- |
| tick | Tab switch, filter chip, segmented button | TICK 0.5 | SEGMENT_TICK (34) → CLOCK_TICK | `UISelectionFeedbackGenerator` |
| tap | Primary and tonal buttons, rows that navigate | CLICK 0.5 | VIRTUAL_KEY | `.light` impact, 0.7 |
| flip | Flashcard flips (both directions) | QUICK_RISE 0.25 → TICK 0.5 @220 | CLOCK_TICK | continuous 0–180 ms, 0.1→0.3, sharp 0.2; transient @220, 0.5/0.5 |
| confirm | Got it, correct answer | CLICK 0.7 → CLICK 0.4 @70 | CONFIRM (30) | transients 0.8/0.6 @0, 0.5/0.4 @70 (fallback `.success`) |
| again | Again | LOW_TICK 0.8 | GESTURE_END | `.soft` impact, 0.6 |
| reject | Wrong test answer | THUD 0.5 → TICK 0.5 @59 → 0.35 @126 → 0.2 @193 | REJECT (30) | 0.7/0.2 @0, 0.5/0.5 @59, 0.35/0.5 @126, 0.2/0.5 @193 (fallback `.error`) |
| celebrate | Session complete, when the score lands (~1000 ms after arrival) | SLOW_RISE 0.5 → CLICK 1.0 → TICK 0.4/0.3/0.2 every 80 | CONFIRM | continuous 0–300 ms, 0.2→0.6, sharp 0.2; transient 1.0/0.7 @300; 0.4, 0.3, 0.2 / 0.9 @380, 460, 540 |
| streak | Streak +1: once per day, 500 ms after celebrate | QUICK_RISE 0.4 → CLICK 0.6 @110 | CONFIRM | `.rigid` impact, 0.6, after a 90 ms soft rise |
| toggle | Motion setting and future switches | TICK 0.6 (on), LOW_TICK 0.5 (off) | TOGGLE_ON / TOGGLE_OFF (34) | `.light` 0.5 on, `.soft` 0.35 off |
| done | A sync the user started finishes | CLICK 0.4 → TICK 0.3 @70 | CONFIRM | `.soft` impact, 0.5 |
| error | Sync or sign-in failed | THUD 0.6 ×2, 110 ms apart | REJECT | `UINotificationFeedbackGenerator(.warning)` |
| threshold | A drag crosses its commit point (future swipe-to-grade) | CLICK 0.6 | GESTURE_THRESHOLD_ACTIVATE (34) → CONTEXT_CLICK | `.rigid` impact, 0.6 |

**Rules**

1. Haptics fire only for things the user did. Never on load, scroll, count-ups, loops, or content that arrives by itself.
2. Every haptic is paired with a visible change, and it is timed to the visual peak:
   - The flip lands at 220 ms.
   - The reject pulses land on the shake peaks (59, 126, 193 ms).
   - Celebrate lands with the score.
3. At most one pattern per 80 ms; a new one cancels the previous one. Celebrate plays at most once per session.
4. "Again" stays gentle. Only a wrong **test** answer uses reject.
5. Buttons fire on release (`onTap`), not on touch-down. Hover never vibrates.

## 3. Settings: haptic strength and motion

- **Haptic strength** is a connected segmented group: Off · Subtle · Standard. Standard is the default.
  - Store it per device in shared preferences. It isn't synced.
  - Changing it plays `tick`, then previews `confirm` at the new strength 260 ms later.
  - "Try it" plays `confirm`.
  - If system haptics are off, Acatrain is silent whatever this setting says.
- **Motion** is Match system · Reduced.
  - Reduced forces the reduce-motion path from `expressive-v3.md` §3.8.
  - Changing it plays `toggle`.
- **Segmented button behaviour:**
  - The selected segment morphs to a full 24 radius on expressiveFast.
  - The fill crossfades on effectsDefault.
  - A check pops in, 0.3 → 1 and −60° → 0.
- **Study content row:**
  - An icon button starts a check.
  - While it runs, it shows the expressive loading indicator: shapes morph while turning. Show it only after 400 ms.
  - When the check finishes, the indicator turns into a check that pops in, the status reads "Up to date · checked just now", and `done` plays.
  - On failure, show an error card with "Try again", and play `error`.

## 4. Review screen

In order, top to bottom:

1. Display title and subtitle.
2. A summary strip with three stats: due now, missed, done today.
3. **Missed recently:**
   - A card with an error-container undo icon, the prompt, and "Subject · missed yesterday".
   - Then a full-width 48dp primary "Practise `n` mistake(s)".
4. **Due by set:** a grouped list with a 44 badge, the title, and "`d` due · `m` missed" (missed in `error`). Each row ends with a tonal 40dp "Review" pill.
5. Empty state, when nothing is due: a sunny badge, "You are caught up", "There are no review items due right now." and a tonal "Browse" button that opens Library.

## 5. UX rules (from the UX system board)

- **Interaction states:**
  - Hover: 8 % state layer.
  - Focus: 10 % state layer plus a 3dp primary ring.
  - Pressed: 10 % state layer plus scale 0.97.
  - Disabled: container at 12 % and content at 38 % of on-surface.
- **One primary action per screen**, in the bottom third where the thumb rests.
- **Targets** are at least 48dp. Every icon-only button has a semantic label and a tooltip.
- **Text scales to 200 %:**
  - Rows grow, and titles wrap to two lines.
  - Answer and explanation text never truncate.
  - Hero and card layouts switch to a column when they don't fit.
- **Screen readers:** results and counters are announced politely with `Semantics(liveRegion: true)`. Reading order matches visual order.
- **Prefer undo to confirmation dialogs.** No "are you sure?" on grading.
- **System states:**
  - Loading indicator only after 400 ms.
  - Offline banner (`surfaceContainerHighest`, cloud_off): "Offline. Studying from saved content."
  - Error card (`errorContainer`) with "Try again".
  - Content-ready snackbar (inverse surface): "New study content is ready. It applies to your next session." with a "Refresh" action.
- **Copy:** short and kind. Say what happened, then what to do next. Never blame the learner.

## 6. Prototype note

The canvas prototypes call `navigator.vibrate` with the "web" patterns on the Haptics board. This only works in Android Chrome. Everywhere else, a small dark pill at the top of the screen shows which haptic fired. The pill is a design-review aid; **do not implement it in the app**.

## 7. Acceptance additions

- [ ] Every action in the feedback map plays exactly its listed token, and nothing else vibrates.
- [ ] Off, Subtle and Standard behave as specified, and system haptics off silences everything.
- [ ] Reject pulses line up with the shake. Check this by recording the screen with a haptic logger in debug builds.
- [ ] No haptic fires during app start, navigation transitions, scrolling or background sync (except `done` / `error` when the user started it).
- [ ] Review and Settings screens match the canvas, including the empty and error states.
