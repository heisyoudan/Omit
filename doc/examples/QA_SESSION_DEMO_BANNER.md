# QA 测试编排 Demo：Banner 会话

这个 demo 用来说明 QA 如何把一个“Banner 测试”翻译成可执行的正式审计方案。

## 一、先做分类

这个任务通常不是单纯视觉，也不是纯逻辑；当且仅当任务显式标记 `audit_required = true` 时，才升级为正式 Maestro 观察方案：
1. 先由程序自动准备异常场景
2. 再由 PO 观察 Banner 的视觉与交互结果

## 二、拆成两层验证

### Truth Verification（QA 自动）
- 通过脚本或状态注入触发：磁盘满、权限不足、trash 失败等异常。
- QA 验证：系统是否识别到了正确的异常类型，是否把正确状态送到 UI 层。

### Projection Verification（PO 输入）
- 测试面板只显示：开始测试 / 继续测试。
- 程序自动执行准备动作。
- 遇到 observe 步骤时暂停，并明确告诉 PO：
  - 看哪里
  - 预期是什么
  - 失败时备注写什么

## 三、标准会话结构

1. `execute`
   - 准备“磁盘满”场景
2. `observe`
   - 观察 Error Banner 是否出现，按钮是否为“打开存储设置”
3. `execute`
   - 清理上一轮状态，准备“trash 部分失败”场景
4. `observe`
   - 观察是否显示 Warning Banner，而不是 Error Banner
5. QA 汇总结果，决定 pass / rollback / blocked

## 四、QA 编排规则

- QA 先给出 5 行验证计划，再执行。
- Test Mode: `chat_observe + audit_required`
- What I will prove automatically: 通过脚本准备异常场景并证明状态驱动输入成立。
- What UI / projection I will verify: Banner 的等级、文案与按钮动作是否正确投影了当前异常。
- What PO must observe: Banner 的等级、文案、按钮动作。
- Pass rule: 所有 observe 步骤都与预期一致。
- Out of scope: 购买链路、本地化全量验证。
- PO 不接触脚本、fixture、内部目录结构。
- `execute` 只负责自动准备。
- `observe` 才接受 PO 输入。
- 逻辑验证与观察验证必须拆层，不混成一个模糊测试。

## 五、参考资产

本仓库提供了一份对应的最小 demo 资产，可直接帮助 QA 理解正式审计模式的文件结构：

- `templates/shared/test-demos/banner-session-demo/run.sh`
- `templates/shared/test-demos/banner-session-demo/rollback.sh`
- `templates/shared/test-demos/banner-session-demo/observe.json`

其中：
- `observe.json`：定义完整的 execute / observe 会话
- `run.sh`：仅在需要自动建立 truth 场景时使用
- `rollback.sh`：仅在需要清理并切换场景时使用
- `results.json`：由 Maestro 会话自动创建与维护，不要求 QA 预置

注意：
- 真实任务资产必须放 `.maestro/tests/<TASK-ID>/`
- 不要把任务专用 QA 脚本放在 `scripts/`
- execute 脚本不得要求 PO 在终端里按回车或输入文字
