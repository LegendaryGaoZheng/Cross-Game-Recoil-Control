using System.Drawing;
using System.Drawing.Imaging;
using System.Diagnostics;
using System.IO;
using System.Windows;
using System.Windows.Input;
using System.Windows.Interop;
using LegendaryCSharp.Services;
using Forms = System.Windows.Forms;
using WpfKeyEventArgs = System.Windows.Input.KeyEventArgs;

namespace LegendaryCSharp;

public partial class MainWindow : Window
{
    private const int MasterHotkeyId = 1001;
    private const int ImageHotkeyId = 1002;
    private const double TrajectoryStartY = 28;
    private const double TrajectoryMargin = 18;
    private const double TrajectoryScaleMax = 18;
    private const int MaxLogLines = 600;
    private const int LogTrimLines = 120;

    private readonly ScreenCaptureService _screenCapture = new();
    private readonly InputService _input = new();
    private readonly ProfileStore _profiles = new();
    private readonly AssistantRuntime _runtime;
    private readonly ImageRecognitionMonitor _imageMonitor;
    private readonly GlobalInputHook _inputHook = new();
    private readonly StatusOverlayWindow _statusOverlay = new();
    private readonly ImageDebugOverlayWindow _imageDebugOverlay = new();
    private AppSettings _settings = AppSettings.Load();
    private HwndSource? _hwndSource;
    private int _logLineCount;

    public MainWindow()
    {
        InitializeComponent();
        _runtime = new AssistantRuntime(_input);
        _runtime.StatusChanged += (_, message) => RunOnUi(() => Log(message));
        _imageMonitor = new ImageRecognitionMonitor(_screenCapture, _input);
        _imageMonitor.MatchFound += ImageMonitor_MatchFound;
        _imageMonitor.DebugUpdated += ImageMonitor_DebugUpdated;
        _imageMonitor.StatusChanged += (_, message) => RunOnUi(() =>
        {
            SetStatus(message);
            Log(message);
        });
        _inputHook.MouseButtonChanged += InputHook_MouseButtonChanged;
        _inputHook.MouseWheel += InputHook_MouseWheel;
        _runtime.ApplySettings(_settings);
        LoadSettingsIntoUi();
        RefreshProfiles();
        Log("程序已启动。");
    }

    protected override void OnSourceInitialized(EventArgs e)
    {
        base.OnSourceInitialized(e);
        _hwndSource = HwndSource.FromHwnd(new WindowInteropHelper(this).Handle);
        _hwndSource?.AddHook(WndProc);
        RegisterHotkeys();
        StartInputHook();
    }

    protected override void OnClosed(EventArgs e)
    {
        _imageMonitor.Stop();
        _inputHook.Dispose();
        _screenCapture.Dispose();
        _statusOverlay.Close();
        _imageDebugOverlay.Close();
        UnregisterHotkeys();
        _hwndSource?.RemoveHook(WndProc);
        base.OnClosed(e);
    }

    private void LoadSettingsIntoUi()
    {
        ImageRecognitionEnabledBox.IsChecked = _settings.ImageRecognitionEnabled;
        RecoilEnabledBox.IsChecked = _settings.RecoilEnabled;
        BreathHoldEnabledBox.IsChecked = _settings.BreathHoldEnabled;
        SemiAutoModeBox.IsChecked = _settings.SemiAutoMode;
        Cut31EnabledBox.IsChecked = _settings.Cut31Enabled;
        SearchX1Box.Text = _settings.SearchX1.ToString();
        SearchY1Box.Text = _settings.SearchY1.ToString();
        SearchX2Box.Text = _settings.SearchX2.ToString();
        SearchY2Box.Text = _settings.SearchY2.ToString();
        TargetColorBox.Text = _settings.TargetColor;
        ToleranceBox.Text = _settings.ColorTolerance.ToString();
        IntervalBox.Text = _settings.SearchIntervalMs.ToString();
        TriggerKeyBox.Text = _settings.TriggerKey;
        HitStreakBox.Text = _settings.ImageHitStreakRequired.ToString();
        TriggerModeBox.SelectedIndex = (int)_settings.ImageTriggerMode;
        ImageCooldownBox.Text = _settings.ImageTriggerCooldownMs.ToString();
        ImageDebugBox.IsChecked = _settings.ImageDebug;
        ColorPickOffsetXBox.Text = _settings.ColorPickOffsetX.ToString();
        ColorPickOffsetYBox.Text = _settings.ColorPickOffsetY.ToString();
        MasterHotkeyBox.Text = string.IsNullOrWhiteSpace(_settings.MasterHotkey) ? "PageDown" : _settings.MasterHotkey;
        FireRateBox.Text = _settings.FireRate.ToString();
        RecoilForceBox.Text = _settings.RecoilForce.ToString();
        HorizontalRecoilBox.Text = _settings.HorizontalRecoil.ToString();
        HorizontalPatternBox.SelectedIndex = Math.Clamp(_settings.HorizontalPattern, 0, 1);
        TriggerSideKeyBox.SelectedIndex = TriggerSideKeyToIndex(_settings.TriggerSideKey);
        BreathHoldKeyBox.Text = _settings.BreathHoldKey;
        Cut31IntervalBox.Text = _settings.Cut31IntervalMs.ToString();
        StatusText.Text = AppSettings.SettingsSummary;
        ApplyRuntimeSettings();
        UpdateTrajectoryPreview();
    }

    private bool TryReadSettingsFromUi(out AppSettings settings)
    {
        settings = new AppSettings();
        if (!TryReadInt(SearchX1Box.Text, "X1", out var x1)
            || !TryReadInt(SearchY1Box.Text, "Y1", out var y1)
            || !TryReadInt(SearchX2Box.Text, "X2", out var x2)
            || !TryReadInt(SearchY2Box.Text, "Y2", out var y2)
            || !TryReadInt(ToleranceBox.Text, "容差", out var tolerance)
            || !TryReadInt(IntervalBox.Text, "间隔", out var interval)
            || !TryReadInt(HitStreakBox.Text, "连续命中", out var hitStreak)
            || !TryReadInt(ImageCooldownBox.Text, "图像冷却", out var imageCooldown)
            || !TryReadInt(ColorPickOffsetXBox.Text, "取色偏移X", out var colorPickOffsetX)
            || !TryReadInt(ColorPickOffsetYBox.Text, "取色偏移Y", out var colorPickOffsetY)
            || !TryReadInt(FireRateBox.Text, "射速", out var fireRate)
            || !TryReadInt(RecoilForceBox.Text, "垂直力度", out var recoilForce)
            || !TryReadInt(HorizontalRecoilBox.Text, "水平力度", out var horizontalRecoil)
            || !TryReadInt(Cut31IntervalBox.Text, "31间隔", out var cut31Interval))
        {
            return false;
        }

        if (!ColorUtilities.TryParseHexColor(TargetColorBox.Text, out var targetRgb))
        {
            SetStatus("目标颜色格式无效，示例：0xFFFF00 或 FFFF00");
            return false;
        }

        if (!TryReadConfiguredKey(MasterHotkeyBox.Text, "总开关热键", KeySelectionMode.MasterHotkey, "PageDown", out var masterHotkey)
            || !TryReadConfiguredKey(TriggerKeyBox.Text, "识别发送键", KeySelectionMode.KeyboardAndMouse, "X", out var triggerKey)
            || !TryReadConfiguredKey(BreathHoldKeyBox.Text, "屏息键", KeySelectionMode.KeyboardAndMouse, "L", out var breathHoldKey))
        {
            return false;
        }

        settings.ImageRecognitionEnabled = ImageRecognitionEnabledBox.IsChecked == true;
        settings.MasterHotkey = masterHotkey;
        settings.ImageRecognitionF2Enabled = _settings.ImageRecognitionF2Enabled;
        settings.MasterEnabled = _runtime.MasterEnabled;
        settings.RecoilEnabled = RecoilEnabledBox.IsChecked == true;
        settings.BreathHoldEnabled = BreathHoldEnabledBox.IsChecked == true;
        settings.SemiAutoMode = SemiAutoModeBox.IsChecked == true;
        settings.Cut31Enabled = Cut31EnabledBox.IsChecked == true;
        settings.SearchX1 = x1;
        settings.SearchY1 = y1;
        settings.SearchX2 = x2;
        settings.SearchY2 = y2;
        settings.ColorTolerance = Math.Clamp(tolerance, 0, 255);
        settings.SearchIntervalMs = Math.Clamp(interval, 20, 2000);
        settings.TargetColor = ColorUtilities.ToHex(targetRgb);
        settings.UseTargetColor = true;
        settings.ColorPickOffsetX = Math.Clamp(colorPickOffsetX, -200, 200);
        settings.ColorPickOffsetY = Math.Clamp(colorPickOffsetY, -200, 200);
        settings.TriggerKey = triggerKey;
        settings.ImageHitStreakRequired = Math.Clamp(hitStreak, 1, 20);
        settings.ImageTriggerMode = (ImageTriggerMode)Math.Clamp(TriggerModeBox.SelectedIndex, 0, 3);
        settings.ImageTriggerCooldownMs = Math.Clamp(imageCooldown, 0, 10000);
        settings.ImageDebug = ImageDebugBox.IsChecked == true;
        settings.FireRate = Math.Clamp(fireRate, 100, 2000);
        settings.RecoilForce = Math.Clamp(recoilForce, 0, 30);
        settings.HorizontalRecoil = Math.Clamp(horizontalRecoil, -15, 15);
        settings.HorizontalPattern = Math.Clamp(HorizontalPatternBox.SelectedIndex, 0, 1);
        settings.TriggerSideKey = SelectedComboContent(TriggerSideKeyBox, "XButton2");
        settings.BreathHoldKey = breathHoldKey;
        settings.Cut31IntervalMs = Math.Clamp(cut31Interval, 10, 2000);
        return true;
    }

    private bool TryReadGeneralSettingsFromUi(out AppSettings settings)
    {
        settings = CloneSettings(_settings);
        if (!TryReadInt(FireRateBox.Text, "射速", out var fireRate)
            || !TryReadInt(RecoilForceBox.Text, "垂直力度", out var recoilForce)
            || !TryReadInt(HorizontalRecoilBox.Text, "水平力度", out var horizontalRecoil)
            || !TryReadInt(Cut31IntervalBox.Text, "31间隔", out var cut31Interval))
        {
            return false;
        }

        if (!TryReadConfiguredKey(MasterHotkeyBox.Text, "总开关热键", KeySelectionMode.MasterHotkey, "PageDown", out var masterHotkey)
            || !TryReadConfiguredKey(BreathHoldKeyBox.Text, "屏息键", KeySelectionMode.KeyboardAndMouse, "L", out var breathHoldKey))
        {
            return false;
        }

        settings.MasterHotkey = masterHotkey;
        settings.MasterEnabled = _runtime.MasterEnabled;
        settings.TriggerSideKey = SelectedComboContent(TriggerSideKeyBox, "XButton2");
        settings.FireRate = Math.Clamp(fireRate, 100, 2000);
        settings.RecoilForce = Math.Clamp(recoilForce, 0, 30);
        settings.HorizontalRecoil = Math.Clamp(horizontalRecoil, -15, 15);
        settings.HorizontalPattern = Math.Clamp(HorizontalPatternBox.SelectedIndex, 0, 1);
        settings.RecoilEnabled = RecoilEnabledBox.IsChecked == true;
        settings.BreathHoldEnabled = BreathHoldEnabledBox.IsChecked == true;
        settings.BreathHoldKey = breathHoldKey;
        settings.SemiAutoMode = SemiAutoModeBox.IsChecked == true;
        settings.Cut31Enabled = Cut31EnabledBox.IsChecked == true;
        settings.Cut31IntervalMs = Math.Clamp(cut31Interval, 10, 2000);
        return true;
    }

    private bool TryReadImageSettingsFromUi(out AppSettings settings)
    {
        settings = CloneSettings(_settings);
        if (!TryReadInt(SearchX1Box.Text, "X1", out var x1)
            || !TryReadInt(SearchY1Box.Text, "Y1", out var y1)
            || !TryReadInt(SearchX2Box.Text, "X2", out var x2)
            || !TryReadInt(SearchY2Box.Text, "Y2", out var y2)
            || !TryReadInt(ToleranceBox.Text, "容差", out var tolerance)
            || !TryReadInt(IntervalBox.Text, "间隔", out var interval)
            || !TryReadInt(HitStreakBox.Text, "连续命中", out var hitStreak)
            || !TryReadInt(ImageCooldownBox.Text, "图像冷却", out var imageCooldown)
            || !TryReadInt(ColorPickOffsetXBox.Text, "取色偏移X", out var colorPickOffsetX)
            || !TryReadInt(ColorPickOffsetYBox.Text, "取色偏移Y", out var colorPickOffsetY))
        {
            return false;
        }

        if (!ColorUtilities.TryParseHexColor(TargetColorBox.Text, out var targetRgb))
        {
            SetStatus("目标颜色格式无效，示例：0xFFFF00 或 FFFF00");
            return false;
        }

        if (!TryReadConfiguredKey(TriggerKeyBox.Text, "识别发送键", KeySelectionMode.KeyboardAndMouse, "X", out var triggerKey))
        {
            return false;
        }

        settings.ImageRecognitionEnabled = ImageRecognitionEnabledBox.IsChecked == true;
        settings.ImageRecognitionF2Enabled = _settings.ImageRecognitionF2Enabled;
        settings.SearchX1 = x1;
        settings.SearchY1 = y1;
        settings.SearchX2 = x2;
        settings.SearchY2 = y2;
        settings.ColorTolerance = Math.Clamp(tolerance, 0, 255);
        settings.SearchIntervalMs = Math.Clamp(interval, 20, 2000);
        settings.TargetColor = ColorUtilities.ToHex(targetRgb);
        settings.UseTargetColor = true;
        settings.ColorPickOffsetX = Math.Clamp(colorPickOffsetX, -200, 200);
        settings.ColorPickOffsetY = Math.Clamp(colorPickOffsetY, -200, 200);
        settings.TriggerKey = triggerKey;
        settings.ImageHitStreakRequired = Math.Clamp(hitStreak, 1, 20);
        settings.ImageTriggerMode = (ImageTriggerMode)Math.Clamp(TriggerModeBox.SelectedIndex, 0, 3);
        settings.ImageTriggerCooldownMs = Math.Clamp(imageCooldown, 0, 10000);
        settings.ImageDebug = ImageDebugBox.IsChecked == true;
        return true;
    }

    private static AppSettings CloneSettings(AppSettings source) => new()
    {
        MasterHotkey = source.MasterHotkey,
        MasterEnabled = source.MasterEnabled,
        TriggerSideKey = source.TriggerSideKey,
        FireRate = source.FireRate,
        RecoilForce = source.RecoilForce,
        HorizontalRecoil = source.HorizontalRecoil,
        HorizontalPattern = source.HorizontalPattern,
        RecoilEnabled = source.RecoilEnabled,
        BreathHoldEnabled = source.BreathHoldEnabled,
        BreathHoldKey = source.BreathHoldKey,
        SemiAutoMode = source.SemiAutoMode,
        Cut31Enabled = source.Cut31Enabled,
        Cut31IntervalMs = source.Cut31IntervalMs,
        ImageRecognitionEnabled = source.ImageRecognitionEnabled,
        ImageRecognitionF2Enabled = source.ImageRecognitionF2Enabled,
        SearchX1 = source.SearchX1,
        SearchY1 = source.SearchY1,
        SearchX2 = source.SearchX2,
        SearchY2 = source.SearchY2,
        ColorTolerance = source.ColorTolerance,
        SearchIntervalMs = source.SearchIntervalMs,
        TargetColor = source.TargetColor,
        UseTargetColor = true,
        ColorPickOffsetX = source.ColorPickOffsetX,
        ColorPickOffsetY = source.ColorPickOffsetY,
        TriggerKey = source.TriggerKey,
        ImageHitStreakRequired = source.ImageHitStreakRequired,
        ImageTriggerMode = source.ImageTriggerMode,
        ImageTriggerCooldownMs = source.ImageTriggerCooldownMs,
        ImageDebug = source.ImageDebug
    };

    private bool TryReadInt(string text, string name, out int value)
    {
        if (int.TryParse(text.Trim(), out value))
        {
            return true;
        }

        SetStatus($"{name} 要填整数");
        return false;
    }

    private bool TryReadConfiguredKey(
        string text,
        string name,
        KeySelectionMode mode,
        string fallback,
        out string key)
    {
        var candidate = string.IsNullOrWhiteSpace(text) ? fallback : text;
        if (KeySelectionCatalog.TryNormalize(candidate, mode, out key))
        {
            return true;
        }

        SetStatus($"{name}无效，请重新选择");
        key = string.Empty;
        return false;
    }

    private void SaveButton_Click(object sender, RoutedEventArgs e)
    {
        if (!TryReadSettingsFromUi(out var settings))
        {
            return;
        }

        _settings = settings;
        _settings.Save();
        LoadSettingsIntoUi();
        RegisterHotkeys();
        ShowButtonFeedback(SaveButton, "已保存");
        SetStatus($"保存完成：{DateTime.Now:HH:mm:ss}");
        Log("已保存。");
    }

    private void ReloadButton_Click(object sender, RoutedEventArgs e)
    {
        _settings = AppSettings.Load();
        _runtime.ApplySettings(_settings);
        LoadSettingsIntoUi();
        RegisterHotkeys();
        ShowButtonFeedback(ReloadButton, "已重载");
        SetStatus($"重载完成：{DateTime.Now:HH:mm:ss}");
        Log("已重载。");
    }

    private void SaveRecoilModuleButton_Click(object sender, RoutedEventArgs e) =>
        SaveCurrentGeneralSettings("压枪已保存");

    private void SaveBreathModuleButton_Click(object sender, RoutedEventArgs e) =>
        SaveCurrentGeneralSettings("屏息已保存");

    private void SaveCut31ModuleButton_Click(object sender, RoutedEventArgs e) =>
        SaveCurrentGeneralSettings("31切枪已保存");

    private void SaveImageModuleButton_Click(object sender, RoutedEventArgs e) =>
        SaveCurrentImageSettings("识别已保存");

    private void RefreshProfilesButton_Click(object sender, RoutedEventArgs e) => RefreshProfiles();

    private void SaveGeneralProfileButton_Click(object sender, RoutedEventArgs e)
    {
        if (!TryReadGeneralSettingsFromUi(out var settings))
        {
            return;
        }

        var name = GetProfileName(GeneralProfileBox);
        if (string.IsNullOrWhiteSpace(name))
        {
            SetStatus("请输入通用档案名称");
            return;
        }

        _profiles.SaveGeneralProfile(name, settings);
        RefreshProfiles(name, null);
        ShowButtonFeedback(SaveGeneralProfileButton, "已保存");
        Log($"通用档案已保存：{name}");
    }

    private void LoadGeneralProfileButton_Click(object sender, RoutedEventArgs e)
    {
        var name = GetProfileName(GeneralProfileBox);
        if (string.IsNullOrWhiteSpace(name))
        {
            SetStatus("请选择通用档案");
            return;
        }

        if (!_profiles.LoadGeneralProfile(name, _settings))
        {
            SetStatus("通用档案不存在");
            return;
        }

        _settings.Save();
        _runtime.ApplySettings(_settings);
        LoadSettingsIntoUi();
        RegisterHotkeys();
        RefreshProfiles(name, null);
        ShowButtonFeedback(LoadGeneralProfileButton, "已加载");
        Log($"通用档案已加载：{name}");
    }

    private void DeleteGeneralProfileButton_Click(object sender, RoutedEventArgs e)
    {
        var name = GetProfileName(GeneralProfileBox);
        if (string.IsNullOrWhiteSpace(name))
        {
            SetStatus("请选择通用档案");
            return;
        }

        _profiles.DeleteGeneralProfile(name);
        RefreshProfiles();
        ShowButtonFeedback(DeleteGeneralProfileButton, "已删除");
        Log($"通用档案已删除：{name}");
    }

    private void SaveImageProfileButton_Click(object sender, RoutedEventArgs e)
    {
        if (!TryReadImageSettingsFromUi(out var settings))
        {
            return;
        }

        var name = GetProfileName(ImageProfileBox);
        if (string.IsNullOrWhiteSpace(name))
        {
            SetStatus("请输入图像识别档案名称");
            return;
        }

        _profiles.SaveImageRecognitionProfile(name, settings);
        RefreshProfiles(null, name);
        ShowButtonFeedback(SaveImageProfileButton, "已保存");
        Log($"图像识别档案已保存：{name}");
    }

    private void LoadImageProfileButton_Click(object sender, RoutedEventArgs e)
    {
        var name = GetProfileName(ImageProfileBox);
        if (string.IsNullOrWhiteSpace(name))
        {
            SetStatus("请选择图像识别档案");
            return;
        }

        if (!_profiles.LoadImageRecognitionProfile(name, _settings))
        {
            SetStatus("图像识别档案不存在");
            return;
        }

        _settings.Save();
        _runtime.ApplySettings(_settings);
        LoadSettingsIntoUi();
        RefreshProfiles(null, name);
        ShowButtonFeedback(LoadImageProfileButton, "已加载");
        Log($"图像识别档案已加载：{name}");
    }

    private void DeleteImageProfileButton_Click(object sender, RoutedEventArgs e)
    {
        var name = GetProfileName(ImageProfileBox);
        if (string.IsNullOrWhiteSpace(name))
        {
            SetStatus("请选择图像识别档案");
            return;
        }

        _profiles.DeleteImageRecognitionProfile(name);
        RefreshProfiles();
        ShowButtonFeedback(DeleteImageProfileButton, "已删除");
        Log($"图像识别档案已删除：{name}");
    }

    private void HelpButton_Click(object sender, RoutedEventArgs e)
    {
        var window = new UsageInstructionsWindow { Owner = this };
        window.ShowDialog();
    }

    private void OpenProfilesButton_Click(object sender, RoutedEventArgs e) => MainTabs.SelectedIndex = 4;

    private void OpenRecoilButton_Click(object sender, RoutedEventArgs e) => MainTabs.SelectedIndex = 1;

    private void OpenBreathButton_Click(object sender, RoutedEventArgs e) => MainTabs.SelectedIndex = 2;

    private void OpenImageButton_Click(object sender, RoutedEventArgs e) => MainTabs.SelectedIndex = 3;

    private void HotkeyBox_PreviewKeyDown(object sender, WpfKeyEventArgs e)
    {
        if (sender is not System.Windows.Controls.TextBox textBox)
        {
            return;
        }

        var key = GetActualKey(e);
        if (key is Key.None
            or Key.ImeProcessed
            or Key.DeadCharProcessed
            or Key.LeftAlt
            or Key.RightAlt
            or Key.LeftCtrl
            or Key.RightCtrl
            or Key.LeftShift
            or Key.RightShift)
        {
            e.Handled = true;
            return;
        }

        var hotkeyName = ToHotkeyName(key);
        if (!KeySelectionCatalog.TryNormalize(hotkeyName, KeySelectionMode.MasterHotkey, out var normalizedName))
        {
        SetStatus("总开关热键支持 PageDown、PageUp、Insert、Delete、Home、End、F1、F3-F12");
            e.Handled = true;
            return;
        }

        textBox.Text = normalizedName;
        textBox.CaretIndex = textBox.Text.Length;
        e.Handled = true;
    }

    private void PickMasterHotkeyButton_Click(object sender, RoutedEventArgs e) =>
        PickKey(MasterHotkeyBox, "选择总开关热键", KeySelectionMode.MasterHotkey);

    private void PickBreathHoldKeyButton_Click(object sender, RoutedEventArgs e) =>
        PickKey(BreathHoldKeyBox, "选择屏息键", KeySelectionMode.KeyboardAndMouse);

    private void PickTriggerKeyButton_Click(object sender, RoutedEventArgs e) =>
        PickKey(TriggerKeyBox, "选择识别发送键", KeySelectionMode.KeyboardAndMouse);

    private void PickKey(System.Windows.Controls.TextBox target, string title, KeySelectionMode mode)
    {
        var picker = new KeyPickerWindow(title, target.Text, mode) { Owner = this };
        if (picker.ShowDialog() != true)
        {
            return;
        }

        target.Text = picker.SelectedKey;
        SetStatus($"{title}：{picker.SelectedKey}");
    }

    private void PickColorButton_Click(object sender, RoutedEventArgs e)
    {
        try
        {
            Hide();
            Dispatcher.Invoke(() => { }, System.Windows.Threading.DispatcherPriority.ApplicationIdle);
            var picker = new PixelPickerWindow();
            if (picker.ShowDialog() != true || picker.SelectedPixel is not { } pixel)
            {
                SetStatus("已取消取色");
                return;
            }

            var hex = ColorUtilities.ToHex(pixel.Rgb);
            var liveRgb = _screenCapture.GetPixelColor(pixel.X, pixel.Y);
            var liveHex = ColorUtilities.ToHex(liveRgb);
            ExtractedColorBox.Text = hex;
            PickedColorBox.Text = $"{hex} @ {pixel.X},{pixel.Y} [放大镜]";
            SetStatus(liveRgb == pixel.Rgb
                ? $"取色 {hex} @ {pixel.X},{pixel.Y}"
                : $"取色 {hex}，实时 {liveHex}");
            Log(liveRgb == pixel.Rgb
                ? $"取色：{hex} @ {pixel.X},{pixel.Y}"
                : $"取色：{hex} @ {pixel.X},{pixel.Y}，实时读取 {liveHex}，不一致");
        }
        catch (Exception ex)
        {
            SetStatus("取色失败：" + ex.Message);
            Log(ex.ToString());
        }
        finally
        {
            Show();
            Activate();
        }
    }

    private void SearchColorButton_Click(object sender, RoutedEventArgs e)
    {
        if (!TryReadSettingsFromUi(out var settings))
        {
            return;
        }

        if (!ColorUtilities.TryParseHexColor(settings.TargetColor, out var targetRgb))
        {
            SetStatus("目标颜色格式无效");
            return;
        }

        try
        {
            var region = System.Drawing.Rectangle.FromLTRB(settings.SearchX1, settings.SearchY1, settings.SearchX2, settings.SearchY2);
            var result = _screenCapture.FindColor(region, targetRgb, settings.ColorTolerance);
            if (result is null)
            {
                SearchResultBox.Text = "未命中";
                SetStatus("未找到目标颜色");
                Log($"未命中：目标 {settings.TargetColor}，容差 {settings.ColorTolerance}");
                return;
            }

            var foundHex = ColorUtilities.ToHex(result.Rgb);
            SearchResultBox.Text = $"{foundHex} @ {result.X},{result.Y}";
            SetStatus($"命中 {foundHex} @ {result.X},{result.Y}");
            Log($"命中：{foundHex} @ {result.X},{result.Y}，目标 {settings.TargetColor}");
        }
        catch (Exception ex)
        {
            SetStatus("搜索失败：" + ex.Message);
            Log(ex.ToString());
        }
    }

    private void DiagnoseImageButton_Click(object sender, RoutedEventArgs e)
    {
        if (!TryReadImageSettingsFromUi(out var settings))
        {
            return;
        }

        if (!ColorUtilities.TryParseHexColor(settings.TargetColor, out var targetRgb))
        {
            SetStatus("目标颜色格式无效");
            return;
        }

        var region = System.Drawing.Rectangle.FromLTRB(settings.SearchX1, settings.SearchY1, settings.SearchX2, settings.SearchY2);
        try
        {
            var stopwatch = Stopwatch.StartNew();
            using var capture = _screenCapture.CaptureRegion(region);
            stopwatch.Stop();
            if (capture is null)
            {
                SetStatus("诊断失败：区域无效");
                Log($"诊断失败：区域无效 {region.Left},{region.Top}-{region.Right},{region.Bottom}");
                return;
            }

            var analysis = AnalyzeCapture(capture.Image, targetRgb, settings.ColorTolerance);
            var imagePath = Path.Combine(AppContext.BaseDirectory, "image-diagnostic.png");
            capture.Image.Save(imagePath, ImageFormat.Png);

            var hitText = analysis.FirstHit is null
                ? "未命中"
                : $"命中 {ColorUtilities.ToHex(analysis.FirstHit.Rgb)} @ {capture.Left + analysis.FirstHit.X},{capture.Top + analysis.FirstHit.Y}";
            var matchText = analysis.MatchCountCapped ? $"{analysis.MatchCount}+" : analysis.MatchCount.ToString();
            SetStatus($"诊断：{hitText}，中心 {ColorUtilities.ToHex(analysis.CenterRgb)}");
            Log(
                $"诊断：区域 {capture.Left},{capture.Top}-{capture.Left + capture.Image.Width - 1},{capture.Top + capture.Image.Height - 1}，" +
                $"大小 {capture.Image.Width}x{capture.Image.Height}，中心 {ColorUtilities.ToHex(analysis.CenterRgb)}，" +
                $"采样色 {analysis.DistinctSampledColors}，匹配 {matchText}，截图 {stopwatch.Elapsed.TotalMilliseconds:0.0}ms，文件 {imagePath}");

            if (analysis.DistinctSampledColors <= 1)
            {
                Log("诊断：区域几乎是单色。若游戏画面不是这样，说明当前截图没有读到游戏。");
            }
        }
        catch (Exception ex)
        {
            SetStatus("诊断失败：" + ex.Message);
            Log(ex.ToString());
        }
    }

    private void PickRegionButton_Click(object sender, RoutedEventArgs e)
    {
        var picker = new RegionSelectionWindow { Owner = this };
        if (picker.ShowDialog() != true || picker.SelectedRegion is not { } region)
        {
            SetStatus("已取消框选区域");
            return;
        }

        SearchX1Box.Text = region.Left.ToString();
        SearchY1Box.Text = region.Top.ToString();
        SearchX2Box.Text = region.Right.ToString();
        SearchY2Box.Text = region.Bottom.ToString();

        if (TryReadSettingsFromUi(out var settings))
        {
            _settings = settings;
            _settings.Save();
            ApplyRuntimeSettings();
            SetStatus($"区域已保存：{region.Left},{region.Top} - {region.Right},{region.Bottom}");
        }

        Log($"框选区域：{region.Width}x{region.Height} @ {region.Left},{region.Top}");
    }

    private static CaptureAnalysis AnalyzeCapture(Bitmap bitmap, int targetRgb, int tolerance)
    {
        var center = bitmap.GetPixel(bitmap.Width / 2, bitmap.Height / 2);
        var centerRgb = (center.R << 16) | (center.G << 8) | center.B;
        var distinctColors = new HashSet<int>();
        var sampleStep = Math.Max(1, (int)Math.Sqrt(bitmap.Width * bitmap.Height / 10000.0));
        var matchCount = 0;
        var matchCountCapped = false;
        CaptureHit? firstHit = null;

        var bounds = new System.Drawing.Rectangle(0, 0, bitmap.Width, bitmap.Height);
        var data = bitmap.LockBits(bounds, ImageLockMode.ReadOnly, PixelFormat.Format32bppArgb);
        try
        {
            unsafe
            {
                var basePtr = (byte*)data.Scan0;
                for (var y = 0; y < bounds.Height; y++)
                {
                    var row = basePtr + y * data.Stride;
                    for (var x = 0; x < bounds.Width; x++)
                    {
                        var pixel = row + x * 4;
                        var rgb = ColorUtilities.FromBgra(pixel[0], pixel[1], pixel[2]);
                        if (x % sampleStep == 0 && y % sampleStep == 0)
                        {
                            distinctColors.Add(rgb);
                        }

                        if (!ColorUtilities.WithinTolerance(rgb, targetRgb, tolerance))
                        {
                            continue;
                        }

                        firstHit ??= new CaptureHit(x, y, rgb);
                        if (matchCount < 100000)
                        {
                            matchCount++;
                        }
                        else
                        {
                            matchCountCapped = true;
                        }
                    }
                }
            }
        }
        finally
        {
            bitmap.UnlockBits(data);
        }

        return new CaptureAnalysis(centerRgb, distinctColors.Count, matchCount, matchCountCapped, firstHit);
    }

    private void SetStatus(string message)
    {
        StatusText.Text = message;
    }

    private void Log(string message)
    {
        LogBox.AppendText($"[{DateTime.Now:HH:mm:ss}] {message}{Environment.NewLine}");
        _logLineCount++;
        TrimLogIfNeeded();
        if (LogBox.IsVisible)
        {
            LogBox.ScrollToEnd();
        }
    }

    private void TrimLogIfNeeded()
    {
        if (_logLineCount <= MaxLogLines)
        {
            return;
        }

        var text = LogBox.Text;
        var cutIndex = 0;
        var removed = 0;
        while (removed < LogTrimLines && cutIndex >= 0 && cutIndex < text.Length)
        {
            cutIndex = text.IndexOf(Environment.NewLine, cutIndex, StringComparison.Ordinal);
            if (cutIndex < 0)
            {
                break;
            }

            cutIndex += Environment.NewLine.Length;
            removed++;
        }

        if (cutIndex <= 0 || cutIndex >= text.Length)
        {
            return;
        }

        LogBox.Text = text[cutIndex..];
        LogBox.CaretIndex = LogBox.Text.Length;
        _logLineCount = Math.Max(0, _logLineCount - removed);
    }

    private void SaveCurrentSettings(string message)
    {
        if (!TryReadSettingsFromUi(out var settings))
        {
            return;
        }

        _settings = settings;
        _settings.Save();
        ApplyRuntimeSettings();
        RegisterHotkeys();
        LoadSettingsIntoUi();
        SetStatus($"{message}：{DateTime.Now:HH:mm:ss}");
        Log(message);
    }

    private void SaveCurrentGeneralSettings(string message)
    {
        if (!TryReadGeneralSettingsFromUi(out var settings))
        {
            return;
        }

        _settings = settings;
        _settings.Save();
        ApplyRuntimeSettings();
        RegisterHotkeys();
        LoadSettingsIntoUi();
        SetStatus($"{message}：{DateTime.Now:HH:mm:ss}");
        Log(message);
    }

    private void SaveCurrentImageSettings(string message)
    {
        if (!TryReadImageSettingsFromUi(out var settings))
        {
            return;
        }

        _settings = settings;
        _settings.Save();
        ApplyRuntimeSettings();
        LoadSettingsIntoUi();
        SetStatus($"{message}：{DateTime.Now:HH:mm:ss}");
        Log(message);
    }

    private async void ShowButtonFeedback(System.Windows.Controls.Button button, string doneText)
    {
        var originalContent = button.Content;
        var originalBackground = button.Background;
        var originalForeground = button.Foreground;

        button.Content = doneText;
        button.Background = new System.Windows.Media.SolidColorBrush(System.Windows.Media.Color.FromRgb(46, 125, 50));
        button.Foreground = System.Windows.Media.Brushes.White;
        button.IsEnabled = false;

        await Task.Delay(900);

        if (!button.IsVisible)
        {
            return;
        }

        button.Content = originalContent;
        button.Background = originalBackground;
        button.Foreground = originalForeground;
        button.IsEnabled = true;
    }

    private void RunOnUi(Action action)
    {
        if (Dispatcher.CheckAccess())
        {
            action();
        }
        else
        {
            Dispatcher.BeginInvoke(action, System.Windows.Threading.DispatcherPriority.Background);
        }
    }

    private void RefreshProfiles(string? selectGeneralName = null, string? selectImageName = null)
    {
        RefreshProfileBox(GeneralProfileBox, _profiles.ListGeneralProfiles(), selectGeneralName);
        RefreshProfileBox(ImageProfileBox, _profiles.ListImageRecognitionProfiles(), selectImageName);
    }

    private static void RefreshProfileBox(
        System.Windows.Controls.ComboBox box,
        IReadOnlyList<string> profiles,
        string? selectName)
    {
        var previousText = box.Text.Trim();
        box.ItemsSource = profiles;

        if (!string.IsNullOrWhiteSpace(selectName))
        {
            box.Text = selectName;
            box.SelectedItem = profiles.Contains(selectName) ? selectName : null;
        }
        else if (!string.IsNullOrWhiteSpace(previousText))
        {
            box.Text = previousText;
            box.SelectedItem = profiles.Contains(previousText) ? previousText : null;
        }
        else if (profiles.Count > 0)
        {
            box.SelectedIndex = 0;
            box.Text = profiles[0];
        }
        else
        {
            box.SelectedItem = null;
            box.Text = string.Empty;
        }
    }

    private static string GetProfileName(System.Windows.Controls.ComboBox box)
    {
        var typed = box.Text.Trim();
        if (!string.IsNullOrWhiteSpace(typed))
        {
            return typed;
        }

        return box.SelectedItem?.ToString() ?? string.Empty;
    }

    private void RegisterHotkeys()
    {
        var hwnd = new WindowInteropHelper(this).Handle;
        UnregisterHotkeys();
        var masterVk = KeyNameMapper.ToVirtualKey(_settings.MasterHotkey);
        if (masterVk == 0)
        {
            masterVk = (ushort)Forms.Keys.PageDown;
        }

        NativeHotkeys.RegisterHotKey(hwnd, MasterHotkeyId, NativeHotkeys.ModNoRepeat, masterVk);
        NativeHotkeys.RegisterHotKey(hwnd, ImageHotkeyId, NativeHotkeys.ModNoRepeat, (uint)Forms.Keys.F2);
        Log($"热键：{_settings.MasterHotkey} / F2");
    }

    private void UnregisterHotkeys()
    {
        var hwnd = new WindowInteropHelper(this).Handle;
        NativeHotkeys.UnregisterHotKey(hwnd, MasterHotkeyId);
        NativeHotkeys.UnregisterHotKey(hwnd, ImageHotkeyId);
    }

    private IntPtr WndProc(IntPtr hwnd, int msg, IntPtr wParam, IntPtr lParam, ref bool handled)
    {
        if (msg != NativeHotkeys.WmHotkey)
        {
            return IntPtr.Zero;
        }

        var id = wParam.ToInt32();
        if (id == MasterHotkeyId)
        {
            _runtime.ToggleMaster();
            _settings.MasterEnabled = _runtime.MasterEnabled;
            _settings.Save();
            ApplyRuntimeSettings();
            SetStatus(_runtime.MasterEnabled ? "热键总开关：开" : "热键总开关：关");
            ShowStateOverlay("热键总开关", _runtime.MasterEnabled ? "已开启" : "已关闭", _runtime.MasterEnabled);
            Log(_runtime.MasterEnabled ? "热键总开关已开启。" : "热键总开关已关闭。");
            handled = true;
        }
        else if (id == ImageHotkeyId)
        {
            _settings.ImageRecognitionF2Enabled = !_settings.ImageRecognitionF2Enabled;
            _settings.Save();
            ApplyRuntimeSettings();
            SetStatus(_settings.ImageRecognitionF2Enabled ? "图像识别：开(F2)" : "图像识别：关(F2)");
            ShowStateOverlay("图像识别", _settings.ImageRecognitionF2Enabled ? "F2 开" : "F2 关", _settings.ImageRecognitionF2Enabled);
            Log(_settings.ImageRecognitionF2Enabled ? "图像识别已开启。" : "图像识别已关闭。");
            handled = true;
        }

        return IntPtr.Zero;
    }

    private void ApplyRuntimeSettings()
    {
        _runtime.ApplySettings(_settings);
        _imageMonitor.ApplySettings(_settings);
        UpdateImageDebugOverlayVisibility();
        UpdateTrajectoryPreview();
    }

    private void ImageMonitor_MatchFound(object? sender, ImageRecognitionEventArgs e)
    {
        RunOnUi(() =>
        {
            SearchResultBox.Text = $"{ColorUtilities.ToHex(e.Rgb)} @ {e.X},{e.Y}";
            SetStatus($"识别命中 @ {e.X},{e.Y}，连续 {e.HitStreak}");
            if (_settings.ImageDebug)
            {
                Log($"识别命中：{ColorUtilities.ToHex(e.Rgb)} @ {e.X},{e.Y}，连续 {e.HitStreak}");
            }
        });
    }

    private void ImageMonitor_DebugUpdated(object? sender, ImageRecognitionDebugEventArgs e)
    {
        RunOnUi(() =>
        {
            if (!IsImageRecognitionActive())
            {
                _imageDebugOverlay.Hide();
                return;
            }

            _imageDebugOverlay.UpdateState(e.State, e.Detail);
            if (!_imageDebugOverlay.IsVisible)
            {
                _imageDebugOverlay.Show();
            }
        });
    }

    private void ShowStateOverlay(string title, string detail, bool enabled) =>
        _statusOverlay.ShowStatus(title, detail, enabled, TimeSpan.FromMilliseconds(1300));

    private void UpdateImageDebugOverlayVisibility()
    {
        if (IsImageRecognitionActive())
        {
            _imageDebugOverlay.UpdateState("等待扫描", $"区域 {_settings.SearchX1},{_settings.SearchY1}-{_settings.SearchX2},{_settings.SearchY2}");
            if (!_imageDebugOverlay.IsVisible)
            {
                _imageDebugOverlay.Show();
            }
        }
        else
        {
            _imageDebugOverlay.Hide();
        }
    }

    private bool IsImageRecognitionActive() =>
        _settings.ImageRecognitionEnabled && _settings.ImageRecognitionF2Enabled && _settings.ImageDebug;

    private void StartInputHook()
    {
        try
        {
            _inputHook.Start();
            Log("输入监听已启动。");
        }
        catch (Exception ex)
        {
            Log("输入监听启动失败：" + ex.Message);
            SetStatus("输入监听失败，请用管理员身份运行。");
        }
    }

    private void InputHook_MouseButtonChanged(object? sender, GlobalMouseButtonEventArgs e)
    {
        _runtime.HandleMouseButton(e.Button, e.IsDown);
    }

    private void InputHook_MouseWheel(object? sender, GlobalMouseWheelEventArgs e)
    {
        _runtime.HandleMouseWheel(e.Delta);
    }

    private static int TriggerSideKeyToIndex(string key)
    {
        return KeyNameMapper.Normalize(key) switch
        {
            "XBUTTON1" => 1,
            "RBUTTON" => 2,
            "MBUTTON" => 3,
            _ => 0
        };
    }

    private static string SelectedComboContent(System.Windows.Controls.ComboBox comboBox, string fallback)
    {
        return (comboBox.SelectedItem as System.Windows.Controls.ComboBoxItem)?.Content?.ToString() ?? fallback;
    }

    private static string ToHotkeyName(Key key)
    {
        return key switch
        {
            >= Key.A and <= Key.Z => key.ToString(),
            >= Key.D0 and <= Key.D9 => ((int)key - (int)Key.D0).ToString(),
            >= Key.NumPad0 and <= Key.NumPad9 => $"NumPad{(int)key - (int)Key.NumPad0}",
            Key.PageDown => "PageDown",
            Key.PageUp => "PageUp",
            Key.Escape => "Escape",
            Key.Space => "Space",
            Key.Tab => "Tab",
            Key.CapsLock => "CapsLock",
            Key.Return => "Enter",
            Key.Back => "Backspace",
            Key.Delete => "Delete",
            Key.Insert => "Insert",
            Key.Home => "Home",
            Key.End => "End",
            Key.Left => "Left",
            Key.Right => "Right",
            Key.Up => "Up",
            Key.Down => "Down",
            _ => key.ToString()
        };
    }

    private static Key GetActualKey(WpfKeyEventArgs e)
    {
        return e.Key switch
        {
            Key.System => e.SystemKey,
            Key.ImeProcessed => e.ImeProcessedKey,
            Key.DeadCharProcessed => e.DeadCharProcessedKey,
            _ => e.Key
        };
    }

    private void RecoilPreview_Changed(object sender, RoutedEventArgs e) => UpdateTrajectoryPreview();

    private void TrajectoryCanvas_SizeChanged(object sender, SizeChangedEventArgs e) => UpdateTrajectoryPreview();

    private void UpdateTrajectoryPreview()
    {
        if (TrajectoryCanvas is null)
        {
            return;
        }

        if (TrajectoryVerticalGuide is null
            || TrajectoryHorizontalGuide is null
            || TrajectoryLine is null
            || TrajectoryStartDot is null
            || TrajectoryEndDot is null
            || TrajectoryInfoText is null)
        {
            return;
        }

        var width = TrajectoryCanvas.ActualWidth;
        var height = TrajectoryCanvas.ActualHeight;
        if (width <= 0 || height <= 0)
        {
            return;
        }

        var vertical = ReadPreviewInt(RecoilForceBox?.Text, _settings.RecoilForce);
        var horizontal = ReadPreviewInt(HorizontalRecoilBox?.Text, _settings.HorizontalRecoil);
        var pattern = HorizontalPatternBox?.SelectedIndex ?? _settings.HorizontalPattern;

        const int previewSteps = 12;
        var startX = width / 2;
        var startY = TrajectoryStartY;
        var rawPoints = new List<System.Windows.Point> { new(0, 0) };
        var accumulatedX = 0.0;
        var accumulatedY = 0.0;
        for (var shot = 0; shot < previewSteps; shot++)
        {
            var stepX = pattern == 1 && shot % 2 != 0 ? -horizontal : horizontal;
            accumulatedX += stepX;
            accumulatedY += vertical;
            rawPoints.Add(new System.Windows.Point(accumulatedX, accumulatedY));
        }

        var maxX = Math.Max(1, rawPoints.Max(point => Math.Abs(point.X)));
        var maxY = Math.Max(1, rawPoints.Max(point => Math.Abs(point.Y)));
        var scaleX = (width / 2 - TrajectoryMargin) / maxX;
        var scaleY = (height - TrajectoryStartY - TrajectoryMargin) / maxY;
        var scale = Math.Min(TrajectoryScaleMax, Math.Min(scaleX, scaleY));
        var points = new System.Windows.Media.PointCollection();
        foreach (var point in rawPoints)
        {
            points.Add(new System.Windows.Point(
                Math.Clamp(startX + point.X * scale, TrajectoryMargin, width - TrajectoryMargin),
                Math.Clamp(startY + point.Y * scale, startY, height - TrajectoryMargin)));
        }

        var endPoint = points[points.Count - 1];

        TrajectoryVerticalGuide.X1 = startX;
        TrajectoryVerticalGuide.Y1 = 0;
        TrajectoryVerticalGuide.X2 = startX;
        TrajectoryVerticalGuide.Y2 = height;

        TrajectoryHorizontalGuide.X1 = 0;
        TrajectoryHorizontalGuide.Y1 = startY;
        TrajectoryHorizontalGuide.X2 = width;
        TrajectoryHorizontalGuide.Y2 = startY;

        TrajectoryLine.Points = points;

        CanvasSetCenter(TrajectoryStartDot, startX, startY);
        CanvasSetCenter(TrajectoryEndDot, endPoint.X, endPoint.Y);

        var patternText = pattern == 1 ? "左右交替" : "固定方向";
        TrajectoryInfoText.Text = $"压枪路径 | 垂直: {vertical}  横向: {horizontal}  模式: {patternText}";
    }

    private static int ReadPreviewInt(string? text, int fallback) =>
        int.TryParse((text ?? string.Empty).Trim(), out var value) ? value : fallback;

    private static void CanvasSetCenter(FrameworkElement element, double x, double y)
    {
        System.Windows.Controls.Canvas.SetLeft(element, x - element.Width / 2);
        System.Windows.Controls.Canvas.SetTop(element, y - element.Height / 2);
    }

    private sealed record CaptureAnalysis(
        int CenterRgb,
        int DistinctSampledColors,
        int MatchCount,
        bool MatchCountCapped,
        CaptureHit? FirstHit);

    private sealed record CaptureHit(int X, int Y, int Rgb);
}
