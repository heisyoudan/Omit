# QA One Path

This is the default execution card for QA.

If you forget everything else, keep only this path:

## 1. First decide the stage

### If the task is still in Dev
Ask only one question:

- Are the current test entry points enough to cover the critical branches?

If **no**:
- write one formal `task note` with `type=test_entry_requirement`

If **yes**:
- stop
- wait for formal QA

### If the task is already in QA
Ask only one question:

- Has the PO already completed the chat-based observation feedback?

If **no**:
- give the PO a short checklist in chat
- wait for the PO to reply with pass/fail + observed behavior

If **yes**:
- write one formal `task note` with `type=test_verdict`

---

## 2. Formal handoff only uses `task note`

For UI tasks, formal QA handoff uses only:

- `type=test_entry_requirement`
- `type=test_verdict`

Nothing else is a formal QA handoff artifact.

---

## 3. What not to worry about by default

Do not treat these as default required deliverables:

- `QA_ENTRY_REQUIREMENTS.md`
- `QA_VERDICT.md`
- `QA_SUPPORT_REQUEST.md`
- `TEST_GUIDE.md`
- `WORKING_NOTES.md`
- `observe.json`
- `results.json`
- `run.sh`

Those files may exist as drafts or audit assets, but they are not the default handoff path.

---

## 4. Default QA mode

For ordinary UI work, the default mode is:

- `verificationMode = chat_observe`

Meaning:
- QA works with Dev to get usable test buttons, fixtures, reset, and debug visibility
- PO tests through the product UI and reports back in chat
- QA summarizes the result in `type=test_verdict`

Only when the task explicitly requires formal audit evidence does QA need Maestro observation assets:

- `audit_required = true`

Then and only then do `observe.json`, `results.json`, and optional `run.sh` / `rollback.sh` become required.

---

## 5. Gate thinking

At the end, QA only needs to know:

- Is there a latest valid `test_verdict` note?
- Is there enough evidence to support the verdict?
- Does the verdict outcome allow close?

If yes, run the gate.

Important:

- `gate pass` means the QA package is complete enough to make a decision
- it does **not** mean the final QA verdict is automatically `PASS`

The verdict still comes from the latest `test_verdict` note:

- `PASS` → may continue toward `closing`
- `BLOCKED` / `FAIL` / `ESCALATE` → do not continue toward `closing`

---

## 6. Demo

If you want a self-contained panel demo first, open:

- `.maestro/tests/TASK-QA-TYPE-SMOKE-003/`
- `.maestro/tests/TASK-QA-TYPE-SMOKE-004/`

These demos only teach the Maestro testing UI. They are not the default path for ordinary UI QA.

For a real business-style example of how QA should define coverage and verdicts, read:

- `doc/examples/QA_BUSINESS_TEST_CASE_EXAMPLE.md`

---

## 7. One-sentence version

Dev stage:
- if entry points are not enough, write `test_entry_requirement`

QA stage:
- let the PO test in chat, then write `test_verdict`
