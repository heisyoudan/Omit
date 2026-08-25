# Sage Task Publish Review

## Use When
- You are `sage` and are about to publish, restart, or redispatch a task.
- A task has returned from `blocked` and needs a clean contract.
- The next role is not receiving an immediately executable handoff.

## Do Not Use When
- You are already inside execution work as `dev`, `design`, or `qa`.
- The task contract is already complete and the next role can execute immediately.

## Workflow
1. Verify the task has a concrete `summary` and `currentAction`.
2. Verify `acceptanceCriteria` and `boundaries` are real, not placeholders.
3. Check that the task belongs to the correct owner role for this round.
4. Ensure the next handoff target can execute now; do not dispatch an idle or blocked dead-end.
5. If the task is too broad, split it before dispatching.
6. If the contract is unclear, keep the task with Sage and revise the task card or spec first.

## Emergency Override
- Only use this when the user explicitly authorizes Sage to rearrange a card in an abnormal situation.
- This is not a normal workflow shortcut; prefer `task publish`, `task dispatch`, `transition request`, and `transition rollback` first.
- Command:

```bash
./scripts/maestro transition force <TASK-ID> --role sage --to <backlog|planned|in_progress|qa|closing|blocked|done> --reason "..." --authorized-by-user "用户已明确授权 Sage 在异常情况下强制改卡"
```

- Required behavior when using it:
  1. Record the user's authorization in `--authorized-by-user`.
  2. State the abnormal reason in `--reason`.
  3. Treat the result as a manual override and immediately re-check `task context`.

## Output Requirements
- A task card with executable contract fields filled.
- A valid dispatch target and handoff command.
- If blocked: an explicit Sage decision on whether to clarify, split, or cancel.

## Completion Criteria
- The next role can run `maestro task context <TASK-ID> --role <role>` and start work without extra chat clarification.
