using System.IO;
using System.Text.Json;

namespace LegendaryCSharp;

public sealed class AppSettings
{
    private static readonly JsonSerializerOptions JsonOptions = new() { WriteIndented = true };

    public string Language { get; set; } = Localization.Chinese;
    public string MasterHotkey { get; set; } = "PageDown";
    public bool MasterEnabled { get; set; } = true;
    public string TriggerSideKey { get; set; } = "XButton2";
    public int FireRate { get; set; } = 600;
    public int RecoilForce { get; set; } = 5;
    public int HorizontalRecoil { get; set; }
    public int HorizontalPattern { get; set; }
    public bool RecoilEnabled { get; set; } = true;
    public bool BreathHoldEnabled { get; set; }
    public string BreathHoldKey { get; set; } = "L";
    public bool SemiAutoMode { get; set; }
    public bool Cut31Enabled { get; set; } = true;
    public int Cut31IntervalMs { get; set; } = 60;
    public bool ImageRecognitionEnabled { get; set; }
    public bool ImageRecognitionF2Enabled { get; set; } = true;
    public int SearchX1 { get; set; } = 0;
    public int SearchY1 { get; set; } = 0;
    public int SearchX2 { get; set; } = 200;
    public int SearchY2 { get; set; } = 200;
    public int ColorTolerance { get; set; } = 30;
    public int SearchIntervalMs { get; set; } = 50;
    public string TargetColor { get; set; } = "0x000000";
    public bool UseTargetColor { get; set; } = true;
    public int ColorPickOffsetX { get; set; } = 14;
    public int ColorPickOffsetY { get; set; } = 14;
    public string TriggerKey { get; set; } = "x";
    public int ImageHitStreakRequired { get; set; } = 3;
    public ImageTriggerMode ImageTriggerMode { get; set; }
    public int ImageTriggerCooldownMs { get; set; } = 300;
    public bool ImageDebug { get; set; }

    public static string SettingsPath => MainSettingsPath;

    public static string MainSettingsPath =>
        Path.Combine(AppContext.BaseDirectory, "LegendaryCSharp.settings.json");

    public static string ImageSettingsPath =>
        Path.Combine(AppContext.BaseDirectory, "LegendaryCSharp.image-recognition.json");

    public static string SettingsSummary =>
        Localization.T("Status.ConfigLoaded");

    public static AppSettings Load()
    {
        var settings = TryReadLegacySettings() ?? new AppSettings();

        if (TryReadJson<MainSettingsDocument>(MainSettingsPath) is { } mainSettings)
        {
            mainSettings.ApplyTo(settings);
        }

        if (TryReadJson<ImageRecognitionSettingsDocument>(ImageSettingsPath) is { } imageSettings)
        {
            imageSettings.ApplyTo(settings);
        }

        return settings;
    }

    private static AppSettings? TryReadLegacySettings()
    {
        if (!File.Exists(SettingsPath))
        {
            return null;
        }

        try
        {
            var json = File.ReadAllText(SettingsPath);
            using var document = JsonDocument.Parse(json);
            if (!document.RootElement.TryGetProperty(nameof(ImageRecognitionEnabled), out _))
            {
                return null;
            }

            return JsonSerializer.Deserialize<AppSettings>(json);
        }
        catch
        {
            return null;
        }
    }

    public void Save()
    {
        WriteJson(MainSettingsPath, MainSettingsDocument.From(this));
        WriteJson(ImageSettingsPath, ImageRecognitionSettingsDocument.From(this));
    }

    private static T? TryReadJson<T>(string path)
    {
        try
        {
            if (!File.Exists(path))
            {
                return default;
            }

            var json = File.ReadAllText(path);
            return JsonSerializer.Deserialize<T>(json);
        }
        catch
        {
            return default;
        }
    }

    private static void WriteJson<T>(string path, T value)
    {
        var json = JsonSerializer.Serialize(value, JsonOptions);
        File.WriteAllText(path, json);
    }

    public sealed class MainSettingsDocument
    {
        public string MasterHotkey { get; set; } = "PageDown";
        public string Language { get; set; } = Localization.Chinese;
        public bool MasterEnabled { get; set; } = true;
        public string TriggerSideKey { get; set; } = "XButton2";
        public int FireRate { get; set; } = 600;
        public int RecoilForce { get; set; } = 5;
        public int HorizontalRecoil { get; set; }
        public int HorizontalPattern { get; set; }
        public bool RecoilEnabled { get; set; } = true;
        public bool BreathHoldEnabled { get; set; }
        public string BreathHoldKey { get; set; } = "L";
        public bool SemiAutoMode { get; set; }
        public bool Cut31Enabled { get; set; } = true;
        public int Cut31IntervalMs { get; set; } = 60;

        public static MainSettingsDocument From(AppSettings settings) => new()
        {
            MasterHotkey = settings.MasterHotkey,
            Language = Localization.NormalizeLanguage(settings.Language),
            MasterEnabled = settings.MasterEnabled,
            TriggerSideKey = settings.TriggerSideKey,
            FireRate = settings.FireRate,
            RecoilForce = settings.RecoilForce,
            HorizontalRecoil = settings.HorizontalRecoil,
            HorizontalPattern = settings.HorizontalPattern,
            RecoilEnabled = settings.RecoilEnabled,
            BreathHoldEnabled = settings.BreathHoldEnabled,
            BreathHoldKey = settings.BreathHoldKey,
            SemiAutoMode = settings.SemiAutoMode,
            Cut31Enabled = settings.Cut31Enabled,
            Cut31IntervalMs = settings.Cut31IntervalMs
        };

        public void ApplyTo(AppSettings settings)
        {
            settings.MasterHotkey = MasterHotkey;
            settings.Language = Localization.NormalizeLanguage(Language);
            settings.MasterEnabled = MasterEnabled;
            settings.TriggerSideKey = TriggerSideKey;
            settings.FireRate = FireRate;
            settings.RecoilForce = RecoilForce;
            settings.HorizontalRecoil = HorizontalRecoil;
            settings.HorizontalPattern = HorizontalPattern;
            settings.RecoilEnabled = RecoilEnabled;
            settings.BreathHoldEnabled = BreathHoldEnabled;
            settings.BreathHoldKey = BreathHoldKey;
            settings.SemiAutoMode = SemiAutoMode;
            settings.Cut31Enabled = Cut31Enabled;
            settings.Cut31IntervalMs = Cut31IntervalMs;
        }
    }

    public sealed class ImageRecognitionSettingsDocument
    {
        public bool ImageRecognitionEnabled { get; set; }
        public bool ImageRecognitionF2Enabled { get; set; } = true;
        public int SearchX1 { get; set; } = 0;
        public int SearchY1 { get; set; } = 0;
        public int SearchX2 { get; set; } = 200;
        public int SearchY2 { get; set; } = 200;
        public int ColorTolerance { get; set; } = 30;
        public int SearchIntervalMs { get; set; } = 50;
        public string TargetColor { get; set; } = "0x000000";
        public bool UseTargetColor { get; set; } = true;
        public int ColorPickOffsetX { get; set; } = 14;
        public int ColorPickOffsetY { get; set; } = 14;
        public string TriggerKey { get; set; } = "x";
        public int ImageHitStreakRequired { get; set; } = 3;
        public ImageTriggerMode ImageTriggerMode { get; set; }
        public int ImageTriggerCooldownMs { get; set; } = 300;
        public bool ImageDebug { get; set; }

        public static ImageRecognitionSettingsDocument From(AppSettings settings) => new()
        {
            ImageRecognitionEnabled = settings.ImageRecognitionEnabled,
            ImageRecognitionF2Enabled = settings.ImageRecognitionF2Enabled,
            SearchX1 = settings.SearchX1,
            SearchY1 = settings.SearchY1,
            SearchX2 = settings.SearchX2,
            SearchY2 = settings.SearchY2,
            ColorTolerance = settings.ColorTolerance,
            SearchIntervalMs = settings.SearchIntervalMs,
            TargetColor = settings.TargetColor,
            UseTargetColor = true,
            ColorPickOffsetX = settings.ColorPickOffsetX,
            ColorPickOffsetY = settings.ColorPickOffsetY,
            TriggerKey = settings.TriggerKey,
            ImageHitStreakRequired = settings.ImageHitStreakRequired,
            ImageTriggerMode = settings.ImageTriggerMode,
            ImageTriggerCooldownMs = settings.ImageTriggerCooldownMs,
            ImageDebug = settings.ImageDebug
        };

        public void ApplyTo(AppSettings settings)
        {
            settings.ImageRecognitionEnabled = ImageRecognitionEnabled;
            settings.ImageRecognitionF2Enabled = ImageRecognitionF2Enabled;
            settings.SearchX1 = SearchX1;
            settings.SearchY1 = SearchY1;
            settings.SearchX2 = SearchX2;
            settings.SearchY2 = SearchY2;
            settings.ColorTolerance = ColorTolerance;
            settings.SearchIntervalMs = SearchIntervalMs;
            settings.TargetColor = TargetColor;
            settings.UseTargetColor = true;
            settings.ColorPickOffsetX = ColorPickOffsetX;
            settings.ColorPickOffsetY = ColorPickOffsetY;
            settings.TriggerKey = TriggerKey;
            settings.ImageHitStreakRequired = ImageHitStreakRequired;
            settings.ImageTriggerMode = ImageTriggerMode;
            settings.ImageTriggerCooldownMs = ImageTriggerCooldownMs;
            settings.ImageDebug = ImageDebug;
        }
    }
}

public enum ImageTriggerMode
{
    Tap = 0,
    Down = 1,
    Up = 2,
    Auto = 3
}
