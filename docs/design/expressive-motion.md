# Acatrain: motion and liveliness (addendum to expressive-redesign.md)

Source: the same design canvas. The phone screens and the desktop board are now clickable prototypes: press Play on an artboard to try them.
The `Motion.dc.html` board shows each motion playing on a loop, with its spec and a Flutter hint.
The reference markup in `docs/design/expressive/*.dc.html` is updated. The CSS `@keyframes` in each file's `<helmet>` and the inline `animation:` values are the exact timings.

## Rules

- **Reduce motion wins.** When `MediaQuery.disableAnimations` is on, every animation below is replaced by its end state: nothing loops, nothing bounces and numbers show their final value. This is a hard requirement.
- **Loops must be cheap and pausable.** Slow shape rotation and wave drift run only while the widget is visible and the app is in the foreground (tie controllers to route visibility via `TickerMode` / `RouteAware`; no new dependency needed). Wrap each loop in a `RepaintBoundary`.
- **Motion follows the springs** in expressive-redesign.md §8:

  | Spring | Stiffness / ratio | Used for |
  | --- | --- | --- |
  | spatialFast | 800 / 0.6 | presses and pops |
  | spatialDefault | 380 / 0.8 | entrances and the card flip |
  | spatialSlow | 200 / 0.8 | the celebration |
  | effects | 1600 / 1.0 | colour and opacity changes |

- **Haptics:**
  - `HapticFeedback.lightImpact()` on a correct answer and on Got it.
  - `mediumImpact()` on a wrong answer.
  - `selectionClick()` on filter chips and navigation.

## Catalogue

| # | Motion | Where | Spec | Flutter approach |
| --- | --- | --- | --- | --- |
| 1 | Staggered rise | Every screen as it opens | translateY 18 → 0 plus fade, 55 ms stagger per block, spatialDefault | One controller per page, with an `Interval` per child |
| 2 | Living shapes | Logo (18 s per turn), hero badge (24 s), subject badges (14–30 s), decorative background shapes (36–48 s, reversed on some) | Linear, infinite | `RotationTransition(turns: controller..repeat())`. Pause off-screen. |
| 3 | Flowing wavy progress | Session header, set page, Library cards, desktop tiles | The wave moves forward one wavelength (20 dp) every 1.1 s. On first view the active part grows from 0 over 1.1 s (emphasized decelerate). When the value changes, the width animates on spatialDefault. | `WavyProgress` gets a `phase` (0–1) from a repeating controller, plus an implicit animation on `value` |
| 4 | Wavy progress ring | Around the hero due-count badge (Today, desktop) | The ring shows reviewed-today ÷ (reviewed-today + due) and draws in over 1.4 s after a 300–500 ms delay | `CustomPainter` sweep with an amplitude-2 wave of 12–14 lobes |
| 5 | Count-up numbers | Due count, reviewed today, well-practised, session score and stats | 0 → value over 950 ms, ease-out cubic, 250 ms delay, tabular figures | `TweenAnimationBuilder<double>` rounded to int |
| 6 | Press feedback | All pills, tiles and list rows | Scale 0.96 while pressed. Springs back on spatialFast. Square icon buttons (hero quiz button) round from radius 18 to 28 while held. | The existing `AcatrainPressScale`, plus `AnimatedContainer` for the radius |
| 7 | Nudging arrow | "Start learning", the Flashcards tile | The arrow nudges 5 dp right once every 2.6 s | A small repeating `TweenSequence`. Stop it after 3 cycles to avoid nagging. |
| 8 | Card flip | Flashcard: tap the card or "Show answer" | rotateY 0 → 180° with perspective (`setEntry(3, 2, 0.0012)`), 620 ms on spatialDefault. The back face is primaryContainer with the prompt echoed above the answer. | `AnimatedBuilder` with `Transform`, showing the front or back face based on the angle |
| 9 | Card swipe-out and deal-in | After Again / Got it | Got it: the card flies right (+470 dp, rotate 16°). Again: it flies left. 340 ms, emphasized accelerate. The next card deals in: translateY 46 → 0, scale 0.9 → 1, rotate −3° → 0, 620 ms. | `AnimatedSwitcher` with a custom transition, keyed by item |
| 10 | Button-group squash | Again / Got it | The pressed button's flex goes 1 → 1.45 and its inner corners 10 → 22. The other button gives way. spatialFast. | `AnimatedContainer` plus animated `flex` via `TweenAnimationBuilder` |
| 11 | Toast plus burst | After grading a card | A pill above the buttons pops in, floats up 26 dp and fades (1.3 s): "Nice! +1 practised" (primary) or "Coming back soon" (energy container). 14 shape particles burst upward from it. | An overlay entry with a sequence animation. Particles are a `CustomPainter`. |
| 12 | Correct answer | Practice test | The row tints to primaryContainer. The badge pops (0.35 → 1.12 → 1) into a slowly spinning cookie with a check and throws 12 shape particles (800 ms). A trailing tag rises in. | See 11. `lightImpact`. |
| 13 | Wrong answer | Practice test | The chosen row shakes (±9, −8, +6, −4, +2 dp over 460 ms), turns errorContainer, and the badge pops to a square with an ✕. The correct row reveals as in 12. The explanation card rises 160 ms later. | `TweenSequence` on translateX. `mediumImpact`. |
| 14 | Counter bump | "`i` / `n`" in the session header | The number scales 1 → 1.18 → 1 whenever it changes | Implicit scale animation keyed on the value |
| 15 | Celebration | Session complete | The outer cookie12 and the inner cookie9 pop in, staggered by 160 ms, then rotate slowly. Confetti comes in two waves: 30 particles after 250 ms and 18 after 650 ms, 1.3–1.6 s, with gravity. Expressive shapes and slips in primary, tertiary, container and energy colours. The score and stats count up. The streak chip pops in at 1.3 s. Tapping the badge replays it. Four small shapes float gently in the background. | A `CustomPainter` particle system with a deterministic seed per session. `lightImpact` when the score lands. |
| 16 | Navigation indicator | Nav bar and rail | The selected pill stretches from the icon: scaleX 0.4 → 1, 520 ms, spatialFast | Tune `NavigationBar`'s indicator animation, or use a custom indicator |
| 17 | Streak flame | Streak chip (Today, Library, desktop Review queue, Complete) | The flame flickers: rotate ±5° and scale 1.12, on a 1.8 s loop from a bottom-centre origin | A small repeating controller. It stays static under reduce motion. |
| 18 | Chip select | Library filter chips | The check pops in and the chip morphs from radius 12 with an outline to a filled stadium. Filtered cards re-enter with the staggered rise. | `AnimatedContainer` plus `AnimatedSwitcher` on the list |
| 19 | Card lift | Library cards, desktop tiles (hover and press) | Hover lifts the card 3 dp. Press scales it to 0.97. | `MouseRegion` plus `AnimatedSlide` / `AnimatedScale` |

## New elements that need small data additions

These additions are allowed. Keep them pure or local, and don't change the review scheduling.

1. **Reviewed today.** Count the `ReviewState`s whose `updatedAt` is today in local time. This feeds the hero "`n` reviewed today" pill and the progress ring. Add it as a getter on `AppStore`.
2. **Study streak.** This needs a persisted set of local dates on which at least one item was recorded:
   - Add `List<String> studyDays` (ISO `yyyy-MM-dd`) to the progress shared-preferences payload.
   - Append today's date in `record()`.
   - Compute the streak as the run of consecutive days ending today or yesterday.
   - Keep it device-local and don't include it in cloud progress merge unless that's trivial. If it's awkward, ship the streak chip hidden behind a `const bool kShowStreak = false` and say so in the PR.
   - Guest and account progress must stay separate, as they do now.
3. **Energy colour** (a custom colour harmonised to the seed), for streaks and celebrations. Add it to the `AcatrainTones` extension. In dark mode, derive the equivalent tones via `ColorScheme.fromSeed(seedColor: Color(0xFF9A4A1C))`.

   | Role | Hex |
   | --- | --- |
   | energy | `#9A4A1C` |
   | energyContainer | `#FFDBC8` |
   | onEnergyContainer | `#3A1604` |

## Content correction

The earlier static Flashcard mockup showed an invented answer for "What is product differentiation?". Always render the answer from the content bundle. The prototype now uses the real seed answers.

## Acceptance additions

- [ ] Reduce motion shows every screen in its final state with no looping animation.
- [ ] Flutter DevTools shows no jank at 120 Hz on Today with all loops running. Loops stop when the route isn't visible.
- [ ] Particles and the confetti are painted, not built from hundreds of widgets.
- [ ] The streak and reviewed-today values come from the store. None are hard-coded.
- [ ] Haptics fire only on the listed events.
