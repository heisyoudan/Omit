# QA Verdict Template

Use this template for the **formal QA handoff**.

Suggested command:

```bash
./scripts/maestro task note <TASK-ID> --role qa --type test_verdict --summary "QA 最终测试裁定" --details-file .maestro/tests/<TASK-ID>/QA_VERDICT.md
```

Suggested file path:

```text
.maestro/tests/<TASK-ID>/QA_VERDICT.md
```

## Template

```md
# QA Verdict for <TASK-ID>

## Delivery Surface
- logic | ui

## Truth
- What was proven:
- Evidence:
- Result: PASS | FAIL

## Projection
- What the UI or output should project:
- Evidence:
- Result: PASS | FAIL | NOT_REQUIRED

## Observe
- What was actually observed:
- Evidence (chat summary / screenshot / log / optional results.json):
- Result: PASS | FAIL | NOT_REQUIRED
- Which final verdict this Observe evidence supports:

## Final Verdict
- PASS | FAIL | NEED_OBSERVE | NEED_SAGE_DECISION
- Blocking reason (if any):
- Next routing:
```

## Minimum rule

For `deliverySurface = ui`, missing `Observe` evidence means formal QA cannot PASS.
