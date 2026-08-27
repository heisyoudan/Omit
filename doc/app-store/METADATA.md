# App Store Metadata Draft

状态：PO 审核草稿  
适用发行：Mac App Store  
本地化：简体中文、English、日本語  
更新：2026-08-27

## 1. 字段限制基线

以下限制按 Apple App Store Connect 官方文档核对：

| 字段 | Apple 限制 | 本稿检查方式 |
|---|---:|---|
| Name | 2–30 字符 | Unicode 字符数 |
| Subtitle | 最多 30 字符 | Unicode 字符数 |
| Promotional Text | 最多 170 字符 | Unicode 字符数 |
| Description | 最多 4,000 字符，纯文本，不支持 HTML | Unicode 字符数 |
| Keywords | 最多 100 bytes；逗号分隔；单项多于 2 个字符 | UTF-8 bytes |
| What’s New in This Version | 最多 4,000 字符；首次版本不要求，后续更新需要 | Unicode 字符数 |

官方参考：

- [App information — Name / Subtitle](https://developer.apple.com/help/app-store-connect/reference/app-information/app-information)
- [Platform version information — Promotional Text / Description / Keywords / What’s New](https://developer.apple.com/help/app-store-connect/reference/app-information/platform-version-information/)
- [Required, localizable, and editable properties](https://developer.apple.com/help/app-store-connect/reference/app-information/required-localizable-and-editable-properties)

计数包含空格、换行和标点。Keywords 单独以 UTF-8 bytes 检查。App Store Connect 最终保存时仍需再做一次平台内校验。

## 2. 简体中文（zh-Hans）

### 应用名称

```text
Omit
```

检查：4 / 30 字符，PASS。

### 副标题

```text
三秒读懂你的 Mac 状态
```

检查：13 / 30 字符，PASS。

### 推广文本

```text
打开菜单栏，三秒查看内存、存储空间、CPU、电池与网络状态。Omit 以安静、原生的亮色与暗色界面，只保留当下需要的信息。
```

检查：61 / 170 字符，PASS。

### 完整描述

```text
Omit 是一款安静、克制的 macOS 菜单栏状态工具。打开面板，你可以在几秒内了解 Mac 当前的关键状态，然后继续手上的事。

一眼查看
• 内存：显示估算已用内存、物理内存总量与使用比例
• 存储空间：以可用空间为主值，并明确标注已用比例
• CPU：显示整体处理器使用率
• 电池：显示电量与充电状态
• 网络：分别显示下行与上行速度

只保留需要的信息
内存和存储空间保持清晰的主要层级，其他状态卡片根据你启用的模块排列。你可以在设置中单独显示或隐藏模块，让面板保持简洁。

自然融入 macOS
Omit 提供跟随系统、亮色和暗色三种外观。界面使用清晰的语义、克制的色彩与紧凑布局，不加入曲线图、进程列表或复杂诊断信息。

Omit 适合希望快速了解 Mac 状态，又不想停留在大型监控仪表盘中的用户。
```

检查：358 / 4,000 字符，PASS。

### 关键词

```text
系统监控,菜单栏工具,内存状态,存储空间,处理器,电池状态,网络状态
```

检查：90 / 100 UTF-8 bytes，PASS。未重复应用名称，未包含竞品或公司名称；每项均多于 2 个字符。

### 版本说明草稿

```text
Omit 首次发布。可从菜单栏查看内存、存储空间、CPU、电池和网络状态，并可选择跟随系统、亮色或暗色外观。
```

检查：54 / 4,000 字符，PASS。首次版本通常不要求填写；仅在 App Store Connect 显示该字段时使用。

## 3. English (en-US)

### App Name

```text
Omit
```

Check: 4 / 30 characters, PASS.

### Subtitle

```text
Your Mac status at a glance
```

Check: 27 / 30 characters, PASS.

### Promotional Text

```text
Open the menu bar and understand Memory, Storage, CPU, Battery, and Network status in seconds. Omit stays quiet, native, and clear in both Light and Dark.
```

Check: 154 / 170 characters, PASS.

### Description

```text
Omit is a quiet, focused system status utility for the macOS menu bar. Open the panel, understand the essential state of your Mac in seconds, and get back to what you were doing.

See the essentials at a glance
• Memory: estimated used memory, physical total, and usage percentage
• Storage: available space as the primary value, with the used percentage clearly labeled
• CPU: total processor utilization
• Battery: charge level and charging state
• Network: separate download and upload rates

Keep only what matters
Memory and Storage retain a clear primary hierarchy while the remaining status cards arrange around the modules you enable. Show or hide modules individually in Settings to keep the panel focused.

At home on macOS
Choose System, Light, or Dark appearance. Omit uses clear labels, restrained color, and a compact layout—without charts, process lists, or a dense diagnostics dashboard.

Omit is for people who want a quick read on their Mac without living in a monitoring app.
```

Check: 994 / 4,000 characters, PASS.

### Keywords

```text
system monitor,menu bar,memory,storage,cpu,battery,network,status,mac utility
```

Check: 77 / 100 UTF-8 bytes, PASS. The app name, company names, and competitor names are not repeated; every item is longer than two characters.

### What’s New Draft

```text
Introducing Omit. See Memory, Storage, CPU, Battery, and Network status from the menu bar, with System, Light, and Dark appearance options.
```

Check: 139 / 4,000 characters, PASS. This field is normally required for updates, not the first version; use only if App Store Connect presents it.

## 4. 日本語（ja）

### アプリ名

```text
Omit
```

確認：4 / 30 文字、PASS。

### サブタイトル

```text
Macの状態を3秒でひと目に
```

確認：14 / 30 文字、PASS。

### プロモーションテキスト

```text
メニューバーを開くだけで、メモリ、ストレージ、CPU、バッテリー、ネットワークの状態をすばやく確認。Omitはライトでもダークでも、静かで自然な見やすさを保ちます。
```

確認：82 / 170 文字、PASS。

### 詳細説明

```text
Omitは、macOSのメニューバーで使える、静かで簡潔なシステムステータスツールです。パネルを開けば、Macの大切な状態を数秒で確認し、すぐに作業へ戻れます。

必要な情報をひと目で
• メモリ：推定使用量、物理メモリ総量、使用率
• ストレージ：空き容量を主な値として表示し、使用率を明記
• CPU：プロセッサ全体の使用率
• バッテリー：残量と充電状態
• ネットワーク：ダウンロードとアップロードを個別に表示

必要なものだけを表示
メモリとストレージを主要な情報として保ちながら、ほかのステータスカードは有効なモジュールに合わせて並びます。設定では各モジュールを個別に表示・非表示にできます。

macOSになじむ外観
システム、ライト、ダークから外観を選べます。明確なラベル、控えめな色、コンパクトなレイアウトで、グラフやプロセス一覧、複雑な診断画面は表示しません。

大きな監視アプリを開き続けることなく、Macの状態をすばやく把握したい人のためのアプリです。
```

確認：438 / 4,000 文字、PASS。

### キーワード

```text
システム,メニュー,メモリ,ストレージ,バッテリー,ネットワーク
```

確認：86 / 100 UTF-8 bytes、PASS。アプリ名、企業名、競合名は含まず、各項目は 2 文字を超えています。

### バージョン情報の草案

```text
Omitの最初のリリースです。メニューバーからメモリ、ストレージ、CPU、バッテリー、ネットワークの状態を確認でき、システム、ライト、ダークの外観を選べます。
```

確認：79 / 4,000 文字、PASS。初回バージョンでは通常不要です。App Store Connect にフィールドが表示された場合のみ使用します。

## 5. Thermal State 条件草稿 — BLOCKED

当前生产 UI 与任务清单中没有系统 Thermal State 的完成证据。以下内容不得加入上述三套正式 metadata，也不得出现在首发截图中。

解除条件：系统 Thermal State 已实现 nominal / fair / serious / critical / unavailable，完成三语言本地化、App Store 发行配置接线和可复现 fixture，并通过对应任务门禁。

解除后可在功能列表追加：

- 简体中文：`• 热状态：显示 macOS 提供的系统热状态，不显示温度数值`
- English: `• Thermal State: the system state reported by macOS, without a numeric temperature`
- 日本語：`• 熱状態：macOSが報告するシステム状態を表示し、温度の数値は表示しません`

此条件草稿只描述系统状态，不承诺真实温度、降温、加速、性能提升或硬件诊断。

## 6. Claims Audit

三套正式稿均已检查：

- 包含：三秒理解、菜单栏、Memory、Storage、CPU、Battery、Network、模块显示、System/Light/Dark。
- 不包含：Trash、Full Disk Access、GitHub Direct、温度数值、风扇、GPU、清理或加速承诺。
- 不包含：无法证明的性能提升、低资源占用、隐私保证、Activity Monitor 等值承诺。
- Memory 明确为 estimated / 推定 / 估算，避免声称与其他系统工具逐字节一致。
