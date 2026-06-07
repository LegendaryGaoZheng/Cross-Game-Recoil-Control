# Legendary压枪助手 - 更新日志 / Legendary Recoil Assistant - Changelog

<img src="images/logo.jpg" width="100%" />

本文档记录 Legendary压枪助手 主要发布版本的更新历史。English version is available in the second half of this README.

- [中文说明](#使用教程)
- [English README](#english-readme)

## 使用教程

- [完整使用教程](docs/usage-guide.md)
- 教程截图保存在 [docs/images](docs/images)。
- PDF 版建议作为 GitHub Releases 附件发布，仓库内以 Markdown 教程为主，方便阅读、搜索和维护。

## 使用方式（必看）

### 直接运行发行版

1. 下载或复制 `Legendary游戏助手v3.1.2.exe` 到任意目录。
2. 右键该 `.exe` 文件：**以管理员身份运行**。
3. 程序启动后：
   - `PageDown`：切换热键辅助总开关。
   - `F2`：切换图像识别独立开关。
   - 右上角可选择 `中文` / `English`，语言选择会保存到配置。
   - 右上角“使用说明 / Guide”可查看当前版本内置说明。

### 从源码生成执行文件

1. 安装 .NET SDK 10.0 或更新版本。
2. 打开 PowerShell，进入项目目录：

```powershell
cd C:\Users\Legen\Desktop\LegendaryCSharp
```

3. 编译检查：

```powershell
dotnet build
```

4. 生成 Windows x64 单文件发行版：

```powershell
dotnet publish -c Release -r win-x64 --self-contained true -p:PublishSingleFile=true
```

5. 生成后的执行文件位于：

```text
C:\Users\Legen\Desktop\LegendaryCSharp\bin\Release\net10.0-windows\win-x64\publish\LegendaryCSharp.exe
```

---

## [v3.1.2]

> v3.1.2 是 v3.1.1 之后的小幅体验修正版，主要整理开关逻辑、弹道预览和识别参数交互。

### 本次更新

- **中英双语界面**：
  - 主窗口右上角新增语言选择，可在 `中文` / `English` 之间切换。
  - 主界面标签、按钮、状态栏、日志提示、按键选择窗口、取色/框选窗口、调试浮窗和内置使用说明跟随语言切换。
  - 语言选择写入主配置，下次启动自动沿用。

- **弹道预览调整**：
  - 弹道预览改为显示实际压枪移动路径。
  - 固定方向按当前水平/垂直参数累计显示，左右交替模式显示交替路径。

- **图像识别开关独立**：
  - 热键辅助总开关只影响压枪、屏息、31切枪等热键辅助。
  - 图像识别不再要求先打开热键辅助总开关，只看“自动触发”和 `F2`。

- **目标颜色交互简化**：
  - 删除“使用目标颜色”勾选项。
  - 图像识别固定使用“目标颜色”，取色后仍需手动复制到目标颜色框。

- **命名同步**：
  - 总览里的“半自动随压枪”改回“半自动”。
  - 程序标题、内置使用说明和项目版本同步为 `v3.1.2`。

- **档案按钮反馈修复**：
  - 修复加载档案后按钮停留在“已加载”且无法继续点击的问题。

---

## [v3.1.1]

> v3.1.1 是从 AutoHotkey v2 脚本迁移到 C# / WPF 后的正式整理版。  
> 这一版的重点不是简单复刻旧脚本，而是把界面、配置、输入监听、图像识别和运行性能重新拆分成更稳定、可维护的 Windows 桌面程序。

### 重大更新：从 AHK 迁移到 C# / WPF

- **从脚本形态迁移为独立桌面程序**：
  - 旧版依赖 `.ahk` 文件和 AutoHotkey v2 运行环境。
  - 新版使用 C# / WPF 重写，可通过 `dotnet publish` 生成独立 `.exe`。
  - 发布时支持单文件、自包含运行，不需要用户额外安装 AutoHotkey。

- **界面层迁移到 WPF**：
  - 主界面从 AHK GUI 改为 WPF 窗口。
  - 功能页按“压枪 / 图像识别 / 档案 / 日志 / 使用说明”等逻辑重新整理。
  - 右上角新增“使用说明”按钮，说明内容随程序一起维护。
  - 状态栏、调试浮窗、弹道预览等界面元素更容易扩展。

- **输入逻辑模块化**：
  - 全局热键使用 Win32 `RegisterHotKey`。
  - 鼠标监听使用 low-level mouse hook。
  - 按键、鼠标点击、鼠标移动统一封装到 `InputService`。
  - 压枪、屏息、31切枪等运行逻辑拆入 `AssistantRuntime`，不再堆在单个脚本文件中。

- **配置系统重构**：
  - 旧版 INI 配置迁移为 JSON 配置。
  - 通用配置和图像识别配置拆分保存：
    - `LegendaryCSharp.settings.json`
    - `LegendaryCSharp.image-recognition.json`
  - 档案分为“通用档案”和“图像识别档案”。
  - 档案保存到 `%AppData%\Legendary\Profiles`，不再污染 exe 所在目录。
  - 旧版发布目录里的 `Profiles` 会自动读取并迁移。

### 图像识别模块重构

- **从 AHK PixelSearch 迁移到 C# 截图搜色**：
  - 使用 GDI 截取屏幕区域。
  - 使用 `LockBits` 读取位图内存。
  - 逐像素比较 RGB 通道与目标颜色的容差范围。

- **搜索区域优化**：
  - 旧逻辑容易扫描过大区域。
  - 新版只截取用户框选区域，区域越小，扫描越轻。
  - 支持高 DPI 坐标换算，减少高缩放屏幕下的定位偏差。

- **取色体验优化**：
  - 取色窗口新增放大镜。
  - 红框标出当前实际取色像素。
  - “提取像素”不会直接覆盖“目标颜色”，而是先放到独立小框中，用户确认后再手动复制。
  - 取色后会记录实时读取值，便于判断画面是否被正确读取。

- **识别诊断增强**：
  - 新增“诊断”按钮。
  - 诊断会保存程序实际读取到的搜索区域截图：`image-diagnostic.png`。
  - 日志会显示中心颜色、采样颜色数量、命中数量、首个命中点等信息。
  - 如果截图是黑屏、旧画面或不是目标区域，可直接判断当前截图方式没有读到游戏画面。

### 性能优化

- **扫描线程优化**：
  - 图像识别扫描从 UI 线程挪到后台任务。
  - 低间隔扫描时，窗口和前台程序不再被 UI 线程阻塞。

- **截图分配优化**：
  - 搜色时复用同尺寸 `Bitmap` / `Graphics`。
  - 减少每次扫描都创建对象造成的 GC 压力。

- **像素比较优化**：
  - 将逐像素匹配改为直接比较 RGB 通道范围。
  - 减少高频扫描中的函数调用和临时计算。

- **界面刷新降频**：
  - 命中结果、调试浮窗和未命中状态不会每次扫描都刷新 UI。
  - 触发判断仍按扫描间隔执行，不影响实际识别逻辑。
  - 左上角调试浮窗移除无意义扫描计数，只保留当前状态和区域。

- **日志性能优化**：
  - 日志框限制最大保留行数。
  - 长时间运行后不会因为日志文本过长拖慢界面。

- **输入监听减负**：
  - 当前没有订阅键盘监听时，不额外安装键盘全局 hook。
  - 常驻监听负担更低。

### 功能与体验变化

- **图像识别三重开关保留**：
  - 总开关：默认 `PageDown`
  - 主界面“图像识别自动触发”
  - `F2` 图像识别独立开关

- **触发参数更清晰**：
  - 容差范围明确为 `0-255`。
  - 支持连续命中 N 次后才触发。
  - 支持触发方式：`Tap` / `Down` / `Up` / `Auto`。
  - 支持冷却时间，减少连续误触。

- **保留并整理旧版核心功能**：
  - 侧键 + 左键压枪
  - 屏息
  - 半自动模式
  - 滚轮下触发 31 切枪
  - 弹道预览
  - 配置保存 / 加载 / 删除

### 数据位置

- 主配置仍跟随 exe：

```text
LegendaryCSharp.settings.json
LegendaryCSharp.image-recognition.json
```

- 档案保存到用户数据目录：

```text
%AppData%\Legendary\Profiles
```

### 维护说明

- 程序内说明维护在 `UsageGuide.cs`。
- 中英双语界面文字和运行提示维护在 `Localization.cs`。
- 修改功能、按钮、配置项、热键、触发逻辑或数据位置时，需要同步更新：
  - `UsageGuide.cs`
  - `Localization.cs`
  - `README.md`

---

## [v2.4.9]

> v2.4.9 是一次“新版本级别”的整理与增强，下面列的是相对 **v2.4.6** 的主要差异。

### 重大更新（相对 v2.4.6）

- **主界面模块化重排**：主 GUI 重构为两大模块：
  - 「热键辅助」：启用压枪 / 启用屏息 / 启用半自动模式 / 启用31切枪
  - 「图像识别」：图像识别自动触发
  - 相关开关与“配置”按钮按模块分组显示，状态栏固定在底部，避免错位。

- **配置管理重构：一份 INI，两套独立配置体系**：
  - 「热键辅助」与「图像识别」支持分别保存/加载配置，但仍共用同一个 `AutoFire.ini`。
  - 写入 section 前缀区分：
    - 热键辅助配置：`HK_配置名`
    - 图像识别配置：`IMG_配置名`
  - **兼容旧配置**：热键辅助列表可读取旧 `Config_配置名`（加载时优先 `HK_`，找不到再回退 `Config_`）。

- **屏息/半自动配置增强**：
  - 「启用屏息」与「启用半自动模式」配置窗口新增 **触发按键**下拉（侧键2/侧键1/右键），与压枪触发键保持同步。
  - 点击「应用设置」后会自动收起配置窗口，并同步热键/定时器状态。

- **图像识别参数更可控**（v2.4.6 基础上增强）：
  - 新增“连续命中 N 次后才触发”（避免一闪而过误触发）。
  - 新增“触发方式”：点击(tap) / 按下(down) / 抬起(up) / 智能(auto)。
  - 新增“目标颜色”输入与启用开关，并支持取色（右键取色复制到剪贴板）。

- **弹道预览回归/增强**：压枪配置窗口加入弹道预览区域，实时显示垂直/横向趋势，便于按参数对比游戏内弹道。

### 命名与体验

- **文案统一**：主界面与压枪配置窗口将「启用辅助」统一更名为「启用压枪」，语义更明确。

---

## [v2.4.6]

### 重大更新

- **自动图像识别触发（PixelSearch）上线**：在指定区域持续识别目标颜色，命中即自动触发按键（默认 `X`）。
  - 更适合准星/状态颜色类场景：不依赖模板图，配置更直接
  - **三重开关更安全**：
    - 总开关（默认 `PgDn`）
    - 主界面勾选「图像识别自动触发」
    - **`F2` 图像识别独立开关**（想开就开，想停就停）
- **右键单点取色**：图像识别配置页新增「取色」按钮，右键点一下就能获取 `0xRRGGBB`（自动复制到剪贴板），`Esc` 可取消。

### 体验与稳定性

- **操作指南同步更新**：明确 `F2` 独立开关与取色流程，新手更容易上手。
- **应用设置不再报错**：修复「应用设置」自动收起配置窗口时，因部分 GUI 未初始化导致的属性访问报错（如 `RecoilConfigGui`）。

---

## [v2.3.9]

### 新增与优化

- **31切枪（滚轮下划）**：新增「31切枪」功能，可在主界面勾选启用。
  - 滚轮下划后：等待(可调) → 3 → 10ms → 1
  - 可调参数为「滚轮下划到执行31之间的延迟」，范围 10-2000ms，便于按手感微调
- **滚轮透传**：切枪热键使用 `~WheelDown` 透传滚轮事件，减少与游戏内滚轮操作冲突。
- **压枪循环节流**：压枪/连点轮询由 `Sleep 0` 调整为 `Sleep 1`，降低 CPU 占用并提升系统响应稳定性。

### 行为修正

- **异常安全收尾**：压枪核心逻辑加入 `try/finally`，确保在异常情况下也能可靠释放 `LButton` 并复位运行状态，减少卡死/需重启脚本的概率。
- **总开关逻辑调整**：热键切换改为「总开关」概念（暂停/恢复已勾选功能），不再强制改动各功能勾选状态，避免误操作导致设置被意外改变。

### 技术改进

- **参数校验重构**：以 `ClampInt()` 替代旧版 `Validate()` 的动态变量写法，在读取配置/应用设置/加载配置时统一进行范围钳制（含切枪间隔），提升 AHK v2 兼容性与稳定性。

---

## [v2.3.3]

### 新增与优化

- **排版优化**：界面布局与尺寸调整，弹道预览固定于右侧，底部按钮不被挤出视口，便于使用与维护。
- **操作指南**：主界面右上角新增「操作指南」按钮，可打开说明窗口，包含基本用法、参数说明、配置管理、力度换算等。
- **可视化弹道图**：主界面右侧增加弹道预览框，以红线显示当前压枪方向（比例 1:2），悬停有说明，下方显示当前垂直/横向数值，便于对比游戏内弹道。
- **屏息键可选**：「启用屏息」旁新增「屏息键」输入框，默认 L，可改为其他键名，并随配置保存/加载。

### 行为修正

- **半自动 / 全自动射速与计时修复**
  - 半自动模式下实际连点速率与设置的 RPM 不一致、存在波动的问题已修正
  - 以「发射周期起点」计时，射速与设置一致；半自动抬/按间隔固定 2ms；等待下一发使用 Sleep 0 轮询，减少波动
  - 全自动模式同样按周期起点计时，压枪节奏更稳定

---

## [v2.2.6]

### Bug 修复

- **修复半自动模式下的按键绑定问题**
  - 修复了半自动模式下左键不需与侧键绑定就会自动射击的情况
  - 现在半自动模式下的连点功能与压枪功能保持一致，均需要同时按下侧键和左键才能触发
  - 解决了单独按下左键时意外触发连点的问题，提升了操作的准确性和可控性

- **修复脚本关闭时的按键冲突问题**
  - 修复了当脚本关闭（辅助功能禁用）时，再同时按下侧键和左键时无法正常射击的 bug
  - 通过 `SyncComboHotkey()` 函数实现动态热键注册/注销机制
  - 确保在辅助功能关闭时不会钩住左键，避免影响正常游戏操作，特别是开镜射击场景

### 新功能

- **自定义热键功能**
  - 新增了热键可以自己选择的功能
  - 用户可以在 GUI 界面中通过「启用/禁用热键」输入框自定义热键
  - 支持实时更改热键，无需重启脚本即可生效
  - 热键设置会自动保存到配置文件中，方便不同用户根据个人习惯设置

### 技术改进

- 实现了动态热键管理机制，根据辅助功能的启用/禁用状态自动注册或注销组合键热键
- 优化了热键变更事件处理，提升了用户体验和脚本的稳定性

---

## [v2.1.3]

### 简介

Legendary压枪助手是一款专业的游戏鼠标压枪辅助工具，专为FPS游戏设计。通过智能算法模拟真实枪械后坐力补偿，帮助玩家在射击时保持准星稳定。支持多种射击模式和自定义配置。

### 功能特性

- **全自动压枪模式**：侧键+左键组合，实现自动射击与压枪
- **半自动模拟模式**：模拟半自动武器的快速连点效果
- **智能后坐力补偿**：可调节垂直/横向压枪力度
- **多种补偿模式**：固定、交替、随机三种横向模式
- **屏息辅助功能**：按下侧键自动屏息（需游戏支持）
- **配置文件管理**：支持保存/加载不同武器配置
- **热键控制**：一键启用/禁用辅助功能（默认热键：PgDn）

### 系统要求

- 操作系统: Windows 10/11 64位
- 内存: 2GB 或更高
- 权限: 需要管理员权限运行
- 鼠标: 推荐带有侧键的游戏鼠标

---

# English README

This document records the major release history of Legendary Recoil Assistant. The Chinese version remains the primary historical record; this English section mirrors the current usage instructions and release notes so GitHub visitors can understand the project more easily.

## Usage Guide

- [Full Usage Guide](docs/usage-guide.md)
- Tutorial screenshots are stored in [docs/images](docs/images).
- A PDF version is better published as a GitHub Releases attachment. The repository keeps the Markdown guide for easier reading, searching, and maintenance.

## How To Use

### Run The Release Build

1. Download or copy `Legendary游戏助手v3.1.2.exe` to any folder.
2. Right-click the `.exe` file and choose **Run as administrator**.
3. After launch:
   - `PageDown`: toggles the hotkey-assisted features.
   - `F2`: toggles image recognition independently.
   - Use the top-right `中文` / `English` selector to switch the UI language. The selection is saved.
   - The top-right `使用说明 / Guide` button opens the built-in guide for the current version.

### Build The Executable From Source

1. Install .NET SDK 10.0 or newer.
2. Open PowerShell and enter the project folder:

```powershell
cd C:\Users\Legen\Desktop\LegendaryCSharp
```

3. Build check:

```powershell
dotnet build
```

4. Publish a Windows x64 single-file release build:

```powershell
dotnet publish -c Release -r win-x64 --self-contained true -p:PublishSingleFile=true
```

5. The generated executable is located at:

```text
C:\Users\Legen\Desktop\LegendaryCSharp\bin\Release\net10.0-windows\win-x64\publish\LegendaryCSharp.exe
```

---

## [v3.1.2]

> v3.1.2 is a small usability-focused update after v3.1.1. It mainly cleans up switch logic, trajectory preview behavior, image recognition controls, profile button feedback, and bilingual UI support.

### Changes

- **Bilingual UI**:
  - Added a top-right language selector for `中文` / `English`.
  - Main labels, buttons, status bar, log messages, key picker, color picker, region selector, debug overlays, and the built-in guide follow the selected language.
  - The language setting is saved in the main configuration and reused on the next launch.

- **Trajectory Preview Update**:
  - The preview now shows the actual recoil movement path.
  - Fixed direction accumulates the configured horizontal and vertical movement.
  - Alternating mode displays the left-right alternating path.

- **Independent Image Recognition Switch**:
  - The hotkey master only affects hotkey-assisted features such as recoil, breath hold, semi-auto, and 31 swap.
  - Image recognition no longer requires the hotkey master to be enabled. It only depends on `Auto Trigger` and `F2`.

- **Simplified Target Color Logic**:
  - Removed the redundant `Use Target Color` checkbox.
  - Image recognition always uses the value in `Target Color`. Picked colors still need to be copied manually into the target color field.

- **Naming Sync**:
  - The overview label `半自动随压枪` was changed back to `半自动`.
  - Program title, built-in guide, and project version are synced to `v3.1.2`.

- **Profile Button Feedback Fix**:
  - Fixed the issue where loading a profile could leave the button stuck as `已加载 / Loaded` and unclickable.

---

## [v3.1.1]

> v3.1.1 is the formal C# / WPF migration release from the older AutoHotkey v2 script. The focus is not a direct copy of the old script, but a cleaner Windows desktop application with separated UI, settings, input handling, image recognition, and runtime logic.

### Major Update: Migration From AHK To C# / WPF

- **From script to standalone desktop app**:
  - The old version depended on `.ahk` files and the AutoHotkey v2 runtime.
  - The new version is rewritten in C# / WPF and can be published as a standalone `.exe`.
  - Single-file, self-contained publishing is supported, so users do not need to install AutoHotkey.

- **UI migrated to WPF**:
  - The main UI moved from AHK GUI to a WPF window.
  - Features are organized into pages such as recoil, image recognition, profiles, logs, and guide.
  - The top-right guide button opens instructions maintained with the program.
  - Status bar, debug overlay, and trajectory preview are easier to extend.

- **Input logic modularized**:
  - Global hotkeys use Win32 `RegisterHotKey`.
  - Mouse listening uses a low-level mouse hook.
  - Keyboard input, mouse clicks, and mouse movement are wrapped by `InputService`.
  - Recoil, breath hold, semi-auto, and 31 swap runtime logic are moved into `AssistantRuntime` instead of being kept in one large script.

- **Settings system rebuilt**:
  - The old INI settings were migrated to JSON.
  - General settings and image recognition settings are saved separately:
    - `LegendaryCSharp.settings.json`
    - `LegendaryCSharp.image-recognition.json`
  - Profiles are separated into general profiles and image recognition profiles.
  - Profiles are saved under `%AppData%\Legendary\Profiles` instead of cluttering the exe folder.
  - Legacy `Profiles` folders beside old releases are read and migrated automatically.

### Image Recognition Module

- **From AHK PixelSearch to C# screenshot color search**:
  - Uses GDI to capture the selected screen region.
  - Uses `LockBits` to read bitmap memory.
  - Compares RGB channels against the configured target color and tolerance.

- **Search region optimization**:
  - The old logic could scan overly large areas.
  - The new version captures only the selected region. Smaller regions reduce scan cost.
  - High-DPI coordinate conversion is supported to reduce offset issues on scaled displays.

- **Color picking improvements**:
  - Added a magnifier window.
  - A red box marks the actual picked pixel.
  - Picked colors are placed in a separate field first and do not overwrite `Target Color` automatically.
  - Live read values are logged after picking, which helps confirm whether the current screen is being read correctly.

- **Recognition diagnostics**:
  - Added the `Diagnose` button.
  - Diagnosis saves the actual captured search area as `image-diagnostic.png`.
  - Logs include center color, sampled color count, match count, and first match point.
  - If the diagnostic image is black, stale, or not the expected region, the capture method is not reading the target screen correctly.

### Performance Optimizations

- **Scanning thread optimization**:
  - Image recognition scanning moved away from the UI thread.
  - Low-interval scanning no longer blocks the window or foreground application through UI-thread pressure.

- **Screenshot allocation optimization**:
  - Reuses same-size `Bitmap` / `Graphics` objects during color search.
  - Reduces GC pressure caused by creating new objects every scan.

- **Pixel comparison optimization**:
  - Replaced per-pixel helper calls with direct RGB range comparison.
  - Reduces temporary calculations in high-frequency scanning.

- **Reduced UI refresh pressure**:
  - Match results, debug overlays, and miss states are not refreshed on every scan.
  - Trigger checks still follow the scan interval.
  - The debug overlay no longer shows a meaningless scan counter and only keeps status and region info.

- **Log performance optimization**:
  - The log box has a maximum retained line count.
  - Long sessions will not slow the UI because of an oversized log text buffer.

- **Input listener load reduction**:
  - The keyboard global hook is not installed when no keyboard listener is needed.
  - Background listener overhead is lower.

### Current Feature Set

- `PageDown` hotkey master.
- `F2` independent image recognition switch.
- Side trigger + left click recoil.
- Breath hold.
- Semi-auto mode.
- Mouse wheel down 31 swap.
- Trajectory preview.
- General and image recognition profile save / load / delete.
- Bilingual Chinese / English UI and guide.

### Data Locations

- Main configuration files beside the exe:

```text
LegendaryCSharp.settings.json
LegendaryCSharp.image-recognition.json
```

- Profiles are saved under:

```text
%AppData%\Legendary\Profiles
```

### Maintenance Notes

- Built-in guide text is maintained in `UsageGuide.cs`.
- Bilingual UI strings and runtime messages are maintained in `Localization.cs`.
- When changing features, buttons, settings, hotkeys, trigger logic, or data locations, update:
  - `UsageGuide.cs`
  - `Localization.cs`
  - `README.md`

---

## Legacy AHK Release Notes

The older releases below document the AutoHotkey-era history of the project:

- **v2.4.9**: reorganized the main GUI into hotkey assist and image recognition sections; split profile sections; improved breath hold, semi-auto, image recognition parameters, and trajectory preview.
- **v2.4.6**: introduced automatic pixel-search image recognition with a triple-switch model and right-click color picking.
- **v2.3.9**: added 31 swap, mouse wheel pass-through, recoil loop throttling, safer cleanup logic, and master-switch behavior changes.
- **v2.3.3**: improved layout, added a guide button, restored/enhanced trajectory preview, added configurable breath-hold key, and fixed semi-auto timing.
- **v2.2.6**: fixed semi-auto binding and disabled-state click conflicts; added customizable hotkeys.
- **v2.1.3**: early feature baseline with recoil, semi-auto, compensation settings, breath hold, profiles, and hotkey control.
