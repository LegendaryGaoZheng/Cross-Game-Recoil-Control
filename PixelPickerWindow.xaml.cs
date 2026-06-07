using System.Drawing;
using System.Drawing.Imaging;
using System.IO;
using System.Windows;
using System.Windows.Media.Imaging;
using DrawingBitmap = System.Drawing.Bitmap;
using DrawingGraphics = System.Drawing.Graphics;
using DrawingRectangle = System.Drawing.Rectangle;
using Forms = System.Windows.Forms;
using WpfKey = System.Windows.Input.Key;
using WpfKeyEventArgs = System.Windows.Input.KeyEventArgs;
using WpfMouseButtonEventArgs = System.Windows.Input.MouseButtonEventArgs;
using WpfMouseEventArgs = System.Windows.Input.MouseEventArgs;
using WpfPoint = System.Windows.Point;

namespace LegendaryCSharp;

public partial class PixelPickerWindow : Window
{
    private const int LoupeSourceSize = 21;
    private const int LoupePixelScale = 8;
    private readonly DrawingBitmap _screenBitmap;
    private readonly int _screenLeft;
    private readonly int _screenTop;

    public PixelPickerWindow()
    {
        InitializeComponent();
        Localization.ApplyTo(this);

        var physicalBounds = GetVirtualScreenBounds();
        _screenLeft = physicalBounds.Left;
        _screenTop = physicalBounds.Top;
        var screenWidth = physicalBounds.Width;
        var screenHeight = physicalBounds.Height;

        Left = SystemParameters.VirtualScreenLeft;
        Top = SystemParameters.VirtualScreenTop;
        Width = SystemParameters.VirtualScreenWidth;
        Height = SystemParameters.VirtualScreenHeight;

        _screenBitmap = CaptureScreen(_screenLeft, _screenTop, screenWidth, screenHeight);
        ScreenImage.Width = Width;
        ScreenImage.Height = Height;
        ScreenImage.Source = ToBitmapImage(_screenBitmap);

        Loaded += (_, _) =>
        {
            Focus();
            UpdateLoupe(GetMousePosition());
        };
    }

    public PixelPickResult? SelectedPixel { get; private set; }

    protected override void OnClosed(EventArgs e)
    {
        _screenBitmap.Dispose();
        base.OnClosed(e);
    }

    private void Window_MouseMove(object sender, WpfMouseEventArgs e)
    {
        UpdateLoupe(e.GetPosition(this));
    }

    private void Window_MouseLeftButtonDown(object sender, WpfMouseButtonEventArgs e)
    {
        var point = e.GetPosition(this);
        var (x, y) = GetBitmapPosition(point);
        var color = _screenBitmap.GetPixel(x, y);
        var rgb = (color.R << 16) | (color.G << 8) | color.B;

        SelectedPixel = new PixelPickResult(_screenLeft + x, _screenTop + y, rgb);
        DialogResult = true;
    }

    private void Window_KeyDown(object sender, WpfKeyEventArgs e)
    {
        if (e.Key == WpfKey.Escape)
        {
            DialogResult = false;
        }
    }

    private void UpdateLoupe(WpfPoint point)
    {
        var (centerX, centerY) = GetBitmapPosition(point);
        var sourceLeft = Math.Clamp(centerX - LoupeSourceSize / 2, 0, Math.Max(0, _screenBitmap.Width - LoupeSourceSize));
        var sourceTop = Math.Clamp(centerY - LoupeSourceSize / 2, 0, Math.Max(0, _screenBitmap.Height - LoupeSourceSize));
        using var cropped = _screenBitmap.Clone(
            DrawingRectangle.FromLTRB(sourceLeft, sourceTop, sourceLeft + LoupeSourceSize, sourceTop + LoupeSourceSize),
            PixelFormat.Format32bppArgb);

        LoupeImage.Source = ToBitmapImage(cropped);
        System.Windows.Controls.Canvas.SetLeft(TargetPixelRectangle, (centerX - sourceLeft) * LoupePixelScale);
        System.Windows.Controls.Canvas.SetTop(TargetPixelRectangle, (centerY - sourceTop) * LoupePixelScale);

        var color = _screenBitmap.GetPixel(centerX, centerY);
        var rgb = (color.R << 16) | (color.G << 8) | color.B;
        PixelInfoText.Text = $"{ColorUtilities.ToHex(rgb)}  @  {_screenLeft + centerX},{_screenTop + centerY}";

        var loupeLeft = point.X + 24;
        var loupeTop = point.Y + 24;
        if (loupeLeft + LoupeBorder.Width > ActualWidth)
        {
            loupeLeft = point.X - LoupeBorder.Width - 24;
        }

        if (loupeTop + LoupeBorder.Height > ActualHeight)
        {
            loupeTop = point.Y - LoupeBorder.Height - 24;
        }

        System.Windows.Controls.Canvas.SetLeft(LoupeBorder, Math.Max(8, loupeLeft));
        System.Windows.Controls.Canvas.SetTop(LoupeBorder, Math.Max(8, loupeTop));
    }

    private WpfPoint GetMousePosition()
    {
        var point = Forms.Cursor.Position;
        return PointFromScreen(new WpfPoint(point.X, point.Y));
    }

    private (int X, int Y) GetBitmapPosition(WpfPoint windowPoint)
    {
        var screenPoint = PointToScreen(windowPoint);
        var x = Math.Clamp((int)Math.Floor(screenPoint.X) - _screenLeft, 0, _screenBitmap.Width - 1);
        var y = Math.Clamp((int)Math.Floor(screenPoint.Y) - _screenTop, 0, _screenBitmap.Height - 1);
        return (x, y);
    }

    private static DrawingRectangle GetVirtualScreenBounds()
    {
        var screens = Forms.Screen.AllScreens;
        if (screens.Length == 0)
        {
            return new DrawingRectangle(0, 0, 1, 1);
        }

        var bounds = screens[0].Bounds;
        for (var i = 1; i < screens.Length; i++)
        {
            bounds = DrawingRectangle.Union(bounds, screens[i].Bounds);
        }

        return bounds;
    }

    private static DrawingBitmap CaptureScreen(int left, int top, int width, int height)
    {
        var bitmap = new DrawingBitmap(width, height, PixelFormat.Format32bppArgb);
        using var graphics = DrawingGraphics.FromImage(bitmap);
        graphics.CopyFromScreen(left, top, 0, 0, new System.Drawing.Size(width, height), CopyPixelOperation.SourceCopy);
        return bitmap;
    }

    private static BitmapImage ToBitmapImage(DrawingBitmap bitmap)
    {
        using var stream = new MemoryStream();
        bitmap.Save(stream, ImageFormat.Png);
        stream.Position = 0;

        var image = new BitmapImage();
        image.BeginInit();
        image.CacheOption = BitmapCacheOption.OnLoad;
        image.StreamSource = stream;
        image.EndInit();
        image.Freeze();
        return image;
    }
}

public sealed record PixelPickResult(int X, int Y, int Rgb);
