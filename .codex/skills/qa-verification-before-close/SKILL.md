# QA Verification Before Close

## Use When
- You are `qa` and are preparing to validate a task.
- You need to design a verification chain before deciding whether PO observation is required.
- The task may still expose `qaMode=logic_only`, `qaMode=chat_observe`, or `audit_required = true`, but those are execution wrappers, not the real testing philosophy.

## Core Rule
- QA is not a command runner.
- QA must first design a `truth -> projection -> acceptance` verification chain.
- QA does not own the test-panel UI layout; QA owns the entry requirements and final judgment.
- The default execution card is `doc/QA_ONE_PATH.md`; treat long-form docs as reference, not as the first action list.
- If the panel flow itself is unclear, first open:
  - `.maestro/tests/TASK-QA-TYPE-SMOKE-003/` for the minimal observe-only demo
  - `.maestro/tests/TASK-QA-TYPE-SMOKE-004/` for the prepare -> observe -> reset demo
- If you understand the panel but not the business-style test design, read `doc/examples/QA_BUSINESS_TEST_CASE_EXAMPLE.md`.
- Upstream `testType` / `qaMode` are suggestion inputs, not final truth.
- If the business app already has a stronger native debug/test surface, prefer that surface and use Maestro to record evidence and routing.
- Maestro is the observation-input and evidence-management surface; it is not the primary business test driver.
- QA must read the task goal and code diff before proposing any test flow.
- If logs, state dumps, debug drivers, or event fields are missing, QA must first ask Dev for support instead of faking coverage.
- Observe is allowed only for final, stable, meaningful UI outcomes that cannot be replaced by Truth evidence.

## Workflow
1. Read the task goal and code diff:
   - What changed?
   - Which branches, states, and UI projections are affected?
2. Collapse the task into one stage question before doing anything else:
   - Dev stage: are entry points sufficient?
   - QA stage: is observation complete?
3. For UI tasks in Dev phase, only if entry points are insufficient, start from `doc/examples/QA_ENTRY_REQUIREMENTS_TEMPLATE.md` and convert the result into a `task note --type test_entry_requirement`.
4. Formal QA uses one structured verdict note via `doc/examples/QA_VERDICT_TEMPLATE.md` and `task note --type test_verdict`.
5. If observability is insufficient, use `doc/examples/QA_SUPPORT_REQUEST_TEMPLATE.md`.
6. In Dev phase, define testing-entry requirements instead of inventing panel layout:
   - `Branches Under Review`
   - `Risk Focus`
   - `Required Entry Points`
   - `Required Reset/Cleanup`
   - `Required Debug Visibility`
   - `PO Observe Targets`
   - `Final Verdict Rule`
7. In formal QA, write one verdict note:
   - `Truth`
   - `Projection`
   - `Observe`
   - `Final Verdict`
8. Identify the truth layer:
   - What state, data, event, file-system result, log output, or gate result must be proven?
9. Identify the projection layer:
   - What UI, copy, list item, banner, badge, or control state must correctly project the truth layer?
10. Identify the human acceptance layer:
   - What still requires human judgment (visual comfort, hierarchy, animation, wording, overall fit)?
11. Filter Observe candidates before handing anything to PO:
   - Can this state be reproduced stably?
   - Can a human judge it reliably?
   - Does it directly matter to final product experience?
   - Can Truth evidence replace this step?
   - If any answer is wrong, the step must return to Truth or Projection and must not go to PO.
12. Produce the minimal plan first:
   - `Test Mode`
   - `What I will prove automatically`
   - `What UI / projection I will verify`
   - `What PO must observe`
   - `Pass rule`
   - `Out of scope`
13. If support is missing, stop and request Dev support:
   - logs / timestamps / trace ids
   - state dump
   - debug panel buttons or dropdowns
   - test-driver hooks
14. Only when `audit_required = true`, use the task test directory for formal observation assets:
   - `.maestro/tests/<TASK-ID>/observe.json`
   - optional scripts such as `.maestro/tests/<TASK-ID>/run.sh`
   - Maestro-managed `.maestro/tests/<TASK-ID>/results.json`
   - do not put task QA scripts under `scripts/`
   - execute scripts must be non-interactive; do not use `read`, prompts, or terminal pauses
   - for ordinary `chat_observe` work, do not manufacture these assets by default
15. QA defines what must be coverable; Dev decides how those entry points are implemented as buttons, segments, dropdowns, or debug UI.
16. Then choose the execution wrapper:
   - `logic_only`: truth verification dominates; keep PO out of the loop
   - `chat_observe`: projection + human acceptance dominate; QA drives the test through chat, not Maestro observation assets
   - `audit_required`: add formal Maestro observation assets only when explicit traceability is required
17. If there is a primary mode plus a lightweight extra check, keep one primary mode and place the extra into `secondaryChecks`.
18. For UI-related logic, use mapping verification:
   - verify the event exists
   - verify event parameters are correct
   - verify event order is correct
   - verify the PO-observed UI is the projection of that exact event
19. Intermediate, transient, or short timing-window states default to Truth verification, not Observe.
20. Every Observe step must identify:
   - which final verdict it supports
   - what would be lost without it
   - why Truth or Projection alone is insufficient
21. After evidence is complete, write the structured verdict note, run the QA gate, and either move to `closing` or rollback with a concrete reason.
22. Formal handoff lives in typed task notes only:
   - `type = test_entry_requirement` during Dev-phase support definition
   - `type = test_verdict` during formal QA
   - task-folder `.md` files are drafts only
23. QA verdict must be structured:
   - `Truth`
   - `Projection`
   - `Observe`
   - `Final Verdict`
   - For `deliverySurface=logic`, `Observe` may be `NOT_REQUIRED`.
   - For `deliverySurface=ui`, `Observe` may be summarized from PO chat feedback unless `audit_required = true`.

## Demo References
- `doc/examples/QA_DRIVER_MODEL_GUIDE.md`
- `doc/examples/QA_SESSION_DEMO_LOGIC.md`
- `doc/examples/QA_SESSION_DEMO_VISUAL.md`
- `doc/examples/QA_SESSION_DEMO_BANNER.md`

## Output Requirements
- Truth verification plan.
- Projection verification plan.
- Human acceptance scope.
- Dev support request when observability is insufficient.
- Evidence source or observation summary.
- QA conclusion and explicit routing.

## Completion Criteria
- The task reaches `closing`, or a rollback reason is recorded clearly enough for the next role to act without extra clarification.
