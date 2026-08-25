# QA 测试编排 Demo：纯观察任务

这个 demo 用来说明 QA 如何处理默认 `verificationMode=chat_observe` 的普通 UI 观察任务。

## 适用场景

- 核心验收依赖 PO 肉眼判断样式、布局、动效、文案呈现
- 不需要复杂脚本准备或状态注入
- 例如：卡片 hover 样式、Banner 视觉层级、间距与排版

## 标准起手式

- Test Mode: `chat_observe`
- What I will prove automatically: 整理 projectionChecks，并用最小必要代码审查确认当前视图来源
- What UI / projection I will verify: 当前界面的布局、状态表达、文案与层级
- What PO must observe: 当前界面的视觉结果是否符合预期
- Pass rule: 所有观察点都符合预期
- Out of scope: 编译通过以外的复杂逻辑验证

## 最小执行步骤

1. 先确认这真的是纯观察任务，而不是“代码修复 + 顺便观察”
2. 列出观察点：
   - 看哪里
   - 预期是什么
   - 若失败，备注里该写什么
3. 只把观察路径交给 PO
4. QA 根据 PO 输入给出最终裁定

## 记录要求

- 不要把脚本、fixture 目录、内部实现细节暴露给 PO
- 若只有轻量补充逻辑验证，把它写进 `secondaryChecks`，不要把主模式改掉
