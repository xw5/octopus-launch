# octopus-launch / 章鱼启动

<p align="center"><img src="docs/logo.png" alt="octopus-launch logo" width="128"></p>

[中文](#中文) | [English](#english)

---

<a id="中文"></a>

## 中文

octopus-launch 是一个 Windows 桌面工具：把鼠标推到屏幕边缘并稍作停留，即可弹出一个可自定义的多级启动菜单，快速打开应用程序、网址或文件夹。常驻系统托盘，单实例运行。

![菜单效果](test/menu_open1.png)

### 功能特性

- **屏幕边缘触发**：可选上 / 下 / 左 / 右任意组合边缘，鼠标进入边缘热区并停留后弹出菜单
- **多显示器支持**：只在屏幕"外边缘"触发，相邻显示器的接缝处不会误触发；显示器拓扑变化（插拔、改分辨率）自动重新枚举
- **防误触设计**：热区宽度（`edgeZone`）与停留时长（`dwellMs`）均可调，带迟滞退出区防止微抖动反复归零
- **四种菜单项类型**：
  - `app` — 启动程序，可带参数、工作目录，支持 UAC 提权（以管理员运行）
  - `url` — 用默认浏览器打开网址（自动补全 `https://`，带 `cmd start` 兜底）
  - `dir` — 用资源管理器打开文件夹
  - `sep` — 分隔线
- **无限层级子菜单**
- **图形化设置窗口**：托盘图标右键 →"设置..."（或双击托盘图标），树形编辑菜单、配置触发区与开机自启
- **开机自启**：写入注册表 `HKCU\Software\Microsoft\Windows\CurrentVersion\Run`
- **低级鼠标钩子 + 看门狗**：Windows 静默移除钩子时自动重装，保证长期驻留可靠
- **单实例**：通过命名互斥量防止重复启动

### 配置文件

配置保存在 `%APPDATA%\octopus-launch\config.json`（UTF-8），设置窗口保存时自动写入；调试日志为同目录 `debug.log`。

示例：

```json
{
  "edges": ["top", "bottom"],
  "dwellMs": 300,
  "edgeZone": 10,
  "language": "zh",
  "menu": [
    {
      "name": "终端",
      "type": "app",
      "target": "C:\\Windows\\System32\\cmd.exe",
      "params": "/k",
      "workdir": "",
      "admin": false
    },
    {
      "name": "GitHub",
      "type": "url",
      "target": "https://github.com"
    },
    { "name": "-", "type": "sep" },
    {
      "name": "工具",
      "type": "app",
      "children": [
        { "name": "注册表", "type": "app", "target": "regedit.exe", "admin": true }
      ]
    }
  ]
}
```

| 字段 | 说明 | 取值范围 / 默认 |
|------|------|-----------------|
| `edges` | 启用的触发边缘 | `top` / `bottom` / `left` / `right`，默认上下 |
| `dwellMs` | 边缘停留多少毫秒后触发 | 0–5000，默认 300 |
| `edgeZone` | 边缘热区宽度（像素） | 2–200，默认 10 |
| `language` | 界面语言（设置窗口可切换） | `zh` / `en`，默认跟随系统 |

菜单项字段：`name`（名称）、`type`（`app`/`url`/`dir`/`sep`）、`target`（目标路径或网址）、`params`（程序参数）、`workdir`（工作目录）、`admin`（提权运行）、`children`（子菜单）。

### 从源码构建

环境要求：Windows + [Free Pascal](https://www.freepascal.org/) 3.x + [Lazarus](https://www.lazarus-ide.org/)（LCL win32/win64 目标）。

```bash
# 方式一：Lazarus IDE 打开根目录 octopus_launch.lpi 直接编译
# 方式二：用响应文件命令行编译（注意rsp内为绝对路径，需按本机环境调整）
fpc @build.rsp
```

产物输出到 `bin/octopus_launch.exe`。

### 目录结构

```
src/
  octopus_launch.lpr  程序入口（单实例、COM 初始化）
  uMain.pas           隐藏主窗体：托盘 + 钩子调度
  uHooks.pas          低级鼠标钩子、边缘/驻留检测、看门狗
  uMenuWin.pas        菜单窗口（自绘多级菜单）
  uLauncher.pas       菜单项执行（app/url/dir）
  uConfig.pas         JSON 配置读写、调试日志
  uSettings.pas       设置窗口
  uIcons.pas          图标缓存
  octopus.rc/.ico     图标资源
test/                 开发期测试脚本与截图
```

### 许可证

[MIT](LICENSE)

---

<a id="english"></a>

## English

octopus-launch is a Windows desktop utility: push your mouse against a screen edge and hold it there briefly to pop up a customizable multi-level launcher menu for quickly opening applications, URLs, or folders. It lives in the system tray and runs as a single instance.

![Menu preview](test/menu_open1.png)

### Features

- **Screen-edge trigger**: enable any combination of top / bottom / left / right edges; the menu pops up after the mouse enters the edge hot zone and dwells
- **Multi-monitor aware**: only "outer" edges trigger — seams between adjacent monitors never false-trigger; monitor topology changes (plug/unplug, resolution change) are re-enumerated automatically
- **Anti-mistouch design**: hot-zone width (`edgeZone`) and dwell time (`dwellMs`) are both tunable, with a hysteresis exit zone so tiny jitters don't reset the timer repeatedly
- **Four menu item types**:
  - `app` — launch a program with optional parameters, working directory, and UAC elevation (run as administrator)
  - `url` — open a URL in the default browser (auto-prepends `https://`, with a `cmd start` fallback)
  - `dir` — open a folder in Explorer
  - `sep` — separator line
- **Unlimited submenu nesting**
- **GUI settings window**: tray icon right-click → "Settings..." (or double-click the tray icon); tree-based menu editor, trigger-zone configuration, and auto-start toggle
- **Auto-start on login**: written to registry `HKCU\Software\Microsoft\Windows\CurrentVersion\Run`
- **Low-level mouse hook + watchdog**: automatically reinstalls the hook if Windows silently removes it, ensuring long-term reliability
- **Single instance**: enforced via a named mutex

### Configuration

Settings are stored in `%APPDATA%\octopus-launch\config.json` (UTF-8) and written automatically when you save in the settings window; the debug log is `debug.log` in the same directory.

Example:

```json
{
  "edges": ["top", "bottom"],
  "dwellMs": 300,
  "edgeZone": 10,
  "language": "en",
  "menu": [
    {
      "name": "Terminal",
      "type": "app",
      "target": "C:\\Windows\\System32\\cmd.exe",
      "params": "/k",
      "workdir": "",
      "admin": false
    },
    {
      "name": "GitHub",
      "type": "url",
      "target": "https://github.com"
    },
    { "name": "-", "type": "sep" },
    {
      "name": "Tools",
      "type": "app",
      "children": [
        { "name": "Registry Editor", "type": "app", "target": "regedit.exe", "admin": true }
      ]
    }
  ]
}
```

| Field | Description | Range / Default |
|-------|-------------|-----------------|
| `edges` | Enabled trigger edges | `top` / `bottom` / `left` / `right`, default top+bottom |
| `dwellMs` | Milliseconds to dwell at the edge before triggering | 0–5000, default 300 |
| `edgeZone` | Edge hot-zone width in pixels | 2–200, default 10 |
| `language` | UI language (switchable in the settings window) | `zh` / `en`, default follows the system |

Menu item fields: `name`, `type` (`app`/`url`/`dir`/`sep`), `target` (path or URL), `params` (program arguments), `workdir`, `admin` (elevated launch), `children` (submenu).

### Building from Source

Requirements: Windows + [Free Pascal](https://www.freepascal.org/) 3.x + [Lazarus](https://www.lazarus-ide.org/) (LCL win32/win64 target).

```bash
# Option 1: open octopus_launch.lpi in the Lazarus IDE and build
# Option 2: command-line build via response file (paths inside are absolute — adjust for your machine)
fpc @build.rsp
```

The output goes to `bin/octopus_launch.exe`.

### Project Layout

```
src/
  octopus_launch.lpr  Entry point (single instance, COM initialization)
  uMain.pas           Hidden main form: tray + hook dispatch
  uHooks.pas          Low-level mouse hook, edge/dwell detection, watchdog
  uMenuWin.pas        Menu window (owner-drawn multi-level menu)
  uLauncher.pas       Menu item execution (app/url/dir)
  uConfig.pas         JSON config read/write, debug log
  uSettings.pas       Settings window
  uIcons.pas          Icon cache
  octopus.rc/.ico     Icon resources
test/                 Development-time test scripts and screenshots
```

### License

[MIT](LICENSE)
