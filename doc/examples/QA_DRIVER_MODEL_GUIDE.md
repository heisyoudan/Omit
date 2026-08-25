# QA 验证链模板：Truth / Projection / Human Acceptance

这份模板用来帮助 QA 在接到任务后的第一分钟完成测试方案设计，而不是盲目跟随标签。

## 固定起手式

先回答下面 4 个问题：

1. **Truth Source 是什么？**
   - 哪个状态、事件、日志、文件、脚本输出、调试输出可以证明“事实已经成立”？
2. **Projection Surface 是什么？**
   - 哪个 UI、文案、列表项、banner、badge、按钮状态会投影这层事实？
3. **Human Acceptance Scope 是什么？**
   - 哪一部分仍然必须由 PO / Design 通过肉眼或体验判断？
4. **Verification Strategy 是什么？**
   - 先证明 truth，还是先建立 projection，再进入最小人工观察？

## 固定 6 行验证计划

- `Test Mode`
- `What I will prove automatically`
- `What UI / projection I will verify`
- `What PO must observe`
- `Pass rule`
- `Out of scope`

## 分类顺序

1. 如果任务的核心验收依赖脚本、日志、状态、文件系统、门禁或编译结果：
   - 主模式优先选 `logic_only`
2. 如果任务的核心验收依赖 UI 呈现和体验：
   - 主模式优先选 `chat_observe`
3. 如果任务还要求正式可追溯的观察资产：
   - 保持主模式为 `chat_observe`
   - 额外打开 `audit_required = true`

补充验证一律写进 `secondaryChecks`，不要因为一个轻量观察就把整个任务抬升成重型观察链。

## Truth / Projection / Human Acceptance 示例

### 例 1：状态同步 Bug 修复
- Truth Source：脚本输出、状态 dump、gate 结果
- Projection Surface：列表项状态、badge 文案
- Human Acceptance Scope：可选，仅确认画面没有明显分裂

### 例 2：Banner 视觉收口
- Truth Source：轻量代码审查或现成 debug panel
- Projection Surface：Banner 本身
- Human Acceptance Scope：颜色、层级、文案、动作是否合理

### 例 3：错误类型驱动 Banner
- Truth Source：错误类型与驱动状态的一一对应
- Projection Surface：Banner 等级、文案、按钮
- Human Acceptance Scope：最终 UI 呈现是否可接受

## 资产模板要求

### logic_only
- 可以没有 `observe.json`
- 重点是脚本、日志、状态 dump、gate 结果

### chat_observe
- 不要求复杂脚本
- 重点是 QA 通过 chat 提供观察点、预期和失败备注模板
- 默认不要求 Maestro observation 资产

### chat_observe + audit_required
- Dev 阶段的入口需求优先参考：`doc/examples/QA_ENTRY_REQUIREMENTS_TEMPLATE.md`
- 正式 QA 裁定优先参考：`doc/examples/QA_VERDICT_TEMPLATE.md`
- 需要 Dev 补可测性时，优先参考：`doc/examples/QA_SUPPORT_REQUEST_TEMPLATE.md`
- 必须具备：
  - `.maestro/tests/<TASK-ID>/observe.json`
- `results.json` 由 Maestro 会话自动创建和维护
- 仅当 truth setup / probe 需要自动化时，再提供：
  - `run.sh`
  - `rollback.sh`
- 任务测试资产不要放在 `scripts/`
- execute 脚本不得包含 `read` 或终端交互

## 最后判断

QA 的职责不是证明“标签对不对”，而是建立一条可证明的验证链：

- 先证明 truth
- 再验证 projection
- 最后只把必要的人类判断留给 PO / Design
