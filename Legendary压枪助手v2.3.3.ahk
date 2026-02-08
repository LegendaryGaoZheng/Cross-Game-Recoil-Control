#Requires AutoHotkey v2.0+
#SingleInstance Force
/*
  -------------------------
    Legendary压枪助手 v2.3.3
  -------------------------
  v2.2.6~v2.2.9：见历史更新。
  v2.3.1：弹道预览修复（红线框内裁剪）。
  v2.3.2：优化更新（ToolTip、屏息键可配置、常量命名等）。
  v2.3.3：半自动/全自动射速与计时修复
    - 以「发射周期起点」计时，射速与设置一致；抬/按间隔固定 2ms；Sleep 0 轮询减少波动。
  配置与 v2.2.6 共用同一 AutoFire.ini。
  */
Persistent
global scriptVersion := "2.3.3"
SetWorkingDir A_ScriptDir
ProcessSetPriority "High"
SendMode "Input"

; 全局变量
global configFile := A_ScriptDir "\AutoFire.ini"
global isFiring := false
global assistantEnabled := false

; 配置变量
global HotkeyCC := "PgDn"
global FireRate := 600
global RecoilForce := 5
global HorizontalRecoil := 0
global HorizontalPattern := 0
global TriggerSideKey := "XButton2"
global breathHold := 0
global breathHoldKey := "L"
global semiAutoMode := 0
global ED := 1

; 弹道预览常量（与 CreateGUI / TrajectoryPaintWndProc 一致）
global TRAJ_WIDTH := 120
global TRAJ_HEIGHT := 240
global TRAJ_MARGIN := 3
global TRAJ_START_Y := 12
global TRAJ_SCALE_MAX := 95
global TRAJ_DEBOUNCE_MS := 120

; GUI引用
global MyGui
global HotkeyCtrl, FireRateCtrl, RecoilForceCtrl, HorizontalRecoilCtrl, HorizontalPatternCtrl
global BreathHoldCtrl, BreathHoldKeyCtrl, SemiAutoModeCtrl, ED_Ctrl, ConfigNameCtrl, ConfigListCtrl, StatusTextCtrl
global TriggerKeyCtrl
global TrajectoryPicCtrl, TrajectorySlopeCtrl
global TrajectoryDrawHwnd
global _TrajOldWndProc := 0   ; 子类化时由 SetWindowLongPtr 返回值写入
global _TrajWndProcCallback := 0   ; CreateGUI 中由 CallbackCreate 写入

; 动态热键注册状态
global _registeredComboHotkey := ""
global _registeredSideHotkey := ""

; -------------------------------
;          权限检查
; -------------------------------
if !A_IsAdmin {
    try {
        if A_IsCompiled
            Run '*RunAs "' A_ScriptFullPath '"'
        else
            Run '*RunAs "' A_AhkPath '" /restart "' A_ScriptFullPath '"'
        ExitApp
    } catch {
        MsgBox "需要管理员权限才能正常运行此程序。`n请右键以管理员身份运行。", "权限不足", "Iconx T5"
        ExitApp
    }
}

; -------------------------------
;          初始化
; -------------------------------
InitializeConfig()
CreateGUI()
RefreshConfigList()
UpdateStatusDisplay()

A_TrayMenu.Add "显示主界面", ShowMainWindow
A_TrayMenu.Add "退出程序", GuiClose
A_TrayMenu.Default := "显示主界面"
A_IconTip := "Legendary压枪助手v" scriptVersion

try {
    Hotkey HotkeyCC, HotkeyToggle, "On"
} catch {
    MsgBox "热键初始化失败，请检查热键 [" HotkeyCC "] 是否被占用！", "错误", "Iconx"
}
SyncComboHotkey()
SyncSideHotkey()

; -------------------------------
;          热键部分
; -------------------------------
HotkeyToggle(*) {
    global assistantEnabled, ED
    assistantEnabled := !assistantEnabled
    ED := assistantEnabled
    ED_Ctrl.Value := ED
    UpdateStatusDisplay()
    SyncComboHotkey()
    ToolTip assistantEnabled ? "辅助功能已启用" : "辅助功能已禁用"
    SetTimer () => ToolTip(), -2000
}

SyncComboHotkey() {
    global ED, assistantEnabled, TriggerSideKey, _registeredComboHotkey
    local newHotkey := "~" TriggerSideKey " & LButton"
    try {
        if (_registeredComboHotkey != "" && _registeredComboHotkey != newHotkey) {
            try Hotkey _registeredComboHotkey, "Off"
        }
        _registeredComboHotkey := newHotkey
        if ED && assistantEnabled
            Hotkey newHotkey, ComboFire, "On"
        else
            Hotkey newHotkey, ComboFire, "Off"
    } catch {
    }
}

SyncSideHotkey() {
    global TriggerSideKey, _registeredSideHotkey
    local newHotkey := "~" TriggerSideKey
    try {
        if (_registeredSideHotkey != "" && _registeredSideHotkey != newHotkey) {
            try Hotkey _registeredSideHotkey, "Off"
        }
        _registeredSideHotkey := newHotkey
        Hotkey newHotkey, SideKeyPressed, "On"
    } catch {
    }
}

SideKeyPressed(*) {
    global ED, assistantEnabled, breathHold, breathHoldKey, TriggerSideKey
    if !ED || !assistantEnabled
        return
    if breathHold {
        Send "{Blind}{" breathHoldKey " down}"
        KeyWait TriggerSideKey
        Send "{Blind}{" breathHoldKey " up}"
    } else {
        KeyWait TriggerSideKey
    }
}

CalculateHorizontalCompensation(shotCount, baseHorizontal, pattern, randHoriz) {
    local hComp
    if pattern = 0 {
        hComp := baseHorizontal + randHoriz
    } else {
        if Mod(shotCount, 2) = 0
            hComp := baseHorizontal
        else
            hComp := -baseHorizontal
        hComp += randHoriz
    }
    return hComp
}

ApplyRecoilCompensation(hComp, vComp) {
    MouseXY(Round(hComp), Round(vComp))
}

ComboFire(*) {
    global ED, assistantEnabled, isFiring, semiAutoMode, TriggerSideKey
    global FireRate, RecoilForce, HorizontalRecoil, HorizontalPattern
    if !ED || !assistantEnabled || isFiring
        return
    isFiring := true
    GetCurrentValues()
    local fireInterval := Round(60000 / FireRate)
    local baseRecoil := RecoilForce
    local lastFireTimeLocal := A_TickCount - fireInterval
    local shotCount := 0
    SendInput "{Blind}{LButton down}"
    if semiAutoMode {
        ; 半自动：以「发射周期起点」计时，抬/按间隔固定 2ms，减少速度偏差与波动
        while GetKeyState(TriggerSideKey, "P") && GetKeyState("LButton", "P") && ED && assistantEnabled && semiAutoMode {
            if A_TickCount - lastFireTimeLocal >= fireInterval {
                lastFireTimeLocal := A_TickCount
                SendInput "{Blind}{LButton up}"
                Sleep 2
                SendInput "{Blind}{LButton down}"
                local randRecoil := Random(-0.5, 0.5)
                local randHoriz := Random(-0.3, 0.3)
                local hComp := CalculateHorizontalCompensation(shotCount, HorizontalRecoil, HorizontalPattern, randHoriz)
                local vComp := baseRecoil * 0.9 + randRecoil
                ApplyRecoilCompensation(hComp, vComp)
                shotCount += 1
            }
            Sleep 0
        }
    } else {
        while GetKeyState(TriggerSideKey, "P") && GetKeyState("LButton", "P") && ED && assistantEnabled && !semiAutoMode {
            if A_TickCount - lastFireTimeLocal >= fireInterval {
                lastFireTimeLocal := A_TickCount
                local randRecoil := Random(-1, 1)
                local randHoriz := Random(-0.5, 0.5)
                local hComp := CalculateHorizontalCompensation(shotCount, HorizontalRecoil, HorizontalPattern, randHoriz)
                local vComp := baseRecoil + randRecoil
                ApplyRecoilCompensation(hComp, vComp)
                shotCount += 1
            }
            Sleep 0
        }
    }
    SendInput "{Blind}{LButton up}"
    isFiring := false
}

; -------------------------------
;          GUI与事件
; -------------------------------
CreateGUI() {
    global MyGui, HotkeyCtrl, FireRateCtrl, RecoilForceCtrl, HorizontalRecoilCtrl, HorizontalPatternCtrl
    global BreathHoldCtrl, BreathHoldKeyCtrl, SemiAutoModeCtrl, ED_Ctrl, ConfigNameCtrl, ConfigListCtrl, StatusTextCtrl
    global HotkeyCC, FireRate, RecoilForce, HorizontalRecoil, HorizontalPattern
    global breathHold, breathHoldKey, semiAutoMode, ED
    global TriggerKeyCtrl, TrajectoryPicCtrl, TrajectorySlopeCtrl, TrajectoryDrawHwnd
    global _TrajOldWndProc, _TrajWndProcCallback
    global TRAJ_WIDTH, TRAJ_HEIGHT

    MyGui := Gui("+Resize", "Legendary压枪助手 v" scriptVersion)
    MyGui.OnEvent("Close", GuiClose)
    MyGui.OnEvent("Escape", GuiEscape)
    MyGui.SetFont("s10", "Microsoft YaHei")

    MyGui.Add("Button", "x420 y5 w90 h25", "操作指南").OnEvent("Click", ShowHelpGuide)

    MyGui.Add "Text", "xm ym+5 w80", "启用/禁用热键："
    HotkeyCtrl := MyGui.Add("Hotkey", "x+5 yp-3 w200", HotkeyCC)
    HotkeyCtrl.OnEvent("Change", HotkeyChanged)

    MyGui.Add "Text", "xm y+12 w80", "触发按键："
    TriggerKeyCtrl := MyGui.Add("DropDownList", "x+5 yp-3 w200", ["侧键2(XButton2)", "侧键1(XButton1)", "右键(RButton)"])
    TriggerKeyCtrl.Choose(TriggerSideKey = "XButton1" ? 2 : (TriggerSideKey = "RButton" ? 3 : 1))
    TriggerKeyCtrl.OnEvent("Change", TriggerKeyChanged)

    MyGui.Add "Text", "xm y+12 w80", "射速 (RPM)："
    FireRateCtrl := MyGui.Add("Edit", "x+5 yp-3 w200 Number", FireRate)

    MyGui.Add "Text", "xm y+12 w80", "垂直压枪力度："
    RecoilForceCtrl := MyGui.Add("Edit", "x+5 yp-3 w200 Number", RecoilForce)
    MyGui.Add "Text", "x+10 yp+3 w80 cGray", "(0-30)"

    MyGui.Add "Text", "xm y+12 w80", "横向补偿力度："
    HorizontalRecoilCtrl := MyGui.Add("Edit", "x+5 yp-3 w200", HorizontalRecoil)
    MyGui.Add "Text", "x+10 yp+3 w80 cRed", "(-15~15，负值=向右)"

    MyGui.Add "Text", "xm y+12 w80", "横向模式："
    HorizontalPatternCtrl := MyGui.Add("DropDownList", "x+5 yp-3 w200", ["固定补偿", "左右交替"])
    HorizontalPatternCtrl.Choose(HorizontalPattern + 1)

    RecoilForceCtrl.OnEvent("Change", TrajectoryPreviewDebounce)
    RecoilForceCtrl.OnEvent("LoseFocus", UpdateTrajectoryPreview)
    HorizontalRecoilCtrl.OnEvent("Change", TrajectoryPreviewDebounce)
    HorizontalRecoilCtrl.OnEvent("LoseFocus", UpdateTrajectoryPreview)

    MyGui.Add("Text", "xm y+12 w80", "")   ; 与「横向模式」行对齐
    BreathHoldCtrl := MyGui.Add("CheckBox", "x+5 yp-3", "启用屏息")
    BreathHoldCtrl.Value := breathHold
    MyGui.Add("Text", "x+8 yp+3 w58", "屏息键：")   ; 宽度足够避免「键」换行
    BreathHoldKeyCtrl := MyGui.Add("Edit", "x+2 yp-3 w50", breathHoldKey)

    MyGui.Add("Text", "xm y+8 w80", "")
    SemiAutoModeCtrl := MyGui.Add("CheckBox", "x+5 yp-3", "半自动模式")
    SemiAutoModeCtrl.Value := semiAutoMode

    MyGui.Add("Text", "xm y+10 w80", "")
    ED_Ctrl := MyGui.Add("CheckBox", "x+5 yp-3", "启用辅助")
    ED_Ctrl.Value := ED
    ED_Ctrl.OnEvent("Click", CheckboxChanged)

    MyGui.Add("Text", "xm y+10 w80", "")
    StatusTextCtrl := MyGui.Add("Text", "x+5 yp-3", "状态：未启用")

    MyGui.Add "Text", "xm y+14 w80", "已存配置："
    ConfigListCtrl := MyGui.Add("DropDownList", "x+5 yp-3 w150")
    MyGui.Add("Button", "x+5 yp w70", "加载选中").OnEvent("Click", LoadSelectedConfig)
    MyGui.Add("Button", "x+5 yp w60", "刷新").OnEvent("Click", RefreshConfigList)

    MyGui.Add "Text", "xm y+12 w80", "配置名称："
    ConfigNameCtrl := MyGui.Add("Edit", "x+5 yp-3 w150")
    MyGui.Add("Button", "x+5 yp w60", "保存").OnEvent("Click", SaveCurrentConfig)
    MyGui.Add("Button", "x+5 yp w60", "删除").OnEvent("Click", DeleteSelectedConfig)

    MyGui.Add("Button", "xm y+16 w100", "应用设置").OnEvent("Click", ApplySettings)
    MyGui.Add("Button", "x+10 yp w100", "恢复默认").OnEvent("Click", RestoreDefaults)

    ; 弹道预览（右侧固定位置，不参与左侧流式布局，避免把底部按钮挤出视口）
    MyGui.Add("Text", "x420 y35 w120 Center", "弹道预览")
    TrajectoryPicCtrl := MyGui.Add("Text", "x420 y+2 w" TRAJ_WIDTH " h" TRAJ_HEIGHT " Border")
    TrajectoryPicCtrl.ToolTip := "红线 = 当前压枪方向，便于对比游戏内弹道"
    TrajectoryDrawHwnd := TrajectoryPicCtrl.Hwnd
    _TrajWndProcCallback := CallbackCreate(TrajectoryPaintWndProc, "Fast", 4)
    _TrajOldWndProc := DllCall("SetWindowLongPtr", "Ptr", TrajectoryDrawHwnd, "Int", -4, "Ptr", _TrajWndProcCallback, "Ptr")
    TrajectorySlopeCtrl := MyGui.Add("Text", "x420 y+2 w120 Center cGray", "垂直: 0  横向: 0")

    MyGui.Show "w540 h600"
    UpdateTrajectoryPreview()
}

ShowMainWindow(*) {
    MyGui.Show()
}

CheckboxChanged(ctrlObj, *) {
    global ED, assistantEnabled
    ED := ctrlObj.Value
    assistantEnabled := ED
    UpdateStatusDisplay()
    SyncComboHotkey()
    SyncSideHotkey()
    ToolTip ED ? "辅助功能已启用" : "辅助功能已禁用"
    SetTimer () => ToolTip(), -2000
}

HotkeyChanged(ctrlObj, *) {
    global HotkeyCC
    local newHotkey := Trim(ctrlObj.Value)
    local oldHotkey := HotkeyCC
    if (newHotkey = "" || newHotkey = HotkeyCC)
        return
    try {
        Hotkey HotkeyCC, HotkeyToggle, "Off"
        Hotkey newHotkey, HotkeyToggle, "On"
        HotkeyCC := newHotkey
    } catch as err {
        HotkeyCC := oldHotkey
        HotkeyCtrl.Value := oldHotkey
        try Hotkey oldHotkey, HotkeyToggle, "On"
        catch {
        }
        MsgBox "热键设置失败，请检查热键格式或是否被占用！`n已恢复原热键。", "错误", "Iconx"
    }
}

FormatTriggerKeyName(key) {
    if key = "XButton1"
        return "侧键1(XButton1)"
    if key = "XButton2"
        return "侧键2(XButton2)"
    if key = "RButton"
        return "右键(RButton)"
    return key
}

TriggerKeyChanged(ctrlObj, *) {
    global TriggerSideKey, TriggerKeyCtrl
    local label := ctrlObj.Text
    if InStr(label, "XButton2")
        TriggerSideKey := "XButton2"
    else if InStr(label, "XButton1")
        TriggerSideKey := "XButton1"
    else
        TriggerSideKey := "RButton"
    SyncComboHotkey()
    SyncSideHotkey()
}

; 弹道预览防抖：Change 时延迟重绘，减少输入时频繁刷新
TrajectoryPreviewDebounce(*) {
    SetTimer DoUpdateTrajectoryPreview, 0
    SetTimer DoUpdateTrajectoryPreview, -TRAJ_DEBOUNCE_MS
}

DoUpdateTrajectoryPreview() {
    UpdateTrajectoryPreview()
}

UpdateTrajectoryPreview(*) {
    global TrajectoryDrawHwnd, TrajectorySlopeCtrl
    global RecoilForceCtrl, HorizontalRecoilCtrl, RecoilForce, HorizontalRecoil
    try {
        v := RecoilForceCtrl.Value !== "" ? Integer(RecoilForceCtrl.Value) : RecoilForce
        h := HorizontalRecoilCtrl.Value !== "" ? Integer(HorizontalRecoilCtrl.Value) : HorizontalRecoil
    } catch {
        v := RecoilForce
        h := HorizontalRecoil
    }
    v := IsNumber(v) ? Integer(v) : 0
    h := IsNumber(h) ? Integer(h) : 0
    if IsSet(TrajectorySlopeCtrl) && TrajectorySlopeCtrl
        TrajectorySlopeCtrl.Text := "垂直: " v "  横向: " h
    if IsSet(TrajectoryDrawHwnd) && TrajectoryDrawHwnd
        DllCall("InvalidateRect", "Ptr", TrajectoryDrawHwnd, "Ptr", 0, "Int", 1)
}

; 弹道预览 Static 的子类 WndProc：在 WM_PAINT 里用 GDI 画白底、灰框、红线
TrajectoryPaintWndProc(hwnd, uMsg, wParam, lParam) {
    global _TrajOldWndProc, RecoilForceCtrl, HorizontalRecoilCtrl, RecoilForce, HorizontalRecoil
    global TRAJ_MARGIN, TRAJ_START_Y, TRAJ_SCALE_MAX
    if (uMsg != 0x0F)  ; 非 WM_PAINT 交给原过程
        return DllCall("CallWindowProc", "Ptr", _TrajOldWndProc, "Ptr", hwnd, "UInt", uMsg, "Ptr", wParam, "Ptr", lParam)
    v := RecoilForce
    h := HorizontalRecoil
    try {
        if IsSet(RecoilForceCtrl) && RecoilForceCtrl
            v := RecoilForceCtrl.Value
        if IsSet(HorizontalRecoilCtrl) && HorizontalRecoilCtrl
            h := HorizontalRecoilCtrl.Value
    } catch {
    }
    v := IsNumber(v) ? Integer(v) : (IsInteger(RecoilForce) ? RecoilForce : 0)
    h := IsNumber(h) ? Integer(h) : (IsInteger(HorizontalRecoil) ? HorizontalRecoil : 0)
    ps := Buffer(64, 0)
    hdc := DllCall("BeginPaint", "Ptr", hwnd, "Ptr", ps, "Ptr")
    rect := Buffer(16, 0)
    DllCall("GetClientRect", "Ptr", hwnd, "Ptr", rect)
    r := NumGet(rect, 8, "Int")
    b := NumGet(rect, 12, "Int")
    DllCall("SetDCBrushColor", "Ptr", hdc, "UInt", 0x00FFFFFF)
    DllCall("SelectObject", "Ptr", hdc, "Ptr", DllCall("GetStockObject", "Int", 18, "Ptr"))
    DllCall("Rectangle", "Ptr", hdc, "Int", 0, "Int", 0, "Int", r, "Int", b)
    penBorder := DllCall("CreatePen", "Int", 0, "Int", 1, "UInt", 0x00606060, "Ptr")
    oldPen := DllCall("SelectObject", "Ptr", hdc, "Ptr", penBorder, "Ptr")
    DllCall("SelectObject", "Ptr", hdc, "Ptr", DllCall("GetStockObject", "Int", 5, "Ptr"))
    DllCall("Rectangle", "Ptr", hdc, "Int", 0, "Int", 0, "Int", r, "Int", b)
    DllCall("SelectObject", "Ptr", hdc, "Ptr", oldPen, "Ptr")
    DllCall("DeleteObject", "Ptr", penBorder)
    x1 := r // 2
    y1 := TRAJ_START_Y
    W := r
    HBox := b
    len := Sqrt(h*h + v*v)
    scale := (len > 0) ? Min(TRAJ_SCALE_MAX, (HBox - TRAJ_START_Y * 2) / len) : 0
    x2 := Round(x1 - h * scale)
    y2 := Round(TRAJ_START_Y + v * scale)
    x2 := Max(TRAJ_MARGIN, Min(W - TRAJ_MARGIN, x2))
    y2 := Max(y1 + 2, Min(HBox - TRAJ_MARGIN, y2))
    if scale > 0 {
        penLine := DllCall("CreatePen", "Int", 0, "Int", 2, "UInt", 0x000000FF, "Ptr")
        DllCall("SelectObject", "Ptr", hdc, "Ptr", penLine, "Ptr")
        DllCall("MoveToEx", "Ptr", hdc, "Int", x1, "Int", y1, "Ptr", 0)
        DllCall("LineTo", "Ptr", hdc, "Int", x2, "Int", y2)
        DllCall("SelectObject", "Ptr", hdc, "Ptr", oldPen, "Ptr")
        DllCall("DeleteObject", "Ptr", penLine)
    }
    DllCall("EndPaint", "Ptr", hwnd, "Ptr", ps)
    return 0
}

ShowHelpGuide(*) {
    HelpGui := Gui("+Resize", "操作指南 - Legendary压枪助手")
    HelpGui.SetFont("s10", "Microsoft YaHei")
    HelpText := HelpGui.Add("Edit", "xm ym w600 h500 ReadOnly Multi VScroll", GetHelpText())
    HelpGui.Add("Button", "xm y+10 w100 Center", "关闭").OnEvent("Click", (*) => HelpGui.Destroy())
    HelpGui.Show "w620 h560"
}

GetHelpText() {
    return "
    (
═══════════════════════════════════════════════════════════
              Legendary压枪助手 - 操作指南
═══════════════════════════════════════════════════════════

【一、基本使用方法】

1. 启动脚本后，确保"启用辅助"已勾选（默认已启用）
2. 在游戏中，同时按下触发按键 + 左键（LButton）即可触发压枪功能
   - 触发按键可在主界面里选择（侧键2/侧键1/右键）
3. 按默认热键 PgDn（可在界面中自定义）可快速启用/禁用辅助功能
4. 调整参数后，点击"应用设置"使设置生效


【二、各参数说明】

【启用/禁用热键】 设置快速开启/关闭辅助的快捷键，默认 PgDn
【射速 (RPM)】 武器理论射速，范围 100-2000，默认 600
【垂直压枪力度】 每次射击后鼠标向下移动幅度，范围 0-30，1 格≈1 像素
【横向补偿力度】 每次射击后鼠标左右移动，范围 -15~15，正值向左，负值向右
【横向模式】 固定补偿 / 左右交替
【启用屏息】 侧键按住时自动按屏息键；【屏息键】可配置，默认 L
【半自动模式】 侧键+左键模拟连点
【启用辅助】 总开关


【三、配置管理】

保存/加载/删除配置见主界面；配置与 v2.2.6 共用 AutoFire.ini。


【四、弹道预览】

主界面右侧「弹道预览」框为 1:2 比例，红线方向 = 当前垂直压枪力度与横向补偿力度的合成方向。
下方显示当前垂直/横向数值，便于对比游戏内弹道并微调。

═══════════════════════════════════════════════════════════
    )"
}

; -------------------------------
;          核心功能函数
; -------------------------------
InitializeConfig() {
    global configFile
    if !FileExist(configFile)
        CreateDefaultConfig()
    try {
        LoadSettings()
    } catch as err {
        MsgBox "配置文件读取失败，将使用默认设置。`n错误信息：" err.Message, "警告", "Icon!"
        CreateDefaultConfig()
        LoadSettings()
    }
    global ED, assistantEnabled
    assistantEnabled := ED
}

GetCurrentValues() {
    global FireRate, RecoilForce, HorizontalRecoil, HorizontalPattern
    global breathHold, breathHoldKey, semiAutoMode, ED, TriggerSideKey
    global FireRateCtrl, RecoilForceCtrl, HorizontalRecoilCtrl, HorizontalPatternCtrl
    global BreathHoldCtrl, BreathHoldKeyCtrl, SemiAutoModeCtrl, ED_Ctrl, TriggerKeyCtrl
    FireRate := FireRateCtrl.Value
    RecoilForce := RecoilForceCtrl.Value
    HorizontalRecoil := HorizontalRecoilCtrl.Value
    HorizontalPattern := HorizontalPatternCtrl.Value - 1
    breathHold := BreathHoldCtrl.Value
    local key := Trim(BreathHoldKeyCtrl.Value)
    breathHoldKey := (key = "") ? "L" : key
    semiAutoMode := SemiAutoModeCtrl.Value
    ED := ED_Ctrl.Value
}

UpdateGUIDisplay() {
    global HotkeyCC, FireRate, RecoilForce, HorizontalRecoil, HorizontalPattern
    global breathHold, breathHoldKey, semiAutoMode, ED, TriggerSideKey
    global HotkeyCtrl, FireRateCtrl, RecoilForceCtrl, HorizontalRecoilCtrl, HorizontalPatternCtrl
    global BreathHoldCtrl, BreathHoldKeyCtrl, SemiAutoModeCtrl, ED_Ctrl, TriggerKeyCtrl
    HotkeyCtrl.Value := HotkeyCC
    FireRateCtrl.Value := FireRate
    RecoilForceCtrl.Value := RecoilForce
    HorizontalRecoilCtrl.Value := HorizontalRecoil
    HorizontalPatternCtrl.Choose(HorizontalPattern + 1)
    BreathHoldCtrl.Value := breathHold
    BreathHoldKeyCtrl.Value := breathHoldKey
    SemiAutoModeCtrl.Value := semiAutoMode
    ED_Ctrl.Value := ED
    if IsSet(TriggerKeyCtrl) && TriggerKeyCtrl
        TriggerKeyCtrl.Choose(TriggerSideKey = "XButton1" ? 2 : (TriggerSideKey = "RButton" ? 3 : 1))
}

UpdateStatusDisplay() {
    global ED, assistantEnabled, semiAutoMode, HorizontalPattern
    global StatusTextCtrl
    local status := (ED && assistantEnabled) ? "已启用" : "未启用"
    local mode := semiAutoMode ? "半自动" : "全自动"
    local hMode := (HorizontalPattern = 1) ? "左右交替" : "固定补偿"
    StatusTextCtrl.Text := "状态：" status " (" mode "，横向：" hMode ")"
}

Validate(name, min, max, def) {
    global
    local value := %name%
    if value = ""
        %name% := def
    else if IsNumber(value) {
        if value < min || value > max
            %name% := def
    } else
        %name% := def
}

MouseXY(x, y) {
    DllCall "mouse_event", "UInt", 0x01, "Int", x, "Int", y, "UInt", 0, "Ptr", 0
}

; -------------------------------
;          配置管理
; -------------------------------
CreateDefaultConfig() {
    global configFile
    try {
        IniWrite "PgDn", configFile, "Settings", "Hotkey"
        IniWrite "600", configFile, "Settings", "FireRate"
        IniWrite "5", configFile, "Settings", "RecoilForce"
        IniWrite "0", configFile, "Settings", "HorizontalRecoil"
        IniWrite "0", configFile, "Settings", "HorizontalPattern"
        IniWrite "XButton2", configFile, "Settings", "TriggerKey"
        IniWrite "0", configFile, "Settings", "BreathHold"
        IniWrite "L", configFile, "Settings", "BreathHoldKey"
        IniWrite "0", configFile, "Settings", "SemiAutoMode"
        IniWrite "1", configFile, "Settings", "ED"
    } catch {
        MsgBox "创建默认配置文件失败！", "错误", "Iconx"
    }
}

LoadSettings() {
    global configFile
    global HotkeyCC, FireRate, RecoilForce, HorizontalRecoil, HorizontalPattern
    global breathHold, breathHoldKey, semiAutoMode, ED, TriggerSideKey
    try {
        HotkeyCC := IniRead(configFile, "Settings", "Hotkey", "PgDn")
        FireRate := Integer(IniRead(configFile, "Settings", "FireRate", 600))
        RecoilForce := Integer(IniRead(configFile, "Settings", "RecoilForce", 5))
        HorizontalRecoil := Integer(IniRead(configFile, "Settings", "HorizontalRecoil", 0))
        HorizontalPattern := Integer(IniRead(configFile, "Settings", "HorizontalPattern", 0))
        TriggerSideKey := IniRead(configFile, "Settings", "TriggerKey", "XButton2")
        breathHold := Integer(IniRead(configFile, "Settings", "BreathHold", 0))
        breathHoldKey := IniRead(configFile, "Settings", "BreathHoldKey", "L")
        if (Trim(breathHoldKey) = "")
            breathHoldKey := "L"
        semiAutoMode := Integer(IniRead(configFile, "Settings", "SemiAutoMode", 0))
        ED := Integer(IniRead(configFile, "Settings", "ED", 1))
        Validate("FireRate", 100, 2000, 600)
        Validate("RecoilForce", 0, 30, 5)
        Validate("HorizontalRecoil", -15, 15, 0)
        Validate("HorizontalPattern", 0, 1, 0)
    } catch as err {
        throw Error("配置文件读取失败: " err.Message)
    }
}

SaveSettings() {
    global configFile
    global HotkeyCC, FireRate, RecoilForce, HorizontalRecoil, HorizontalPattern
    global breathHold, breathHoldKey, semiAutoMode, ED, TriggerSideKey
    try {
        IniWrite HotkeyCC, configFile, "Settings", "Hotkey"
        IniWrite FireRate, configFile, "Settings", "FireRate"
        IniWrite RecoilForce, configFile, "Settings", "RecoilForce"
        IniWrite HorizontalRecoil, configFile, "Settings", "HorizontalRecoil"
        IniWrite HorizontalPattern, configFile, "Settings", "HorizontalPattern"
        IniWrite TriggerSideKey, configFile, "Settings", "TriggerKey"
        IniWrite breathHold, configFile, "Settings", "BreathHold"
        IniWrite (Trim(breathHoldKey) = "" ? "L" : breathHoldKey), configFile, "Settings", "BreathHoldKey"
        IniWrite semiAutoMode, configFile, "Settings", "SemiAutoMode"
        IniWrite ED, configFile, "Settings", "ED"
    } catch {
        MsgBox "保存设置失败！", "错误", "Iconx"
    }
}

ApplySettings(*) {
    global HotkeyCC, HotkeyCtrl
    local oldHotkey := HotkeyCC
    GetCurrentValues()
    local newHotkey := HotkeyCtrl.Value
    if (newHotkey != "" && newHotkey != HotkeyCC) {
        try {
            Hotkey HotkeyCC, HotkeyToggle, "Off"
            Hotkey newHotkey, HotkeyToggle, "On"
            HotkeyCC := newHotkey
        } catch {
            HotkeyCC := oldHotkey
            HotkeyCtrl.Value := oldHotkey
            try Hotkey oldHotkey, HotkeyToggle, "On"
            catch {
            }
            MsgBox "热键设置失败，请检查热键格式或是否被占用！`n已恢复原热键。", "错误", "Iconx"
            return
        }
    }
    Validate("FireRate", 100, 2000, 600)
    Validate("RecoilForce", 0, 30, 5)
    Validate("HorizontalRecoil", -15, 15, 0)
    Validate("HorizontalPattern", 0, 1, 0)
    SaveSettings()
    UpdateGUIDisplay()
    UpdateStatusDisplay()
    UpdateTrajectoryPreview()
    SyncComboHotkey()
    SyncSideHotkey()
    MsgBox "设置已应用！", "提示", "Iconi T2"
}

RestoreDefaults(*) {
    CreateDefaultConfig()
    LoadSettings()
    global ED, assistantEnabled
    assistantEnabled := ED
    UpdateGUIDisplay()
    UpdateStatusDisplay()
    UpdateTrajectoryPreview()
    SyncComboHotkey()
    SyncSideHotkey()
    MsgBox "默认设置已恢复！", "提示", "Iconi"
}

SaveCurrentConfig(*) {
    global configFile
    global FireRate, RecoilForce, HorizontalRecoil, HorizontalPattern
    global HotkeyCC, breathHold, breathHoldKey, semiAutoMode, ED, TriggerSideKey
    global ConfigNameCtrl
    GetCurrentValues()
    local configName := Trim(ConfigNameCtrl.Value)
    if configName = "" {
        MsgBox "请输入配置名称！", "提示", "Icon!"
        return
    }
    local section := "Config_" configName
    local existingFireRate := IniRead(configFile, section, "FireRate", "")
    if existingFireRate != "" {
        if MsgBox("配置 [" configName "] 已存在，是否覆盖？", "确认覆盖", "YesNo Icon?") != "Yes"
            return
    }
    try {
        IniWrite FireRate, configFile, section, "FireRate"
        IniWrite RecoilForce, configFile, section, "RecoilForce"
        IniWrite HorizontalRecoil, configFile, section, "HorizontalRecoil"
        IniWrite HorizontalPattern, configFile, section, "HorizontalPattern"
        IniWrite HotkeyCC, configFile, section, "Hotkey"
        IniWrite TriggerSideKey, configFile, section, "TriggerKey"
        IniWrite breathHold, configFile, section, "BreathHold"
        IniWrite (Trim(breathHoldKey) = "" ? "L" : breathHoldKey), configFile, section, "BreathHoldKey"
        IniWrite semiAutoMode, configFile, section, "SemiAutoMode"
        IniWrite ED, configFile, section, "ED"
        RefreshConfigList()
        MsgBox "配置 [" configName "] 已保存！", "提示", "Iconi"
    } catch {
        MsgBox "保存配置失败！", "错误", "Iconx"
    }
}

LoadSelectedConfig(*) {
    global configFile
    global FireRate, RecoilForce, HorizontalRecoil, HorizontalPattern
    global breathHold, breathHoldKey, semiAutoMode, ED, HotkeyCC, assistantEnabled, TriggerSideKey
    global ConfigListCtrl, ConfigNameCtrl
    local oldHotkey := HotkeyCC
    local configName := ConfigListCtrl.Text
    if configName = ""
        return
    local section := "Config_" configName
    try {
        local tempFireRate := IniRead(configFile, section, "FireRate", "")
        if tempFireRate = "" {
            MsgBox "未找到配置 [" configName "]！", "错误", "Iconx"
            return
        }
        FireRate := Integer(IniRead(configFile, section, "FireRate", FireRate))
        RecoilForce := Integer(IniRead(configFile, section, "RecoilForce", RecoilForce))
        HorizontalRecoil := Integer(IniRead(configFile, section, "HorizontalRecoil", HorizontalRecoil))
        HorizontalPattern := Integer(IniRead(configFile, section, "HorizontalPattern", HorizontalPattern))
        local tempHotkey := IniRead(configFile, section, "Hotkey", HotkeyCC)
        local tempTriggerKey := IniRead(configFile, section, "TriggerKey", TriggerSideKey)
        breathHold := Integer(IniRead(configFile, section, "BreathHold", breathHold))
        breathHoldKey := IniRead(configFile, section, "BreathHoldKey", breathHoldKey)
        if (Trim(breathHoldKey) = "")
            breathHoldKey := "L"
        semiAutoMode := Integer(IniRead(configFile, section, "SemiAutoMode", semiAutoMode))
        ED := Integer(IniRead(configFile, section, "ED", ED))
        TriggerSideKey := tempTriggerKey
        if (HorizontalPattern < 0 || HorizontalPattern > 1)
            HorizontalPattern := 0
        UpdateGUIDisplay()
        UpdateTrajectoryPreview()
        assistantEnabled := ED
        ConfigNameCtrl.Value := configName
        if tempHotkey != HotkeyCC {
            try {
                Hotkey HotkeyCC, HotkeyToggle, "Off"
                Hotkey tempHotkey, HotkeyToggle, "On"
                HotkeyCC := tempHotkey
            } catch {
                HotkeyCC := oldHotkey
                try Hotkey oldHotkey, HotkeyToggle, "On"
                catch {
                }
                MsgBox "配置已加载，但热键设置失败（可能被占用）。`n已恢复原热键。", "警告", "Icon!"
            }
        }
        UpdateStatusDisplay()
        SyncComboHotkey()
        SyncSideHotkey()
        ToolTip "配置 [" configName "] 已加载！"
        SetTimer () => ToolTip(), -1500
    } catch as err {
        MsgBox "加载配置失败！`n错误信息：" err.Message, "错误", "Iconx"
    }
}

DeleteSelectedConfig(*) {
    global configFile
    global ConfigNameCtrl, ConfigListCtrl
    local configToDelete
    local configName := ConfigNameCtrl.Value
    local configList := ConfigListCtrl.Text
    if configName != ""
        configToDelete := configName
    else if configList != ""
        configToDelete := configList
    else {
        MsgBox "请选择要删除的配置！", "提示", "Icon!"
        return
    }
    if MsgBox("是否确定删除配置 [" configToDelete "]？", "确认删除", "YesNo Icon?") = "Yes" {
        try {
            IniDelete configFile, "Config_" configToDelete
            ConfigNameCtrl.Value := ""
            RefreshConfigList()
            MsgBox "配置 [" configToDelete "] 已删除！", "提示", "Iconi"
        } catch {
            MsgBox "删除配置失败！", "错误", "Iconx"
        }
    }
}

RefreshConfigList(*) {
    global configFile
    global ConfigListCtrl
    try {
        local sections := IniRead(configFile)
        local configs := []
        if sections != "" {
            for line in StrSplit(sections, "`n") {
                if InStr(line, "Config_") = 1
                    configs.Push(SubStr(line, 8))
            }
        }
        ConfigListCtrl.Delete()
        if configs.Length > 0 {
            for name in configs
                ConfigListCtrl.Add([name])
        }
    } catch {
        MsgBox "刷新配置列表失败！", "错误", "Iconx"
    }
}

GuiClose(*) {
    ExitApp
}

GuiEscape(*) {
    global MyGui
    MyGui.Hide()
}
