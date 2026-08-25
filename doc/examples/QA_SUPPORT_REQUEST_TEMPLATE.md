# QA Support Request Template

Use this when QA cannot prove the truth layer or mapping layer with the current Dev outputs.

Suggested command:

```bash
./scripts/maestro task note <TASK-ID> --role qa --summary "QA 需要 Dev 支持" --details-file .maestro/tests/<TASK-ID>/QA_SUPPORT_REQUEST.md
```

Suggested file path:

```text
.maestro/tests/<TASK-ID>/QA_SUPPORT_REQUEST.md
```

## Template

```md
# QA Support Request for <TASK-ID>

## Missing Support
- Missing log fields:
- Missing state dump:
- Missing event correlation fields:
- Missing debug/test driver:

## Why This Blocks QA
- Truth target that cannot be proven:
- Projection mapping that cannot be proven:
- Risk of shallow or false validation:

## Requested Dev Changes
1.
2.
3.

## Acceptance Criteria For Support
- After the change, QA can prove:
- Required evidence artifact(s):
- Required UI/test-panel trigger(s):
```

## Minimum rule

Do not fake coverage when support is missing. Write this request, then wait for Dev support or rollback the task.
