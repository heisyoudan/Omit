# README_AGENT.md

## 目的
这是 Maestro 项目里所有 Agent 的最小操作手册。

它只保留稳定规则，不承载当前任务细节。当前任务该做什么，统一从：

```bash
./scripts/maestro task context <TASK-ID> --role <role>
```

获取。

分工原则：
- `README_AGENT.md` 负责仓库级硬规则
- `task context` 负责当前任务的动态执行面
- `.maestro/*` 是工作流真相源
- `execState` 是唯一生命周期真相；`ownerRole`、`gateProfile`、看板展示与下一步建议都只是派生伴随字段

## 1. 角色
可用角色：
- `sage`
- `dev`
- `design`
- `qa`

规则：
- `sage` 负责发布、裁定异常、最终关单
- `dev/design/qa` 负责执行层工作
- `sage` 发布任务后，若当前项目存在可用 Git 仓库与远端，必须立即 push，确保执行级角色可查看代码差分
- 正常情况自动推进到当前权限边界
- 只有失败、冲突、阻塞、规格不清时才打断用户

框架定位：
- Maestro 是 vendor-neutral 的工作流框架，不绑定某个 AI 提供商或对话产品
- AI 平台提供 worker；Maestro 提供共享项目真相、任务契约、流转与验证协议
- 当前仓库默认 profile 是 `software-development`

## 2. 开始任务前
固定顺序：
1. 阅读本文件
2. 阅读 `doc/WORKFLOW_RULES.md`
3. 运行 `task context`
4. 只按当前任务契约执行

命令：

```bash
./scripts/maestro task context <TASK-ID> --role <role>
```

## 3. 禁止事项
执行级 Agent 默认禁止：
1. 直接编辑 `.maestro/tasks.json`
2. 直接编辑 `.maestro/project.json`
3. 绕过命令直接修改任务状态
4. 静默放弃任务
5. 只在聊天里说明问题而不留记录
6. 在 `isMultilingual=false` 时额外引入多语言流程噪音
7. 在 `/doc` 下残留临时过程文件

若任务真相源需要升级 schema：
- 使用 `./scripts/maestro migrate tasks`
- 不允许让角色直接手改 JSON
- 若在 Git linked worktree 中执行，CLI 与 App 仍必须回主项目根目录下的 `.maestro/` 读写共享真相源

异常例外：
- 仅当用户明确授权 Sage 做异常卡片编排时，允许 Sage 使用强制改卡命令覆盖任务状态。
- 该能力只允许用于异常处置，不得作为日常流转替代。
- 正式命令：

```bash
./scripts/maestro transition force <TASK-ID> --role sage --to <backlog|planned|in_progress|qa|closing|blocked|done> --reason "..." --authorized-by-user "用户已明确授权 Sage 在异常情况下强制改卡"
```

## 4. 主流程
当前主链：
- `sage -> dev -> qa -> sage(close)`
- `sage -> design -> sage(close)`

常用命令：

```bash
./scripts/maestro task publish <TASK-ID> --role sage --title "..." --owner <dev|design|qa> --priority <p0|p1|p2|p3> --summary "..."
./scripts/maestro task dispatch <TASK-ID> --role sage --to <dev|design|qa|sage>
./scripts/maestro submit journal <TASK-ID> --role <role> --summary "..." --details-file ./note.md
./scripts/maestro gate run <TASK-ID> --role <role>
./scripts/maestro transition request <TASK-ID> --role <role> --to <qa|closing>
./scripts/maestro transition rollback <TASK-ID> --role <role> --to <in_progress|blocked> --reason "..."
./scripts/maestro transition rollback <TASK-ID> --role sage --to <qa|in_progress> --reason "..."
./scripts/maestro transition force <TASK-ID> --role sage --to <backlog|planned|in_progress|qa|closing|blocked|done> --reason "..." --authorized-by-user "..."
./scripts/maestro task close <TASK-ID> --role sage --note "..."
```

规则：
- `task dispatch` 只能交给当前可立即执行的下一个角色
- `dev` 正常推进到 `qa`
- `design` 正常推进到 `closing`
- `qa` 正常推进到 `closing`
- `sage` 负责最终审核；审核不通过时可正式回退到 `qa` 或 `in_progress`
- 若 Sage 发布任务后无法 push（无 git 仓库、无远端、push 失败），不得继续交接，应先说明阻塞前提
- `transition force` 仅限异常场景，且必须有用户对 Sage 的明确授权说明

## 5. 测试原则
测试规则只记最小硬边界，具体执行法交给规格和 Skill。

硬规则：
1. 测试按 `Truth -> Projection -> Human Acceptance` 顺序组织。
2. 能自动证明的，不交给人工观察。
3. 若 `deliverySurface = ui`，QA 不能只做代码/日志验证；最终必须提交 `Truth / Projection / Observe / Final Verdict` 四段结论。
4. Observe 只能用于最终稳定、可判断、不可被 Truth 证据替代的 UI 结果；中间态、瞬态、短窗口状态默认回到 Truth。
5. 对 UI 任务，QA 先定义“需要哪些测试入口”，Dev 再决定这些入口如何实现成测试面板、debug 按钮或注入入口。
6. 若业务应用已有更稳定的 debug/test 面板，优先在业务应用中驱动真实状态；Maestro 负责流程、证据和观察结果回传。
7. 对 `deliverySurface = ui` 的任务，正式 QA 交接统一写入 `task note`：Dev 阶段用 `type=test_entry_requirement`，正式 QA 用 `type=test_verdict`。
8. 若 QA 判定任务契约与实际验证模式冲突，仍先提交 `type=test_verdict` 作为唯一正式裁定；`type=contract_correction` 只作为补充异常说明交给 Sage。
9. QA 的默认执行入口是 `doc/QA_ONE_PATH.md`；`doc/QA_CURRENT_FLOW_AND_DESIGN.md` 只作为系统总览，不作为一线执行卡。
10. `doc/examples/QA_ENTRY_REQUIREMENTS_TEMPLATE.md`、`doc/examples/QA_VERDICT_TEMPLATE.md`、`doc/examples/QA_CONTRACT_CORRECTION_TEMPLATE.md`、`doc/examples/QA_SUPPORT_REQUEST_TEMPLATE.md` 只是草稿模板；`.md` 本身不参与 gate，正式结论必须回写 `task note`。

补充说明：
- 详细的 Observe 准入规则在 `doc/SPEC.md`
- QA 的专项执行步骤在 `qa-verification-before-close` skill
- 当前任务该怎么测，以 `task context` 为准

## 6. 多语言原则
是否启用多语言约束，只看：
- `.maestro/project.json` 的 `isMultilingual`

若为 `false`：
- 不注入多语言 checklist / forbidden actions

若为 `true`：
- 多语言约束进入任务契约与检查项

## 7. 2.0 初始化原则
Maestro 2.0 采用：
- 平台无关核心模板层
- 平台导出器层

共同母体文件：
- `doc/README_AGENT.md`
- `doc/WORKFLOW_RULES.md`
- `.maestro/agent_core_template.json`
- `.maestro/workflow_templates.json`
- `.maestro/task_contract_templates.json`
- `.maestro/bootstrap_manifest.json`
- `.maestro/skill_registry.json`

平台附加文件：
- Codex：`AGENTS.md`
- Codex Skills：`.codex/skills/<skill-id>/SKILL.md`
- GitHub Copilot：Maestro 当前默认导出到 `.github/copilot-instructions.md`
- GitHub Copilot Skills：Maestro 当前默认导出到 `.github/skills/<skill-id>/SKILL.md`

初始化时：
- 共同母体文件和当前平台附加文件允许覆盖刷新
- `.maestro/tasks.json` 等运行数据只补缺，不覆盖
- 当前平台的 skills 托管目录会先清理再重建
- 非当前平台的 skills 托管目录会被移除，避免残留旧平台文件

## 8. Skills 原则
Skills 用来承载专项工作流，不承载整仓长期规则。

当前 2.0 原型 skills：
- `sage-task-publish-review`
- `dev-systematic-debugging`
- `design-ui-shell`
- `qa-verification-before-close`

规则：
- 角色长期规则继续放在 `README_AGENT.md` / `WORKFLOW_RULES.md` / `.maestro/*`
- Skills 只解决高复用、步骤稳定的专项任务
- 初始化时按目标平台导出到对应 skills 目录
