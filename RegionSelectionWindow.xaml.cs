using System.Windows;
using System.Windows.Controls;
using DrawingRectangle = System.Drawing.Rectangle;
using WpfKey = System.Windows.Input.Key;
using WpfKeyEventArgs = System.Windows.Input.KeyEventArgs;
using WpfMouseButtonEventArgs = System.Windows.Input.MouseButtonEventArgs;
using WpfMouseEventArgs = System.Windows.Input.MouseEventArgs;
using WpfPoint = System.Windows.Point;

namespace LegendaryCSharp;

public partial class RegionSelectionWindow : Window
{
    private WpfPoint _start;
    private bool _dragging;

    public RegionSelectionWindow()
    {
        InitializeComponent();
        Localization.ApplyTo(this);
        Left = SystemParameters.VirtualScreenLeft;
        Top = SystemParameters.VirtualScreenTop;
        Width = SystemParameters.VirtualScreenWidth;
        Height = SystemParameters.VirtualScreenHeight;
    }

    public DrawingRectangle? SelectedRegion { get; private set; }

    private void Window_MouseLeftButtonDown(object sender, WpfMouseButtonEventArgs e)
    {
        _start = e.GetPosition(this);
        _dragging = true;
        SelectionRectangle.Visibility = Visibility.Visible;
        UpdateRectangle(_start, _start);
        CaptureMouse();
    }

    private void Window_MouseMove(object sender, WpfMouseEventArgs e)
    {
        if (!_dragging)
        {
            return;
        }

        UpdateRectangle(_start, e.GetPosition(this));
    }

    private void Window_MouseLeftButtonUp(object sender, WpfMouseButtonEventArgs e)
    {
        if (!_dragging)
        {
            return;
        }

        _dragging = false;
        ReleaseMouseCapture();

        var end = e.GetPosition(this);
        var startScreen = PointToScreen(_start);
        var endScreen = PointToScreen(end);
        var left = (int)Math.Round(Math.Min(startScreen.X, endScreen.X));
        var top = (int)Math.Round(Math.Min(startScreen.Y, endScreen.Y));
        var right = (int)Math.Round(Math.Max(startScreen.X, endScreen.X));
        var bottom = (int)Math.Round(Math.Max(startScreen.Y, endScreen.Y));

        if (Math.Abs(right - left) < 3 || Math.Abs(bottom - top) < 3)
        {
            DialogResult = false;
            return;
        }

        SelectedRegion = DrawingRectangle.FromLTRB(left, top, right, bottom);
        DialogResult = true;
    }

    private void Window_KeyDown(object sender, WpfKeyEventArgs e)
    {
        if (e.Key == WpfKey.Escape)
        {
            DialogResult = false;
        }
    }

    private void UpdateRectangle(WpfPoint start, WpfPoint end)
    {
        var left = Math.Min(start.X, end.X);
        var top = Math.Min(start.Y, end.Y);
        var width = Math.Abs(end.X - start.X);
        var height = Math.Abs(end.Y - start.Y);

        Canvas.SetLeft(SelectionRectangle, left);
        Canvas.SetTop(SelectionRectangle, top);
        SelectionRectangle.Width = width;
        SelectionRectangle.Height = height;
    }
}
