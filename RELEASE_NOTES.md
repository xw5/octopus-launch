# Release Notes / 发布说明

## v1.1.0 — 2026-11-26

<a id="中文"></a>

### 中文

**新功能**

- **菜单导入 / 导出**：设置窗口新增"导入 / 导出"按钮，可将整个菜单（含多级子菜单）保存为 JSON 文件或从文件载入，方便备份、迁移与分享。兼容纯菜单数组和完整配置对象两种格式

**改进**

- **子菜单交互修复**：从父菜单斜向移入子菜单不再需要"快速冲过去"——子菜单改为延时关闭（300 ms），移入子菜单窗口或折返父条目即取消关闭；快速掠过条目时若正冲向其子菜单也能照常弹出
- **设置窗口布局**：触发区改为两栏布局（左侧 2×2 贴边方向、右侧数值与自启），导入/导出按钮位于菜单分组标题行；窗口去掉最大化按钮并固定尺寸
- **菜单配置统一序列化**：主配置与导入/导出共用同一套菜单 JSON 读写代码

**安装与使用**

- 下载 `octopus_launch.exe`（x64，绿色单文件，无需安装），放到任意目录直接运行
- 若已安装旧版本，直接覆盖运行即可（配置位置不变）

**环境要求**

- Windows 10 / 11（x64）

**反馈**

- 问题反馈：https://github.com/xw5/octopus-launch/issues

---

<a id="english"></a>

### English

**New features**

- **Menu import / export**: the settings window now has "Import / Export" buttons to save the whole menu (including nested submenus) to a JSON file or load it back — for backup, migration, and sharing. Both a plain menu array and a full config object are accepted

**Improvements**

- **Submenu interaction fix**: moving diagonally from the parent menu into a submenu no longer requires rushing — submenus now close after a 300 ms delay, canceled when the cursor enters the submenu window or returns to the parent row; quickly brushing past an item toward its submenu still opens it
- **Settings window layout**: trigger section rearranged into two columns (2×2 edge toggles on the left, values & auto-start on the right); Import/Export buttons sit on the menu group caption row; the window is fixed-size without a maximize button
- **Unified menu serialization**: the main config and import/export share the same menu JSON read/write code

**Install & Usage**

- Download `octopus_launch.exe` (x64, portable single file, no installation required), put it anywhere and run it
- If upgrading from an older version, just replace the executable (config location unchanged)

**Requirements**

- Windows 10 / 11 (x64)

**Feedback**

- Issues: https://github.com/xw5/octopus-launch/issues

---

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
