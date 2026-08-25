# QA Business Test Case Example

Use this example when QA already understands the panel basics but still does not know how to design a real UI task.

The purpose of this example is not to teach every edge case. It teaches the default shape of a good UI-task test design in Maestro.

---

## Scenario

Business requirement:

- The system can enter several retry branches.
- Different branches should project different countdown text in UI.
- PO should only observe the final UI meaning.
- QA should not force PO to reason about internal state machine details.

This is the same class of task as:

- retry countdown
- badge state switch
- banner visibility
- disabled/enabled action state
- list row semantic state

---

## What QA should read first

Before writing anything, QA reads only:

1. the task goal on the card
2. the current diff
3. the directly related code path

QA is not expected to rediscover the whole system.

---

## What QA should produce in Dev phase

If the existing test entry points are not enough, QA writes one formal note:

- `type=test_entry_requirement`

The content should be short and concrete.

### Example

```md
## Branches Under Review
- Base state: item visible, no retry text
- Failure 1: item shows 2s retry
- Failure 2: item shows 8s retry
- Failure 3: item shows 30s retry
- Reset: item returns to clean state

## Risk Focus
- Wrong branch-to-UI mapping
- Countdown not refreshed after branch switch
- Reset leaves stale UI state behind

## Required Entry Points
- Prepare retry fixture
- Inject failureCount = 1
- Inject failureCount = 2
- Inject failureCount = 3

## Required Reset/Cleanup
- Clear injected state
- Remove fixture row from UI

## Required Debug Visibility
- Current failureCount
- Current retry delay in seconds

## PO Observe Targets
- UI shows 2s when branch = failure 1
- UI shows 8s when branch = failure 2
- UI shows 30s when branch = failure 3
- UI clears after reset

## Final Verdict Rule
- PASS only if each injected branch matches its expected UI text
```

---

## What Dev should deliver

Dev decides implementation details, but the result must be:

- clickable
- repeatable
- resettable
- minimally visible

Typical delivery:

- `Prepare`
- `Failure 1 -> 2s`
- `Failure 2 -> 8s`
- `Failure 3 -> 30s`
- `Reset`

QA does not design the button layout. QA only checks that the required entry points exist.

---

## What PO should actually do

PO should not design the test and should not infer internal logic.

PO should only:

1. click the provided entry point
2. look at the specified UI area
3. answer pass/fail
4. write a short note only if the result is unclear or wrong

---

## What QA should produce in formal QA

After Observe is complete, QA writes one formal note:

- `type=test_verdict`

### Example

```md
## Truth
- Dev provided stable branch injection for failure 1 / 2 / 3 and reset.
- Debug visibility confirms the retry branch changes correctly.

## Projection
- Branch failure 1 should map to 2s UI text.
- Branch failure 2 should map to 8s UI text.
- Branch failure 3 should map to 30s UI text.
- Reset should remove stale retry text.

## Observe
- PO observed 2s / 8s / 30s correctly.
- Reset returned the row to clean state.

## Final Verdict
- PASS
```

---

## What QA should NOT do

Do not ask PO to:

- wait for unstable timing windows
- create real-world failure conditions manually
- infer hidden state machine branches
- read raw logs to understand whether UI is correct

Do not design observe steps like:

- "wait until some background state maybe becomes visible"
- "watch a transient internal countdown if you can catch it"
- "create a real occupied file by hand unless this is the feature under test"

Those belong to Truth evidence or Dev-side test-entry design, not PO Observe.

---

## One-sentence rule

For business UI tasks, QA should design branch injection plus final UI observation, not real-world chaos reenactment.
