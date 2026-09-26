# Acatrain: v3 refinement (neater layout and an exact motion system)

This file **supersedes** the conflicting values in `expressive-redesign.md` and `expressive-motion.md`. Where they disagree, v3 wins.
The canvas artboards and `docs/design/expressive/*.dc.html` are the visual source of truth. Every `animation:` and `transition:` in those files uses the tokens below.

## 1. Layout: what changed and why

| Area | Before | v3 |
| --- | --- | --- |
| Page margin | 16, plus 4 extra on headings | **16 everywhere** (32 on desktop). Every left edge sits on it. |
| Vertical rhythm | Ad hoc (10–28) | 8 inside groups, 12 between related blocks, 24 above a section title, 40dp section-title row |
| Type ramp | 10 sizes | **8 styles** (table below) |
| Radii | 4, 6, 8, 10, 12, 14, 16, 18, 20, 24, 26, 28, 32, 36 | **4, 8, 12, 16, 20, 28, full** |
| Stats | Three separate icon tiles | One `surfaceContainerLow` strip, radius 20, cells split by 1dp hairlines (`#DCE3DB`) |
| Today list rows | Subject eyebrow, title, flat bar, meta, chevron | 72dp row: 44 badge, one title line, one meta line ("Economics · 7 items · **4 due**" with due in `primary`), trailing 28dp mini progress ring. No chevron. |
| Hero | 104 cookie with a background flower and a pill | Headline "`n` to review", body "`d` done today. Recall first, then check.", right side a 104 wavy ring around a 74 cookie. No decorative shapes. |
| Library cards | Radius 28, filled subject badge, coloured due pill | Radius 20, **container-tinted** badge (40), a neutral white due pill with primary text, 18/24 title |
| Set mode tiles | Radius 24–28, 128 tall | Radius 20. The Flashcards tile is 80 tall; the other two are 112. |
| Choice rows | Radius 24/8, 64 tall, 36 badges | Radius 20/4, 60 tall, 32 badges, 17sp text |
| Session header | Title, overflow button, 300-wide wave | Close button, title and set, and a **rolling counter** "3 of 7" on the right, above a full-width (358) wave. The overflow button is removed. |
| Decorative motion | Most shapes rotate | Only the due badge (40 s per turn) and the Complete badge rotate. The logo and subject badges are still. |
| Streak chip | 36 tall, looping flame | 32 tall; the flame flickers **once** on load |
| Hover and focus | None | Rows and cards get a `surfaceContainer` state layer on hover (effects-fast). There's a visible 3dp primary focus ring (`:focus-visible`). |

### Type ramp (Google Sans Flex)

| Style | Size / line | Weight | Tracking |
| --- | --- | --- | --- |
| display | 32 / 38 | 700 | −0.9 |
| headline | 26 / 32 | 700 | −0.6 |
| titleLarge | 18 / 24 | 650 | −0.2 |
| titleMedium | 16 / 22 | 600 | −0.1 |
| body | 15 / 22 | 400 | 0 |
| label | 13 / 18 | 600 | 0 |
| caption | 12 / 16 | 500 | 0 |
| eyebrow | 11 / 16 | 700 | +0.9, uppercase |

Local sizes are allowed only for:

- the flashcard prompt (28/34)
- the flashcard answer (22/30)
- the quiz prompt (28/34)
- the set title (28/34)
- stats (22/28)
- the hero badge number (30)
- the Complete score (52)

## 2. Motion tokens

These are M3 Expressive springs, mass 1, with damping given as a **ratio**. In Flutter:

```dart
SpringDescription.withDampingRatio(mass: 1, stiffness: k, ratio: z)
```

The CSS prototypes use `linear()` easings sampled from the same equations, so they match 1:1.

| Token | Stiffness | Ratio | Settles | Overshoot | Use |
| --- | --- | --- | --- | --- | --- |
| expressiveFast | 800 | 0.6 | 360 ms | ≈ 9.5 % | Pops, badges, chips, press release, button-group squash |
| expressiveDefault | 380 | 0.8 | 440 ms | ≈ 1.5 % | Entrances, card flip, deal-in, nav indicator, counter roll |
| expressiveSlow | 200 | 0.8 | 600 ms | ≈ 1.5 % | Celebration shapes |
| standardFast | 1400 | 0.9 | 220 ms | ≈ 0.15 % | Press-in (110 ms), small utility moves |
| standardDefault | 700 | 0.9 | 320 ms | ≈ 0.15 % | Progress value changes, size changes |
| effectsDefault | 1600 | 1.0 | 230 ms | 0 | Every opacity and colour change |
| effectsFast | 3800 | 1.0 | 150 ms | 0 | Hover and pressed state layers |

These moves are not springs:

- **Emphasized decelerate**, `Cubic(0.05, 0.7, 0.1, 1)`: progress fills (900 ms), ring sweeps (1000 ms), particle puffs, the flip depth dip.
- **Emphasized accelerate**, `Cubic(0.3, 0, 0.8, 0.15)`: exits only, 180–200 ms.
- **Linear**: wave drift (one 24dp wavelength per 1.6 s) and badge rotation (40–60 s per turn).

## 3. Principles

1. **Split space from effect.** Transforms ride a spatial spring; opacity and colour ride effectsDefault, so fades never bounce. Every entrance is two animations: `translateY 12 → 0` on expressiveDefault, and `opacity 0 → 1` on effectsDefault.
2. **Springs, not durations.** When an animation is interrupted, retarget it from its current velocity; don't restart it. Use `AnimationController.animateWith(SpringSimulation(...))`.
3. **Exits are quicker than entrances.** Out is 200 ms accelerate. In is 440 ms expressive. The next element starts arriving about 200 ms after the exit begins.
4. **Keep staggers short and capped.** Siblings start 40 ms apart, and the whole stagger never exceeds 280 ms.
5. **Keep travel small.** Entrance lift is 12dp. Press is scale 0.97. The flip depth dip is 0.965. Card exit is 120 % of width with a 10° rotation. Deal-in is 28dp at scale 0.94.
6. **Only earn overshoot where it helps.** Only expressiveFast overshoots visibly. Text and content blocks never wobble.
7. **Loops must mean "live".** Only the progress waves and the due badge move continuously. The flame and the arrow nudge play once or twice, then stop.
8. **Reduce motion.** Every animation resolves to its end state immediately. Colour changes may still cross-fade.

## 4. Choreography (ms from the trigger)

**Today enter**

| Element | Start | Duration / curve |
| --- | --- | --- |
| Date and title | 0 / 40 | expressiveDefault |
| Hero card | 80 | expressiveDefault |
| Summary strip | 120 | expressiveDefault |
| Badge scale-in (0.6 → 1) | 160 | expressiveDefault |
| "Study sets" header | 160 | expressiveDefault |
| Rows | 240, 280, 320 | expressiveDefault |
| Count-up | 260 | 700 ms, ease-out quart |
| Ring sweep | 420 | 1000 ms, emphasized decelerate |
| Row mini-rings | 520 | 1000 ms, emphasized decelerate |
| Arrow nudge | 1100 | 700 ms, twice |
| Streak flame flicker | 700 | 900 ms, once |

**Flip** (tap the card or "Show answer")

- The card rotates on Y, 0 → 180° with perspective 1/1600, on expressiveDefault.
- At the same time, a depth dip scales it 1 → 0.965 → 1 (emphasized decelerate, peak at 45 %).
- "Show answer" fades out (effectsDefault) while the Again / Got it group enters: 12dp lift plus fade, with Got it 40 ms after Again.
- The progress wave advances half a step on standardDefault.

**Grade** (Again / Got it)

1. Press-in: flex 1 → 1.35 and inner radius 8 → 20 over 110 ms (standardFast). The release springs back on expressiveFast.
2. Exit: 0–200 ms emphasized accelerate. Got it sends the card to the right, Again to the left: translate ±120 %, −2 %, rotate ±10°.
3. At 120 ms the toast springs up 16dp from scale 0.86 (expressiveFast) and fades in. It holds, then leaves at 1250 ms: 180 ms accelerate, up 10dp.
4. At the same time, 8 shape particles puff out 26–52dp (700 ms, emphasized decelerate).
5. At 200 ms the next card deals in: translateY 28 → 0 and scale 0.94 → 1 on expressiveDefault, opacity on effectsDefault.
6. The counter rolls: the new digit rises from +60 % with a fade (expressiveDefault). Keep it clipped to its 20dp line box.

**Answer (practice test)**

- The row tint crossfades on effectsDefault.
- **Correct:**
  - The letter badge is replaced by a cookie9 check that scales 0.3 → 1 and rotates −60° → 0 on expressiveFast.
  - 8 particles puff out 24–40dp, starting at 80 ms.
  - A "Correct" tag fades in at 140 ms.
  - `HapticFeedback.lightImpact`.
- **Wrong:**
  - The row shakes as a damped sine: −7, +5.5, −3.5, +2, −0.8, 0 dp over 420 ms, linear between keys.
  - The badge becomes a radius-10 square with ✕ (scale 0.6 → 1, expressiveFast).
  - `mediumImpact`.
- The explanation enters at 200 ms and Continue at 280 ms, both as entrance pairs.
- Other rows dim to `onSurfaceVariant` on effectsDefault.

**Session complete**

- The outer cookie12 scales 0.6 → 1 on expressiveSlow at 0 ms.
- The inner cookie9 scales 0.3 → 1 and rotates −60° → 0 on expressiveSlow at 150 ms.
- The score counts up from 300 ms over 700 ms.
- **Confetti:** 26 particles starting at 460 ms, each 1.3–1.75 s.
  - X decelerates with emphasized decelerate.
  - Y rises to a peak of −110 to −190dp over the first 38 % with an ease-out, then falls to +60 to +170dp with an ease-in.
  - The body tumbles 200–560° and fades during the last 20 %.
- Title and copy enter at 560 / 600 ms, the stats strip at 640 ms, the buttons at 820 ms, and the streak chip at 1150 ms (expressiveFast).
- Tapping the badge replays the whole sequence.
- `lightImpact` fires when the count lands.
- The two cookies keep rotating slowly in opposite directions (60 s and 40 s per turn).

**Filter chip select (Library)**

- The fill and border crossfade on effectsDefault.
- Radius 10 → 18 and the padding change on expressiveFast.
- The check pops in (0.3 → 1, −60° → 0) on expressiveFast.
- The filtered cards re-enter with the 50 ms stagger.

**Hover and press (all tappable surfaces)**

- Press-in: scale 0.97 over 110 ms (standardFast).
- Release: expressiveFast.
- Hover: state layer on effectsFast, plus a 2dp lift for cards on expressiveDefault.
- The square hero quiz button rounds 16 → 28 while held.

## 5. Flutter implementation notes

- Put the tokens in one place:

  ```dart
  abstract final class AcatrainMotion {
    static const expressiveFast = SpringDescription.withDampingRatio(mass: 1, stiffness: 800, ratio: 0.6);
    // ...the remaining tokens...
  }
  ```

  Add an `AcatrainMotion.of(context)` that returns instant specs when `MediaQuery.disableAnimationsOf(context)` is true.
- Entrances: write a `StaggeredEntrance` widget that takes an `index` and a `baseDelay`, with one `AnimationController` per page. Clamp the stagger at 280 ms.
- Implicit spring animations: write a small `SpringTween` helper, or use the Flutter 3.44 spring-based `Curves`. Never approximate a spring with `Curves.easeOutBack`.
- Particles and confetti: one `CustomPainter` driven by a single controller. Use a deterministic seed per session. Don't build one widget per particle.
- The counter roll and the card deal-in use `AnimatedSwitcher` with custom transitions keyed by value or index.
- Continuous loops (the wave and badge rotation) must stop when the route is covered: use `TickerMode` or `RouteAware`.
- Remove the `Curves.easeOutBack` in `AcatrainPressScale` and `HomeShell`'s page switcher. Replace them with the tokens above.
