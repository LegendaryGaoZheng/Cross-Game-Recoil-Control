using System.Windows;
using LegendaryCSharp.Services;

namespace LegendaryCSharp;

public partial class KeyPickerWindow : Window
{
    private readonly KeySelectionMode _mode;

    public KeyPickerWindow(string title, string currentKey, KeySelectionMode mode)
    {
        InitializeComponent();
        _mode = mode;
        Title = title;
        TitleText.Text = title;
        HintText.Text = mode == KeySelectionMode.MasterHotkey
            ? Localization.T("Picker.MasterHint")
            : Localization.T("Picker.KeyMouseHint");
        CurrentKeyText.Text = $"{Localization.T("Ui.CurrentKey")}{currentKey}";
        SelectedKey = currentKey;
        BuildKeyButtons();
        Localization.ApplyTo(this);
    }

    public string SelectedKey { get; private set; }

    private void BuildKeyButtons()
    {
        AddKeys(FunctionKeyPanel, "Escape", "F1", "F2", "F3", "F4", "F5", "F6", "F7", "F8", "F9", "F10", "F11", "F12");
        AddKeys(NumberKeyPanel, "1", "2", "3", "4", "5", "6", "7", "8", "9", "0");
        AddKeys(TopLetterPanel, "Q", "W", "E", "R", "T", "Y", "U", "I", "O", "P");
        AddKeys(HomeLetterPanel, "A", "S", "D", "F", "G", "H", "J", "K", "L");
        AddKeys(BottomLetterPanel, "Z", "X", "C", "V", "B", "N", "M");
        AddKeys(ModifierKeyPanel, "Tab", "CapsLock", "Shift", "Ctrl", "Alt", "Space", "Enter", "Backspace");
        AddKeys(NavigationKeyPanel, "Insert", "Delete", "Home", "End", "PageUp", "PageDown", "Up", "Down", "Left", "Right");
        AddKeys(NumPadPanel, "NumPad7", "NumPad8", "NumPad9", "NumPad4", "NumPad5", "NumPad6", "NumPad1", "NumPad2", "NumPad3", "NumPad0");

        if (_mode == KeySelectionMode.MasterHotkey)
        {
            MouseKeyPanel.Visibility = Visibility.Collapsed;
            return;
        }

        AddKeys(MouseKeyPanel, "LButton", "RButton", "MButton", "XButton1", "XButton2");
    }

    private void AddKeys(System.Windows.Controls.Panel panel, params string[] names)
    {
        foreach (var name in names)
        {
            if (!KeySelectionCatalog.TryNormalize(name, _mode, out var normalizedName))
            {
                continue;
            }

            var label = KeySelectionCatalog.GetChoices(_mode)
                .First(choice => choice.Name == normalizedName)
                .Label;
            var button = new System.Windows.Controls.Button
            {
                Content = label,
                Tag = normalizedName,
                Style = (Style)FindResource("KeyButtonStyle")
            };
            button.Click += KeyButton_Click;
            panel.Children.Add(button);
        }
    }

    private void KeyButton_Click(object sender, RoutedEventArgs e)
    {
        if (sender is not System.Windows.Controls.Button { Tag: string key })
        {
            return;
        }

        SelectedKey = key;
        DialogResult = true;
    }

    private void CancelButton_Click(object sender, RoutedEventArgs e)
    {
        DialogResult = false;
    }
}
