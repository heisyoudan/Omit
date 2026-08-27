# Mac App Store Screenshot Storyboard

状态：截图制作规范；尚未生成最终素材  
发行：Mac App Store  
首发数量：每个本地化 3 张，共 9 个文件  
保留镜头：Thermal State 1 张，当前 `BLOCKED`

## 1. Apple 交付规格

- Mac 截图必须使用 16:10。
- 可接受尺寸：1280×800、1440×900、2560×1600、2880×1800 px。
- 本项目统一产出：`2880×1800 px`、PNG、RGB、扁平化、无 alpha channel。
- 每个本地化最少 1 张、最多 10 张；本项目首发使用 3 张。
- 不使用设备边框、第三方商标、第三方壁纸、私人菜单栏信息或未经授权素材。

官方参考：

- [Screenshot specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications/)
- [Upload app previews and screenshots](https://developer.apple.com/help/app-store-connect/manage-app-information/upload-app-previews-and-screenshots)

## 2. 统一画布与安全区

- 画布：2880×1800 px。
- 外安全区：左右各 160 px，上下各 120 px；标题、副标题和 Omit 面板均不得越界。
- 标题区：距顶部 180–260 px；最多两行，不贴近 App Store 裁切边缘。
- 产品区：使用生产 UI 或本文指定 fixture 的真实渲染；保持面板比例，不拉伸。
- 菜单栏关系：至少在第 1 张保留 Omit 菜单栏入口与面板连接关系；其他镜头可使用干净的面板近景。
- 背景：使用自制的暖中性 Light 或近黑 Dark 纯色/轻渐变；不得使用 macOS 官方宣传壁纸。
- 字体：SF Pro / 系统字体；标题建议 76–88 px，副标题 34–42 px。
- 文案对比度：正文与背景至少按 4.5:1 目标检查；不可只靠模块色区分含义。
- 画面净化：时间、Wi-Fi、电量、用户名、通知、文件名及其他菜单栏图标需隐藏或使用干净测试账户。

## 3. 固定截图 Fixture 合同

截图不得依赖瞬时真实采样。使用固定 fixture 或等价的生产截图驱动，三种语言保持同一组数值：

| Fixture | Memory | Storage | CPU | Battery | Network ↓ / ↑ | Appearance | 模块 |
|---|---|---|---|---|---|---|---|
| `StoreHeroLight` | 10.8 / 16 GB，68% | 182 GB available，55% used | 18% | 82%，Charging | 2.4 MB/s / 180 KB/s | Light | Memory, Storage, CPU, Battery, Network |
| `StoreHeroDark` | 12.1 / 16 GB，76% | 176 GB available，57% used | 32% | 64%，On Battery | 840 KB/s / 96 KB/s | Dark | Memory, Storage, CPU, Battery, Network |
| `StoreAppearanceSettings` | 与 `StoreHeroLight` 相同 | 与 `StoreHeroLight` 相同 | 与 `StoreHeroLight` 相同 | 与 `StoreHeroLight` 相同 | 与 `StoreHeroLight` 相同 | System selected；Light/Dark 均可见 | App Store 模块设置，不含 Trash |

统一要求：

- App Store capability 固定为开启；Trash 卡片、Trash 开关、授权、清空和相关文案必须完全不存在。
- CPU、Battery、Network 均使用 available 状态，不使用 `—`。
- Storage 主值为 available，百分比必须带 Used 本地化标签。
- Memory supporting value 必须表达 used / physical total。
- Network 必须同时显示独立下行与上行。
- footer 使用本地化的“刚刚更新 / Updated just now / たった今更新”。

## 4. 首发截图序列

### 01 — Light Dashboard：三秒理解产品

| 项目 | 规格 |
|---|---|
| 语言 | zh-Hans、en-US、ja 各导出一张；App UI 与营销文案使用同一语言 |
| 主题 | Light |
| 模块组合 | Memory、Storage、CPU、Battery、Network；无 Trash、无 Thermal |
| 真实状态 | `StoreHeroLight` 固定 fixture；全部 available |
| 主标题 zh-Hans | 三秒读懂你的 Mac 状态 |
| 副标题 zh-Hans | 关键状态都在菜单栏里，打开就能看懂。 |
| Headline en-US | Your Mac status at a glance |
| Subheadline en-US | The essentials are right in the menu bar. |
| 主タイトル ja | Macの状態を3秒でひと目に |
| サブタイトル ja | 必要な情報をメニューバーですぐ確認。 |
| 取景 | 左侧标题、右侧面板；保留 Omit 菜单栏入口与展开关系；面板完整，不裁卡片 |
| 安全区 | 所有文字和面板距左右 ≥160 px、上下 ≥120 px |
| 就绪条件 | 可通过 App Store capability 或截图专用 fixture 稳定隐藏 Trash 后制作 |

### 02 — Dark Dashboard：亮暗同等清晰

| 项目 | 规格 |
|---|---|
| 语言 | zh-Hans、en-US、ja 各导出一张；App UI 与营销文案使用同一语言 |
| 主题 | Dark |
| 模块组合 | Memory、Storage、CPU、Battery、Network；无 Trash、无 Thermal |
| 真实状态 | `StoreHeroDark` 固定 fixture；全部 available |
| 主标题 zh-Hans | 亮色或暗色，同样一目了然 |
| 副标题 zh-Hans | 信息层级不变，只选择适合你的外观。 |
| Headline en-US | Clear in Light or Dark |
| Subheadline en-US | The same hierarchy, in the appearance you prefer. |
| 主タイトル ja | ライトでもダークでも、ひと目で把握 |
| サブタイトル ja | 情報の順序はそのまま。好みの外観を選べます。 |
| 取景 | 面板居中偏右，背景近黑；完整保留 Network 上下行、Battery 状态和 footer |
| 安全区 | 所有文字和面板距左右 ≥160 px、上下 ≥120 px |
| 就绪条件 | 可通过 App Store capability 或截图专用 fixture 稳定隐藏 Trash 后制作 |

### 03 — Appearance Settings：真实切换表达

| 项目 | 规格 |
|---|---|
| 语言 | zh-Hans、en-US、ja 各导出一张；App UI 与营销文案使用同一语言 |
| 主题 | System；截图环境固定为 Light，以便同时看清三项选择 |
| 模块组合 | Settings 中 System / Light / Dark 三项完整可见；App Store 模块列表不含 Trash |
| 真实状态 | `StoreAppearanceSettings`；System 为当前选中，Light / Dark 为可选项 |
| 主标题 zh-Hans | 外观跟随你，也可以由你决定 |
| 副标题 zh-Hans | 跟随系统、亮色、暗色，选择即时生效。 |
| Headline en-US | Follow the system—or choose |
| Subheadline en-US | Switch between System, Light, and Dark instantly. |
| 主タイトル ja | システムに合わせる。自分で選ぶ。 |
| サブタイトル ja | システム、ライト、ダークをすぐに切り替え。 |
| 取景 | Settings 面板完整；Appearance 为视觉焦点，选中态清晰；不可通过裁切掩盖不合规设置项 |
| 安全区 | 所有文字和面板距左右 ≥160 px、上下 ≥120 px |
| 就绪条件 | `BLOCKED by TASK-REL-001`：App Store Settings 必须先真实移除 Trash 设置项，再制作最终截图 |

## 5. 保留截图 04 — Thermal State：BLOCKED

此镜头不属于首发 9 个文件，禁止提前输出、占位或上传。

| 项目 | 规格 |
|---|---|
| 语言 | zh-Hans、en-US、ja |
| 主题 | Dark |
| 模块组合 | Memory、Storage、CPU、Network、Thermal；无 Trash；Battery 可按 fixture 保留 |
| 状态 | Thermal `.fair` 固定 fixture；标签必须直接写明状态，颜色仅作辅助；不得显示温度数字 |
| 主标题 zh-Hans | 查看系统热状态，不虚构温度 |
| 副标题 zh-Hans | 只呈现 macOS 提供的状态。 |
| Headline en-US | See the system thermal state |
| Subheadline en-US | Reported by macOS, without a made-up temperature. |
| 主タイトル ja | システムの熱状態を確認 |
| サブタイトル ja | macOSが報告する状態だけを表示します。 |
| 解除条件 | nominal / fair / serious / critical / unavailable 全部实现并本地化；fixture 可复现；App Store capability 接线；对应 gate 通过 |

## 6. 文件命名与排序

```text
zh-Hans/01-light-dashboard-zh-Hans.png
zh-Hans/02-dark-dashboard-zh-Hans.png
zh-Hans/03-appearance-settings-zh-Hans.png
en-US/01-light-dashboard-en-US.png
en-US/02-dark-dashboard-en-US.png
en-US/03-appearance-settings-en-US.png
ja/01-light-dashboard-ja.png
ja/02-dark-dashboard-ja.png
ja/03-appearance-settings-ja.png
```

Thermal 解锁后使用 `04-thermal-state-<locale>.png`，并在三种语言同时具备素材后才加入商品页，避免本地化之间叙事不一致。

