using System.Windows;

namespace LegendaryCSharp;

public partial class ImageDebugOverlayWindow : Window
{
    public ImageDebugOverlayWindow()
    {
        InitializeComponent();
        Localization.ApplyTo(this);
        Left = SystemParameters.WorkArea.Left + 28;
        Top = SystemParameters.WorkArea.Top + 28;
    }

    public void ApplyLanguage() => Localization.ApplyTo(this);

    public void UpdateState(string state, string detail)
    {
        StateText.Text = state;
        DetailText.Text = detail;
        TimeText.Text = DateTime.Now.ToString("HH:mm:ss");
    }
}
