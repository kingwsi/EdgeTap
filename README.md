# EdgeTap

**EdgeTap** 是一款原生的 macOS 增强工具，通过监听触控板边缘的滑动和角落点击，帮助你以前所未有的速度和直觉方式触发快捷操作。无需改变你的握持姿势，只要手指贴着触控板边缘“走一遭”，就能实现调整音量、触发应用快捷键等功能。

## 🌟 核心特性 (Features)

*   **极简驻留**：超轻量的菜单栏应用，不占用 Dock 栏，所有的设置整合在极致简洁的原生界面里。
*   **边缘连贯滑轨 (Continuous Slider)**：
    *   **无缝音量控制**：将触控板边缘化身“虚拟调节滚轮”。设定某个边缘（例如左侧）为“音量调节”后，只要在该边缘上下滑动，即可如丝般顺滑地进行 **连续步进式** 的系统音量增减，随滑随动。
*   **四边自定义动作** (Custom Shortcuts)：
    *   在顶部、底部、左侧、右侧，分别绑定上滑、下滑、左滑、右滑动作的单独快捷键组合（例如：`Cmd + C`、`Option + Space`）。
    *   支持绑定如静音 (Mute) 等基础媒体键。
*   **四周角落点击**：四个对角（左上、右上、左下、右下）均可设置点击手势，一触即发。
*   **底层加持**：深度接入 macOS 原生的 `MultitouchSupport` 私有框架，捕捉最源头的触控板电容阵列数据。准确率即使是在极高精度或快速移动中也令人叹服。

## 🛠 构架 (Architecture)

应用被设计为多层结构：
1.  **EdgeTapApp**: 前端 UI 与设置中心、快捷键和媒体键仿真器 (`ShortcutExecutor`)。
2.  **EdgeTapCore**: 多点触控底层的捕获引擎 (`MultitouchManager`) 与手势坐标识别系统 (`EdgeSwipeDetector`)。

## 🚀 安装与编译 (Build)

1. 环境依赖：
   - Swift 5.9+ / macOS 13.0+
   - Xcode 15+ 

2. 在终端使用 Swift Package Manager 直接编译运行：
   ```bash
   cd EdgeTap
   swift build
   swift run EdgeTapApp
   ```
*(你也可以使用 `swift package generate-xcodeproj` 导出给 Xcode 打开)*

## 🛡 权限提示 (Permissions)

`EdgeTap` 依赖于系统的底层触控板监听以及键盘按键仿真功能。在首次启用 "Enable EdgeTap" (启动监听) 时：
* 系统可能会拦截操作。
* `EdgeTap` 界面将自动弹窗提醒。
* 请进入 macOS 的系统设置 **「隐私与安全性 -> 辅助功能」**（Privacy & Security -> Accessibility），并为对应的终端 (如 Terminal/iTerm2，或如果你打包成了 .app，请授权给 EdgeTap) 开启允许。

## 🎨 界面展示与使用指导 (Usage)

1. 点击 macOS 右上角菜单栏的图标打开 **Settings... (设置)**。
2. 开启第一行的总开关：「启用 EdgeTap (Enable EdgeTap)」。
3. 在下方标签页中切换你想要定制的边缘（Top, Bottom, Left, Right, Corners）。
4. 在每个边缘面板，你可以一键选择将其设置为全局滑轨 **“音量调节”**，或是分别自定义其正反方向上的 **“自定义按键”** 操作组合。

## 📝 证书 (License)
本项目目前为个人折腾项目。随意 Fork, 随意自用。
