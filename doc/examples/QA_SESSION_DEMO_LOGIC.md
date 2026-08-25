# QA 测试编排 Demo：纯逻辑任务

这个 demo 用来说明 QA 如何处理 `qaMode=logic_only` 的任务。

## 适用场景

- 核心验收依赖编译、日志、状态、文件系统或脚本输出
- 不需要 PO 肉眼判断界面
- 例如：状态机修复、权限恢复链路、数据写回一致性

## 标准起手式

- Test Mode: logic_only
- What I will prove automatically: 运行脚本、门禁、日志检查并证明 truth 层成立
- What UI / projection I will verify: 仅在必要时做轻量补充确认
- What PO must observe: 无需 PO 参与
- Pass rule: 编译 / gate / 状态检查全部通过
- Out of scope: 视觉样式、动效、纯 UI 手感

## 最小执行步骤

1. 先重新确认这个任务是否真的无需 PO 参与
2. 写出自动验证路径：
   - 运行什么脚本
   - 看什么日志
   - 跑什么 gate
3. 产出最小证据：
   - gate 结果
   - 关键日志片段
   - 必要时补 task note / journal
4. 给出 QA 结论：
   - pass -> `closing`
   - fail -> rollback / blocked

## 记录要求

- 证据优先写进：
  - `gate run`
  - `submit journal`
  - `task note`
- 不要为了“让 PO 看一眼”把纯逻辑任务抬升成观察任务
