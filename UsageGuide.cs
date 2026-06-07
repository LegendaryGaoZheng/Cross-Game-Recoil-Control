namespace LegendaryCSharp;

public static class UsageGuide
{
    public static string Text => Localization.IsEnglish ? EnglishText : ChineseText;

    private const string ChineseText =
        """
        使用说明 v3.1.2

        语言
        - 主窗口右上角可以选择中文或 English。
        - 语言选择会保存到主配置，下次启动继续使用。

        热键辅助总开关
        - PageDown：开关热键辅助。
        - 热键总开关关掉后，压枪、屏息、半自动、31切枪都会停。
        - 改完参数点“保存全部”，或在当前页单独保存。

        压枪 / 屏息 / 31
        - 压枪：按住侧触发键，再按住左键。
        - 屏息：按住侧触发键时按下屏息键，松开侧键释放。
        - 半自动：按住侧触发键和左键时，按射速节奏工作。
        - 31切枪：滚轮下触发。

        图像识别
        - 两个地方要开：自动触发、F2。
        - F2 只管图像识别；热键辅助总开关不影响图像识别。
        - “框选区域”用来定搜索范围，区域越小越稳。
        - “取色”里红框内就是当前像素。
        - “取色”只把颜色放进旁边的小框，不会改目标颜色。
        - 想用取到的颜色，手动复制到“目标颜色”。
        - “诊断”会保存程序实际读到的搜索区域，文件名是 image-diagnostic.png。
        - 容差是 0-255。0 最严，255 最宽。
        - 先用连续命中 1 测触发；误触多了再改成 2 或 3。
        - Tap 是点击，Down 是按下，Up 是抬起，Auto 会按当前按键状态处理。
        - 打开“调试日志”可以看扫描、命中、触发状态。
        - 间隔越低越吃性能；如果游戏卡顿，先把区域缩小，再把间隔调高。

        档案
        - 通用档案：压枪、屏息、半自动、31切枪这些参数。
        - 图像识别档案：区域、颜色、容差、发送键、触发方式。
        - 档案保存到 Windows 用户数据目录，旧版 exe 旁边的 Profiles 会自动迁移。
        - 保存、加载、删除按钮会短暂显示结果，然后自动恢复。

        没反应先看这里
        - 状态栏有没有“识别扫描中”。
        - 没启动就看自动触发和 F2。
        - 扫描中但不触发，就提高容差、缩小区域、重取目标颜色。
        - 热键没反应，试试管理员身份运行。

        维护
        - 完整图文教程维护在 docs/usage-guide.md。
        - 界面文字和运行提示维护在 Localization.cs。
        - 改功能、按钮、配置项、热键、触发逻辑或数据位置时，同步改这里和 README。
        """;

    private const string EnglishText =
        """
        Usage Guide v3.1.2

        Language
        - Use the selector in the top-right corner to switch between Chinese and English.
        - The selected language is saved in the main settings and reused next time.

        Hotkey Master
        - PageDown toggles the hotkey-assisted features.
        - When the master switch is off, recoil, breath hold, semi-auto, and 31 swap stop.
        - After changing settings, click Save All or the save button on the current page.

        Recoil / Breath / 31
        - Recoil: hold the side trigger, then hold left click.
        - Breath hold: while the side trigger is held, the configured breath key is held down; it is released when the side trigger is released.
        - Semi-auto: while the side trigger and left click are held, it follows the fire-rate rhythm.
        - 31 swap: triggered by mouse wheel down.

        Image Recognition
        - Two switches must be on: Auto Trigger and F2.
        - F2 only controls image recognition; the hotkey master does not affect it.
        - Select Region defines the search area. A smaller area is usually steadier and lighter.
        - In Pick Color, the red box marks the actual target pixel.
        - Pick Color only writes the color into the extracted-color box; it does not overwrite Target Color.
        - To use the picked color, copy it into Target Color manually.
        - Diagnose saves the actual captured search area as image-diagnostic.png.
        - Tolerance is 0-255. 0 is strict; 255 is widest.
        - Start with Hit Streak 1 while testing, then raise it to 2 or 3 if false triggers happen.
        - Tap clicks once, Down presses, Up releases, and Auto reacts to the current key state.
        - Debug Log shows scanning, matching, and trigger status.
        - Lower intervals cost more performance. If the game stutters, shrink the region first, then raise the interval.

        Profiles
        - General profiles store recoil, breath hold, semi-auto, and 31 swap parameters.
        - Image profiles store region, color, tolerance, send key, and trigger mode.
        - Profiles are saved in the Windows user data folder. Legacy Profiles beside the exe are migrated automatically.
        - Save, Load, and Delete buttons show a short result and then return to normal.

        Troubleshooting
        - Check whether the status bar says recognition is scanning.
        - If recognition is not started, check Auto Trigger and F2.
        - If it scans but does not trigger, raise tolerance, shrink the region, or pick the target color again.
        - If hotkeys do not work, try running as administrator.

        Maintenance
        - The full illustrated guide is maintained in docs/usage-guide.md.
        - UI text and runtime messages are maintained in Localization.cs.
        - When features, buttons, settings, hotkeys, trigger logic, or data locations change, update this guide and README together.
        """;
}
