# Acatrain: Material 3 Expressive redesign, implementation handoff

Source design: the Design canvas "Acatrain — Expressive redesign" (https://claude.ai/artifact/3GAKn3hFq1kn4z7JUCzjg6).
Reference markup for every artboard is in `docs/design/expressive/*.dc.html`. Read those files for exact values
(each element's inline `style="…"` is the spec). Ignore `support.js`, `<x-dc>` and the `<script type="text/x-dc">` blocks. They belong to the design tool.

| Artboard file | Screen | Flutter target |
| --- | --- | --- |
| `Main.dc.html` | Today (phone) | `HomeShell._today`, `_TodayHero`, `_MetricStrip`, `_grid` in `lib/main.dart` |
| `Library.dc.html` | Library (phone) | `HomeShell._library` |
| `Set.dc.html` | Study set detail | `SetPage`, `_SetMetric`, `_StudyActions`, `_ActionCard` in `lib/study_page.dart` |
| `Flashcard.dc.html` | Flashcard, answer revealed | `StudyPage` (flashcard mode), `_Flashcard` |
| `Quiz.dc.html` | Practice test, answered wrong | `StudyPage` (quiz mode), `_QuizCard` |
| `Complete.dc.html` | Session complete | `_FinishedSession` |
| `Desktop.dc.html` | Today at the expanded width class | `HomeShell` when `AcatrainWindowClass.expanded` |
| `System.dc.html` | Tokens: colour, type, shape, motion, spacing | `AcatrainApp._theme` plus new `lib/expressive.dart` |

## Ground rules

1. **UI only.** Do not change `store.dart` behaviour, the content schema, sync, auth or the scheduling logic. Adding small, pure read-only getters to `AppStore` is fine (see "Data bindings").
2. **Never hard-code numbers from the mockups.** Values like 12 due, 7 well-practised, 3/7 and "Wednesday, 23 September" are sample state. Bind every value to the store or the session.
3. **Content is dynamic.** Subjects and sets come from published bundles, so subject styling must fall back gracefully for unknown subjects.
4. Keep the existing accessibility and motion behaviour: `MediaQuery.disableAnimations` handling, `Hero` transitions, `AcatrainPressScale`, predictive back, tooltips and semantics labels. Every icon-only button needs a `tooltip`. Tap targets must be at least 48dp.
5. Keep the responsive classes in `app_ui.dart` (compact / medium / expanded) and the existing screens that aren't drawn (Review, Settings, the auth sheet). Restyle those with the same tokens and components so they match.
6. The app is offline-first, so fonts must be **bundled as assets**, never fetched at runtime.
7. Finish with `flutter analyze --no-fatal-infos` and `flutter test` passing. Update widget tests that match on changed text or widget types.

## 1. Colour

The light scheme below is the design's exact palette (a tonal-spot scheme from seed `#426B58`). Build it as an explicit `ColorScheme`. For dark mode, keep `ColorScheme.fromSeed(seedColor: Color(0xFF426B58), brightness: Brightness.dark)` so it still has a dark theme. The design only draws light.

| Role | Hex | Role | Hex |
| --- | --- | --- | --- |
| primary | `#36684F` | onPrimary | `#FFFFFF` |
| primaryContainer | `#B8F0CF` | onPrimaryContainer | `#0E3A26` |
| secondary | `#4E6356` | onSecondary | `#FFFFFF` |
| secondaryContainer | `#D0E8D7` | onSecondaryContainer | `#0B2616` |
| tertiary | `#3B6470` | onTertiary | `#FFFFFF` |
| tertiaryContainer | `#BFE9F8` | onTertiaryContainer | `#0A3642` |
| error | `#BA1A1A` | onError | `#FFFFFF` |
| errorContainer | `#FFDAD6` | onErrorContainer | `#410002` |
| surface | `#F6FBF4` | onSurface | `#171D19` |
| surfaceContainerLowest | `#FFFFFF` | onSurfaceVariant | `#404943` |
| surfaceContainerLow | `#F0F5EE` | outline | `#707973` |
| surfaceContainer | `#EAEFE9` | outlineVariant | `#C0C9C1` |
| surfaceContainerHigh | `#E4EAE3` | inverseSurface | `#2C322E` |
| surfaceContainerHighest | `#DFE4DD` | inversePrimary | `#9DD4B4` |

The design uses two extra tones on primaryContainer:

- `#93D5AE` fills the secondary button and chip inside the hero card and the flashcard "Answer" chip.
- `#1E4A34` is the hero card's supporting text.

Expose them through a small `ThemeExtension<AcatrainTones>` (`heroAccent`, `heroBody`) with dark variants derived from the dark scheme (for example `primary` and `onPrimaryContainer`).

## 2. Typography

The typeface is **Google Sans Flex** (SIL OFL), with **Figtree** (OFL) as the fallback. Add the variable TTF(s) under `assets/fonts/` and declare them in `pubspec.yaml`. If Google Sans Flex can't be obtained, ship Figtree alone and note it in the PR. Set `fontFamily` and `fontFamilyFallback` on the `ThemeData`.

Replace the current `TextTheme` with this one (size / line height, weight, letter spacing):

| Style | Spec | Used for |
| --- | --- | --- |
| displaySmall | 36 / 42, w750*, −1.2 | Page titles ("Make room for learning.", "Library") |
| headlineLarge | 32 / 38, w750, −1.0 | Set title, "Session complete", quiz prompt (32/40, −0.8) |
| headlineMedium | 28 / 34, w700, −0.5 | Hero headline (desktop hero is 40/46, −1.2) |
| titleLarge | 20 / 26, w700, −0.3 | Section headers; card titles 22/28 in Library |
| titleMedium | 16 / 22, w650, −0.1 | List titles |
| bodyLarge | 16 / 24, w400 | Supporting copy (hero body 15/22) |
| bodyMedium | 14 / 20, w400 | |
| bodySmall | 12 / 16, w400 | Meta lines |
| labelLarge | 14 / 20, w650 | Buttons 16–17 w650–700 |
| labelSmall | 12 / 16, w700, +0.8, uppercase | Eyebrows ("TODAY'S REVIEW", "QUESTION 1") |

\* Variable weights: use `FontVariation('wght', 750)` together with `fontWeight` (nearest `FontWeight`) so non-variable fallbacks still look right. Use `FontFeature.tabularFigures()` for counters (`3 / 7`, scores).

## 3. Shape scale

Corner radii in dp: XS 4 · S 8 · M 12 · L 16 · L+ 20 · XL 28 · XL+ 32 · XXL 48 · Full (stadium). Put them in `app_ui.dart` as constants (`AcatrainRadii`).

- Cards and set tiles: 28. Hero: 32 on phone, 36 on desktop. Flashcard: 32 outer, 26 inner answer panel.
- Primary buttons are stadium pills: 56 tall normally, **64** for the session-footer actions (Again / Got it, Continue, Practise missed).
- The hero's square secondary action is 56×56 with radius 18.
- Search bar: 56 tall, stadium, `surfaceContainerHigh`, leading search icon, trailing voice icon button (phone only; hide it if there's no voice action. Don't add a dead button).
- Filter chips: the selected chip is a stadium in `secondaryContainer` with a leading check. Unselected chips have radius 12 and a 1dp `outlineVariant` border.
- Status pills (Due / Practised / Missed / New): height 24, radius 8, 11sp w700, +0.4 spacing.

### Segmented (grouped) lists

Rows in a group are separate containers with a 2–3dp gap. The outer corners are large and the inner corners small:

- first row: top corners `outer`, bottom corners `inner`
- middle rows: all corners `inner`
- last row: top corners `inner`, bottom corners `outer`
- a single row: all corners `outer`

Used for:

| Where | Outer | Inner | Gap |
| --- | --- | --- | --- |
| Today set list | 24 | 6 | 3 |
| "Inside this set" | 20 | 4 | 2 |
| Quiz choices | 24 | 8 | 3 |
| Desktop review queue | 20 | 4 | 2 |
| Stat trio on Complete | 20 | 6 | 6 |

Write one helper: `BorderRadius segmentRadius(int index, int count, {double outer, double inner})`.

### Connected button group (Again / Got it)

Two equal-width buttons, 4dp apart, 64 tall. The outer ends are fully round (32) and the inner corners are 10. Again uses `secondaryContainer` with a replay icon. Got it uses `primary` with a check icon.

## 4. Expressive shapes

Create `lib/expressive.dart` with an `ExpressiveShape` enum and a `ShapeBorder` (or `CustomClipper<Path>`) that builds a closed polar path. Use 240 samples (fine for all sizes used). Start with a lobe pointing straight up:

```
r(θ) = R · (1 + a·cos(nθ)) / (1 + a),   point = centre + r·(cos(θ − π/2), sin(θ − π/2))
```

| Shape | n | a | Used for |
| --- | --- | --- | --- |
| cookie9 | 9 | 0.075 | Logo mark, hero due count, Economics, "correct" badge |
| cookie12 | 12 | 0.05 | Outer ring on Session complete |
| clover4 | 4 | 0.16 | Mathematics |
| flower6 | 6 | 0.13 | English |
| sunny | 8 | 0.045 | Icon plates (Flashcards tile, explanation, metrics) |

Then add `ExpressiveBadge(shape, size, color, child)`, a shape-filled box with a centred child. Use it for:

- the logo (34 in the app bar, 44 on the desktop rail): cookie9 with a filled `school` icon
- the hero count: 104 on phone, 184 on desktop
- subject avatars: 52 in the Today list, 44 in Library, 48 on desktop tiles, 28 as the set-page eyebrow
- metric icon plates: 32
- the Complete score: cookie12 at 232 in primaryContainer behind cookie9 at 176 in primary

Optional polish: animate a morph between shapes on press or selection, interpolating the radius function. Skip it when `disableAnimations` is on.

### Subject styling

Map subjects to styles, with a fallback for unknown subjects:

```dart
Economics   → cookie9,  primary / primaryContainer,   Icons.storefront_rounded
Mathematics → clover4,  tertiary / tertiaryContainer, Icons.functions_rounded
English     → flower6,  secondary / secondaryContainer, Icons.translate_rounded
otherwise   → pick from [cookie9, clover4, flower6, sunny] × [primary, tertiary, secondary]
              by a stable hash of the subject string; icon Icons.bookmark_rounded
```

Put the mapping in one place (`SubjectStyle.of(context, subject)`) returning `shape, fill, onFill, container, onContainer, icon`.

## 5. Wavy progress

Add a `WavyProgress` widget (a `CustomPainter`) in `lib/expressive.dart`:

- **Active segment:** a sine stroke with amplitude 2.6, wavelength 20, stroke width 4, round caps and a 12dp box height.
- **Track:** flat, 4dp stroke in `surfaceContainerHighest`, starting 6dp after the active end (a visible gap).
- **Stop indicator:** a 2dp-radius dot in the active colour at the far right end.
- If `value == 0`, draw only the track and the dot.
- Optionally let the wave phase drift slowly while a session is open. Freeze it when `disableAnimations` is on.
- **Semantics:** `Semantics(value: '3 of 7')`, or wrap it with the label of the value it shows.

Use it for the session progress bar under the header, the set page's "3 of 7 well-practised" bar (full width), Library card progress (220 wide) and desktop tile progress (212 wide).

The Today list rows use a **flat** 96×4 bar instead: the active part and the track are split by a 3dp gap, both with rounded ends.

## 6. Components and themes

Set these on `ThemeData` so screens stay thin:

- **NavigationBar:** 80 high including the bottom inset, `surfaceContainer` background. The indicator is 56×32 with radius 16 in `secondaryContainer`. Selected icons are filled (`*_rounded`) in `onSecondaryContainer`. Labels are 12sp: w700 in `onSurface` when selected, w550 in `onSurfaceVariant` otherwise.
- **NavigationRail** (medium and expanded): 96 wide, cookie9 logo (44) at the top, then 28dp of space, then the destinations with the same indicator spec. Replace the extended rail with this compact expressive rail, and drop the `VerticalDivider`.
- **AppBar:** 64 high, `scrolledUnderElevation: 0`. On Today: logo + "acatrain" (22sp, w750, −0.6), sync icon button, 32dp avatar (`tertiaryContainer`). Library has no title in the app bar. The large page title sits in the body.
- **FilledButton / FilledButton.tonal / OutlinedButton:** `StadiumBorder`, minimum height 56, horizontal padding 24, text 16 w650.
- **Card:** elevation 0, radius 28, `surfaceContainerLow`.
- **Flashcard surface:** `surfaceContainerLowest` with a soft two-layer shadow: `0 1 2 rgba(23,29,25,.08)` and `0 4 16 rgba(23,29,25,.06)`.
- **Input:** filled with `surfaceContainerHigh`, stadium shape, no border; a 2dp primary border when focused.

## 7. Screens

### Today (compact)

The page has 16dp side padding. In order:

1. An eyebrow date line: 14sp w600 in `onSurfaceVariant`, formatted "Weekday, d Month" from `DateTime.now()`. Write a tiny local formatter; don't add `intl` just for this.
2. The display title "Make room / for learning.", with an explicit line break on phones.
3. The **hero** (primaryContainer, radius 32, padding 22/22/22/24):
   - left column: the eyebrow "TODAY'S REVIEW", then the headline "`{totalDue}` items ready to review", then "Start with recall, then check what really stuck."
   - right: a cookie9 badge (104, `primary`) showing `totalDue` at 40sp w800
   - below: a button group made of a full-width "Start learning" pill (play icon) and a 56×56 square that starts a practice test on the same set. Hide the square when that set has no MCQs.
   - when `totalDue == 0`, the headline reads "You're caught up" and the button opens the first set.
4. 8dp gap, then a **metric trio**: a 3-column grid with 8dp gaps. Each tile is `surfaceContainerLow`, radius 20, padding 14/14/16, with a 32 shape plate, a 22sp w750 value and a 12sp label: sets count (sunny, secondary), `mastered` "well-practised" (clover4, tertiary), and "Ready / for offline" (flower6, primary).
5. The header row "Your study sets" plus a "See all" text button that switches to the Library tab.
6. A **segmented list** of sets, one row each: the subject badge (52), the subject eyebrow (12 w650), the title (16 w650, one line, ellipsis) and a meta row with the flat bar plus "`n` items · **`d` due**". Each row ends with a chevron and keeps the `StudySetHero` wrapper.
7. The status text stays at the bottom in bodySmall.

### Today (expanded, ≥ 1024)

This follows `Desktop.dc.html`:

- rail, then content (8dp left and 32dp right padding) with an 88dp header: date eyebrow and a 32sp title on the left, then a 320-wide search field that jumps to Library with the query, a sync button and a 40dp avatar.
- body: a Row with 24dp between a left column (flex) and a 340dp **Review queue** side panel.
- left column: a horizontal hero (radius 36, padding 32/36, headline 40/46, two buttons "Start learning" and "Practice test", and a 184 cookie showing the count plus "due today"), then the "Your study sets" header with an "Open library" link, then a 3-column tile grid with 12dp gaps. Tiles are 212 minimum height with the badge and due pill, subject, title, wavy progress and "`k` of `n` well-practised".
- **Review queue** panel (`surfaceContainerLow`, radius 32): header plus total due, then a segmented list of up to 4 due items across sets (missed items first, labelled "Missed" in `error`, others "Due now"), a tonal "Practise mistakes" button (it opens the mistakes-only session for the set with the most misses and is disabled when there are none), and a 2-stat footer (well-practised, items offline).

Medium width (600–1023) uses the rail, the phone layout for the content, and a 2-column tile grid.

### Library

- the display title "Library" plus subtitle, the search bar, then a horizontally scrolling row of filter chips (the existing `_subject` state).
- a meta row: "`N` sets · `M` items" on the left. On the right, a "Most due" sort toggle (swap_vert icon). This is new state: sorting by `dueCount` descending vs. bundle order. It must stay local UI state.
- one-column cards, 10dp apart (2 or 3 columns at wider widths). Each card is `surfaceContainerLow`, radius 28, padding 18:
  - a top row: badge (44, filled subject colour), subject label, and a due pill in the subject container colour
  - the title (22/28 w700) and the description (14/20, `onSurfaceVariant`, 2 lines max)
  - a wavy progress bar plus "`k`/`n` practised"
- Keep `_EmptyState`, restyled with a sunny badge.

### Study set (`SetPage`)

- app bar: back, then bookmark and more icons on the right. **Only include buttons that have a real action.** Omit bookmark and more unless they're wired.
- eyebrow row: 28dp subject badge plus the subject name, then the title (headlineLarge) and the description.
- progress block: "`k` of `n` well-practised" on the left and "`d` due" on the right (13sp), then a full-width WavyProgress.
- **Mode tiles** in a 2-column grid with 8dp gaps:
  - Flashcards spans both columns: `primary` fill, radius 28, min height 96, a sunny badge (56, primaryContainer) with a `style` icon, then "Flashcards" / "Recall all `n` items" and a trailing arrow.
  - Practice test: `tertiaryContainer`, radius 24, min height 128, icon on top, then title and "`q` questions".
  - Review due: `secondaryContainer`, same layout, "`d` items ready now".
  - Disabled tiles (0 questions or 0 due) go to 38% content opacity and aren't tappable.
- "Inside this set" plus the item count, then a segmented list: prompt (15 w550, one line), type ("Flashcard" / "Multiple choice") and a status pill:
  - **Missed**: `isWrong`, error container
  - **Due**: in `dueItems`, tertiary container
  - **Practised**: box ≥ 3, primary container
  - **New**: no progress, `surfaceContainerHigh`

### Session header (flashcard and quiz)

A 64dp bar: close (tooltip "End session"), then a two-line title (mode 16 w700 / set title 12 in `onSurfaceVariant`), then more (only if wired). Below it, a row with WavyProgress (flex) and a tabular counter "`i` / `n`": the index is w700 and the " / n" is w550 in `onSurfaceVariant`.

### Flashcard

- the card is one tappable surface (radius 32, 8dp inner padding) containing:
  - a question block: a chip with a "help" icon and the text "Question", then the prompt at 30/36 w700 −0.8, min height 212.
  - once revealed, an answer panel (primaryContainer, radius 26) with an "Answer" chip (lightbulb, `heroAccent`) and the answer at 18/27 w500.
- the reveal animates the panel with size and fade on the expressive default spatial spring. Keep the existing toggle semantics label.
- a hint under the card: "Tap the card to flip it back" when revealed, "Tap card to reveal the answer" otherwise.
- the footer is pinned 28dp from the bottom with 16dp sides:
  - before reveal: one 64dp "Show answer" pill.
  - after reveal: the connected **Again / Got it** group, then "Progress is saved on this device." in 12sp.

### Practice test

- eyebrow "QUESTION `i`" in `tertiary`, then the prompt at 32/40 w750.
- choices: a segmented list of full-width rows (min height 64, padding 12/16/12/14, 18sp w600). Each row has a leading 36dp badge.
  - idle: a letter A–D in a circle (`surfaceContainerHigh`).
  - **correct** (after answering): primaryContainer row, a cookie9 badge in primary with a check, and a trailing "Correct answer".
  - **chosen and wrong**: errorContainer row, a radius-12 square in `error` with a close icon, and a trailing "Your answer".
  - before answering, the selected row uses `secondaryContainer` with the letter badge in `secondary`.
  - lock the choices after Continue is available, the same way the current logic does.
- explanation: a tertiaryContainer card (radius 24), with a sunny badge (36, tertiary, lightbulb), "Why" in w700 and the explanation text.
- footer: a 64dp full-width "Continue" pill with a trailing arrow, pinned to the bottom.
- math prompts: render `^2`/`^3` as `²`/`³` and `-` between spaces as `−` **for display only**, in a small helper. Leave any other content untouched, because LaTeX isn't supported yet.

### Session complete

- centred: a cookie12 (232, primaryContainer) behind a cookie9 (176, primary) holding the score `correct` (60sp w800) plus "/`total`" (32sp, `inversePrimary`) and "recalled" (or "correct" in quiz mode).
- "Session complete" (headlineLarge), then a line that names the set and says how many items went back into review.
- a stat trio (segmented horizontally): got it / to revisit / now practised (for the set).
- footer: a 64dp primary "Practise `m` missed item(s)" (only if `m > 0`) and a 56dp text button "Back to learning".
- entrance: the shapes scale from 0.6 on the expressive slow spatial spring, and the text fades on the effects spring.

## 8. Motion

Use `SpringDescription`s. In M3 Expressive, damping is the damping *ratio*. Convert with `SpringDescription.withDampingRatio(mass: 1, stiffness: s, ratio: r)`.

| Token | Stiffness | Ratio | Use |
| --- | --- | --- | --- |
| spatialFast (expressive) | 800 | 0.6 | press scale, chip select, button-group press |
| spatialDefault (expressive) | 380 | 0.8 | card reveal, shape morph, hero, page content switch |
| spatialSlow (expressive) | 200 | 0.8 | session-complete reveal |
| effectsDefault | 1600 | 1.0 | colour, opacity (no overshoot) |

Keep the existing duration constants for route transitions. When `disableAnimations` is on, every spring resolves instantly.

## 9. Data bindings (add as pure getters on `AppStore` if missing)

- `int practisedCount(StudySet set)`: items with `box >= 3`, which is the same rule as `mastered`.
- `ItemStatus statusOf(StudySet set, StudyItem item)`: returns `missed` / `due` / `practised` / `new_`, using the rules in the Study set section.
- `int get totalItems`: the sum of items across sets.
- The Review queue list is derived from `dueItems` and `isWrong`. Don't add new persistence.

## 10. Acceptance checklist

- [ ] Compact screens match the artboards at 390×844 (spacing, radii, colours, type) with seed data loaded.
- [ ] Expanded layout matches `Desktop.dc.html` at 1280×800. Medium layout is coherent at 800 wide.
- [ ] Dark theme renders with no hard-coded light colours. Everything reads from `ColorScheme` or the `AcatrainTones` extension.
- [ ] Unknown subjects get a deterministic fallback style.
- [ ] No mock numbers or dates are hard-coded.
- [ ] Every icon-only button has a tooltip, and text contrast is at least 4.5:1 (caption text uses `onSurfaceVariant`, never lighter).
- [ ] Reduce-motion disables springs, wave drift and shape morphs.
- [ ] Fonts are bundled, and the app works fully offline.
- [ ] `flutter analyze --no-fatal-infos` and `flutter test` pass. Update tests or add golden tests for `WavyProgress` and `ExpressiveShape` if practical.
