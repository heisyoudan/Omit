# Maestro SPEC

Last updated: 2026-08-18
Status: current

## 0. Version History

| Date | Version | Update | Why it matters |
|---|---|---|---|
| 2026-08-18 | v0.9.7 | Reframed Maestro as a vendor-neutral workflow framework, aligned public docs and generated guidance on `execState` as the only lifecycle truth, and clarified profile-specific workflow routing. | Reduces agent confusion when generated guidance, workflow docs, and task context are consumed without code access. |
| 2026-05-23 | v0.9.6 | Added Sage emergency override contract (`transition force`) and aligned lifecycle migration to trust explicit `execState` instead of silently promoting QA-owned cards back to `qa`. | Gives Sage a formal, auditable exception path for user-authorized card scheduling while preventing rollback cards from drifting back into the QA column. |
| 2026-05-21 | v0.9.5 | QA public contract fully aligned on `logic_only + chat_observe + audit_required`; QA default docs and user-facing guidance no longer treat Maestro observation assets as the normal path. | External agents can align to the same lightweight workflow without mixing old `visual_only / guided_observe` assumptions into current execution. |
| 2026-05-21 | v0.9.4 | QA workflow defaulted to `chat_observe`; `audit_required` downgraded to an explicit overlay instead of a default path; SPEC clarified default QA one-path flow and asset tiers. | Other agents can now align on the intended lightweight workflow without assuming Maestro observation assets are always mandatory. |
| 2026-05-21 | v0.9.3 | Lifecycle normalization rules were aligned across CLI and App so `execState`, `ownerRole`, `gateProfile`, and displayed column semantics stay in sync. | Prevents cards from visually drifting away from the real executable state during transition / rollback / close. |
| 2026-05-20 | v0.9.2 | Formal QA handoff unified on typed `task note` (`test_entry_requirement`, `test_verdict`) with latest-note-wins semantics. | Gives external agents one formal handoff channel instead of guessing between notes, journals, plans, and reports. |
| 2026-05-20 | v0.9.1 | Added `QA_ONE_PATH.md` and rewrote QA-facing guidance around stage-first execution. | Makes QA onboarding shorter and reduces confusion from draft files and low-level asset details. |
| 2026-04-09 | v0.9.0 | Established current SPEC baseline for role model, task contract, and QA truth/projection/observe philosophy. | Serves as the stable baseline for subsequent workflow tightening. |

## 0.1 Alignment Entry Points

External agents that cannot inspect code should align from documentation in this order:

| Layer | File | Purpose | Required for |
|---|---|---|---|
| System contract | `doc/SPEC.md` | Canonical workflow contracts, role semantics, verification modes, gate meaning, and formal handoff rules. | Everyone |
| Repository hard rules | `doc/README_AGENT.md` | Minimal always-on rules and prohibitions for all agents. | Everyone |
| Workflow operations | `doc/WORKFLOW_RULES.md` | Active chains, initialization/update policy, and current workflow operating rules. | Sage / infra / tooling alignment |
| QA execution card | `doc/QA_ONE_PATH.md` | Stage-first QA default path with the minimum actions QA should take. | QA and any agent simulating QA |
| QA architecture overview | `doc/QA_CURRENT_FLOW_AND_DESIGN.md` | Background rationale and non-default QA design context. | QA leads / system designers |
| Role skill | `.codex/skills/<skill-id>/SKILL.md` or generated platform skill | Role-specific SOP derived from the contract. | The matching role only |
| Runtime task packet | `./scripts/maestro task context <TASK-ID> --role <role>` | Current task goal, current stage, allowed actions, and local execution boundary. | The agent currently executing the task |

Alignment rule:

1. `SPEC.md` defines the contract.
2. `README_AGENT.md` defines always-on behavior constraints.
3. `WORKFLOW_RULES.md` defines current operational policy.
4. `QA_ONE_PATH.md` defines QA's default action path.
5. Skills translate these contracts into role-specific SOP.
6. `task context` is the only source for the current task's live execution packet.

If these layers disagree, the precedence is:

`Task context / task contract > SPEC > README_AGENT / WORKFLOW_RULES / QA_ONE_PATH > Role Skill > draft notes`

## 1. Product Position

Maestro is a vendor-neutral workflow framework for multi-role AI execution.

It does not assume a specific provider, chat product, or agent host. Any AI platform may supply the worker runtime. Maestro supplies the shared project truth, task contract, role boundary, transition rules, and verification protocol.

It does not replace the target product's own debug tooling. It manages:

- role boundaries
- task contracts
- handoff flow
- QA evidence expectations
- project initialization for agent-facing rules

Maestro is the workflow controller, not the application's business test platform.

The current repository uses the `software-development` profile, which layers the current role model, Git expectations, QA path, and generated platform guidance on top of the core framework.

## 1.1 Conversation Topology

Maestro separates three layers that are often mixed together in ordinary chat-based execution:

- user intent and business decision
- shared workflow truth and task contract
- platform-specific worker execution

The user may speak inside a long-running chat, but execution roles should still align from the current task packet rather than from incidental chat history. This is why `task context` is the live execution entry and why generated guidance must converge on the same contract language.

## 1.2 Core / Profile Separation

Maestro Core owns stable framework semantics:

- `.maestro/*` as the shared workflow truth source
- task contract shape
- lifecycle state machine
- role boundary semantics
- journal / gate / transition records

Profiles own domain-specific workflow policy:

- active role chain
- Git / diff visibility requirements
- QA mode defaults
- generated role guidance for the selected platform

This repository's default profile is `software-development`.

## 1.3 Non-Goals

Maestro does not try to:

- rename `.maestro` as part of normal contract evolution
- replace the target product's own debug panel or business-specific test harness
- introduce provider-specific orchestration concepts into the core contract
- create a second lifecycle truth outside `execState`

## 1.4 Human Authority

Agents execute within contract boundaries, but human authority still decides:

- task priority and publication
- abnormal overrides
- final acceptance when business judgment is required

Normal workflow should minimize unnecessary chat, but explicit human authorization remains mandatory for exceptional lifecycle overrides such as `transition force`.

## 2. Core Laws

### 2.1 Rule Convergence

Only systematize problems that are:

- high-frequency
- high communication cost
- likely to cause wrong execution or expensive rework

All other issues should be corrected through direct conversation instead of adding permanent rules, templates, checks, or states.

### 2.2 Maestro Design Principle

Maestro is a workflow controller that sits above the agent host and below the target product's own engineering surface.

It exists to:

- enforce role boundaries
- enforce task contracts
- capture evidence
- keep initialization and migration stable

It does not try to replace the target product's own debug tooling, test panel, or business-specific verification surface.

### 2.3 Task / Skill Separation

Task defines what to do.

Skill defines how to do it.

Task remains the truth source for:

- goal
- current action
- acceptance criteria
- boundaries
- handoff target

Skill only carries:

- method
- execution order
- output expectations
- exception handling guidance

When Task and Skill conflict, the priority is:

`Task > Skill > auxiliary guidance`

Generated platform guidance is a translation layer, not a new contract layer. It must not contradict `SPEC.md`, `README_AGENT.md`, `WORKFLOW_RULES.md`, or `task context`.

### 2.3.1 Rule Placement Model

Maestro uses four documentation layers, and each rule should have one primary home:

- `SPEC.md`: long-lived system rules, contracts, and cross-role semantics
- `README_AGENT.md`: minimal repository-wide hard rules that every agent should remember
- `Skill`: task-type or role-specific SOP that only matters when that workflow is actually triggered
- `task context`: current task's dynamic execution packet, including current risks, next actions, and local instructions

Do not fully duplicate the same rule across all four layers.

The primary layer owns the full rule. Other layers should only reference it or translate it into execution steps.

### 2.4 Skill Design Principle

Skills are auxiliary execution guides.

They should only exist when they improve repeatable, specialized work. They must not duplicate task contracts, business truth, or long-form project specs.

The skill design rule is:

- Task says what to do
- Skill says how to do it
- auxiliary guidance only constrains the floor, not the goal

### 2.5 QA Design Principle

QA is not a passive gate runner.

QA must:

- read task purpose and code diff
- plan the verification chain first
- ask Dev for missing observability support when needed
- verify truth first, projection second, human acceptance last
- only release when the truth-to-projection mapping is proven

Without a QA test plan, formal QA has not started.

### 2.6 Test Philosophy

Testing should be organized in this order:

1. truth verification
2. projection verification
3. human acceptance

Meaning:

- first prove the internal truth layer
- then verify that UI correctly projects that truth
- finally keep only the minimum human judgment that cannot be stably automated

### 2.6.1 UI Delivery Rule

If the task's final acceptance lands on user-visible UI, QA must carry verification all the way to the UI delivery surface.

That means:

- code review alone is insufficient
- truth verification alone is insufficient
- QA must explain what the user finally sees
- if `deliverySurface = ui`, the final user-visible result must be explicitly judged
- default mode is `chat_observe`, where the Observe conclusion may be summarized from PO chat feedback in `test_verdict`
- only when `audit_required = true` is formal Maestro observation evidence mandatory before PASS

### 2.6.2 Current Default Collaboration Model

For UI tasks, Maestro's current preferred collaboration model is:

1. QA reads the task goal, acceptance criteria, diff, and related logic.
2. QA determines which branches matter and what testability support is missing.
3. If support is missing, QA writes one `type=test_entry_requirement` note.
4. Dev implements feature work plus the required test entry points, reset paths, and minimum debug visibility.
5. QA gives the PO a short chat-based observation checklist.
6. PO performs the observation in chat and reports the result back in plain language, screenshots, or concise evidence.
7. QA writes one `type=test_verdict` note.
8. Sage reviews the verdict and closes only if the verdict outcome allows close.

This is the default workflow. Formal Maestro observation assets are not the default requirement.

### 2.6.3 Residual Ambiguity Rule

If the contract still leaves a real ambiguity after `task context`, the ambiguity should be made explicit in notes or residual scope instead of silently guessed by generated guidance.

### 2.7 Schema Migration

Runtime code should only rely on the current task schema.

Historical task cards must be upgraded through migration, not through manual JSON editing and not through permanent display-layer compatibility hacks.

Migration requirements:

- backup before overwrite
- transform old fields to the current schema
- validate the migrated file against the current decoder before saving
- keep business code and board rendering aligned to the same `execState` semantics
- if running inside a Git linked worktree, still read and write the primary project root `.maestro/` instead of maintaining a worktree-local workflow truth source

Current task migration entry points:

- `./scripts/maestro migrate tasks`
- automatic safe migration when the app opens a project and detects an outdated `tasks.json`

## 3. Role Model

### 3.1 Sage

Sage owns:

- task publication
- chain routing
- contract quality
- final close
- emergency exception routing under explicit user authorization

Sage must not hand off a task unless the next role can execute immediately.

If the current project has a working git repository and reachable remote, Sage must push after publishing so execution roles can inspect diffs. In the `software-development` profile this is a profile requirement, not a universal core rule for all future profiles.

If push cannot be completed because git or remote prerequisites are missing, Sage must explicitly treat that as a blocked precondition instead of pretending the requirement is satisfied.

Sage may use `./scripts/maestro transition force ...` only when all of the following are true:

- the situation is abnormal and normal workflow commands are not the right tool
- the user explicitly authorizes Sage to override the card state
- the authorization text is recorded in the command payload
- the override is treated as an auditable exception, not a normal shortcut

`transition force` is allowed to directly rewrite lifecycle fields and board placement, but it must still leave formal transition and journal records.

### 3.2 Dev

Dev owns:

- production logic
- implementation details
- debug and test drivability for engineering validation
- event / log / state outputs needed by QA

For logic that drives visible UI, QA defines which entry points must exist and what reset/debug support is required. Dev owns the actual implementation and organization of those entry points.

The Dev-side delivery must cover:

- required entry points for the key branches under review
- reset / cleanup that returns the app to a clean state
- minimum debug visibility so QA can confirm the active branch

Typical implementations include:

- debug panel controls
- state injection entry points
- traceable event output
- state dump hooks

### 3.3 Design

Design owns:

- product UI design
- information hierarchy
- state expression
- preview shell
- design handoff

Design does not own:

- test panel implementation
- test scripts
- QA evidence
- logic verification

Pure design tasks follow:

`sage -> design -> sage(close)`

They do not go through QA.

### 3.4 QA

QA owns:

- branch review based on task goal and diff
- testing-entry requirements definition
- support requests when Dev-side entry coverage or observability is insufficient
- evidence-based release judgment

QA is not a passive gate runner, but QA also does not own the concrete test-panel layout.

QA must first understand:

- task purpose
- code diff
- truth layer to verify
- projection layer to verify
- human acceptance scope

Then QA defines what coverage is needed, and Dev decides how to implement it.

### 3.4.1 QA Entry Requirements During Dev Phase

For UI delivery tasks, QA may intervene while the task still remains in Dev.

This does not introduce a new main-chain state.
The task stays in Dev until feature work and testability support are both ready.

When the task's `deliverySurface` is `ui`, QA should first write a testing-entry requirements note before final QA begins.

Use the canonical template at `doc/examples/QA_ENTRY_REQUIREMENTS_TEMPLATE.md`.

The minimum structure is:

- `Branches Under Review`
- `Risk Focus`
- `Required Entry Points`
- `Required Reset/Cleanup`
- `Required Debug Visibility`
- `PO Observe Targets`
- `Final Verdict Rule`

This note defines what testability support is needed.
It does not define the visual layout of the test panel.

## 4. Active Chains

The current active chains are:

- `sage -> dev -> qa -> sage(close)`
- `sage -> design -> sage(close)`

Normal path should auto-advance to the current role boundary.

Only interrupt the user on:

- failure
- state conflict
- blocked prerequisite
- unclear spec

When a task reaches `closing`, Sage performs the final review. If that review fails, Sage may formally `transition rollback` the task back to `qa` or `in_progress` without using the abnormal `transition force` path.

## 5. Task Contract

Every executable task must contain:

- title
- summary
- current action
- acceptance criteria
- boundaries
- priority

Execution-critical lifecycle truth is stored in `execState`.

Companion fields such as `ownerRole`, `gateProfile`, board column, and suggested next actions are derived fields that help routing and UI, but they do not create a second lifecycle truth. If any of them conflict with `execState`, runtime behavior, generated guidance, and human interpretation must normalize around `execState`.

Task routing metadata may still include:

- owner role
- gate profile

If any of the execution-critical fields are placeholder quality, the task is not ready for handoff.

## 6. QA Workflow

### 6.1 QA First Responsibility

QA must classify and plan before validating.

QA does not simply inherit an upstream label and execute mechanically.

Upstream `testType` or `qaMode` is only a suggestion.

QA must recompute the verification approach from:

- task goal
- code diff
- required truth checks
- required projection checks
- required human checks

### 6.2 QA Entry Requirements Before Formal QA

For UI delivery tasks, QA should define testing-entry requirements while the task is still in Dev.

This note exists to tell Dev:

- which branches must be injectable
- which reset / cleanup path must exist
- which debug visibility is required
- what PO will eventually be asked to observe

Use the canonical template at `doc/examples/QA_ENTRY_REQUIREMENTS_TEMPLATE.md`.

This note is a Dev-phase support artifact.
It does not replace the final QA verdict.

### 6.3 Verification Modes

Maestro should treat QA verification as two main modes plus one optional audit overlay:

- `logic_only`
- `chat_observe`
- optional `audit_required = true`

The intent is:

- `logic_only` handles pure logic/state/data validation with no human UI observation
- `chat_observe` is the default UI path: QA defines coverage, Dev provides entry points, PO tests in chat, QA writes a verdict
- `audit_required = true` upgrades a task into formal recorded observation only when explicit traceability is required

`formal_observe` is therefore not a default mainline mode. It is an audit overlay on top of a UI task, not the standard path for ordinary UI work.

### 6.4 Formal QA Verdict Note

Formal QA uses exactly one structured verdict note as the official QA handoff artifact.

The note must be written through `task note` with:

- `role = qa`
- `type = test_verdict`

The minimum structure is:

- `Truth`
- `Projection`
- `Observe`
- `Final Verdict`

For `verificationMode = logic_only`, `Observe` may be `NOT_REQUIRED`.
For `verificationMode = chat_observe`, `Observe` may be summarized from chat-based PO validation and does not require Maestro observation assets by default.
Only when `audit_required = true` does UI PASS require formal observation evidence files.

Use the canonical template at `doc/examples/QA_VERDICT_TEMPLATE.md`.

### 6.5 Dev Support Request

If QA lacks critical support, QA must explicitly request Dev support instead of improvising shallow validation.

Typical missing support:

- event log fields
- trace ID
- timestamp
- error detail
- state dump
- debug driver
- test panel trigger

### 6.6 QA Completion Definition

QA is done only when:

- truth verification is complete enough for the task
- projection verification is complete enough for the task
- required human acceptance is captured where needed
- evidence is written back and gate passes

Build passing alone is not QA completion.

For UI tasks in `chat_observe`, build/code review plus PO chat feedback may be sufficient when the verdict clearly summarizes the observation outcome. For UI tasks with `audit_required = true`, build/code review without formal Observe evidence is not QA completion.

### 6.6.0 Gate Meaning vs Verdict Meaning

Maestro must distinguish between:

- gate package completeness
- final QA verdict outcome

`gate.status = pass` only means:

- the formal QA package is structurally complete enough to make a decision
- the required typed note and supporting evidence exist
- if `audit_required = true`, the required observation evidence also exists

It does **not** automatically mean the task may close.

For UI tasks, the close-ready decision must be derived from the latest `test_verdict` note:

- `Final Verdict = PASS` → may continue toward `closing`
- `Final Verdict = BLOCKED` / `FAIL` / `ESCALATE` → must not continue toward `closing`

UI and CLI surfaces should therefore present both:

- gate completeness
- final verdict outcome

These two values are related but not interchangeable.

### 6.6.1 Formal Handoff Storage Rule

Formal multi-agent handoff is stored in `task note`.

- `task note` is the only formal handoff channel for structured QA entry requirements and final QA verdicts.
- task-folder `.md` files are draft materials only.
- Draft `.md` files do not participate in gate checks.
- If a draft becomes a formal conclusion, it must be copied into a typed `task note`.

### 6.6.2 Typed Task Note Rule

For `deliverySurface = ui`, Maestro recognizes these formal QA note types:

- `test_entry_requirement`
- `test_verdict`
- `contract_correction`

`contract_correction` records a contract mismatch for Sage follow-up, but it does not replace the latest `test_verdict` as the closing decision source.

Other notes default to `general` and are not used as formal QA gate artifacts.

### 6.6.3 QA Execution Entry

QA documentation is split into two layers:

- `doc/QA_CURRENT_FLOW_AND_DESIGN.md` is the architecture overview and background explanation.
- `doc/QA_ONE_PATH.md` is the default execution card for QA.

The execution card must stay short and stage-first:

- Dev stage: if entry points are insufficient, write `type=test_entry_requirement`
- QA stage: complete Observe, then write `type=test_verdict`

Default QA UI and CLI surfaces should prefer this stage-first execution path over exposing draft-file names or low-level asset details first.

### 6.6.3.1 Default QA One-Path Workflow

For ordinary UI work, QA should follow a single default path:

- Dev stage: determine whether existing test entry points are sufficient
  - if sufficient, do not create extra formal artifacts yet
  - if insufficient, write one `type=test_entry_requirement` note
- QA stage: ask PO to execute the chat-based observation steps, then write one `type=test_verdict` note

In this default path, QA should not require Maestro observation assets unless the task has explicitly been marked `audit_required = true`.

### 6.6.4 Latest Effective Note Rule

For the same `taskId` and formal note `type`, Maestro treats the latest timestamped note as the current effective record.

- Older notes remain as history.
- Gate checks ignore older notes of the same type.
- This rule applies to `test_entry_requirement` and `test_verdict`.

### 6.6.5 Observe Qualification Rule

Observe is a high-cost human validation surface.

An Observe step is valid only if all conditions hold:

1. it can be reproduced stably
2. a human can judge it reliably
3. it has direct meaning for final product experience
4. it cannot be replaced by Truth-layer evidence alone

If any of the above is false, the step must not enter `observe.json`.

### 6.6.6 Intermediate-State Default Rule

Intermediate, transient, and short-window timing-sensitive states default to Truth verification.

Typical examples:

- scan transient states
- short cooldown windows
- internal scheduling timestamps
- state-machine transition windows
- rapidly changing retry scheduler internals

Only when such a state is itself part of the final user experience, and requires direct human judgment, may it be promoted into Observe.

### 6.6.7 PO Observation Boundary

PO only observes final, meaningful UI projection.

PO should not be asked to:

- infer internal state-machine meaning
- judge unstable intermediate states
- prove logic already available through log / event / state evidence

PO should be asked to verify:

- the final banner / badge / list item / button state shown to users
- whether wording and timing are understandable
- whether the projected result matches intended product meaning

### 6.7 Task Test Assets Contract

Task-specific QA assets exist in two tiers.

#### Default tier: chat-based observation

For ordinary UI work, QA should prefer `verificationMode = chat_observe`. In this mode the formal workflow does **not** require Maestro observation assets.

Required formal artifacts:

- optional `type=test_entry_requirement` note when Dev-side entry coverage is insufficient
- required `type=test_verdict` note at formal QA conclusion

Allowed supporting evidence may include:

- chat summary of PO observations
- screenshots or logs referenced from the verdict
- Dev debug output
- task notes describing the exercised entry points

#### Audit tier: formal observation

Only when `audit_required = true` should the task require structured Maestro observation assets under:

- `.maestro/tests/<TASK-ID>/observe.json`
- optional `.maestro/tests/<TASK-ID>/run.sh`
- optional `.maestro/tests/<TASK-ID>/rollback.sh`
- Maestro-managed `.maestro/tests/<TASK-ID>/results.json`
- optional QA-facing `.maestro/tests/<TASK-ID>/README.md`

Rules:

- Do not put task QA scripts under `scripts/`.
- In audit mode, `observe.json` is the required source of observation structure.
- In audit mode, `results.json` is runtime session state and may be auto-created by Maestro.
- `run.sh` is optional; require it only when truth setup or probe must be automated.
- Any execute script must be non-interactive:
  - no `read`
  - no prompt pauses
  - no terminal-driven human steps

### 6.8 `observe.json` Minimum Schema

This section applies only when `audit_required = true`.

Each observe plan should define:

- top-level:
  - `taskId`
  - `qaMode`
  - `qaDriver`
  - `truthSource`
  - `projectionSurface`
  - `verificationStrategy`
  - `humanAcceptanceScope`
  - `validationPlan`
  - `steps`
- each step:
  - `id`
  - `type` or `kind`
  - `goal` or `title`
  - `action` or `instruction`
  - `whereToLook` (or top-level `observationTarget`)
  - `expected`
  - `onFailWrite` or `notePlaceholder`

If a step is `execute` and needs automation, it may include `script`.
If a step is `observe`, Maestro should collect the human observation result there.

## 7. UI Projection Verification

For UI-related logic features, Maestro uses the following model:

### 7.1 Truth Layer

QA proves the internal event, state, parameter, and order are correct.

Typical sources:

- logs
- state dumps
- file snapshots
- event streams
- gate results
- code review where appropriate

### 7.2 Projection Layer

The product UI or debug/test panel shows the visible effect of that truth.

Projection verification checks whether:

- the expected banner appears
- the expected list item appears
- the expected button state is shown
- the expected text or badge is rendered

If the task's `deliverySurface` is `ui`, QA must carry this projection check through to an explicit Observe conclusion. Formal asset evidence is only mandatory when `audit_required = true`; otherwise chat-based PO observation summarized in `test_verdict` is sufficient.

### 7.3 Human Acceptance

Human observation is only for what cannot be stably proven automatically, such as:

- visual comfort
- hierarchy clarity
- animation feel
- obvious truncation or layout issues

### 7.4 Mapping Judgment

QA must not only prove that:

- an event exists
- a UI effect exists

QA must prove that the UI effect is the correct projection of that specific event.

At minimum, key projection events should be associable by fields such as:

- event name
- timestamp
- trace ID or related item ID
- key arguments

Every Observe step must also identify which final verdict it supports.

If QA cannot explain:

- which final verdict this Observe step supports
- what would be lost without this Observe step
- why Truth or Projection analysis alone is insufficient

then the Observe step is not valid.

## 8. Test Surface Ownership

Maestro's built-in observation panel is an optional structured human-input tool.

It is not the default business test path for complex products.

When the application already has a stronger product-native debug or test panel, QA should prefer the product-native driver and use Maestro primarily to:

- carry typed handoff notes
- summarize PO observations in chat-driven workflows
- correlate final verdicts with truth-layer evidence

Only when `audit_required = true` should Maestro observation assets become mandatory.
Maestro does not replace the business app's debug panel; the product-native panel remains the preferred branch driver for `chat_observe`.

## 9. Design Constraints

`DESIGN.md` is the design constraint layer.

It exists to prevent low-level design mistakes, not to replace tasks or skills.

Its scope is limited to:

- product feel
- information hierarchy
- state expression
- layout rhythm
- interaction constraints
- do / don't rules

It is a lower-bound design guard, not a full design system.

## 10. Initialization

Project initialization is driven by `.maestro/bootstrap_manifest.json`.

Initialization must keep these distinctions:

- common managed files: overwrite
- runtime truth source files: create if missing
- platform-managed outputs: overwrite current platform outputs

Current supported platform outputs:

- Codex
- GitHub Copilot

Repository skill content is managed from the shared templates and exported to platform-specific locations during initialization.

## 11. Current Non-Goals

Maestro does not currently aim to provide:

- a universal business test runner
- a full scoring system for QA quality
- a visual design automation engine
- a replacement for the target product's own debug tooling

These areas should only be expanded when they clearly satisfy the Rule Convergence law.

## 12. Archive Policy

When the workflow model changes materially:

- archive the previous spec snapshot under `doc/archive/`
- keep this file as the clean current spec

Current archive snapshot for the pre-rewrite spec:

- `doc/archive/SPEC_legacy_20260409.md`
