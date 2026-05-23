using System.Drawing;

namespace LegendaryCSharp.Services;

public sealed class ImageRecognitionMonitor
{
    private readonly ScreenCaptureService _screenCapture;
    private readonly InputService _input;
    private readonly object _syncRoot = new();
    private CancellationTokenSource? _scanCancellation;
    private int _isSearching;
    private int _hitStreak;
    private int _lastX = int.MinValue;
    private int _lastY = int.MinValue;
    private string? _lastStateMessage;
    private DateTime _lastMissDebugUtc = DateTime.MinValue;
    private DateTime _lastMatchUpdateUtc = DateTime.MinValue;
    private DateTime _lastTriggerUtc = DateTime.MinValue;

    public ImageRecognitionMonitor(ScreenCaptureService screenCapture, InputService input)
    {
        _screenCapture = screenCapture;
        _input = input;
    }

    public event EventHandler<ImageRecognitionEventArgs>? MatchFound;
    public event EventHandler<ImageRecognitionDebugEventArgs>? DebugUpdated;
    public event EventHandler<string>? StatusChanged;

    public void ApplySettings(AppSettings settings)
    {
        RestartScanner(ImageScanPlan.From(settings));
    }

    public void Stop()
    {
        CancellationTokenSource? cancellation;
        lock (_syncRoot)
        {
            cancellation = _scanCancellation;
            _scanCancellation = null;
        }

        cancellation?.Cancel();
    }

    private void RestartScanner(ImageScanPlan plan)
    {
        Stop();
        ResetSearchState();

        if (!plan.CanScan)
        {
            PublishState(plan.StatusMessage);
            return;
        }

        var cancellation = new CancellationTokenSource();
        lock (_syncRoot)
        {
            _scanCancellation = cancellation;
        }

        var scanTask = Task.Run(() => ScanLoopAsync(plan, cancellation.Token));
        _ = scanTask.ContinueWith(
            _ => cancellation.Dispose(),
            CancellationToken.None,
            TaskContinuationOptions.ExecuteSynchronously,
            TaskScheduler.Default);
        PublishState(plan.StatusMessage);
    }

    private async Task ScanLoopAsync(ImageScanPlan plan, CancellationToken cancellationToken)
    {
        try
        {
            using var timer = new PeriodicTimer(TimeSpan.FromMilliseconds(plan.IntervalMs));
            while (await timer.WaitForNextTickAsync(cancellationToken).ConfigureAwait(false))
            {
                ScanOnce(plan);
            }
        }
        catch (OperationCanceledException)
        {
        }
    }

    private void ScanOnce(ImageScanPlan plan)
    {
        if (Interlocked.Exchange(ref _isSearching, 1) == 1)
        {
            return;
        }

        try
        {
            var result = _screenCapture.FindColor(plan.Region, plan.TargetRgb, plan.ColorTolerance);
            if (result is null)
            {
                _hitStreak = 0;
                _lastX = int.MinValue;
                _lastY = int.MinValue;
                PublishMissDebug(plan);
                return;
            }

            if (Math.Abs(result.X - _lastX) <= 1 && Math.Abs(result.Y - _lastY) <= 1)
            {
                _hitStreak++;
            }
            else
            {
                _hitStreak = 1;
            }

            _lastX = result.X;
            _lastY = result.Y;
            var now = DateTime.UtcNow;
            PublishMatch(plan, result);
            PublishDebug(plan, "命中", $"{ColorUtilities.ToHex(result.Rgb)} @ {result.X},{result.Y} | 连续 {_hitStreak}/{plan.HitStreakRequired}");

            if (_hitStreak < plan.HitStreakRequired)
            {
                return;
            }

            if (now - _lastTriggerUtc < TimeSpan.FromMilliseconds(plan.TriggerCooldownMs))
            {
                return;
            }

            _hitStreak = 0;
            _lastTriggerUtc = now;
            TriggerConfiguredKey(plan);
        }
        catch (Exception ex)
        {
            Stop();
            PublishDebug("已停止", ex.Message);
            StatusChanged?.Invoke(this, "图像识别已停止：" + ex.Message);
        }
        finally
        {
            Interlocked.Exchange(ref _isSearching, 0);
        }
    }

    private void TriggerConfiguredKey(ImageScanPlan plan)
    {
        var key = plan.TriggerKey;
        if (string.IsNullOrWhiteSpace(key))
        {
            return;
        }

        switch (plan.TriggerMode)
        {
            case ImageTriggerMode.Down:
                _input.KeyDown(key);
                PublishDebug(plan, "触发", $"按下 {key}");
                StatusChanged?.Invoke(this, $"图像识别触发：按下 {key}");
                break;
            case ImageTriggerMode.Up:
                _input.KeyUp(key);
                PublishDebug(plan, "触发", $"抬起 {key}");
                StatusChanged?.Invoke(this, $"图像识别触发：抬起 {key}");
                break;
            case ImageTriggerMode.Auto:
                if (_input.IsKeyDown(key))
                {
                    _input.KeyUp(key);
                    PublishDebug(plan, "触发", $"抬起 {key}");
                    StatusChanged?.Invoke(this, $"图像识别触发：抬起 {key}");
                }
                else
                {
                    _input.TapKey(key);
                    PublishDebug(plan, "触发", $"点击 {key}");
                    StatusChanged?.Invoke(this, $"图像识别触发：点击 {key}");
                }

                break;
            case ImageTriggerMode.Tap:
            default:
                _input.TapKey(key);
                PublishDebug(plan, "触发", $"点击 {key}");
                StatusChanged?.Invoke(this, $"图像识别触发：点击 {key}");
                break;
        }
    }

    private void ResetSearchState()
    {
        _hitStreak = 0;
        _lastX = int.MinValue;
        _lastY = int.MinValue;
        _lastMissDebugUtc = DateTime.MinValue;
        _lastMatchUpdateUtc = DateTime.MinValue;
    }

    private void PublishMatch(ImageScanPlan plan, PixelSearchResult result)
    {
        var now = DateTime.UtcNow;
        if (now - _lastMatchUpdateUtc < TimeSpan.FromMilliseconds(100))
        {
            return;
        }

        _lastMatchUpdateUtc = now;
        MatchFound?.Invoke(this, new ImageRecognitionEventArgs(result.X, result.Y, result.Rgb, _hitStreak));
    }

    private void PublishDebug(ImageScanPlan plan, string state, string detail)
    {
        if (plan.DebugEnabled)
        {
            PublishDebug(state, detail);
        }
    }

    private void PublishDebug(string state, string detail) =>
        DebugUpdated?.Invoke(this, new ImageRecognitionDebugEventArgs(state, detail));

    private void PublishMissDebug(ImageScanPlan plan)
    {
        if (!plan.DebugEnabled)
        {
            return;
        }

        var now = DateTime.UtcNow;
        if (now - _lastMissDebugUtc < TimeSpan.FromMilliseconds(200))
        {
            return;
        }

        _lastMissDebugUtc = now;
        PublishDebug("扫描中", $"未命中 | 区域 {plan.Region.Left},{plan.Region.Top}-{plan.Region.Right},{plan.Region.Bottom}");
    }

    private void PublishState(string message)
    {
        lock (_syncRoot)
        {
            if (_lastStateMessage == message)
            {
                return;
            }

            _lastStateMessage = message;
        }

        StatusChanged?.Invoke(this, message);
    }

    private sealed record ImageScanPlan(
        bool CanScan,
        string StatusMessage,
        Rectangle Region,
        int TargetRgb,
        int ColorTolerance,
        int IntervalMs,
        string TriggerKey,
        ImageTriggerMode TriggerMode,
        int HitStreakRequired,
        int TriggerCooldownMs,
        bool DebugEnabled)
    {
        public static ImageScanPlan From(AppSettings settings)
        {
            if (!settings.ImageRecognitionEnabled)
            {
                return Stopped("识别未启动：自动触发未勾选");
            }

            if (!settings.ImageRecognitionF2Enabled)
            {
                return Stopped("识别未启动：F2 关");
            }

            if (!ColorUtilities.TryParseHexColor(settings.TargetColor, out var targetRgb))
            {
                return Stopped("识别未启动：目标颜色格式无效");
            }

            var intervalMs = Math.Clamp(settings.SearchIntervalMs, 20, 2000);
            var targetHex = ColorUtilities.ToHex(targetRgb);
            var region = Rectangle.FromLTRB(settings.SearchX1, settings.SearchY1, settings.SearchX2, settings.SearchY2);
            return new ImageScanPlan(
                true,
                $"识别扫描中：区域 {settings.SearchX1},{settings.SearchY1}-{settings.SearchX2},{settings.SearchY2}，目标 {targetHex}，{intervalMs}ms",
                region,
                targetRgb,
                Math.Clamp(settings.ColorTolerance, 0, 255),
                intervalMs,
                settings.TriggerKey,
                settings.ImageTriggerMode,
                Math.Max(1, settings.ImageHitStreakRequired),
                Math.Max(0, settings.ImageTriggerCooldownMs),
                settings.ImageDebug);
        }

        private static ImageScanPlan Stopped(string statusMessage) =>
            new(
                false,
                statusMessage,
                Rectangle.Empty,
                0,
                0,
                1000,
                string.Empty,
                ImageTriggerMode.Tap,
                1,
                0,
                false);
    }
}

public sealed record ImageRecognitionEventArgs(int X, int Y, int Rgb, int HitStreak);

public sealed record ImageRecognitionDebugEventArgs(string State, string Detail);
