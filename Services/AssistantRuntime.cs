namespace LegendaryCSharp.Services;

public sealed class AssistantRuntime
{
    private readonly InputService _input;
    private readonly SemiAutoController _semiAuto;
    private readonly object _syncRoot = new();
    private AppSettings _settings = new();
    private bool _leftButtonDown;
    private bool _sideTriggerDown;
    private bool _breathKeyDown;
    private int _recoilLoopActive;
    private int _semiAutoLoopActive;
    private int _shotCount;
    private DateTime _lastCut31Utc = DateTime.MinValue;

    public AssistantRuntime(InputService input)
    {
        _input = input;
        _semiAuto = new SemiAutoController(input);
    }

    public bool MasterEnabled { get; private set; } = true;

    public event EventHandler<string>? StatusChanged;

    public void ApplySettings(AppSettings settings)
    {
        lock (_syncRoot)
        {
            _settings = settings;
            MasterEnabled = settings.MasterEnabled;
            if (!MasterEnabled)
            {
                ReleaseBreathHoldIfNeeded();
            }
        }
    }

    public void ToggleMaster()
    {
        lock (_syncRoot)
        {
            MasterEnabled = !MasterEnabled;
            _settings.MasterEnabled = MasterEnabled;
            if (!MasterEnabled)
            {
                ReleaseBreathHoldIfNeeded();
            }
        }

        StatusChanged?.Invoke(this, MasterEnabled ? "热键总开关已开启。" : "热键总开关已关闭。");
    }

    public void HandleMouseButton(GlobalMouseButton button, bool isDown)
    {
        lock (_syncRoot)
        {
            if (IsTriggerSideButton(button))
            {
                _sideTriggerDown = isDown;
                ApplyBreathHoldLocked(isDown);
            }

            if (button == GlobalMouseButton.Left)
            {
                _leftButtonDown = isDown;
                if (!isDown)
                {
                    _shotCount = 0;
                }
            }

            if (!MasterEnabled)
            {
                return;
            }
        }

        StartRecoilLoopIfNeeded();
        StartSemiAutoLoopIfNeeded();
    }

    public void HandleMouseWheel(short delta)
    {
        if (delta < 0)
        {
            ExecuteCut31();
        }
    }

    public void ExecuteCut31()
    {
        AppSettings settings;
        lock (_syncRoot)
        {
            if (!MasterEnabled || !_settings.Cut31Enabled)
            {
                return;
            }

            var now = DateTime.UtcNow;
            if (now - _lastCut31Utc < TimeSpan.FromSeconds(2))
            {
                return;
            }

            _lastCut31Utc = now;
            settings = _settings;
        }

        _ = Task.Run(async () =>
        {
            await Task.Delay(Math.Clamp(settings.Cut31IntervalMs, 10, 2000));

            _input.TapKey("3");
            await Task.Delay(10);
            _input.TapKey("1");
            StatusChanged?.Invoke(this, "31切枪完成。");
        });
    }

    public void ApplyBreathHold(bool keyDown)
    {
        lock (_syncRoot)
        {
            ApplyBreathHoldLocked(keyDown);
        }
    }

    public (double Horizontal, double Vertical) CalculateRecoilCompensation(int shotCount)
    {
        AppSettings settings;
        lock (_syncRoot)
        {
            settings = _settings;
        }

        if (!settings.RecoilEnabled)
        {
            return (0, 0);
        }

        var random = Random.Shared;
        var horizontalJitter = random.NextDouble() - 0.5;
        var verticalJitter = random.NextDouble() * 2 - 1;
        var horizontal = settings.HorizontalPattern == 1 && shotCount % 2 != 0
            ? -settings.HorizontalRecoil
            : settings.HorizontalRecoil;

        return (horizontal + horizontalJitter, settings.RecoilForce + verticalJitter);
    }

    private void StartRecoilLoopIfNeeded()
    {
        if (!ShouldRecoilRun())
        {
            return;
        }

        if (Interlocked.Exchange(ref _recoilLoopActive, 1) == 1)
        {
            return;
        }

        _ = Task.Run(RecoilLoopAsync);
    }

    private void StartSemiAutoLoopIfNeeded()
    {
        if (!ShouldSemiAutoRun())
        {
            return;
        }

        if (Interlocked.Exchange(ref _semiAutoLoopActive, 1) == 1)
        {
            return;
        }

        _ = Task.Run(SemiAutoLoopAsync);
    }

    private async Task RecoilLoopAsync()
    {
        try
        {
            StatusChanged?.Invoke(this, "压枪开始。");

            while (ShouldRecoilRun())
            {
                var settings = SnapshotSettings();
                var interval = Math.Clamp((int)Math.Round(60000.0 / Math.Max(1, settings.FireRate)), 15, 1000);
                var shot = Interlocked.Increment(ref _shotCount) - 1;

                var (horizontal, vertical) = CalculateRecoilCompensation(shot);
                _input.MoveMouseBy((int)Math.Round(horizontal), (int)Math.Round(vertical));
                await Task.Delay(interval);
            }
        }
        finally
        {
            Interlocked.Exchange(ref _recoilLoopActive, 0);
            Interlocked.Exchange(ref _shotCount, 0);
            _semiAuto.ReleaseIfNeeded();

            StatusChanged?.Invoke(this, "压枪结束。");
        }
    }

    private async Task SemiAutoLoopAsync()
    {
        try
        {
            StatusChanged?.Invoke(this, "半自动开始。");

            while (ShouldSemiAutoRun())
            {
                var settings = SnapshotSettings();
                var interval = Math.Clamp((int)Math.Round(60000.0 / Math.Max(1, settings.FireRate)), 15, 1000);

                await _semiAuto.ApplyStepAsync(settings);
                await Task.Delay(interval);
            }
        }
        finally
        {
            Interlocked.Exchange(ref _semiAutoLoopActive, 0);
            _semiAuto.ReleaseIfNeeded();

            StatusChanged?.Invoke(this, "半自动结束。");
        }
    }

    private bool ShouldRecoilRun()
    {
        lock (_syncRoot)
        {
            return MasterEnabled
                && _settings.RecoilEnabled
                && _sideTriggerDown
                && _leftButtonDown;
        }
    }

    private bool ShouldSemiAutoRun()
    {
        lock (_syncRoot)
        {
            return MasterEnabled
                && _settings.SemiAutoMode
                && _sideTriggerDown
                && _leftButtonDown;
        }
    }

    private AppSettings SnapshotSettings()
    {
        lock (_syncRoot)
        {
            return _settings;
        }
    }

    private bool IsTriggerSideButton(GlobalMouseButton button)
    {
        var trigger = KeyNameMapper.Normalize(_settings.TriggerSideKey);
        return (trigger, button) switch
        {
            ("XBUTTON1", GlobalMouseButton.XButton1) => true,
            ("XBUTTON2", GlobalMouseButton.XButton2) => true,
            ("RBUTTON", GlobalMouseButton.Right) => true,
            ("MBUTTON", GlobalMouseButton.Middle) => true,
            ("LBUTTON", GlobalMouseButton.Left) => true,
            _ => false
        };
    }

    private void ApplyBreathHoldLocked(bool keyDown)
    {
        if (!MasterEnabled || !_settings.BreathHoldEnabled)
        {
            if (!keyDown)
            {
                ReleaseBreathHoldIfNeeded();
            }

            return;
        }

        if (keyDown && !_breathKeyDown)
        {
            _input.KeyDown(_settings.BreathHoldKey);
            _breathKeyDown = true;
        }
        else if (!keyDown)
        {
            ReleaseBreathHoldIfNeeded();
        }
    }

    private void ReleaseBreathHoldIfNeeded()
    {
        if (!_breathKeyDown)
        {
            return;
        }

        _input.KeyUp(_settings.BreathHoldKey);
        _breathKeyDown = false;
    }
}
