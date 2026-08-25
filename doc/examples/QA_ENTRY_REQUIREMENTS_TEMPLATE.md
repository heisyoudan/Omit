# QA Entry Requirements Template

Use this template during Dev phase for UI delivery tasks. The goal is to define what testability support must exist before final QA starts.

Suggested command:

```bash
./scripts/maestro task note <TASK-ID> --role qa --type test_entry_requirement --summary "QA 测试入口需求" --details-file .maestro/tests/<TASK-ID>/QA_ENTRY_REQUIREMENTS.md
```

Suggested file path:

```text
.maestro/tests/<TASK-ID>/QA_ENTRY_REQUIREMENTS.md
```

## Template

```md
# QA Entry Requirements for <TASK-ID>

## Delivery Surface
- ui
- This note defines entry requirements during Dev phase. It does not replace the final QA test plan.

## Branches Under Review
- Branch A:
- Branch B:
- Branch C:

## Risk Focus
- Most likely branch to fail:
- Most likely mapping risk:
- Most likely reset / cleanup risk:

## Required Entry Points
- Entry 1:
- Entry 2:
- Entry 3:
- Each entry should push the system directly into a reviewable branch.

## Required Reset/Cleanup
- What must be cleared:
- What must return to baseline:
- How QA will know reset succeeded:

## Required Debug Visibility
- Minimum fields / state that must be visible:
- Minimum logs / trace ids needed:
- What QA needs in order to confirm the active branch:

## PO Observe Targets
- PO should only observe final stable UI outputs:
- Observe step 1:
- Observe step 2:
- Observe step 3:

## Final Verdict Rule
- PASS if:
- FAIL if:
- Roll back to Dev if:
- Escalate to Sage if:
```

## Minimum rule

Do not use this note to design the panel layout itself.
QA defines what must be coverable. Dev decides how the entry points are implemented.
