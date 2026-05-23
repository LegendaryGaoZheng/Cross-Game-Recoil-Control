namespace LegendaryCSharp.Services;

public sealed class SemiAutoController
{
    private readonly InputService _input;
    private bool _leftButtonPressedBySemiAuto;

    public SemiAutoController(InputService input)
    {
        _input = input;
    }

    public async Task ApplyStepAsync(AppSettings settings)
    {
        if (!settings.SemiAutoMode)
        {
            return;
        }

        _input.MouseButtonUp(GlobalMouseButton.Left);
        await Task.Delay(2).ConfigureAwait(false);
        _input.MouseButtonDown(GlobalMouseButton.Left);
        _leftButtonPressedBySemiAuto = true;
    }

    public void ReleaseIfNeeded()
    {
        if (!_leftButtonPressedBySemiAuto)
        {
            return;
        }

        _input.MouseButtonUp(GlobalMouseButton.Left);
        _leftButtonPressedBySemiAuto = false;
    }
}
