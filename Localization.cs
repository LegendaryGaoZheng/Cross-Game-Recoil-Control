using System.Globalization;
using System.Windows;
using System.Windows.Controls;
using WpfButton = System.Windows.Controls.Button;
using WpfCheckBox = System.Windows.Controls.CheckBox;
using WpfComboBoxItem = System.Windows.Controls.ComboBoxItem;
using WpfGroupBox = System.Windows.Controls.GroupBox;
using WpfItemsControl = System.Windows.Controls.ItemsControl;
using WpfTabItem = System.Windows.Controls.TabItem;

namespace LegendaryCSharp;

public static class Localization
{
    public const string Chinese = "zh-CN";
    public const string English = "en-US";

    private static string _language = Chinese;

    public static string CurrentLanguage => _language;

    public static bool IsEnglish => _language == English;

    public static string NormalizeLanguage(string? language) =>
        string.Equals(language, English, StringComparison.OrdinalIgnoreCase) ? English : Chinese;

    public static void SetLanguage(string? language)
    {
        _language = NormalizeLanguage(language);
    }

    public static string T(string key)
    {
        if (Strings.TryGetValue(key, out var text))
        {
            return _language == English ? text.English : text.Chinese;
        }

        return key;
    }

    public static string Format(string key, params object[] args) =>
        string.Format(CultureInfo.CurrentCulture, T(key), args);

    public static string TranslateLiteral(string text)
    {
        foreach (var item in Strings.Values)
        {
            if (text == item.Chinese || text == item.English)
            {
                return _language == English ? item.English : item.Chinese;
            }
        }

        return text;
    }

    public static void ApplyTo(Window window)
    {
        if (window.Title is string title)
        {
            window.Title = TranslateLiteral(title);
        }

        ApplyToObject(window);
    }

    private static void ApplyToObject(DependencyObject root)
    {
        switch (root)
        {
            case TextBlock textBlock:
                textBlock.Text = TranslateLiteral(textBlock.Text);
                break;
            case WpfButton button when button.Content is string buttonText:
                button.Content = TranslateLiteral(buttonText);
                break;
            case WpfCheckBox checkBox when checkBox.Content is string checkBoxText:
                checkBox.Content = TranslateLiteral(checkBoxText);
                break;
            case WpfComboBoxItem comboBoxItem when comboBoxItem.Content is string comboBoxItemText:
                comboBoxItem.Content = TranslateLiteral(comboBoxItemText);
                break;
            case WpfGroupBox groupBox when groupBox.Header is string groupBoxText:
                groupBox.Header = TranslateLiteral(groupBoxText);
                break;
            case WpfTabItem tabItem when tabItem.Header is string tabItemText:
                tabItem.Header = TranslateLiteral(tabItemText);
                break;
        }

        if (root is WpfItemsControl itemsControl)
        {
            foreach (var item in itemsControl.Items)
            {
                if (item is DependencyObject itemObject)
                {
                    ApplyToObject(itemObject);
                }
            }
        }

        foreach (var child in LogicalTreeHelper.GetChildren(root))
        {
            if (child is DependencyObject dependencyObject)
            {
                ApplyToObject(dependencyObject);
            }
        }
    }

    private static readonly Dictionary<string, LocalizedText> Strings = new()
    {
        ["App.Title"] = new("Legendary v3.1.5", "Legendary v3.1.5"),
        ["App.Subtitle"] = new("热键、压枪、屏息、切枪、图像识别", "Hotkeys, recoil, breath hold, quick swap, image recognition"),
        ["Ui.Language"] = new("语言", "Language"),
        ["Ui.Help"] = new("使用说明", "Guide"),
        ["Ui.HelpTitle"] = new("使用说明 v3.1.5", "Usage Guide v3.1.5"),
        ["Ui.SaveAll"] = new("保存全部", "Save All"),
        ["Ui.Reload"] = new("重载", "Reload"),
        ["Ui.Close"] = new("关闭", "Close"),
        ["Ui.Overview"] = new("总览", "Overview"),
        ["Ui.Profiles"] = new("档案", "Profiles"),
        ["Ui.MasterHotkey"] = new("热键总开关", "Hotkey Master"),
        ["Ui.Select"] = new("选择", "Select"),
        ["Ui.MasterHotkeyHint"] = new("默认 PageDown，保存后生效。", "Default: PageDown. Save to apply."),
        ["Ui.HotkeyAssist"] = new("热键辅助", "Hotkey Assist"),
        ["Ui.Recoil"] = new("压枪", "Recoil"),
        ["Ui.Config"] = new("配置", "Config"),
        ["Ui.BreathHold"] = new("屏息", "Breath Hold"),
        ["Ui.SemiAuto"] = new("半自动", "Semi-Auto"),
        ["Ui.Cut31"] = new("31切枪", "31 Swap"),
        ["Ui.ImageRecognition"] = new("图像识别", "Image Recognition"),
        ["Ui.AutoTrigger"] = new("自动触发", "Auto Trigger"),
        ["Ui.ImageHotkeyHint"] = new("F2 切换图像识别；不受热键总开关影响。", "F2 toggles image recognition; it does not depend on the hotkey master."),
        ["Ui.RecoilSettings"] = new("压枪参数", "Recoil Settings"),
        ["Ui.SideTrigger"] = new("侧触发键", "Side Trigger"),
        ["Ui.FireRate"] = new("射速", "Fire Rate"),
        ["Ui.VerticalForce"] = new("垂直力度", "Vertical Force"),
        ["Ui.HorizontalForce"] = new("水平力度", "Horizontal Force"),
        ["Ui.HorizontalMode"] = new("水平模式", "Horizontal Mode"),
        ["Ui.FixedDirection"] = new("固定方向", "Fixed Direction"),
        ["Ui.Alternating"] = new("左右交替", "Alternating"),
        ["Ui.SaveRecoil"] = new("保存压枪", "Save Recoil"),
        ["Ui.TrajectoryPreview"] = new("弹道预览", "Trajectory Preview"),
        ["Ui.TrajectoryZero"] = new("垂直: 0  横向: 0", "Vertical: 0  Horizontal: 0"),
        ["Ui.AutoRefreshHint"] = new("数值变化后自动刷新。", "Refreshes when values change."),
        ["Ui.Breath31"] = new("屏息 / 31", "Breath / 31"),
        ["Ui.BreathSettings"] = new("屏息配置", "Breath Hold Settings"),
        ["Ui.BreathKey"] = new("屏息键", "Breath Key"),
        ["Ui.SaveBreath"] = new("保存屏息", "Save Breath"),
        ["Ui.Cut31Interval"] = new("31间隔(ms)", "31 Interval (ms)"),
        ["Ui.SaveCut31"] = new("保存31切枪", "Save 31 Swap"),
        ["Ui.SearchRegion"] = new("搜索区域", "Search Region"),
        ["Ui.ColorTrigger"] = new("颜色与触发", "Color & Trigger"),
        ["Ui.TargetColor"] = new("目标颜色", "Target Color"),
        ["Ui.Tolerance"] = new("容差(0-255)", "Tolerance (0-255)"),
        ["Ui.Interval"] = new("间隔(ms)", "Interval (ms)"),
        ["Ui.SendKey"] = new("发送键", "Send Key"),
        ["Ui.HitStreak"] = new("连续命中", "Hit Streak"),
        ["Ui.TriggerMode"] = new("触发方式", "Trigger Mode"),
        ["Ui.Cooldown"] = new("冷却(ms)", "Cooldown (ms)"),
        ["Ui.PickOffset"] = new("取色偏移", "Pick Offset"),
        ["Ui.DebugLog"] = new("调试日志", "Debug Log"),
        ["Ui.PickColor"] = new("取色", "Pick Color"),
        ["Ui.SearchColor"] = new("搜色", "Search Color"),
        ["Ui.Diagnose"] = new("诊断", "Diagnose"),
        ["Ui.SelectRegion"] = new("框选区域", "Select Region"),
        ["Ui.SaveRecognition"] = new("保存识别", "Save Recognition"),
        ["Ui.ProfilesLogs"] = new("配置档案 / 日志", "Profiles / Logs"),
        ["Ui.GeneralProfiles"] = new("通用档案", "General Profiles"),
        ["Ui.Refresh"] = new("刷新", "Refresh"),
        ["Ui.Save"] = new("保存", "Save"),
        ["Ui.Load"] = new("加载", "Load"),
        ["Ui.Delete"] = new("删除", "Delete"),
        ["Ui.ImageProfiles"] = new("图像识别档案", "Image Profiles"),
        ["Ui.RuntimeInfo"] = new("运行信息", "Runtime Info"),
        ["Ui.PickedColor"] = new("当前取色", "Picked Color"),
        ["Ui.LastMatch"] = new("最后命中", "Last Match"),
        ["Ui.Ready"] = new("准备就绪", "Ready"),
        ["Ui.SelectKey"] = new("选择按键", "Select Key"),
        ["Ui.ChooseKey"] = new("点一个键", "Choose a key"),
        ["Ui.CurrentKey"] = new("当前：", "Current: "),
        ["Ui.Keyboard"] = new("键盘", "Keyboard"),
        ["Ui.NavigationEdit"] = new("方向 / 编辑", "Navigation / Edit"),
        ["Ui.Numpad"] = new("小键盘", "Numpad"),
        ["Ui.Mouse"] = new("鼠标", "Mouse"),
        ["Ui.Cancel"] = new("取消", "Cancel"),
        ["Ui.DebugOverlayTitle"] = new("识别调试", "Recognition Debug"),
        ["Ui.NotStarted"] = new("未启动", "Not started"),
        ["Ui.WaitingScan"] = new("等待扫描", "Waiting to scan"),
        ["Ui.Status"] = new("状态", "Status"),
        ["Ui.Updated"] = new("已更新", "Updated"),
        ["Ui.RegionInstruction"] = new("拖出识别区域，Esc 取消", "Drag to select recognition region. Esc cancels."),
        ["Ui.PickerInstruction"] = new("移动鼠标取色", "Move mouse to pick color"),
        ["Ui.PickerHint"] = new("红框内为目标像素，左键确认，Esc 取消", "Red box marks target pixel. Left-click to confirm, Esc to cancel"),
        ["Status.ConfigLoaded"] = new("配置已加载", "Settings loaded"),
        ["Status.ProgramStarted"] = new("程序已启动。", "Program started."),
        ["Status.Saved"] = new("已保存", "Saved"),
        ["Status.Reloaded"] = new("已重载", "Reloaded"),
        ["Status.Deleted"] = new("已删除", "Deleted"),
        ["Status.Loaded"] = new("已加载", "Loaded"),
        ["Status.Enabled"] = new("已开启", "Enabled"),
        ["Status.Disabled"] = new("已关闭", "Disabled"),
        ["Status.SavedLog"] = new("已保存。", "Saved."),
        ["Status.ReloadedLog"] = new("已重载。", "Reloaded."),
        ["Status.SaveComplete"] = new("保存完成：{0}", "Save complete: {0}"),
        ["Status.ReloadComplete"] = new("重载完成：{0}", "Reload complete: {0}"),
        ["Status.RecoilSaved"] = new("压枪已保存", "Recoil saved"),
        ["Status.BreathSaved"] = new("屏息已保存", "Breath hold saved"),
        ["Status.Cut31Saved"] = new("31切枪已保存", "31 swap saved"),
        ["Status.RecognitionSaved"] = new("识别已保存", "Recognition saved"),
        ["Status.LanguageChanged"] = new("语言已切换。", "Language changed."),
        ["Error.IntRequired"] = new("{0} 要填整数", "{0} must be an integer"),
        ["Error.InvalidKey"] = new("{0}无效，请重新选择", "{0} is invalid. Please select again"),
        ["Error.InvalidTargetColor"] = new("目标颜色格式无效，示例：0xFFFF00 或 FFFF00", "Invalid target color. Example: 0xFFFF00 or FFFF00"),
        ["Error.TargetColorInvalidShort"] = new("目标颜色格式无效", "Invalid target color"),
        ["Error.MasterHotkeySupported"] = new("总开关热键支持 PageDown、PageUp、Insert、Delete、Home、End、F1、F3-F12", "Master hotkey supports PageDown, PageUp, Insert, Delete, Home, End, F1, and F3-F12"),
        ["Picker.MasterHint"] = new("总开关只能用键盘热键。", "The master switch only supports keyboard hotkeys."),
        ["Picker.KeyMouseHint"] = new("可选键盘键或鼠标键。", "Keyboard keys and mouse buttons are supported."),
        ["Picker.MasterTitle"] = new("选择总开关热键", "Select Master Hotkey"),
        ["Picker.BreathTitle"] = new("选择屏息键", "Select Breath Key"),
        ["Picker.TriggerTitle"] = new("选择识别发送键", "Select Recognition Send Key"),
        ["Label.Tolerance"] = new("容差", "Tolerance"),
        ["Label.Interval"] = new("间隔", "Interval"),
        ["Label.HitStreak"] = new("连续命中", "Hit Streak"),
        ["Label.ImageCooldown"] = new("图像冷却", "Image Cooldown"),
        ["Label.PickOffsetX"] = new("取色偏移X", "Pick Offset X"),
        ["Label.PickOffsetY"] = new("取色偏移Y", "Pick Offset Y"),
        ["Label.FireRate"] = new("射速", "Fire Rate"),
        ["Label.VerticalForce"] = new("垂直力度", "Vertical Force"),
        ["Label.HorizontalForce"] = new("水平力度", "Horizontal Force"),
        ["Label.Cut31Interval"] = new("31间隔", "31 Interval"),
        ["Label.MasterHotkey"] = new("总开关热键", "Master Hotkey"),
        ["Label.TriggerKey"] = new("识别发送键", "Recognition Send Key"),
        ["Label.BreathKey"] = new("屏息键", "Breath Key"),
        ["Profile.EnterGeneral"] = new("请输入通用档案名称", "Enter a general profile name"),
        ["Profile.SelectGeneral"] = new("请选择通用档案", "Select a general profile"),
        ["Profile.GeneralMissing"] = new("通用档案不存在", "General profile does not exist"),
        ["Profile.EnterImage"] = new("请输入图像识别档案名称", "Enter an image recognition profile name"),
        ["Profile.SelectImage"] = new("请选择图像识别档案", "Select an image recognition profile"),
        ["Profile.ImageMissing"] = new("图像识别档案不存在", "Image recognition profile does not exist"),
        ["Profile.GeneralSaved"] = new("通用档案已保存：{0}", "General profile saved: {0}"),
        ["Profile.GeneralLoaded"] = new("通用档案已加载：{0}", "General profile loaded: {0}"),
        ["Profile.GeneralDeleted"] = new("通用档案已删除：{0}", "General profile deleted: {0}"),
        ["Profile.ImageSaved"] = new("图像识别档案已保存：{0}", "Image recognition profile saved: {0}"),
        ["Profile.ImageLoaded"] = new("图像识别档案已加载：{0}", "Image recognition profile loaded: {0}"),
        ["Profile.ImageDeleted"] = new("图像识别档案已删除：{0}", "Image recognition profile deleted: {0}"),
        ["ColorPicker.Cancelled"] = new("已取消取色", "Color picking cancelled"),
        ["ColorPicker.Source"] = new("放大镜", "Loupe"),
        ["ColorPicker.Status"] = new("取色 {0} @ {1},{2}", "Picked {0} @ {1},{2}"),
        ["ColorPicker.StatusLive"] = new("取色 {0}，实时 {1}", "Picked {0}; live {1}"),
        ["ColorPicker.Log"] = new("取色：{0} @ {1},{2}", "Picked: {0} @ {1},{2}"),
        ["ColorPicker.LogLiveMismatch"] = new("取色：{0} @ {1},{2}，实时读取 {3}，不一致", "Picked: {0} @ {1},{2}; live read {3}; mismatch"),
        ["ColorPicker.Failed"] = new("取色失败：{0}", "Color picking failed: {0}"),
        ["Search.NoMatch"] = new("未命中", "No match"),
        ["Search.TargetNotFound"] = new("未找到目标颜色", "Target color not found"),
        ["Search.NoMatchLog"] = new("未命中：目标 {0}，容差 {1}", "No match: target {0}, tolerance {1}"),
        ["Search.MatchStatus"] = new("命中 {0} @ {1},{2}", "Match {0} @ {1},{2}"),
        ["Search.MatchLog"] = new("命中：{0} @ {1},{2}，目标 {3}", "Match: {0} @ {1},{2}, target {3}"),
        ["Search.Failed"] = new("搜索失败：{0}", "Search failed: {0}"),
        ["Diagnose.InvalidRegion"] = new("诊断失败：区域无效", "Diagnosis failed: invalid region"),
        ["Diagnose.InvalidRegionLog"] = new("诊断失败：区域无效 {0},{1}-{2},{3}", "Diagnosis failed: invalid region {0},{1}-{2},{3}"),
        ["Diagnose.Status"] = new("诊断：{0}，中心 {1}", "Diagnosis: {0}, center {1}"),
        ["Diagnose.Log"] = new("诊断：区域 {0},{1}-{2},{3}，大小 {4}x{5}，中心 {6}，采样色 {7}，匹配 {8}，截图 {9:0.0}ms，文件 {10}", "Diagnosis: region {0},{1}-{2},{3}, size {4}x{5}, center {6}, sampled colors {7}, matches {8}, capture {9:0.0}ms, file {10}"),
        ["Diagnose.SolidRegion"] = new("诊断：区域几乎是单色。若游戏画面不是这样，说明当前截图没有读到游戏。", "Diagnosis: the region is almost a solid color. If the game image is not like this, the current capture is not reading the game."),
        ["Diagnose.Failed"] = new("诊断失败：{0}", "Diagnosis failed: {0}"),
        ["Region.Cancelled"] = new("已取消框选区域", "Region selection cancelled"),
        ["Region.Saved"] = new("区域已保存：{0},{1} - {2},{3}", "Region saved: {0},{1} - {2},{3}"),
        ["Region.Log"] = new("框选区域：{0}x{1} @ {2},{3}", "Selected region: {0}x{1} @ {2},{3}"),
        ["Hotkey.Registered"] = new("热键：{0} / F2", "Hotkeys: {0} / F2"),
        ["Hotkey.MasterOnStatus"] = new("热键总开关：开", "Hotkey Master: On"),
        ["Hotkey.MasterOffStatus"] = new("热键总开关：关", "Hotkey Master: Off"),
        ["Hotkey.MasterOn"] = new("热键总开关已开启。", "Hotkey master enabled."),
        ["Hotkey.MasterOff"] = new("热键总开关已关闭。", "Hotkey master disabled."),
        ["Image.F2OnStatus"] = new("图像识别：开(F2)", "Image Recognition: On (F2)"),
        ["Image.F2OffStatus"] = new("图像识别：关(F2)", "Image Recognition: Off (F2)"),
        ["Image.F2OnDetail"] = new("F2 开", "F2 On"),
        ["Image.F2OffDetail"] = new("F2 关", "F2 Off"),
        ["Image.Enabled"] = new("图像识别已开启。", "Image recognition enabled."),
        ["Image.Disabled"] = new("图像识别已关闭。", "Image recognition disabled."),
        ["Image.MatchStatus"] = new("识别命中 @ {0},{1}，连续 {2}", "Recognition match @ {0},{1}, streak {2}"),
        ["Image.MatchLog"] = new("识别命中：{0} @ {1},{2}，连续 {3}", "Recognition match: {0} @ {1},{2}, streak {3}"),
        ["Image.WaitingDetail"] = new("区域 {0},{1}-{2},{3}", "Region {0},{1}-{2},{3}"),
        ["Input.HookStarted"] = new("输入监听已启动。", "Input hook started."),
        ["Input.HookFailed"] = new("输入监听启动失败：{0}", "Input hook failed to start: {0}"),
        ["Input.HookFailedStatus"] = new("输入监听失败，请用管理员身份运行。", "Input hook failed. Run as administrator."),
        ["Input.MouseHookStartFailed"] = new("全局鼠标监听启动失败", "Global mouse hook failed to start"),
        ["Input.KeyboardHookStartFailed"] = new("全局键盘监听启动失败", "Global keyboard hook failed to start"),
        ["Runtime.Cut31Done"] = new("31切枪完成。", "31 swap complete."),
        ["Runtime.RecoilStart"] = new("压枪开始。", "Recoil started."),
        ["Runtime.RecoilEnd"] = new("压枪结束。", "Recoil stopped."),
        ["Runtime.SemiAutoStart"] = new("半自动开始。", "Semi-auto started."),
        ["Runtime.SemiAutoEnd"] = new("半自动结束。", "Semi-auto stopped."),
        ["ImageDebug.Match"] = new("命中", "Match"),
        ["ImageDebug.Trigger"] = new("触发", "Trigger"),
        ["ImageDebug.Stopped"] = new("已停止", "Stopped"),
        ["ImageDebug.Scanning"] = new("扫描中", "Scanning"),
        ["ImageDebug.NoMatchDetail"] = new("未命中 | 区域 {0},{1}-{2},{3}", "No match | Region {0},{1}-{2},{3}"),
        ["ImageDebug.MatchDetail"] = new("{0} @ {1},{2} | 连续 {3}/{4}", "{0} @ {1},{2} | Streak {3}/{4}"),
        ["ImageTrigger.Down"] = new("按下 {0}", "Down {0}"),
        ["ImageTrigger.Up"] = new("抬起 {0}", "Up {0}"),
        ["ImageTrigger.Tap"] = new("点击 {0}", "Tap {0}"),
        ["ImageTrigger.StatusDown"] = new("图像识别触发：按下 {0}", "Image recognition triggered: down {0}"),
        ["ImageTrigger.StatusUp"] = new("图像识别触发：抬起 {0}", "Image recognition triggered: up {0}"),
        ["ImageTrigger.StatusTap"] = new("图像识别触发：点击 {0}", "Image recognition triggered: tap {0}"),
        ["Image.StatusStopped"] = new("图像识别已停止：{0}", "Image recognition stopped: {0}"),
        ["Image.PlanAutoOff"] = new("识别未启动：自动触发未勾选", "Recognition not started: Auto Trigger is unchecked"),
        ["Image.PlanF2Off"] = new("识别未启动：F2 关", "Recognition not started: F2 is off"),
        ["Image.PlanInvalidColor"] = new("识别未启动：目标颜色格式无效", "Recognition not started: invalid target color"),
        ["Image.PlanScanning"] = new("识别扫描中：区域 {0},{1}-{2},{3}，目标 {4}，{5}ms", "Recognition scanning: region {0},{1}-{2},{3}, target {4}, {5}ms"),
        ["Trajectory.Fixed"] = new("固定方向", "Fixed Direction"),
        ["Trajectory.Alternating"] = new("左右交替", "Alternating"),
        ["Trajectory.Info"] = new("压枪路径 | 垂直: {0}  横向: {1}  模式: {2}", "Recoil path | Vertical: {0}  Horizontal: {1}  Mode: {2}")
    };

    private sealed record LocalizedText(string Chinese, string English);
}
