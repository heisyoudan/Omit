# App Store Asset Production Checklist

用途：最终截图制作、审核和交付清单。所有勾选项都应在素材实际生成后填写，不以文档计划代替证据。

## A. 制作前门禁

- [ ] `TASK-REL-001` 已证明 App Store 发行变体不包含 Trash UI、设置项、授权与清空入口。
- [ ] 截图使用 App Store capability，而不是 Debug 条件、运行时猜测或后期遮挡。
- [ ] `StoreHeroLight`、`StoreHeroDark`、`StoreAppearanceSettings` fixture 可重复进入且数值固定。
- [ ] 三种 App UI 语言均已核对：zh-Hans、en-US、ja。
- [ ] System、Light、Dark 选择即时生效且选中态真实。
- [ ] 截图测试账户不包含私人用户名、通知、文件名或多余菜单栏信息。
- [ ] Thermal State 仍未完成时，确认 metadata 和截图目录中没有 Thermal 成品。

## B. 每张截图检查

- [ ] 2880×1800 px，16:10。
- [ ] PNG、RGB、扁平化、无 alpha channel。
- [ ] 未拉伸、未伪造 UI、未使用设备边框。
- [ ] 文字与面板均在左右 160 px、上下 120 px 安全区内。
- [ ] 营销标题不超过两行，副标题不抢过产品主体。
- [ ] App UI 语言与营销文案语言一致。
- [ ] Memory 显示估算已用量 / 物理总量，环与百分比一致。
- [ ] Storage 主值是可用空间，百分比明确写 Used 的本地化词。
- [ ] CPU、Battery、Network 使用指定 fixture 的 available 状态。
- [ ] Network 同时显示独立下行与上行。
- [ ] App Store 画面中不存在 Trash、Full Disk Access 或 GitHub Direct 文案。
- [ ] 不存在温度数字、性能提升、清理加速或隐私保证。
- [ ] 模块含义不只依赖颜色；状态标签可读。

## C. 文件清单

### zh-Hans

- [ ] `01-light-dashboard-zh-Hans.png`
- [ ] `02-dark-dashboard-zh-Hans.png`
- [ ] `03-appearance-settings-zh-Hans.png`

### en-US

- [ ] `01-light-dashboard-en-US.png`
- [ ] `02-dark-dashboard-en-US.png`
- [ ] `03-appearance-settings-en-US.png`

### ja

- [ ] `01-light-dashboard-ja.png`
- [ ] `02-dark-dashboard-ja.png`
- [ ] `03-appearance-settings-ja.png`

## D. Metadata 交付检查

- [ ] 三种语言的 Name、Subtitle、Promotional Text、Description、Keywords 已由 PO 审核。
- [ ] 字符数和 Keywords UTF-8 bytes 已在最终粘贴文本上重跑。
- [ ] Description 使用纯文本，没有 HTML。
- [ ] Keywords 没有应用名、公司名、竞品名或少于 3 字符的单项。
- [ ] What’s New 仅在 App Store Connect 实际要求时填写。
- [ ] Privacy Policy URL 由 PO 提供真实地址。
- [ ] Support URL 指向包含真实联系方式的页面。
- [ ] 没有用占位 URL、虚构法律主体或虚构联系信息。

## E. Thermal State 解锁检查

以下全部完成前，`04-thermal-state-<locale>.png` 与 Thermal metadata 条目保持 `BLOCKED`：

- [ ] nominal、fair、serious、critical、unavailable 已实现。
- [ ] 三种语言状态文案已实现。
- [ ] 状态不依赖颜色即可理解。
- [ ] 不显示、暗示或伪造温度数值。
- [ ] App Store capability 已真实接线。
- [ ] 截图 fixture 可稳定复现 `.fair`。
- [ ] 对应实现任务 gate 已通过。

## F. 最终 PO 决策

- [ ] 应用名称确认。
- [ ] 三种语言文案确认。
- [ ] 三张截图顺序确认。
- [ ] 背景色与标题排版确认。
- [ ] Privacy Policy URL 与 Support URL 已另行提供。
- [ ] 明确批准后才进入 App Store Connect 上传；本任务本身不上传。

