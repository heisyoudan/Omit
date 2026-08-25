# Dev Systematic Debugging

## Use When
- You are `dev` and need to fix a logic, state, build, or workflow defect.
- A task is returned from QA and needs rework.
- A gate or transition path behaves unexpectedly.

## Do Not Use When
- The task is primarily a UI shell or information architecture problem owned by `design`.
- The problem is actually a spec ambiguity that should go back to `sage`.

## Workflow
1. Restate the exact failure symptom and the smallest reproducible path.
2. Identify the probable root cause before editing code.
3. Limit the change to the smallest surface that fixes the issue.
4. Re-run the relevant verification path after the fix.
5. Write a journal entry that records root cause, fix scope, and remaining exclusions.
6. Only then run gate and transition.

## Output Requirements
- Root-cause statement.
- Minimal fix description.
- Verification result.
- Explicit note when something remains intentionally out of scope.

## Failure Escalation
- If the bug is actually a spec conflict, rollback to `blocked` and hand the task back to `sage`.
- If QA asks for rework, absorb the rollback reason into the next pass instead of asking the user to repeat it.
