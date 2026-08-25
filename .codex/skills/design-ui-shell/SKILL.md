# Design UI Shell

## Use When
- You are `design` and need to produce a visual shell, state expression, or information hierarchy.
- The task asks for preview, fixture, mock-driven UI, or explainability surfaces.
- A UI needs to be inspectable before real logic is attached.

## Do Not Use When
- The main work is business logic, data persistence, or real write-back behavior.
- The task requires changing workflow truth sources or schemas.

## Workflow
1. Clarify the current action, audience, and non-goals for this round.
2. Read `DESIGN.md` before shaping layout, hierarchy, primary actions, or state presentation.
3. Deliver UI shell first, not implementation coupling.
4. Cover the key visual states, not only the happy path.
5. Provide preview, fixture, or a test panel so PO/QA can observe the result directly.
6. State clearly which inputs/events Dev must connect later.
7. Keep logic mocked or externally injected.

## Output Requirements
- Observable UI shell.
- State coverage list.
- Preview / fixture / test surface.
- Dev handoff contract for wiring.
- Conformance to `DESIGN.md` unless the task explicitly overrides it.

## Completion Criteria
- QA or PO can inspect the UI result without needing hidden implementation knowledge.
