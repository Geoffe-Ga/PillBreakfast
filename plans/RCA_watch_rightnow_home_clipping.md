# RCA — Watch "Right Now" home screen: title/clock collision + button clipping

- **Date:** 2026-06-18
- **Reporter:** Geoff (field bug report, 3 photos: IMG_3883/3884/3885)
- **Surface:** watchOS app, `RightNowView` "All caught up" empty state
- **Severity:** Medium (cosmetic + reachability). No data risk, but the
  primary watch surface looks broken and the second action button is partly
  unreachable on smaller faces.

## Problem statement

Field photos of the watch app show layout defects. After correcting for the
camera rotation (the watch was photographed sideways), only **one** screen is
actually broken — the home / "All caught up" screen (IMG_3883):

1. **Title collides with the system clock.** The navigation title "Right Now"
   renders centered across the top bar and overlaps the watchOS status-bar
   time, reading as "Right`4:58`Now".
2. **Action buttons clip off the bottom.** The "Log a scheduled dose" button
   wraps to two lines and is cut off at the bottom edge of the display; the
   content has no way to scroll to reveal it.

The other two photographed screens — `PRNListView` "No as-needed meds"
(IMG_3884) and `LogAnytimeView` "No scheduled meds" (IMG_3885) — are **not
defective**. Un-rotated, both empty states are correctly centered with the
title sitting cleanly to the left of the clock. The initial "everything is
clipping on the right edge" reading was an artifact of the rotated photos.

## Root cause

`PillBreakfast Watch App Watch App/RootView/RightNowView.swift`

**Defect 1 — title/clock collision.** `RightNowView` is the *root* of the
`NavigationStack` and fills **both** top-bar corners with custom toolbar items:

```swift
.navigationTitle("Right Now")
.toolbar {
  ToolbarItem(placement: .topBarLeading)  { /* calendar */ }
  ToolbarItem(placement: .topBarTrailing) { /* pills */ }
}
```

On watchOS the status-bar clock lives in the top-trailing region. With both
corners occupied by custom items and no back button present (it is the root,
so the leading slot is not reserved for "back"), the title has nowhere to dock
on the leading side and is centered — directly under/over the clock.

The two pushed screens don't hit this because they are *not* root: each gets an
automatic back button in the leading slot, which docks the title inline to the
left of the clock (`PRNListView` / `LogAnytimeView` render correctly).

The toolbar items are also **redundant in the empty state**: `AllCaughtUpView`
already surfaces "Take as-needed" and "Log a scheduled dose" as large
in-content buttons. The toolbar items exist so those destinations stay
reachable during the *tap-through queue* state (SPEC §2.3 / issue #200), not
the caught-up state.

**Defect 2 — button overflow.** `AllCaughtUpView` lays its hero + two buttons
in a plain `VStack` pinned with `.frame(maxWidth: .infinity, maxHeight:
.infinity)` and **no `ScrollView`**:

```swift
private struct AllCaughtUpView: View {
  var body: some View {
    VStack(spacing: .standard) {
      VStack { checkmark; "All caught up" }
      NavigationLink { ... } label: { Label("Take as-needed", ...) }
      NavigationLink { ... } label: { Label("Log a scheduled dose", ...) }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .glassBackground()
  }
}
```

The established convention in this codebase (`SafetyWarningView`) wraps tall
content in `ScrollView { VStack { … }.padding() }`. `AllCaughtUpView` omits it,
so on faces where hero + two full-width buttons exceed the height, the last
button wraps and clips with no scroll affordance to recover it.

## Impact

- **Scope:** every cold launch with an empty pending queue (no meds yet, or
  all doses logged) — i.e. the most common state. Both 41/45/46 mm faces; even
  the 49 mm Ultra shows the title collision.
- **Frequency:** always, in the caught-up state.
- **Risk:** cosmetic + partial reachability. The redundant in-content button
  means the destination is still reachable via the (colliding) toolbar icon,
  so no destination is fully lost — but the screen reads as broken.

## Contributing factors

- No watchOS snapshot-test harness yet (issue #31 is still a plan), so layout
  regressions aren't caught in CI.
- `AllCaughtUpView` was authored before the `ScrollView` convention in
  `SafetyWarningView` was settled, and never retrofitted.
- Root-level dual top-bar toolbar items were added for queue-state reachability
  (#200) without accounting for their effect on the caught-up title layout.

## Fix strategy

**Recommended:**

1. **Scroll the empty state.** Wrap `AllCaughtUpView`'s content in
   `ScrollView { … .padding() }`, matching `SafetyWarningView`. The hero
   centers when it fits and scrolls when it doesn't; the second button is
   always reachable.
2. **Stop the title/clock collision.** Drop the redundant top-bar toolbar
   items in the caught-up state so the root title can dock cleanly. Keep them
   only when the tap-through queue is showing (where the in-content buttons
   don't exist). Concretely: move the `.toolbar` onto `TapThroughQueueView`
   (the state that actually needs always-reachable affordances) instead of the
   shared `content`, leaving the caught-up root with just its title + clock.

Rejected alternatives:
- *Shorten the title* ("Now") — doesn't fix the underlying dual-corner squeeze
  and loses the SPEC's "Right Now" naming.
- *Force `.navigationBarTitleDisplayMode(.inline)`* — not the watchOS lever;
  the collision is corner contention, not display mode.

## Prevention

- Land the watchOS snapshot harness (#31) and add caught-up / empty-state
  cases across the 41 mm and 49 mm faces so top-bar + overflow regressions are
  caught in CI.
- Treat "tall content on the wrist ⇒ `ScrollView`" as a checklist item for new
  watch screens; reference `SafetyWarningView` as the canonical pattern.
