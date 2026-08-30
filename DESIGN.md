# Omit Design Contract

Last updated: 2026-08-30

This file is the Design role's product-specific UI constraint layer.

Priority: `Task > design-ui-shell skill > DESIGN.md`.

## 1. Product feel

Omit should feel quiet, precise, native, and immediately readable. It is a compact instrument, not a decorative dashboard.

- Preserve the `Omit.` wordmark as the primary brand element.
- Monitoring data stays in the primary white/gray type system; small module accents identify categories without coloring the data itself.
- Module accents are limited to icons and the Memory/Storage rings: Memory teal, Storage violet, CPU blue, Battery green, Network cyan, Thermal yellow, and Direct-only Trash rose.
- Prefer spacing, typography, and contrast to additional borders or effects.
- Avoid charts, dense legends, gratuitous animation, and competing primary actions.

## 2. Hierarchy

1. Brand and Settings entry.
2. Memory and Storage as primary cards.
3. CPU, Battery, Network, and Thermal as adaptive status cards.
4. GitHub Direct only: Trash as a full-width utility card between primary resources and adaptive status cards.
5. No persistent last-update footer in the approved App Store shell; freshness remains an implementation/test concern rather than a permanent visual row.

The panel must be understandable without tooltips. A user should not need to infer whether a percentage means used or available.

## 3. Layout rhythm

- Baseline panel width: 312 pt.
- Outer padding: approximately 20 pt.
- Primary-card spacing: approximately 12 pt.
- Card corner radius: approximately 16–18 pt with continuous corners.
- Primary cards use a restrained solid-color progress ring plus a clear value hierarchy. Percentages remain primary text rather than repeating the ring color.
- Adaptive status cards follow one deterministic rule: `4 -> 2+2`, `3 -> 1+2`, `2 -> 2`, `1 -> 1`, `0 -> none`.
- With three status cards, the wide row is above the pair. Wide priority is Network, Thermal, Battery, then CPU. This order is PO-approved and frozen for the App Store dashboard.
- The GitHub Direct Trash card is always a full-width Wide Utility card and never participates in status-card parity.
- Module changes must use stable row identities and must not animate MenuBarExtra window-height negotiation.
- Compact status cards use a tall two-column form; a single or selected three-card module uses the shorter full-width form above the pair.
- The approved full-width Thermal form is intentionally compact, so Thermal may take the second Wide priority without creating an empty-looking row.
- Memory and Storage use restrained single-color teal and violet rings. Memory presents estimated used memory as the primary value and physical total as supporting context; Storage presents available space with an explicitly labeled used percentage.
- Network uses separate arrow-led receive and transmit values with normalized `B/s`, `KB/s`, `MB/s`, or `GB/s` units; redundant row labels are omitted in the compact shell.
- CPU and Network remain strictly informational: no sparkline, history curve, area chart, animation, or alert tint.
- The dashboard has no persistent “updated just now” footer in the frozen shell.
- The header Settings icon remains visually compact but has at least a 28 × 28 pt hit target.
- Text must not be smaller than 10 pt.

Exact values may be adjusted when SwiftUI rendering proves that optical alignment requires it; preserve the hierarchy rather than blindly copying pixels.

## 4. Theme system

Provide observable System, Light, and Dark appearances.

### Light

- Warm-neutral or system-derived translucent background.
- Dark primary text and restrained secondary text.
- Cards must remain distinguishable without heavy shadows.
- Accent rings and icons retain sufficient contrast while numeric content remains neutral.

### Dark

- Near-black translucent HUD-like background.
- Light primary text with subdued secondary text.
- Cards use subtle lifted surfaces rather than bright borders.
- Accent colors must not bloom or overpower primary numeric values.

### Dashboard accent semantics

- Module color identifies the category only: it appears in module icons and the two primary progress rings, never in ordinary numeric values, percentages, titles, Network arrows, or supporting copy.
- Battery uses a green module icon, while its percentage and status copy remain neutral. Charging changes the battery symbol to its bolt variant; Fully Charged, Power Adapter, On Battery, and Unavailable retain the standard battery symbol.
- Thermal uses a fixed yellow module icon. Nominal, fair, serious, critical, and unavailable never change hue; available labels remain primary, unavailable remains secondary, and segment count carries the severity progression.
- Thermal always retains a written state label, so segment count is supplementary rather than the only carrier of meaning.
- Module icon bases use 10%–15% of the fixed icon accent. Colored card backgrounds, glow, and decorative data tints are not part of the dashboard system.

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
- Battery on-battery, charging, fully charged, external-power, unavailable, and no-battery states.
- Approved Thermal copy maps those states to concise localized user language (for example Normal / Elevated / Hot / Critical) without showing a numeric temperature.
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

Design owns the shell, state expression, fixtures, and previews. Dev later owns sampling, Sandbox/bookmark authorization, destructive write-back, refresh scheduling, and error recovery.

## 8. Reference

Use `doc/assets/omit-ui-light-dark-reference.png` for the intended light/dark balance, layout hierarchy, module accent identity, Network rows, and explicit Trash action. Treat it as directional rather than pixel-perfect; the stable palette in this contract takes precedence over colors in the reference, and its opaque dashboard treatment, extra header controls, and chart decoration are explicitly not implementation targets.
