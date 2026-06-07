using System.Windows;

namespace LegendaryCSharp;

public partial class UsageInstructionsWindow : Window
{
    public UsageInstructionsWindow()
    {
        InitializeComponent();
        Localization.ApplyTo(this);
        UsageText.Text = UsageGuide.Text;
    }

    private void CloseButton_Click(object sender, RoutedEventArgs e) => Close();
}
