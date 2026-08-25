# Maestro 工作流规则

本文件是给新项目里的 Sage 阅读的总规则文档。

定位补充：
1. Maestro Core 是 vendor-neutral workflow framework。
2. 当前仓库默认 profile 是 `software-development`。
3. Core 负责共享项目真相、任务契约、流转与验证协议；profile 负责当前软件开发链路的具体角色与路由。

目的：
1. 说明当前有效工作流
2. 说明初始化/更新时哪些文件会覆盖，哪些只补缺
3. 作为新 Sage 接手项目时的首读入口

最高约束：
1. 只把高频、高成本、强破坏的问题系统化；其余问题优先通过对话纠偏。
2. Task 说做什么，Skill 说怎么做。
3. 每条规则都应该有一个主落点：规格、README、Skill、或 task context；其他层只引用，不重复展开。
4. QA 的一线执行入口应优先收敛到单线流程卡；总览文档与执行卡必须分开。
5. UI 任务默认走 `chat_observe`；只有显式标记 `audit_required = true` 时，才升级为正式 Maestro 观察资产模式。

## 1. 当前主链

- `sage -> dev -> qa -> sage(close)`
- `sage -> design -> sage(close)`

规则：
1. Sage 负责发布、异常裁定、最终收口
2. Dev / Design 负责执行层交付
3. QA 负责测试裁定
4. Sage 发布任务后，若当前项目存在可用 Git 仓库与远端，必须立即 push，确保执行级角色可查看差分
5. 正常路径尽量自动推进到权限边界
6. 失败、冲突、规格不清时才打断用户
7. 任务进入 `closing` 后，Sage 若审核不通过，可正式执行 `transition rollback` 退回 `qa` 或 `in_progress`；这属于主链能力，不属于强制改卡
8. 仅在异常场景且用户明确授权时，Sage 才可使用 `./scripts/maestro transition force ...` 强制改卡；该操作必须留下正式 transition 与 journal 记录

## 2. 初始化 / 更新策略

初始化或重新初始化 Agent 工作流时，程序按 `.maestro/bootstrap_manifest.json` 执行，并先选择目标平台。

### 2.1 直接覆盖更新

以下文件属于共同母体文件，重新初始化时直接覆盖：
- `doc/SPEC.md`
- `doc/README_AGENT.md`
- `doc/WORKFLOW_RULES.md`
- `.maestro/agent_core_template.json`
- `.maestro/workflow_templates.json`
- `.maestro/task_contract_templates.json`
- `.maestro/bootstrap_manifest.json`
- `.maestro/skill_registry.json`
- `scripts/maestro`

按平台额外覆盖：
- `Codex`：`AGENTS.md`
- `Codex Skills`：`.codex/skills/<skill-id>/SKILL.md`
- `GitHub Copilot`：Maestro 当前默认导出到 `.github/copilot-instructions.md`
- `GitHub Copilot Skills`：Maestro 当前默认导出到 `.github/skills/<skill-id>/SKILL.md`

平台托管目录规则：
1. 当前平台的 skills 目录在刷新前应先清理，再重建
2. 非当前平台的托管目录应在初始化时移除，避免残留旧平台文件干扰
3. 只清理 Maestro 明确托管的目录，不扩大到用户其他自定义目录

### 2.2 仅在缺失时创建

以下文件属于项目真相源，重新初始化时只补缺，不覆盖：
- `.maestro/project.json`
- `.maestro/tasks.json`
- `.maestro/journal_entries.json`
- `.maestro/task_notes.json`
- `.maestro/gate_runs.json`
- `.maestro/transition_requests.json`
- `.maestro/issues.json`

原则：
1. 共同母体文件和当前平台附加文件可以刷新
2. 运行数据不得被初始化误伤

### 2.3 Schema 迁移

规则：
1. 运行时代码只认当前 schema，不长期背旧格式兼容。
2. 历史任务卡通过迁移机制升级，而不是让角色手改 JSON。
3. `tasks.json` 迁移必须执行：备份 -> 转换 -> 校验 -> 覆盖。
4. 若检测到旧字段或旧阶段语义（例如 `ownerRole=qa` 且 `execState=in_progress`），应先迁移成当前格式，再继续加载或显示。
5. 当前迁移入口为：
   - `./scripts/maestro migrate tasks`
   - App 打开项目时对 `tasks.json` 自动执行安全迁移
6. Git linked worktree 不得维护独立任务真相源；CLI 与 App 在 worktree 中运行时，必须统一回主项目根目录下的 `.maestro/`。
## 2.4 Skills 注入策略

Skills 的定位：
1. 承载专项工作流
2. 不替代仓库级总规则
3. 由同一份平台无关注册表统一管理

当前 2.0 原型 skills：
1. `sage-task-publish-review`
2. `dev-systematic-debugging`
3. `design-ui-shell`
4. `qa-verification-before-close`

规则：
1. 共同定义保存在 `.maestro/skill_registry.json`
2. 初始化时按目标平台导出到对应 skills 目录
3. Skill 只描述专项执行模块，不描述整个项目方法论
4. Skill 不重复任务卡中的目标、验收标准、边界与当前动作

## 2.5 四层落点规则

按下面的规则放置内容：

1. `SPEC.md`
   - 长期稳定的系统规则、契约、跨角色协议
2. `README_AGENT.md`
   - 所有 Agent 每次都该记住的最小硬规则
3. `Skill`
   - 命中特定任务类型后才需要的专项 SOP
4. `task context`
   - 当前这一张任务卡此时此刻的动态执行信息
5. `QA_ONE_PATH.md`
   - QA 的默认执行卡，只保留阶段判断、唯一动作与正式交接要求

判断标准：
1. “这个系统长期都这样” → 放 `SPEC.md`
2. “所有 Agent 每次都该记住” → 放 `README_AGENT.md`
3. “命中特定任务后具体怎么做” → 放 `Skill`
4. “这张卡片现在该做什么” → 放 `task context`
5. “QA 现在只该做哪一步” → 放 `QA_ONE_PATH.md`

补充：
1. `transition force` 的长期契约归 `SPEC.md`
2. `README_AGENT.md` 只保留最小可执行命令与禁令
3. Sage 的具体异常使用法放在 `sage-task-publish-review` skill

生命周期真相补充：
1. `execState` 是唯一生命周期真相。
2. `ownerRole`、`gateProfile`、看板列、建议下一步都属于派生伴随字段。
3. 若派生字段与 `execState` 冲突，运行时与文档都应围绕 `execState` 收敛，而不是制造第二生命周期真相。

## 3. 任务发布要求

Sage 发布任务时，必须一次性补全：
1. `summary`
2. `currentAction`
3. `acceptanceCriteria`
4. `boundaries`

若这些字段缺失，不应交接给执行级角色。

补充：
1. Sage 发布任务后，必须尽快 push 当前变更，让 Dev / QA 可查看真实差分。
2. 若当前项目缺少 git 仓库、远端或 push 失败，不得继续交接，应先标记阻塞前提。

## 4. Design 任务原则

Design 只做：
1. UI shell
2. 状态表达
3. 信息层级
4. Preview / fixture / 测试承载面

Design 不做：
1. 真实业务逻辑
2. 状态机改写
3. 真相源 schema 变更
4. 真实写回

补充：
1. `DESIGN.md` 是 Design 角色的知识约束层，负责产品气质、信息层级、状态表达、布局节奏与交互下限。
2. `design-ui-shell` 负责“怎么推进和交付”，`DESIGN.md` 负责“做出来别太离谱”。
3. 优先级固定为：`Task > Skill > DESIGN.md`
4. 当前阶段仅在 Maestro 自身项目内使用，先验证真实任务效果，不纳入初始化导出。

## 5. 测试面板原则

测试会话只允许两类步骤：
1. `execute`
2. `observe`

规则：
1. `execute` 自动执行，不要求 PO 输入
2. `observe` 才显示通过/不通过和备注
3. 连续 `execute` 必须自动跑完，直到遇到下一个 `observe`

补充职责边界：
1. 测试面板是工程测试工具，不属于 Design 范围。
2. Dev 负责实现测试驱动入口、debug panel、状态切换器、按钮和日志出口。
3. QA 负责定义测试入口需求：哪些分支需要入口、需要什么 reset/cleanup、需要哪些最小 debug 可见性、PO 最终要看什么。
4. Dev 负责把这些需求实现成可点击、可重复、可清空的测试面板或 debug 入口。
5. PO 只负责在测试面板中填写人工观察结果，不负责设计测试步骤。

## 5.1 QA 编排原则

1. UI 任务在 Dev 阶段先由 QA 提交测试入口需求，再由 Dev 实现；优先使用模板：`doc/examples/QA_ENTRY_REQUIREMENTS_TEMPLATE.md`，并通过 `task note --type test_entry_requirement` 回写正式交接。
2. 正式进入 QA 后，QA 只提交一条结构化最终裁定；优先使用模板：`doc/examples/QA_VERDICT_TEMPLATE.md`，并通过 `task note --type test_verdict` 回写正式交接。
3. 若 QA 判定任务契约与实际验证模式冲突，仍需先提交 `task note --type test_verdict` 作为唯一正式裁定；`task note --type contract_correction` 仅作为补充异常说明交给 Sage。
4. 系统主合同只保留 `verificationMode = logic_only | chat_observe`；需要正式观察留档时，用 `audit_required = true` 作为覆盖层。
5. QA 测试计划必须声明 `deliverySurface: logic | ui`。
6. 若 `deliverySurface = ui`，QA 的放行结论必须同时覆盖 `Truth / Projection / Observe / Final Verdict`；默认 Observe 来自 chat 反馈，只有 `audit_required = true` 才强制要求正式观察资产。
7. `verificationMode=logic_only`：QA 自己设计脚本、门禁与证据，不要求 PO 参与。
8. `verificationMode=chat_observe`：QA 先定义入口需求与观察清单，PO 只在 chat 中执行观察并回复结果。
9. `audit_required = true`：在 `chat_observe` 的基础上追加正式 Maestro 观察资产（`observe.json`、`results.json`、可选 `run.sh` / `rollback.sh`）。
10. 若任务只有轻量补充验证，不改变主模式，补充项写入 `secondaryChecks`。
11. QA 在请求任何 PO 动作前，必须先产出 5 行验证计划：`Test Mode / What I will do automatically / What PO must observe / Pass rule / Out of scope`。
12. 若 QA 还说不清“谁自动做、谁观察、如何裁定”，就说明测试方案尚未完成。
13. 只有 `audit_required = true` 时，任务级 QA 资产才必须放 `.maestro/tests/<TASK-ID>/`；默认 `chat_observe` 不要求这些资产。
14. `run.sh` / `rollback.sh` 仅用于正式审计模式下的自动 truth setup 或 probe，不得包含 `read` 或终端交互。
15. 若缺少 log / state / event / debug panel / 测试驱动入口，先提出 Dev Support Request。优先使用模板：`doc/examples/QA_SUPPORT_REQUEST_TEMPLATE.md`。
16. 测试入口需求定义权属于 QA；入口实现和面板组织权属于 Dev。
17. 测试入口需求阶段不引入新的主链状态；主任务仍停留在 Dev，直到功能和可测性一起完成。
18. 任务目录下的 `.md` 文件仅是草稿；草稿不参与 gate，正式结论必须回写 `task note`。
19. 对同一 `taskId + type` 的正式 QA note，系统默认只认时间最新的一条为当前有效记录。
20. `contract_correction` 只记录契约异常说明，不覆盖 `test_verdict`，也不参与 closing 判定；QA 是否能推进只看最新 `test_verdict`。
21. `doc/QA_CURRENT_FLOW_AND_DESIGN.md` 是系统总览；`doc/QA_ONE_PATH.md` 才是 QA 的默认执行入口。
22. `visual_only` / `guided_observe` 只允许作为 QA 内部心智模型或历史兼容语汇存在，不再作为系统对外主合同语言。

Observe 准入规则：
1. Observe 步骤必须可稳定复现。
2. Observe 步骤必须能被人类可靠判断。
3. Observe 步骤必须对最终产品体验有直接意义。
4. Observe 步骤必须不能被 Truth 证据替代。
5. 若拿不准某一步是否适合 Observe，默认回到 Truth。
6. 中间态、瞬态、短窗口状态默认不得交给 PO 观察。
7. 每个 Observe 步骤都必须说明：它支撑哪个最终裁定，以及为什么必须由人类观察。

最小分类判断：
1. 验收依赖日志、状态、文件系统、脚本输出、编译结果：优先 `logic_only`
2. 验收依赖人类观察最终 UI，且可以通过 Dev 提供的按钮、fixture、reset、debug visibility 完成：优先 `chat_observe`
3. 只有任务被显式标记 `audit_required = true` 时，才升级为正式 Maestro 观察资产模式。
4. 参考 demo：
   - `doc/examples/QA_SESSION_DEMO_LOGIC.md`
   - `doc/examples/QA_SESSION_DEMO_VISUAL.md`
   - `doc/examples/QA_SESSION_DEMO_BANNER.md`

## 5.2 UI 投影关联验证

对带 UI 的逻辑功能，QA 应优先采用“UI 投影关联验证”模型：
1. QA 先验证内部事件、状态、参数与时序成立（truth verification）。
2. PO 再观察 UI 是否正确显示该次事件的投影（projection observation）。
3. QA 最后裁定三者是否一致：事件存在、参数正确、时序正确、UI 投影正确。

最小要求：
1. 关键 UI 现象背后必须存在可关联的事件或状态输出。
2. 事件至少应具备：事件名、时间戳、traceId / itemId、关键参数。
3. QA 不能只验证“有事件”和“有 UI”，还必须验证“这次 UI 就是这次事件的投影”。

## 5.3 Maestro 观察面板职责

1. Maestro 观察面板只负责展示观察步骤、预期结果和收集人工输入。
2. 业务 App 的 debug/test panel 负责实际驱动状态、事件或 UI 场景。
3. PO 在业务 App 中点击，在 Maestro 中回填结果。
4. QA 基于客观 log / state / event 与 Maestro 回填结果做最终裁定。

## 5.4 JSON 上下文原则

1. `task context --json` 应作为执行级角色的首选读取入口。
2. 若最近一次 gate 失败，调用方应优先读取：
   - `latestFailedGate`
   - `failureEvidence`
3. 调用方应优先读取 `recommendedSkills` 与 `specClarification`，不要自行猜测下一步该参考哪份技能或如何处理规格不清。

## 6. 多语言规则

是否启用多语言约束，只看：
- `.maestro/project.json.isMultilingual`

若为 `false`：
- 不注入多语言 checklist / forbidden actions

若为 `true`：
- 多语言约束进入 checklist / forbidden actions

## 7. 最小有效规则原则

任何新增规则只有在明显降低歧义、错误率或沟通成本时，才允许进入系统。

若规则主要增加：
- 上下文长度
- 执行负担
- 官僚性

则应拒绝、合并或替换。
