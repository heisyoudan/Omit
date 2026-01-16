# Omit

<p align="center">
  <img src="https://img.shields.io/badge/Platform-macOS%2013%2B-blue" alt="Platform">
  <img src="https://img.shields.io/badge/Swift-5.9-orange" alt="Swift">
  <img src="https://img.shields.io/badge/License-MIT-green" alt="License">
</p>

A minimal, beautiful menu bar system monitor for macOS.

**Omit** lives in your menu bar and provides real-time monitoring of your Mac's vital stats with a clean, modern interface.

## ✨ Features

- **📊 Memory Monitor** - Track active memory usage and total RAM
- **💾 Storage Monitor** - View available disk space at a glance
- **⚡ CPU Load** - Real-time CPU usage percentage
- **🔋 Battery Status** - Battery level with charging indicator
- **📡 Network Speed** - Live download speed monitoring
- **🗑️ Trash Size** - Monitor trash bin size with one-tap empty

## 🌍 Localization

Omit supports multiple languages out of the box:
- 🇺🇸 English
- 🇨🇳 中文
- 🇯🇵 日本語

## 🖼️ Screenshots

<!-- Add your screenshots here -->
<!-- ![Screenshot](screenshots/screenshot1.png) -->

## 📦 Installation

### Requirements
- macOS 13.0 (Ventura) or later
- Apple Silicon or Intel Mac

### Quick Download (Recommended for Users)

1. Download the latest `Omit.dmg` from [Releases](../../releases)
2. Open the DMG file
3. Drag `Omit` to the **Applications** folder
4. Open **Applications** folder and double-click `Omit`

#### ⚠️ First Launch Security Notice

Since Omit is not signed by Apple, you may see a security warning:
```
"Omit" cannot be opened because the developer cannot be verified.
```

**To fix this, use one of these methods:**

**Method 1: Right-Click to Open (Simplest)**
1. Right-click `Omit.app` in Applications
2. Select "Open" 
3. Click "Open" in the dialog

**Method 2: Disable the Check (Advanced)**
```bash
# Run this command in Terminal once
codesign --force --deep --sign - /Applications/Omit.app
```

**Why this happens?** Omit is not signed by Apple's official certificate. This is completely safe—it's just macOS being cautious.

### Build from Source (for Developers)

```bash
git clone https://github.com/YOUR_USERNAME/Omit.git
cd Omit
open Omit.xcodeproj
```
Then build and run in Xcode (⌘+R).

### Build and Package for Distribution (Developers Only)

```bash
# Make the build script executable
chmod +x build.sh

# Run the build script
./build.sh

# Output: dist/Omit.dmg (ready for distribution)
```

## ⚙️ Preferences

- **Display Modules** - Toggle individual monitoring widgets
- **Launch at Login** - Start Omit automatically when you log in
- **Language** - Switch between supported languages

### Full Disk Access (Optional)
To monitor trash bin size, Omit needs Full Disk Access permission:
1. Open **System Settings** → **Privacy & Security** → **Full Disk Access**
2. Toggle **Omit** ON

## 🎨 Design Philosophy

Omit follows a minimalist design philosophy:
- **Clean Interface** - No clutter, just the information you need
- **Dark Mode Native** - Designed to blend with macOS dark theme
- **Zen Mode** - Hide all modules for a completely minimal experience
- **User-Friendly** - Helpful permission prompts guide you through setup

## ❓ FAQ

**Q: Is Omit safe to use?**
A: Yes! The source code is open on GitHub, and you can verify it yourself. The security warning on first launch is normal for unsigned apps on macOS.

**Q: Why do I see a security warning?**
A: Omit is not signed by Apple's official certificate. This is completely normal for indie macOS apps. You can safely bypass it (see Installation section).

**Q: Does Omit collect my data?**
A: No. Omit runs locally and does not collect or send any data anywhere. All monitoring happens on your device only.

**Q: Can I use Omit on older macOS versions?**
A: Omit requires macOS 13.0 (Ventura) or later due to SwiftUI requirements.

**Q: How often does Omit update the stats?**
A: Every second, keeping your information current and fresh.

## 🛠️ Tech Stack

- SwiftUI
- Combine
- IOKit (Battery monitoring)
- ServiceManagement (Launch at Login)

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🤝 Contributing

Contributions are welcome! Feel free to:
- Report bugs
- Suggest new features
- Submit pull requests

## 📮 Contact

Created by [@heisyoudan](https://github.com/heisyoudan)

---

<p align="center">Made with ❤️ for macOS</p>
