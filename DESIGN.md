# Omit Design Contract

Last updated: 2026-08-27

This file is the Design role's product-specific UI constraint layer.

Priority: `Task > design-ui-shell skill > DESIGN.md`.

## 1. Product feel

Omit should feel quiet, precise, native, and immediately readable. It is a compact instrument, not a decorative dashboard.

- Preserve the `Omit.` wordmark as the primary brand element.
- Use one accent color per module, with semantic meaning carried by labels and state rather than decorative dots.
- Prefer spacing, typography, and contrast to additional borders or effects.
- Avoid charts, dense legends, gratuitous animation, and competing primary actions.

## 2. Hierarchy

1. Brand and Settings entry.
2. Memory and Storage as primary cards.
3. CPU, Battery, Network, and Thermal as adaptive status cards.
4. GitHub Direct only: Trash as a full-width utility card between primary resources and adaptive status cards.
5. Last-update information as quiet footer context.

The panel must be understandable without tooltips. A user should not need to infer whether a percentage means used or available.

## 3. Layout rhythm

- Baseline panel width: 312 pt.
- Outer padding: approximately 20 pt.
- Primary-card spacing: approximately 12 pt.
- Card corner radius: approximately 16–18 pt with continuous corners.
- Primary cards use a ring plus a clear value hierarchy.
- Adaptive status cards follow one deterministic rule: `4 -> 2+2`, `3 -> 1+2`, `2 -> 2`, `1 -> 1`, `0 -> none`.
- With three status cards, the wide row is above the pair. Wide priority is Network, Battery, CPU, then Thermal.
- The GitHub Direct Trash card is always a full-width Wide Utility card and never participates in status-card parity.
- Module changes must use stable row identities and must not animate MenuBarExtra window-height negotiation.
- The header Settings icon remains visually compact but has at least a 28 × 28 pt hit target.
- Text must not be smaller than 10 pt.

Exact values may be adjusted when SwiftUI rendering proves that optical alignment requires it; preserve the hierarchy rather than blindly copying pixels.

## 4. Theme system

Provide observable System, Light, and Dark appearances.

### Light

- Warm-neutral or system-derived translucent background.
- Dark primary text and restrained secondary text.
- Cards must remain distinguishable without heavy shadows.
- Accent rings and icons retain sufficient saturation and contrast.

### Dark

- Near-black translucent HUD-like background.
- Light primary text with subdued secondary text.
- Cards use subtle lifted surfaces rather than bright borders.
- Accent colors must not bloom or overpower numeric values.

Theme switching must not change information hierarchy, dimensions, enabled modules, or content.

## 5. Component states

The UI shell and previews must cover:

- Main panel in Light.
- Main panel in Dark.
- Settings in Light and Dark.
- System appearance selection.
- Trash unauthorized.
- Trash empty.
- Trash containing data with a dedicated Clear action.
- Unavailable CPU or Battery data.
- No-battery hardware with Battery omitted from the dashboard.
- Thermal nominal, fair, serious, critical, and unavailable states.
- All Compact-card counts and Wide-priority combinations.
- Long localized strings without truncating critical values.

Fixtures may supply static values. Design must not invent real monitoring or permission behavior.

## 6. Interaction rules

- Appearance selection applies immediately and clearly indicates the active choice.
- The Settings entry is the only header action.
- Trash authorization is a GitHub Direct-only local secondary action.
- Clear Trash is a dedicated destructive action, never a card-wide gesture.
- A destructive confirmation surface must be represented, but real deletion wiring belongs to Dev.
- Motion should be short and functional; theme and Settings transitions must not distract from status reading.

## 7. Design-to-Dev handoff

The shell should expose presentation inputs for:

- memory value, total, percentage, and availability state
- storage available value and used percentage
- CPU value and availability
- battery value, charge state, and device availability
- network receive and transmit values
- system thermal state and availability
- Trash authorization/status/value and user intents
- selected appearance preference
- last-updated label

Design owns the shell, state expression, fixtures, and previews. Dev later owns sampling, Sandbox/bookmark authorization, destructive write-back, refresh scheduling, and error recovery.

## 8. Reference

Use `doc/assets/omit-ui-light-dark-reference.png` for the intended light/dark balance, layout hierarchy, Network rows, and explicit Trash action. Treat it as directional rather than pixel-perfect.
