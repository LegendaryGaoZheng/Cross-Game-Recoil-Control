using System.ComponentModel;
using System.Runtime.InteropServices;
using LegendaryCSharp;

namespace LegendaryCSharp.Services;

public enum GlobalMouseButton
{
    Left,
    Right,
    Middle,
    XButton1,
    XButton2
}

public sealed class GlobalInputHook : IDisposable
{
    private const int HcAction = 0;
    private const int WhKeyboardLl = 13;
    private const int WhMouseLl = 14;
    private const int MouseInjectedFlag = 0x00000001;
    private const int KeyboardInjectedFlag = 0x00000010;

    private const int WmKeyDown = 0x0100;
    private const int WmKeyUp = 0x0101;
    private const int WmSysKeyDown = 0x0104;
    private const int WmSysKeyUp = 0x0105;

    private const int WmLButtonDown = 0x0201;
    private const int WmLButtonUp = 0x0202;
    private const int WmRButtonDown = 0x0204;
    private const int WmRButtonUp = 0x0205;
    private const int WmMButtonDown = 0x0207;
    private const int WmMButtonUp = 0x0208;
    private const int WmMouseWheel = 0x020A;
    private const int WmXButtonDown = 0x020B;
    private const int WmXButtonUp = 0x020C;

    private readonly LowLevelHookProc _keyboardProc;
    private readonly LowLevelHookProc _mouseProc;
    private IntPtr _keyboardHook;
    private IntPtr _mouseHook;
    private bool _disposed;

    public GlobalInputHook()
    {
        _keyboardProc = KeyboardHookCallback;
        _mouseProc = MouseHookCallback;
    }

    public event EventHandler<GlobalKeyEventArgs>? KeyChanged;
    public event EventHandler<GlobalMouseButtonEventArgs>? MouseButtonChanged;
    public event EventHandler<GlobalMouseWheelEventArgs>? MouseWheel;

    public void Start()
    {
        ObjectDisposedException.ThrowIf(_disposed, this);

        if (_mouseHook == IntPtr.Zero)
        {
            _mouseHook = SetWindowsHookEx(WhMouseLl, _mouseProc, GetModuleHandle(null), 0);
            if (_mouseHook == IntPtr.Zero)
            {
                throw new Win32Exception(Marshal.GetLastWin32Error(), Localization.T("Input.MouseHookStartFailed"));
            }
        }

        if (KeyChanged is not null && _keyboardHook == IntPtr.Zero)
        {
            _keyboardHook = SetWindowsHookEx(WhKeyboardLl, _keyboardProc, GetModuleHandle(null), 0);
            if (_keyboardHook == IntPtr.Zero)
            {
                UnhookWindowsHookEx(_mouseHook);
                _mouseHook = IntPtr.Zero;
                throw new Win32Exception(Marshal.GetLastWin32Error(), Localization.T("Input.KeyboardHookStartFailed"));
            }
        }
    }

    public void Dispose()
    {
        if (_disposed)
        {
            return;
        }

        if (_mouseHook != IntPtr.Zero)
        {
            UnhookWindowsHookEx(_mouseHook);
            _mouseHook = IntPtr.Zero;
        }

        if (_keyboardHook != IntPtr.Zero)
        {
            UnhookWindowsHookEx(_keyboardHook);
            _keyboardHook = IntPtr.Zero;
        }

        _disposed = true;
    }

    private IntPtr MouseHookCallback(int code, IntPtr wParam, IntPtr lParam)
    {
        if (code == HcAction)
        {
            var data = Marshal.PtrToStructure<MouseHookStruct>(lParam);
            if ((data.Flags & MouseInjectedFlag) == 0)
            {
                HandleMouseMessage(wParam.ToInt32(), data);
            }
        }

        return CallNextHookEx(_mouseHook, code, wParam, lParam);
    }

    private IntPtr KeyboardHookCallback(int code, IntPtr wParam, IntPtr lParam)
    {
        if (code == HcAction)
        {
            var data = Marshal.PtrToStructure<KeyboardHookStruct>(lParam);
            if ((data.Flags & KeyboardInjectedFlag) == 0)
            {
                var message = wParam.ToInt32();
                if (message is WmKeyDown or WmSysKeyDown)
                {
                    KeyChanged?.Invoke(this, new GlobalKeyEventArgs(data.VirtualKey, true));
                }
                else if (message is WmKeyUp or WmSysKeyUp)
                {
                    KeyChanged?.Invoke(this, new GlobalKeyEventArgs(data.VirtualKey, false));
                }
            }
        }

        return CallNextHookEx(_keyboardHook, code, wParam, lParam);
    }

    private void HandleMouseMessage(int message, MouseHookStruct data)
    {
        switch (message)
        {
            case WmLButtonDown:
                RaiseMouseButton(GlobalMouseButton.Left, true);
                break;
            case WmLButtonUp:
                RaiseMouseButton(GlobalMouseButton.Left, false);
                break;
            case WmRButtonDown:
                RaiseMouseButton(GlobalMouseButton.Right, true);
                break;
            case WmRButtonUp:
                RaiseMouseButton(GlobalMouseButton.Right, false);
                break;
            case WmMButtonDown:
                RaiseMouseButton(GlobalMouseButton.Middle, true);
                break;
            case WmMButtonUp:
                RaiseMouseButton(GlobalMouseButton.Middle, false);
                break;
            case WmXButtonDown:
                RaiseMouseButton(ResolveXButton(data.MouseData), true);
                break;
            case WmXButtonUp:
                RaiseMouseButton(ResolveXButton(data.MouseData), false);
                break;
            case WmMouseWheel:
                MouseWheel?.Invoke(this, new GlobalMouseWheelEventArgs(GetHighWord(data.MouseData)));
                break;
        }
    }

    private void RaiseMouseButton(GlobalMouseButton button, bool isDown) =>
        MouseButtonChanged?.Invoke(this, new GlobalMouseButtonEventArgs(button, isDown));

    private static GlobalMouseButton ResolveXButton(uint mouseData) =>
        GetHighWord(mouseData) == 1 ? GlobalMouseButton.XButton1 : GlobalMouseButton.XButton2;

    private static short GetHighWord(uint value) => unchecked((short)((value >> 16) & 0xFFFF));

    private delegate IntPtr LowLevelHookProc(int code, IntPtr wParam, IntPtr lParam);

    [DllImport("user32.dll", SetLastError = true)]
    private static extern IntPtr SetWindowsHookEx(int hookId, LowLevelHookProc callback, IntPtr module, uint threadId);

    [DllImport("user32.dll", SetLastError = true)]
    private static extern bool UnhookWindowsHookEx(IntPtr hook);

    [DllImport("user32.dll")]
    private static extern IntPtr CallNextHookEx(IntPtr hook, int code, IntPtr wParam, IntPtr lParam);

    [DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
    private static extern IntPtr GetModuleHandle(string? moduleName);

    [StructLayout(LayoutKind.Sequential)]
    private struct Point
    {
        public int X;
        public int Y;
    }

    [StructLayout(LayoutKind.Sequential)]
    private struct MouseHookStruct
    {
        public Point Point;
        public uint MouseData;
        public int Flags;
        public int Time;
        public nuint ExtraInfo;
    }

    [StructLayout(LayoutKind.Sequential)]
    private struct KeyboardHookStruct
    {
        public uint VirtualKey;
        public uint ScanCode;
        public int Flags;
        public int Time;
        public nuint ExtraInfo;
    }
}

public sealed record GlobalKeyEventArgs(uint VirtualKey, bool IsDown);

public sealed record GlobalMouseButtonEventArgs(GlobalMouseButton Button, bool IsDown);

public sealed record GlobalMouseWheelEventArgs(short Delta);
