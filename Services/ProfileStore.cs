using System.IO;
using System.Text.Json;

namespace LegendaryCSharp.Services;

public sealed class ProfileStore
{
    private static readonly JsonSerializerOptions JsonOptions = new() { WriteIndented = true };
    private bool _legacyProfilesMigrated;

    public string ProfileDirectory { get; } =
        Path.Combine(GetUserDataDirectory(), "Profiles");

    private static string LegacyProfileDirectory =>
        Path.Combine(AppContext.BaseDirectory, "Profiles");

    private string GeneralProfileDirectory =>
        Path.Combine(ProfileDirectory, "General");

    private string ImageRecognitionProfileDirectory =>
        Path.Combine(ProfileDirectory, "ImageRecognition");

    public IReadOnlyList<string> ListGeneralProfiles() =>
        ListProfiles(GeneralProfileDirectory);

    public IReadOnlyList<string> ListImageRecognitionProfiles() =>
        ListProfiles(ImageRecognitionProfileDirectory);

    public void SaveGeneralProfile(string name, AppSettings settings) =>
        WriteProfile(GeneralProfileDirectory, name, AppSettings.MainSettingsDocument.From(settings));

    public void SaveImageRecognitionProfile(string name, AppSettings settings) =>
        WriteProfile(ImageRecognitionProfileDirectory, name, AppSettings.ImageRecognitionSettingsDocument.From(settings));

    public bool LoadGeneralProfile(string name, AppSettings settings)
    {
        MigrateLegacyProfiles();
        var path = GetProfilePath(GeneralProfileDirectory, name);
        if (File.Exists(path))
        {
            var json = File.ReadAllText(path);
            var document = JsonSerializer.Deserialize<AppSettings.MainSettingsDocument>(json);
            if (document is null)
            {
                return false;
            }

            document.ApplyTo(settings, applyLanguage: false);
            return true;
        }

        if (LoadLegacyProfile(name) is not { } legacy)
        {
            return false;
        }

        AppSettings.MainSettingsDocument.From(legacy).ApplyTo(settings, applyLanguage: false);
        return true;
    }

    public bool LoadImageRecognitionProfile(string name, AppSettings settings)
    {
        MigrateLegacyProfiles();
        var path = GetProfilePath(ImageRecognitionProfileDirectory, name);
        if (File.Exists(path))
        {
            var json = File.ReadAllText(path);
            var document = JsonSerializer.Deserialize<AppSettings.ImageRecognitionSettingsDocument>(json);
            if (document is null)
            {
                return false;
            }

            document.ApplyTo(settings);
            return true;
        }

        if (LoadLegacyProfile(name) is not { } legacy)
        {
            return false;
        }

        AppSettings.ImageRecognitionSettingsDocument.From(legacy).ApplyTo(settings);
        return true;
    }

    public void DeleteGeneralProfile(string name) =>
        DeleteProfile(GeneralProfileDirectory, name);

    public void DeleteImageRecognitionProfile(string name) =>
        DeleteProfile(ImageRecognitionProfileDirectory, name);

    private IReadOnlyList<string> ListProfiles(string directory)
    {
        MigrateLegacyProfiles();
        Directory.CreateDirectory(directory);
        return Directory
            .EnumerateFiles(directory, "*.json")
            .Select(Path.GetFileNameWithoutExtension)
            .Where(name => !string.IsNullOrWhiteSpace(name))
            .OrderBy(name => name, StringComparer.OrdinalIgnoreCase)
            .ToArray()!;
    }

    private void WriteProfile<T>(string directory, string name, T document)
    {
        Directory.CreateDirectory(directory);
        var path = GetProfilePath(directory, name);
        var json = JsonSerializer.Serialize(document, JsonOptions);
        File.WriteAllText(path, json);
    }

    private void DeleteProfile(string directory, string name)
    {
        var path = GetProfilePath(directory, name);
        if (File.Exists(path))
        {
            File.Delete(path);
        }
    }

    private void MigrateLegacyProfiles()
    {
        if (_legacyProfilesMigrated)
        {
            return;
        }

        _legacyProfilesMigrated = true;

        MigrateProfileDirectory(ProfileDirectory);

        if (!PathsEqual(ProfileDirectory, LegacyProfileDirectory))
        {
            MigrateProfileDirectory(LegacyProfileDirectory);
        }
    }

    private void MigrateProfileDirectory(string sourceDirectory)
    {
        if (!Directory.Exists(sourceDirectory))
        {
            return;
        }

        Directory.CreateDirectory(GeneralProfileDirectory);
        Directory.CreateDirectory(ImageRecognitionProfileDirectory);

        CopyProfileFiles(Path.Combine(sourceDirectory, "General"), GeneralProfileDirectory);
        CopyProfileFiles(Path.Combine(sourceDirectory, "ImageRecognition"), ImageRecognitionProfileDirectory);

        foreach (var file in Directory.EnumerateFiles(sourceDirectory, "*.json"))
        {
            try
            {
                var json = File.ReadAllText(file);
                var settings = JsonSerializer.Deserialize<AppSettings>(json);
                var name = Path.GetFileNameWithoutExtension(file);
                if (settings is null || string.IsNullOrWhiteSpace(name))
                {
                    continue;
                }

                var generalPath = GetProfilePath(GeneralProfileDirectory, name);
                if (!File.Exists(generalPath))
                {
                    var generalJson = JsonSerializer.Serialize(AppSettings.MainSettingsDocument.From(settings), JsonOptions);
                    File.WriteAllText(generalPath, generalJson);
                }

                var imagePath = GetProfilePath(ImageRecognitionProfileDirectory, name);
                if (!File.Exists(imagePath))
                {
                    var imageJson = JsonSerializer.Serialize(AppSettings.ImageRecognitionSettingsDocument.From(settings), JsonOptions);
                    File.WriteAllText(imagePath, imageJson);
                }
            }
            catch
            {
            }
        }
    }

    private static void CopyProfileFiles(string sourceDirectory, string targetDirectory)
    {
        if (!Directory.Exists(sourceDirectory))
        {
            return;
        }

        Directory.CreateDirectory(targetDirectory);
        foreach (var file in Directory.EnumerateFiles(sourceDirectory, "*.json"))
        {
            var targetPath = Path.Combine(targetDirectory, Path.GetFileName(file));
            if (File.Exists(targetPath))
            {
                continue;
            }

            File.Copy(file, targetPath);
        }
    }

    private AppSettings? LoadLegacyProfile(string name)
    {
        var path = GetProfilePath(ProfileDirectory, name);
        if (!File.Exists(path))
        {
            path = GetProfilePath(LegacyProfileDirectory, name);
        }

        if (!File.Exists(path))
        {
            return null;
        }

        var json = File.ReadAllText(path);
        return JsonSerializer.Deserialize<AppSettings>(json);
    }

    private string GetProfilePath(string directory, string name)
    {
        var safeName = SanitizeName(name);
        if (string.IsNullOrWhiteSpace(safeName))
        {
            safeName = "profile";
        }

        return Path.Combine(directory, safeName + ".json");
    }

    private static string SanitizeName(string name)
    {
        var invalid = Path.GetInvalidFileNameChars().ToHashSet();
        return new string(name.Trim().Select(ch => invalid.Contains(ch) ? '_' : ch).ToArray());
    }

    private static string GetUserDataDirectory()
    {
        var appData = Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData);
        return string.IsNullOrWhiteSpace(appData)
            ? AppContext.BaseDirectory
            : Path.Combine(appData, "Legendary");
    }

    private static bool PathsEqual(string first, string second)
    {
        var normalizedFirst = Path.GetFullPath(first).TrimEnd(Path.DirectorySeparatorChar, Path.AltDirectorySeparatorChar);
        var normalizedSecond = Path.GetFullPath(second).TrimEnd(Path.DirectorySeparatorChar, Path.AltDirectorySeparatorChar);
        return string.Equals(normalizedFirst, normalizedSecond, StringComparison.OrdinalIgnoreCase);
    }
}
