# EdgeTap

[中文文档](README_zh.md)

**EdgeTap** is a native macOS utility that turns your trackpad edges into gesture-driven shortcuts. Without changing your hand position, simply slide a finger along the trackpad's edge to trigger actions like adjusting volume or firing keyboard shortcuts.

## ✨ Features

- **Menu Bar App** — Lives quietly in the menu bar. No Dock icon, no clutter.
- **Continuous Volume Slider** — Assign any edge to volume control. Slide up/down along the edge to smoothly adjust system volume in real time, like a physical scroll wheel.
- **Custom Shortcuts on 4 Edges** — Bind independent keyboard shortcuts to swipe-up and swipe-down (or left/right) on each of the four edges (top, bottom, left, right).
- **Corner Taps** — Tap any of the four corners (top-left, top-right, bottom-left, bottom-right) to trigger an action instantly.
- **Deep Integration** — Powered by macOS's native `MultitouchSupport` private framework, reading raw capacitive data for accurate and responsive gesture detection.

## 🚀 Installation

### Option A: Download from Releases

1. Go to [Releases](https://github.com/kingwsi/EdgeTap/releases) and download the latest `EdgeTap-x.x.x.zip`.
2. Unzip and move `EdgeTap.app` to your Applications folder.
3. If macOS blocks the app, run: `xattr -cr /Applications/EdgeTap.app`

### Option B: Build from Source

Requires Swift 5.9+ and macOS 13.0+.

```bash
git clone https://github.com/kingwsi/EdgeTap.git
cd EdgeTap
./build_app.sh
open EdgeTap.app
```

## 🛡 Permissions

EdgeTap requires **Accessibility** permission to simulate key presses.

On first launch, the app will prompt you to grant access. Navigate to:

**System Settings → Privacy & Security → Accessibility**

> If running from Terminal, grant permission to your terminal app (e.g. Terminal.app or iTerm2).

## 🎮 Usage

1. Click the trackpad icon in the **menu bar** → **Settings**.
2. Toggle **"Enable EdgeTap"** to start listening.
3. Switch between edge tabs (Top, Bottom, Left, Right, Corners).
4. For each edge, choose:
   - **Volume Adjustment** — Continuous slide-to-adjust volume.
   - **Custom Shortcut** — Bind individual keyboard shortcuts per direction.

## 🏗 Architecture

| Layer | Description |
|-------|-------------|
| **EdgeTapApp** | UI, settings, shortcut & media key simulation |
| **EdgeTapCore** | Multitouch capture engine & gesture detection (`EdgeSwipeDetector`) |

## 📄 License

MIT — Free to use, fork, and modify.
