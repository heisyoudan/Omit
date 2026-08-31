<p align="center"><img src="resources/icon.png" width="120" alt="Omit icon"></p>
<h1 align="center">Omit.</h1>
<p align="center">
  <a href="https://github.com/heisyoudan/Omit/raw/main/dist/Omit.zip"><strong>📥 Download Omit 1.0.1</strong></a>
  &nbsp;•&nbsp;
  <a href="#english">English</a> • <a href="#中文">中文</a> • <a href="#日本語">日本語</a>
</p>

## English

**Omit noise. Return to essence.** A free, open-source macOS menu-bar monitor.

### Features and project status

- Memory and storage with solid-color rings; CPU, battery, network upload/download, and system thermal state.
- Translucent cards, restrained module colors, and System / Light / Dark appearance.
- Optional modules, adaptive layouts, English / Chinese / Japanese, and launch-at-login support.
- **No Trash access or cleaning in this download.** No history charts or numeric temperature.

Active development is on hold. App Store submission is postponed. This GitHub download and source remain available, but no update or support schedule is promised.

### Download and install

1. [Download Omit.zip](https://github.com/heisyoudan/Omit/raw/main/dist/Omit.zip) — macOS 13 or later; Universal binary for Apple silicon and Intel. Intel execution has not been verified on physical hardware.
2. Unzip and move **Omit.app** to **Applications**. Quit any older copy before replacing it.
3. This community build is **ad-hoc signed, not Developer ID signed or Apple notarized**. macOS may block it. Review Apple's [guidance for opening apps safely](https://support.apple.com/en-us/102445); proceed only if you trust this source. Do not disable system security globally.

Compare `shasum -a 256 Omit.zip` with [SHA256SUMS](dist/SHA256SUMS) to check download integrity. A matching checksum is not an Apple security review.

### What the numbers mean

- **Memory:** Omit's bounded used-memory estimate, not exact parity with Activity Monitor.
- **Storage:** available space on the startup volume; the ring and percentage show **used** capacity.
- **CPU:** aggregate utilization over a sampling interval, not a per-process measurement.
- **Network:** separate receive/transmit rates for the current primary routed interface, not all interfaces combined. Startup, interface changes, disconnects, or counter resets may briefly show `—`.
- **Battery:** percentage and power-source state; omitted on Macs without a battery.
- **Thermal:** macOS thermal state, **not degrees Celsius**. Text and segment count indicate severity.

Metric, scheduling, capability, and 16-layout checks are available in `scripts/`. These checks do not guarantee coverage of every machine or failure condition. See [metric semantics](doc/PRODUCT_SPEC.md).

### Build from source

Open `Omit.xcodeproj` in Xcode and build the `Omit` scheme. The default configuration disables Trash. The internal `OMIT_APP_STORE` flag selects this restricted capability set; it does **not** mean this GitHub build was submitted to the App Store. Legacy Direct/Trash code and branches are retained for future work and are not the supported download.

With Xcode and its command-line tools installed, reproduce the Universal community package using:

```sh
bash scripts/package-github.sh
```

The script builds Release, applies an ad-hoc signature with sandbox-only entitlements, verifies the bundle, and writes `dist/Omit.zip` plus its checksum. It does not notarize or upload anything.

## 中文

**剔除噪音。回归本质。** 免费、开源的 macOS 菜单栏状态监视器。

### 功能与项目状态

- 内存与磁盘纯色圆环，CPU、电池、网络上下行、系统热状态。
- 半透明卡片、克制的模块识别色，支持跟随系统、亮色和暗色模式。
- 模块开关、自适应布局、中英日三语和登录时启动。
- **本次下载不包含回收站访问或清空功能**，不提供历史曲线或具体温度。

项目现阶段暂停主动开发，App Store 上架计划暂缓。GitHub 下载和源码继续保留，暂不承诺更新或支持时间。

### 下载与安装

1. [下载 Omit.zip](https://github.com/heisyoudan/Omit/raw/main/dist/Omit.zip)：要求 macOS 13 或更新版本，包含 Apple 芯片与 Intel 的 Universal 二进制；尚未在 Intel 实机验证运行。
2. 解压后将 **Omit.app** 放入 **应用程序**；替换旧版前请先退出 Omit。
3. 此社区版本仅使用 **ad-hoc 签名，未经 Developer ID 签名和 Apple 公证**，macOS 可能阻止打开。请阅读 [Apple 的安全打开说明](https://support.apple.com/zh-cn/102445)，仅在信任来源时继续，不要关闭系统级安全保护。

可用 `shasum -a 256 Omit.zip` 与 [SHA256SUMS](dist/SHA256SUMS) 对照，确认下载文件完整；校验一致不代表通过了 Apple 安全审核。

### 数据口径与源码

内存是有边界保护的占用估算，不保证与“活动监视器”逐字节一致。磁盘主值为启动卷可用空间，圆环与百分比表示已用空间。CPU 为采样区间内的整机利用率。网络分别读取当前主路由接口的上下行计数，并非所有网卡总和；启动、断网或切换接口时可能短暂显示 `—`。无电池的 Mac 不显示电池卡片。热状态来自 macOS，**不是摄氏温度**。

仓库保留指标、调度、能力隔离及 16 种布局的自动检查，但不保证所有机器和异常情况都没有问题。自行编译可打开 `Omit.xcodeproj`；打包使用 `bash scripts/package-github.sh`。默认构建不启用回收站，内部 `OMIT_APP_STORE` 标志只用于选择受限能力，并不代表上架。旧 Direct/Trash 代码仅为未来开发保留。

## 日本語

**ノイズを削ぎ落とし、本質へ回帰する。** 無料・オープンソースの macOS メニューバーモニター。

### 機能と開発状況

- 単色リングによるメモリ・ストレージ表示、CPU、バッテリー、ネットワーク送受信、システムの熱状態。
- 半透明カード、控えめなモジュールカラー、システム連動・ライト・ダーク表示。
- モジュール切り替え、可変レイアウト、英語・中国語・日本語、ログイン時の起動。
- **この配布版にはゴミ箱へのアクセス・削除機能は含まれません。** 履歴グラフや数値温度もありません。

現在、積極的な開発を休止しています。App Store への申請は延期しました。GitHub のダウンロードとソースは公開を継続しますが、更新・サポート時期は未定です。

### ダウンロードとインストール

1. [Omit.zip をダウンロード](https://github.com/heisyoudan/Omit/raw/main/dist/Omit.zip)。macOS 13 以降。Apple シリコンと Intel 向けの Universal バイナリです。Intel 実機での動作は未検証です。
2. 解凍して **Omit.app** を **アプリケーション** に移動します。旧版を置き換える前に Omit を終了してください。
3. このコミュニティ版は **ad-hoc 署名のみで、Developer ID 署名・Apple 公証はありません**。macOS が起動をブロックする場合があります。[Apple の安全な起動についての説明](https://support.apple.com/ja-jp/102445)を確認し、配布元を信頼できる場合のみ進めてください。システム全体のセキュリティを無効にしないでください。

`shasum -a 256 Omit.zip` の結果を [SHA256SUMS](dist/SHA256SUMS) と比較するとダウンロードの整合性を確認できます。これは Apple による安全性の審査を意味しません。

### 表示値とソースについて

メモリは使用量推定で、アクティビティモニタとの完全一致は保証しません。ストレージの主値は起動ボリュームの空き容量、リングと割合は使用済み容量です。CPU は一定区間の全体使用率です。ネットワークは主ルートインターフェイスの送受信を別々に計測し、全インターフェイスの合計ではありません。起動直後や接続変更時は一時的に `—` になる場合があります。バッテリー非搭載機ではバッテリーカードを表示しません。熱状態は macOS の状態区分であり、**摂氏温度ではありません**。

自動検証は `scripts/` にありますが、すべての機種・異常状態を保証するものではありません。ビルドには `Omit.xcodeproj`、パッケージ作成には `bash scripts/package-github.sh` を使用します。デフォルト構成ではゴミ箱機能は無効です。内部の `OMIT_APP_STORE` フラグは機能制限の選択用で、App Store への申請を意味しません。旧 Direct/Trash コードは将来の開発用に残しています。

---

Licensed under [MIT](LICENSE). Designed & developed by **Heisyoudan**.
