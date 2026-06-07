using System.Windows;

namespace LegendaryCSharp;

public partial class StatusOverlayWindow : Window
{
    private readonly System.Windows.Threading.DispatcherTimer _hideTimer = new();

    public StatusOverlayWindow()
    {
        InitializeComponent();
        Localization.ApplyTo(this);
        _hideTimer.Tick += (_, _) =>
        {
            _hideTimer.Stop();
            Hide();
        };
    }

    public void ApplyLanguage() => Localization.ApplyTo(this);

    public void ShowStatus(string title, string detail, bool enabled, TimeSpan duration)
    {
        TitleText.Text = title;
        DetailText.Text = detail;
        StateDot.Fill = enabled
            ? new System.Windows.Media.SolidColorBrush(System.Windows.Media.Color.FromRgb(67, 160, 71))
            : new System.Windows.Media.SolidColorBrush(System.Windows.Media.Color.FromRgb(211, 47, 47));

        Left = SystemParameters.WorkArea.Right - Width - 28;
        Top = SystemParameters.WorkArea.Top + 28;
        Show();

        _hideTimer.Stop();
        _hideTimer.Interval = duration;
        _hideTimer.Start();
    }
}
