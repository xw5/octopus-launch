# Release Notes / 发布说明

## v1.0.0 — 2026-11-25

<a id="中文"></a>

### 中文

octopus-launch（章鱼启动）**首个正式版本**。

一个 Windows 桌面工具：把鼠标推到屏幕边缘并稍作停留，即可弹出一个可自定义的多级启动菜单，快速打开应用程序、网址或文件夹。常驻系统托盘，单实例运行。

**主要功能**

- **屏幕边缘触发**：可选上 / 下 / 左 / 右任意组合边缘，鼠标进入边缘热区并停留（`dwellMs`）后弹出菜单
- **多显示器支持**：只在屏幕"外边缘"触发，显示器接缝处不会误触发；显示器拓扑变化（插拔、改分辨率）自动重新枚举
- **防误触设计**：热区宽度（`edgeZone`）与停留时长均可调，带迟滞退出区防止微抖动
- **四种菜单项类型**：`app`（程序，可带参数/工作目录/UAC 提权）、`url`（默认浏览器打开）、`dir`（资源管理器）、`sep`（分隔线）
- **无限层级子菜单**
- **图形化设置窗口**（中 / 英双语界面）：托盘图标右键 →"设置..."，树形编辑菜单、配置触发区与开机自启
- **开机自启**：写入注册表 `HKCU\...\Run`
- **低级鼠标钩子 + 看门狗**：Windows 静默移除钩子时自动重装，长期驻留可靠
- **单实例**：命名互斥量防止重复启动

**安装与使用**

- 下载 `octopus_launch.exe`（x64，约 3.2 MB，绿色单文件，无需安装），放到任意目录直接运行
- 托盘图标右键 →"设置..." 配置菜单项与触发边缘
- 配置保存在 `%APPDATA%\octopus-launch\config.json`

**环境要求**

- Windows 10 / 11（x64）

**反馈**

- 问题反馈：https://github.com/xw5/octopus-launch/issues

---

<a id="english"></a>

### English

octopus-launch — **first stable release**.

A Windows desktop utility: push your mouse against a screen edge and hold it there briefly to pop up a customizable multi-level launcher menu for quickly opening applications, URLs, or folders. It lives in the system tray and runs as a single instance.

**Highlights**

- **Screen-edge trigger**: enable any combination of top / bottom / left / right edges; the menu pops up after the mouse dwells (`dwellMs`) in the edge hot zone
- **Multi-monitor aware**: only "outer" edges trigger — seams between adjacent monitors never false-trigger; monitor topology changes are re-enumerated automatically
- **Anti-mistouch design**: hot-zone width (`edgeZone`) and dwell time are both tunable, with a hysteresis exit zone
- **Four menu item types**: `app` (program, with optional parameters / working directory / UAC elevation), `url` (default browser), `dir` (Explorer), `sep` (separator)
- **Unlimited submenu nesting**
- **GUI settings window** (Chinese / English UI): tray icon right-click → "Settings..."; tree-based menu editor, trigger-zone configuration, and auto-start toggle
- **Auto-start on login**: written to registry `HKCU\...\Run`
- **Low-level mouse hook + watchdog**: the hook is automatically reinstalled if Windows silently removes it, ensuring long-term reliability
- **Single instance**: enforced via a named mutex

**Install & Usage**

- Download `octopus_launch.exe` (x64, ~3.2 MB, portable single file, no installation required), put it anywhere and run it
- Tray icon right-click → "Settings..." to configure menu items and trigger edges
- Settings are stored in `%APPDATA%\octopus-launch\config.json`

**Requirements**

- Windows 10 / 11 (x64)

**Feedback**

- Issues: https://github.com/xw5/octopus-launch/issues
