#Requires AutoHotkey v2.0+

#SingleInstance Force

/*

  -------------------------

    Legendary压枪助手 Legendary v2.4.9

  -------------------------

  v2.4.4：移除无效图像模板项，优化图像识别配置排版与应用后自动收起。

  配置与 v2.2.6 共用 AutoFire.ini。

  */

Persistent



EnsureAdmin()



class LegendaryApp {

    scriptVersion := "v2.4.9"



    _cleaned := false



    _lastCut31Tick := 0



    ; 图像识别相关变量

    ImageRecEnabled := 0

    SearchX1 := 0

    SearchY1 := 0               

    SearchX2 := 200

    SearchY2 := 200

    ImageTolerance := 30

    ImageSearchInterval := 50

    TriggerKey := "x"

    ImageUseTrans := 0

    ImageTransColor := ""

    ImageDebug := 0

    ImageRecF2Enabled := 1

    ImageHitStreakRequired := 3

    ImageTriggerMode := 0  ; 0=tap, 1=down, 2=up, 3=auto

    _imgHitStreak := 0

    _lastImageSearchTick := 0

    _isSearching := false

    _lastImageDebugTipTick := 0



    _pickingColor := false



    ; 全局变量

    configFile := A_ScriptDir "\AutoFire.ini"

    isFiring := false

    assistantEnabled := true



    ; 配置变量

    HotkeyCC := "PgDn"

    FireRate := 600

    RecoilForce := 5

    HorizontalRecoil := 0

    HorizontalPattern := 0

    TriggerSideKey := "XButton2"

    breathHold := 0

    breathHoldKey := "L"

    semiAutoMode := 0

    ED := 1

    Cut31Enabled := 1

    Cut31Interval := 60



    ; 弹道预览常量

    TRAJ_WIDTH := 120

    TRAJ_HEIGHT := 240

    TRAJ_MARGIN := 3

    TRAJ_START_Y := 12

    TRAJ_SCALE_MAX := 95

    TRAJ_DEBOUNCE_MS := 120



    ; GUI引用

    MyGui := unset

    HotkeyCtrl := unset

    StatusTextCtrl := unset



    ED_Ctrl := unset

    BreathHoldCtrl := unset

    SemiAutoModeCtrl := unset

    Cut31Ctrl := unset

    ImageRecCtrl := unset



    RecoilConfigGui := unset

    BreathConfigGui := unset

    SemiAutoConfigGui := unset

    Cut31ConfigGui := unset

    ImageRecConfigGui := unset

    ConfigManagerGui := unset



    ; 以下控件仅在对应配置界面存在

    FireRateCtrl := unset

    RecoilForceCtrl := unset

    HorizontalRecoilCtrl := unset

    HorizontalPatternCtrl := unset

    BreathHoldKeyCtrl := unset

    SideTriggerCtrl := unset

    Cut31IntervalCtrl := unset

    SearchX1Ctrl := unset

    SearchY1Ctrl := unset

    SearchX2Ctrl := unset

    SearchY2Ctrl := unset

    ImageToleranceCtrl := unset

    ImageSearchIntervalCtrl := unset

    ImageSendKeyCtrl := unset

    ImageHitStreakCtrl := unset

    ImageTriggerModeCtrl := unset

    ImageUseTransCtrl := unset

    ImageTransColorCtrl := unset

    ConfigNameCtrl := unset

    ConfigListCtrl := unset

    HotkeyConfigListCtrl := unset

    HotkeyConfigNameCtrl := unset

    ImageConfigListCtrl := unset

    ImageConfigNameCtrl := unset



    TrajectoryPicCtrl := unset

    TrajectorySlopeCtrl := unset

    TrajectoryTitleCtrl := unset



    ; 图像识别GUI引用



    TrajectoryDrawHwnd := 0

    _TrajOldWndProc := 0

    _TrajWndProcCallback := 0



    _registeredComboHotkey := ""

    _registeredSideHotkey := ""



    ; 绑定回调，避免 GC

    _cbHotkeyToggle := unset

    _cbComboFire := unset

    _cbSideKeyPressed := unset

    _cbDo31Cut := unset



    _cbGuiClose := unset

    _cbGuiEscape := unset

    _cbGuiSize := unset



    _cbHotkeyChanged := unset

    _cbTriggerKeyChanged := unset

    _cbCheckboxChanged := unset

    _cbCut31Changed := unset

    _cbImageRecChanged := unset



    _cbApplySettings := unset

    _cbRestoreDefaults := unset

    _cbLoadSelectedConfig := unset

    _cbRefreshConfigList := unset

    _cbSaveCurrentConfig := unset

    _cbDeleteSelectedConfig := unset



    _cbTrajectoryPreviewDebounce := unset

    _cbUpdateTrajectoryPreview := unset

    _cbImageSearchTimer := unset

    _cbPickSearchRegion := unset

    _cbOpenRecoilConfig := unset

    _cbOpenBreathConfig := unset

    _cbOpenSemiAutoConfig := unset

    _cbOpenCut31Config := unset

    _cbOpenImageRecConfig := unset

    _cbOpenConfigManager := unset



    _cbToggleImageRecF2 := unset

    _cbStartColorPicker := unset

    _cbColorPickRButton := unset

    _cbColorPickEsc := unset



    __New() {

        SetWorkingDir A_ScriptDir

        ProcessSetPriority "High"

        SendMode "Input"

        ; 图像识别使用整屏坐标，避免与窗口/客户区坐标混用

        CoordMode "Pixel", "Screen"



        this._BindCallbacks()



        this.InitializeConfig()

        this.CreateGUI()

        this.UpdateStatusDisplay()



        A_TrayMenu.Add "显示主界面", ObjBindMethod(this, "ShowMainWindow")

        A_TrayMenu.Add "退出程序", this._cbGuiClose

        A_TrayMenu.Default := "显示主界面"

        A_IconTip := "Legendary压枪助手 " this.scriptVersion



        try {

            Hotkey this.HotkeyCC, this._cbHotkeyToggle, "On"

        } catch {

            MsgBox "热键初始化失败，请检查热键 [" this.HotkeyCC "] 是否被占用！", "错误", "Iconx"

        }



        try Hotkey "F2", this._cbToggleImageRecF2, "On"

        catch {

        }



        this.SyncComboHotkey()

        this.SyncSideHotkey()

        this.SyncCut31Hotkey()

        this.SyncImageRecHotkey()



        OnExit(ObjBindMethod(this, "Cleanup"))

    }



    _BindCallbacks() {

        this._cbHotkeyToggle := ObjBindMethod(this, "HotkeyToggle")

        this._cbComboFire := ObjBindMethod(this, "ComboFire")

        this._cbSideKeyPressed := ObjBindMethod(this, "SideKeyPressed")

        this._cbDo31Cut := ObjBindMethod(this, "Do31Cut")



        this._cbGuiClose := ObjBindMethod(this, "GuiClose")

        this._cbGuiEscape := ObjBindMethod(this, "GuiEscape")

        this._cbGuiSize := ObjBindMethod(this, "GuiSize")



        this._cbHotkeyChanged := ObjBindMethod(this, "HotkeyChanged")

        this._cbTriggerKeyChanged := ObjBindMethod(this, "TriggerKeyChanged")

        this._cbCheckboxChanged := ObjBindMethod(this, "CheckboxChanged")

        this._cbCut31Changed := ObjBindMethod(this, "Cut31Changed")

        this._cbImageRecChanged := ObjBindMethod(this, "ImageRecChanged")



        this._cbApplySettings := ObjBindMethod(this, "ApplySettings")

        this._cbRestoreDefaults := ObjBindMethod(this, "RestoreDefaults")

        this._cbLoadSelectedConfig := ObjBindMethod(this, "LoadSelectedConfig")

        this._cbRefreshConfigList := ObjBindMethod(this, "RefreshConfigList")

        this._cbSaveCurrentConfig := ObjBindMethod(this, "SaveCurrentConfig")

        this._cbDeleteSelectedConfig := ObjBindMethod(this, "DeleteSelectedConfig")



        this._cbTrajectoryPreviewDebounce := ObjBindMethod(this, "TrajectoryPreviewDebounce")

        this._cbUpdateTrajectoryPreview := ObjBindMethod(this, "UpdateTrajectoryPreview")

        this._cbImageSearchTimer := ObjBindMethod(this, "ImageSearchTimer")

        this._cbPickSearchRegion := ObjBindMethod(this, "PickSearchRegion")

        this._cbOpenRecoilConfig := ObjBindMethod(this, "OpenRecoilConfig")

        this._cbOpenBreathConfig := ObjBindMethod(this, "OpenBreathConfig")

        this._cbOpenSemiAutoConfig := ObjBindMethod(this, "OpenSemiAutoConfig")

        this._cbOpenCut31Config := ObjBindMethod(this, "OpenCut31Config")

        this._cbOpenImageRecConfig := ObjBindMethod(this, "OpenImageRecConfig")

        this._cbOpenConfigManager := ObjBindMethod(this, "OpenConfigManager")



        this._cbToggleImageRecF2 := ObjBindMethod(this, "ToggleImageRecF2")

        this._cbStartColorPicker := ObjBindMethod(this, "StartColorPicker")

        this._cbColorPickRButton := ObjBindMethod(this, "ColorPickRButton")

        this._cbColorPickEsc := ObjBindMethod(this, "ColorPickEsc")

    }



    Run() {

        ; no-op: everything started in __New

    }



    ; -------------------------------

    ;          热键部分

    ; -------------------------------

    HotkeyToggle(*) {

        this.assistantEnabled := !this.assistantEnabled

        this.UpdateStatusDisplay()

        this.SyncComboHotkey()

        this.SyncSideHotkey()

        this.SyncCut31Hotkey()

        this.SyncImageRecHotkey()

        ToolTip this.assistantEnabled ? "总开关已启用" : "总开关已禁用（已勾选功能暂停）"

        SetTimer () => ToolTip(), -2000

    }



    SyncComboHotkey() {

        local newHotkey := "~" this.TriggerSideKey " & LButton"

        try {

            if (this._registeredComboHotkey != "" && this._registeredComboHotkey != newHotkey) {

                try Hotkey this._registeredComboHotkey, "Off"

            }

            this._registeredComboHotkey := newHotkey

            if this.ED && this.assistantEnabled

                Hotkey newHotkey, this._cbComboFire, "On"

            else

                Hotkey newHotkey, this._cbComboFire, "Off"

        } catch {

        }

    }



    SyncSideHotkey() {

        local newHotkey := "~" this.TriggerSideKey

        try {

            if (this._registeredSideHotkey != "" && this._registeredSideHotkey != newHotkey) {

                try Hotkey this._registeredSideHotkey, "Off"

            }

            this._registeredSideHotkey := newHotkey

            Hotkey newHotkey, this._cbSideKeyPressed, "On"

        } catch {

        }

    }



    SyncCut31Hotkey() {

        try {

            if this.Cut31Enabled && this.assistantEnabled

                Hotkey "~WheelDown", this._cbDo31Cut, "On"

            else

                Hotkey "~WheelDown", this._cbDo31Cut, "Off"

        } catch {

        }

    }



    SyncImageRecHotkey() {

        if this.ImageRecEnabled && this.assistantEnabled && this.ImageRecF2Enabled {

            SetTimer this._cbImageSearchTimer, this.ImageSearchInterval

        } else {

            SetTimer this._cbImageSearchTimer, 0

        }

    }



    ToggleImageRecF2(*) {

        this.ImageRecF2Enabled := !this.ImageRecF2Enabled

        this.SaveSettings()

        this.SyncImageRecHotkey()

        this.UpdateStatusDisplay()

        ToolTip this.ImageRecF2Enabled ? "图像识别独立开关：开(F2)" : "图像识别独立开关：关(F2)"

        SetTimer () => ToolTip(), -1200

    }



    Do31Cut(*) {

        this.GetCurrentValues()

        if !this.Cut31Enabled || !this.assistantEnabled

            return



        if (A_TickCount - this._lastCut31Tick < 2000)

            return

        this._lastCut31Tick := A_TickCount



        local ms := Integer(this.Cut31Interval)

        if ms < 10

            ms := 10

        if ms > 2000

            ms := 2000

        Sleep ms

        SendInput "3"

        Sleep 10

        SendInput "1"

    }



    SideKeyPressed(*) {

        if !this.breathHold || !this.assistantEnabled

            return

        Send "{Blind}{" this.breathHoldKey " down}"

        KeyWait this.TriggerSideKey

        Send "{Blind}{" this.breathHoldKey " up}"

    }



    ; -------------------------------

    ;          图像识别部分

    ; -------------------------------

    ImageSearchTimer(*) {

        if !this.ImageRecEnabled || !this.assistantEnabled || this._isSearching

            return



        ; 防止过于频繁的搜索

        if (A_TickCount - this._lastImageSearchTick < this.ImageSearchInterval)

            return

        this._lastImageSearchTick := A_TickCount



        this._isSearching := true

        try {

            local FoundX := 0, FoundY := 0

            local x1 := Min(this.SearchX1, this.SearchX2)

            local y1 := Min(this.SearchY1, this.SearchY2)

            local x2 := Max(this.SearchX1, this.SearchX2)

            local y2 := Max(this.SearchY1, this.SearchY2)



            ; 改为 PixelSearch：默认搜索黑色；若填写了颜色则优先用填写值

            local targetColor := this.ResolvePixelTargetColor()



            ; 执行像素搜索

            try {

                if PixelSearch(&FoundX, &FoundY, x1, y1, x2, y2, targetColor, this.ImageTolerance) {

                    ; 连续命中计数（防误触）

                    this._imgHitStreak += 1

                    if (this._imgHitStreak >= this.ImageHitStreakRequired) {

                        this._imgHitStreak := 0

                        this.TriggerImageHotkey()

                        Sleep 50 ; 防止连续触发

                    }

                    if this.ImageDebug {

                        if (A_TickCount - this._lastImageDebugTipTick > 250) {

                            this._lastImageDebugTipTick := A_TickCount

                            ToolTip "命中：" FoundX "," FoundY "  连续=" this._imgHitStreak "/" this.ImageHitStreakRequired "  目标色=0x" Format("{:06X}", targetColor & 0xFFFFFF) "  容差=" this.ImageTolerance

                            SetTimer () => ToolTip(), -600

                        }

                    }

                } else {

                    this._imgHitStreak := 0

                    if this.ImageDebug {

                        if (A_TickCount - this._lastImageDebugTipTick > 800) {

                            this._lastImageDebugTipTick := A_TickCount

                            ToolTip "未命中（区域=" x1 "," y1 "-" x2 "," y2 "  目标色=0x" Format("{:06X}", targetColor & 0xFFFFFF) "  容差=" this.ImageTolerance ")"

                            SetTimer () => ToolTip(), -400

                        }

                    }

                }

            } catch {

                ; 搜索失败，忽略

            }

        } finally {

            this._isSearching := false

        }

    }



    TriggerImageHotkey() {

        local key := Trim(this.TriggerKey)

        if (key = "")

            return

        try {

            if (this.ImageTriggerMode = 3) {

                if GetKeyState(key, "P")

                    SendInput "{Blind}{" key " up}"

                else

                    SendInput "{Blind}{" key "}"

            } else if (this.ImageTriggerMode = 1)

                SendInput "{Blind}{" key " down}"

            else if (this.ImageTriggerMode = 2)

                SendInput "{Blind}{" key " up}"

            else

                SendInput "{Blind}{" key "}"

        } catch {

        }

    }



    ResolvePixelTargetColor() {

        local defaultColor := 0x000000

        if !this.ImageUseTrans

            return defaultColor

        local raw := Trim(this.ImageTransColor)

        if (raw = "")

            return defaultColor



        if (SubStr(raw, 1, 2) = "0x")

            raw := SubStr(raw, 3)

        raw := RegExReplace(raw, "[^0-9A-Fa-f]", "")

        if (raw = "")

            return defaultColor



        try {

            return Integer("0x" raw)

        } catch {

            return defaultColor

        }

    }



    ImageRecChanged(ctrlObj, *) {

        this.ImageRecEnabled := ctrlObj.Value ? 1 : 0

        this.SyncImageRecHotkey()

        ToolTip this.ImageRecEnabled ? "图像识别已启用" : "图像识别已关闭"

        SetTimer () => ToolTip(), -1500

    }



    PickSearchRegion(*) {

        if MsgBox(

            "步骤：`n"

            "1. 点「确定」后，主窗口会最小化。`n"

            "2. 切换到要监控的游戏或画面。`n"

            "3. 按住右键拖出矩形，松开右键完成框选。`n"

            "4. 在出现提示后、完成框选前，可随时按 Esc 取消。`n`n"

            "说明：坐标为整屏像素。若全屏游戏里右键无效，可改用手动填写 X1 Y1 X2 Y2。",

            "框选图像搜索区域", "OKCancel Icon?") != "OK"

            return



        this.MyGui.Minimize()

        Sleep 300

        CoordMode "Mouse", "Screen"

        ToolTip "切换到目标画面，按住右键拖拽框选（松开完成，Esc 取消）"



        picked := false

        deadline := A_TickCount + 120000



        while A_TickCount < deadline {

            if GetKeyState("Escape", "P") {

                ToolTip()

                this.MyGui.Restore()

                return

            }

            if GetKeyState("RButton", "P") {

                MouseGetPos &x1, &y1

                while GetKeyState("RButton", "P") {

                    if GetKeyState("Escape", "P") {

                        ToolTip()

                        this.MyGui.Restore()

                        return

                    }

                    MouseGetPos &cx, &cy

                    ToolTip "拖拽中… 宽 " Abs(cx - x1) " 高 " Abs(cy - y1) " （松开完成，Esc 取消）"

                    Sleep 20

                }

                MouseGetPos &x2, &y2

                ToolTip()

                rx1 := Min(x1, x2), ry1 := Min(y1, y2), rx2 := Max(x1, x2), ry2 := Max(y1, y2)

                picked := true

                break

            }

            Sleep 20

        }



        if !picked {

            ToolTip()

            this.MyGui.Restore()

            if A_TickCount >= deadline

                MsgBox "等待超时：未检测到右键按下。`n仍可直接在上方填写坐标。", "框选未开始", "Icon!"

            return

        }



        rx1 := Max(0, rx1), ry1 := Max(0, ry1)

        rx2 := Min(A_ScreenWidth - 1, rx2), ry2 := Min(A_ScreenHeight - 1, ry2)

        if (rx2 - rx1 < 2 || ry2 - ry1 < 2) {

            this.MyGui.Restore()

            MsgBox "区域太小（请拖大一点）。", "框选无效", "Icon!"

            return

        }



        this.SearchX1Ctrl.Value := rx1

        this.SearchY1Ctrl.Value := ry1

        this.SearchX2Ctrl.Value := rx2

        this.SearchY2Ctrl.Value := ry2

        this.MyGui.Restore()

        ToolTip "已填入搜索区域 " (rx2 - rx1 + 1) "×" (ry2 - ry1 + 1) " 像素，记得点「应用设置」保存。"

        SetTimer () => ToolTip(), -3500

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

        this.MouseXY(Round(hComp), Round(vComp))

    }



    ComboFire(*) {

        if !this.ED || !this.assistantEnabled || this.isFiring

            return



        this.isFiring := true

        this.GetCurrentValues()

        local fireInterval := Round(60000 / this.FireRate)

        local baseRecoil := this.RecoilForce

        local lastFireTimeLocal := A_TickCount - fireInterval

        local shotCount := 0



        SendInput "{Blind}{LButton down}"

        try {

            if this.semiAutoMode {

                while GetKeyState(this.TriggerSideKey, "P") && GetKeyState("LButton", "P") && this.ED && this.assistantEnabled && this.semiAutoMode {

                    if A_TickCount - lastFireTimeLocal >= fireInterval {

                        lastFireTimeLocal := A_TickCount

                        SendInput "{Blind}{LButton up}"

                        Sleep 2

                        SendInput "{Blind}{LButton down}"

                        local randRecoil := Random(-0.5, 0.5)

                        local randHoriz := Random(-0.3, 0.3)

                        local hComp := this.CalculateHorizontalCompensation(shotCount, this.HorizontalRecoil, this.HorizontalPattern, randHoriz)

                        local vComp := baseRecoil * 0.9 + randRecoil

                        this.ApplyRecoilCompensation(hComp, vComp)

                        shotCount += 1

                    }

                    Sleep 1

                }

            } else {

                while GetKeyState(this.TriggerSideKey, "P") && GetKeyState("LButton", "P") && this.ED && this.assistantEnabled && !this.semiAutoMode {

                    if A_TickCount - lastFireTimeLocal >= fireInterval {

                        lastFireTimeLocal := A_TickCount

                        local randRecoil := Random(-1, 1)

                        local randHoriz := Random(-0.5, 0.5)

                        local hComp := this.CalculateHorizontalCompensation(shotCount, this.HorizontalRecoil, this.HorizontalPattern, randHoriz)

                        local vComp := baseRecoil + randRecoil

                        this.ApplyRecoilCompensation(hComp, vComp)

                        shotCount += 1

                    }

                    Sleep 1

                }

            }

        } finally {

            SendInput "{Blind}{LButton up}"

            this.isFiring := false

        }

    }



    ; -------------------------------

    ;          GUI与事件

    ; -------------------------------

    CreateGUI() {

        this.MyGui := Gui("+Resize", "Legendary压枪助手 " this.scriptVersion)

        this.MyGui.OnEvent("Close", this._cbGuiClose)

        this.MyGui.OnEvent("Escape", this._cbGuiEscape)

        this.MyGui.SetFont("s10", "Microsoft YaHei")



        this.MyGui.Add("Button", "xm ym w90 h25", "操作指南").OnEvent("Click", ObjBindMethod(this, "ShowHelpGuide"))

        this.MyGui.Add("Button", "x+10 yp w90 h25", "配置管理").OnEvent("Click", this._cbOpenConfigManager)



        this.MyGui.Add "Text", "xm y+14 w120", "启用/禁用热键："

        this.HotkeyCtrl := this.MyGui.Add("Hotkey", "x+5 yp-3 w200", this.HotkeyCC)

        this.HotkeyCtrl.OnEvent("Change", this._cbHotkeyChanged)



        this.MyGui.Add("Text", "xm y+18 w120", "功能启用：")

        local gbX := 12
        local gbY := 115
        local leftW := 250
        local rightW := 250
        local gbGap := 12
        local gbH := 170

        local gbHotkey := this.MyGui.Add("GroupBox", "x" gbX " y" gbY " w" leftW " h" gbH, "热键辅助")
        local gbImg := this.MyGui.Add("GroupBox", "x" (gbX + leftW + gbGap) " y" gbY " w" rightW " h" gbH, "图像识别")

        gbHotkey.GetPos(&hx, &hy, &hw, &hh)
        gbImg.GetPos(&ix, &iy, &iw, &ih)

        local rowY := hy + 25
        local rowGap := 28

        this.ED_Ctrl := this.MyGui.Add("CheckBox", "x" (hx + 12) " y" rowY " w150", "启用压枪")
        this.ED_Ctrl.Value := this.ED
        this.ED_Ctrl.OnEvent("Click", this._cbCheckboxChanged)
        this.MyGui.Add("Button", "x" (hx + hw - 70) " y" (rowY - 3) " w60", "配置").OnEvent("Click", this._cbOpenRecoilConfig)

        rowY += rowGap
        this.BreathHoldCtrl := this.MyGui.Add("CheckBox", "x" (hx + 12) " y" rowY " w150", "启用屏息")
        this.BreathHoldCtrl.Value := this.breathHold
        this.BreathHoldCtrl.OnEvent("Click", (*) => (this.breathHold := this.BreathHoldCtrl.Value, this.SaveSettings(), this.UpdateStatusDisplay()))
        this.MyGui.Add("Button", "x" (hx + hw - 70) " y" (rowY - 3) " w60", "配置").OnEvent("Click", this._cbOpenBreathConfig)

        rowY += rowGap
        this.SemiAutoModeCtrl := this.MyGui.Add("CheckBox", "x" (hx + 12) " y" rowY " w150", "启用半自动模式")
        this.SemiAutoModeCtrl.Value := this.semiAutoMode
        this.SemiAutoModeCtrl.OnEvent("Click", (*) => (this.semiAutoMode := this.SemiAutoModeCtrl.Value, this.SaveSettings(), this.UpdateStatusDisplay()))
        this.MyGui.Add("Button", "x" (hx + hw - 70) " y" (rowY - 3) " w60", "配置").OnEvent("Click", this._cbOpenSemiAutoConfig)

        rowY += rowGap
        this.Cut31Ctrl := this.MyGui.Add("CheckBox", "x" (hx + 12) " y" rowY " w150", "启用31切枪")
        this.Cut31Ctrl.Value := this.Cut31Enabled ? 1 : 0
        this.Cut31Ctrl.OnEvent("Click", this._cbCut31Changed)
        this.MyGui.Add("Button", "x" (hx + hw - 70) " y" (rowY - 3) " w60", "配置").OnEvent("Click", this._cbOpenCut31Config)

        local imgY := iy + 25
        this.ImageRecCtrl := this.MyGui.Add("CheckBox", "x" (ix + 12) " y" imgY " w170", "图像识别自动触发")
        this.ImageRecCtrl.Value := this.ImageRecEnabled ? 1 : 0
        this.ImageRecCtrl.OnEvent("Click", this._cbImageRecChanged)
        this.MyGui.Add("Button", "x" (ix + iw - 70) " y" (imgY - 3) " w60", "配置").OnEvent("Click", this._cbOpenImageRecConfig)

        local bottomY := (hy + hh > iy + ih ? hy + hh : iy + ih) + 18
        this.StatusTextCtrl := this.MyGui.Add("Text", "x" gbX " y" bottomY " w" (leftW + rightW + gbGap) " h22", "状态：未启用")

        this.MyGui.Show "w540 h" (bottomY + 55)

    }



    OpenRecoilConfig(*) {

        if ObjHasOwnProp(this, "RecoilConfigGui") {

            try {

                this.RecoilConfigGui.Show()

                return

            } catch {

            }

        }



        this.RecoilConfigGui := Gui("+Owner" this.MyGui.Hwnd, "配置 - 启用压枪")

        this.RecoilConfigGui.SetFont("s10", "Microsoft YaHei")



        this.RecoilConfigGui.Add "Text", "xm ym w80", "触发按键："

        this.SideTriggerCtrl := this.RecoilConfigGui.Add("DropDownList", "x+5 yp-3 w200", ["侧键2(XButton2)", "侧键1(XButton1)", "右键(RButton)"])

        this.SideTriggerCtrl.Choose(this.TriggerSideKey = "XButton1" ? 2 : (this.TriggerSideKey = "RButton" ? 3 : 1))

        this.SideTriggerCtrl.OnEvent("Change", this._cbTriggerKeyChanged)



        this.RecoilConfigGui.Add "Text", "xm y+12 w80", "射速 (RPM)："

        this.FireRateCtrl := this.RecoilConfigGui.Add("Edit", "x+5 yp-3 w200 Number", this.FireRate)



        this.RecoilConfigGui.Add "Text", "xm y+12 w80", "垂直压枪力度："

        this.RecoilForceCtrl := this.RecoilConfigGui.Add("Edit", "x+5 yp-3 w200 Number", this.RecoilForce)

        this.RecoilConfigGui.Add "Text", "x+10 yp+3 w80 cGray", "(0-30)"



        this.RecoilConfigGui.Add "Text", "xm y+12 w80", "横向补偿力度："

        this.HorizontalRecoilCtrl := this.RecoilConfigGui.Add("Edit", "x+5 yp-3 w200 Number", this.HorizontalRecoil)

        this.RecoilConfigGui.Add "Text", "x+10 yp+3 w160 cRed", "(-15~15，负值=向右)"



        this.RecoilConfigGui.Add "Text", "xm y+12 w80", "横向模式："

        this.HorizontalPatternCtrl := this.RecoilConfigGui.Add("DropDownList", "x+5 yp-3 w200", ["固定补偿", "左右交替"])

        this.HorizontalPatternCtrl.Choose(this.HorizontalPattern + 1)



        this.RecoilForceCtrl.OnEvent("Change", this._cbTrajectoryPreviewDebounce)

        this.RecoilForceCtrl.OnEvent("LoseFocus", this._cbUpdateTrajectoryPreview)

        this.HorizontalRecoilCtrl.OnEvent("Change", this._cbTrajectoryPreviewDebounce)

        this.HorizontalRecoilCtrl.OnEvent("LoseFocus", this._cbUpdateTrajectoryPreview)



        this.TrajectoryTitleCtrl := this.RecoilConfigGui.Add("Text", "x480 ym w120 Center", "弹道预览")

        this.TrajectoryPicCtrl := this.RecoilConfigGui.Add("Text", "x480 y+2 w" this.TRAJ_WIDTH " h" this.TRAJ_HEIGHT " Border")

        this.TrajectoryPicCtrl.ToolTip := "红线 = 当前压枪方向，便于对比游戏内弹道"

        this.TrajectoryDrawHwnd := this.TrajectoryPicCtrl.Hwnd

        this._TrajWndProcCallback := CallbackCreate(ObjBindMethod(this, "TrajectoryPaintWndProc"), "Fast", 4)

        this._TrajOldWndProc := DllCall("SetWindowLongPtr", "Ptr", this.TrajectoryDrawHwnd, "Int", -4, "Ptr", this._TrajWndProcCallback, "Ptr")

        this.TrajectorySlopeCtrl := this.RecoilConfigGui.Add("Text", "x480 y+2 w120 Center cGray", "垂直: 0  横向: 0")



        this.RecoilConfigGui.Add("Button", "xm y+18 w100", "应用设置").OnEvent("Click", this._cbApplySettings)

        this.RecoilConfigGui.Add("Button", "x+10 yp w100", "恢复默认").OnEvent("Click", this._cbRestoreDefaults)

        this.RecoilConfigGui.Show("w660 h320")

        this.UpdateTrajectoryPreview()

    }



    OpenBreathConfig(*) {

        if ObjHasOwnProp(this, "BreathConfigGui") {

            try {

                this.BreathConfigGui.Show()

                return

            } catch {

            }

        }

        this.BreathConfigGui := Gui("+Owner" this.MyGui.Hwnd, "配置 - 启用屏息")

        this.BreathConfigGui.SetFont("s10", "Microsoft YaHei")

        this.BreathConfigGui.Add "Text", "xm ym w80", "触发按键："
        local breathSideTriggerCtrl := this.BreathConfigGui.Add("DropDownList", "x+5 yp-3 w150", ["侧键2(XButton2)", "侧键1(XButton1)", "右键(RButton)"])
        breathSideTriggerCtrl.Choose(this.TriggerSideKey = "XButton1" ? 2 : (this.TriggerSideKey = "RButton" ? 3 : 1))

        this.BreathConfigGui.Add("Text", "xm y+12 w80", "屏息键：")
        this.BreathHoldKeyCtrl := this.BreathConfigGui.Add("Edit", "x+5 yp-3 w150", this.breathHoldKey)

        this.BreathConfigGui.Add("Button", "xm y+18 w100", "应用设置")
            .OnEvent("Click", (*) => (
                this.TriggerSideKey := InStr(breathSideTriggerCtrl.Text, "XButton1") ? "XButton1" : (InStr(breathSideTriggerCtrl.Text, "RButton") ? "RButton" : "XButton2"),
                this.breathHoldKey := (Trim(this.BreathHoldKeyCtrl.Value) = "") ? "L" : Trim(this.BreathHoldKeyCtrl.Value),
                this.SaveSettings(),
                this.UpdateGUIDisplay(),
                this.UpdateStatusDisplay(),
                this.SyncComboHotkey(),
                this.SyncSideHotkey(),
                this.SyncCut31Hotkey(),
                this.SyncImageRecHotkey(),
                this.HideAllConfigGuis(),
                ToolTip("设置已应用！"),
                SetTimer(() => ToolTip(), -1800)
            ))

        this.BreathConfigGui.Show("w360 h150")

    }



    OpenSemiAutoConfig(*) {

        if ObjHasOwnProp(this, "SemiAutoConfigGui") {

            try {

                this.SemiAutoConfigGui.Show()

                return

            } catch {

            }

        }

        this.SemiAutoConfigGui := Gui("+Owner" this.MyGui.Hwnd, "配置 - 启用半自动模式")

        this.SemiAutoConfigGui.SetFont("s10", "Microsoft YaHei")

        this.SemiAutoConfigGui.Add "Text", "xm ym w80", "触发按键："
        local semiSideTriggerCtrl := this.SemiAutoConfigGui.Add("DropDownList", "x+5 yp-3 w150", ["侧键2(XButton2)", "侧键1(XButton1)", "右键(RButton)"])
        semiSideTriggerCtrl.Choose(this.TriggerSideKey = "XButton1" ? 2 : (this.TriggerSideKey = "RButton" ? 3 : 1))

        this.SemiAutoConfigGui.Add("Text", "xm y+12 w80", "射速 (RPM)：")
        local semiFireRateCtrl := this.SemiAutoConfigGui.Add("Edit", "x+5 yp-3 w150 Number", this.FireRate)

        this.SemiAutoConfigGui.Add("Button", "xm y+18 w100", "应用设置")
            .OnEvent("Click", (*) => (
                this.TriggerSideKey := InStr(semiSideTriggerCtrl.Text, "XButton1") ? "XButton1" : (InStr(semiSideTriggerCtrl.Text, "RButton") ? "RButton" : "XButton2"),
                this.FireRate := this.ClampInt(semiFireRateCtrl.Value, 100, 2000, 600),
                this.SaveSettings(),
                this.UpdateGUIDisplay(),
                this.UpdateStatusDisplay(),
                this.SyncComboHotkey(),
                this.SyncSideHotkey(),
                this.SyncCut31Hotkey(),
                this.SyncImageRecHotkey(),
                this.HideAllConfigGuis(),
                ToolTip("设置已应用！"),
                SetTimer(() => ToolTip(), -1800)
            ))

        this.SemiAutoConfigGui.Show("w360 h170")

    }



    OpenCut31Config(*) {

        if ObjHasOwnProp(this, "Cut31ConfigGui") {

            try {

                this.Cut31ConfigGui.Show()

                return

            } catch {

            }

        }

        this.Cut31ConfigGui := Gui("+Owner" this.MyGui.Hwnd, "配置 - 启用31切枪")

        this.Cut31ConfigGui.SetFont("s10", "Microsoft YaHei")

        this.Cut31ConfigGui.Add("Text", "xm ym w90", "间隔(ms)：")

        this.Cut31IntervalCtrl := this.Cut31ConfigGui.Add("Edit", "x+5 yp-3 w120 Number", this.Cut31Interval)

        this.Cut31ConfigGui.Add("Text", "x+5 yp+3 w80 cGray", "10-2000")

        this.Cut31ConfigGui.Add("Button", "xm y+18 w100", "应用设置").OnEvent("Click", this._cbApplySettings)

        this.Cut31ConfigGui.Show("w320 h130")

    }



    OpenImageRecConfig(*) {

        if ObjHasOwnProp(this, "ImageRecConfigGui") {

            try {

                this.ImageRecConfigGui.Show()

                return

            } catch {

            }

        }



        this.ImageRecConfigGui := Gui("+Owner" this.MyGui.Hwnd, "配置 - 图像识别自动触发")

        this.ImageRecConfigGui.SetFont("s10", "Microsoft YaHei")



        this.ImageRecConfigGui.Add("Text", "xm ym cRed", "提示：图像识别需【总开关开启】+【主界面勾选图像识别】+【F2 独立开关为开】才会运行")



        this.ImageRecConfigGui.Add("Text", "xm y+10 w80", "搜索区域：")

        this.ImageRecConfigGui.Add("Text", "x+5 yp+3 w30", "X1")

        this.SearchX1Ctrl := this.ImageRecConfigGui.Add("Edit", "x+2 yp-3 w70 Number", this.SearchX1)

        this.ImageRecConfigGui.Add("Text", "x+10 yp+3 w30", "Y1")

        this.SearchY1Ctrl := this.ImageRecConfigGui.Add("Edit", "x+2 yp-3 w70 Number", this.SearchY1)



        this.ImageRecConfigGui.Add("Text", "xm+85 y+12 w30", "X2")

        this.SearchX2Ctrl := this.ImageRecConfigGui.Add("Edit", "x+2 yp-3 w70 Number", this.SearchX2)

        this.ImageRecConfigGui.Add("Text", "x+10 yp+3 w30", "Y2")

        this.SearchY2Ctrl := this.ImageRecConfigGui.Add("Edit", "x+2 yp-3 w70 Number", this.SearchY2)



        this.ImageRecConfigGui.Add("Button", "xm y+10 w150", "右键拖拽框选区域").OnEvent("Click", this._cbPickSearchRegion)



        this.ImageRecConfigGui.Add("Text", "xm y+12 w80", "容差(0-255)：")

        this.ImageToleranceCtrl := this.ImageRecConfigGui.Add("Edit", "x+5 yp-3 w100 Number", this.ImageTolerance)

        this.ImageRecConfigGui.Add("Text", "x+8 yp+3 w80 cGray", "(0=精确匹配)")



        this.ImageRecConfigGui.Add("Text", "xm y+12 w80", "搜索间隔(ms)：")

        this.ImageSearchIntervalCtrl := this.ImageRecConfigGui.Add("Edit", "x+5 yp-3 w100 Number", this.ImageSearchInterval)

        this.ImageRecConfigGui.Add("Text", "x+8 yp+3 w80 cGray", "(20-200)")



        this.ImageRecConfigGui.Add("Text", "xm y+12 w80", "图像识别发送键：")

        this.ImageSendKeyCtrl := this.ImageRecConfigGui.Add("Edit", "x+5 yp-3 w50", this.TriggerKey)



        this.ImageRecConfigGui.Add("Text", "xm y+12 w80", "触发方式：")

        this.ImageTriggerModeCtrl := this.ImageRecConfigGui.Add("DropDownList", "x+5 yp-3 w160", ["点击(tap)", "按下(down)", "抬起(up)", "智能(auto)"])

        this.ImageTriggerModeCtrl.Choose(this.ImageTriggerMode + 1)



        this.ImageRecConfigGui.Add("Text", "xm y+12 w80", "连续命中：")

        this.ImageHitStreakCtrl := this.ImageRecConfigGui.Add("Edit", "x+5 yp-3 w100 Number", this.ImageHitStreakRequired)

        this.ImageRecConfigGui.Add("Text", "x+8 yp+3 w250 cGray", "N 次连续命中后才触发(1=每次命中都触发)")



        this.ImageRecConfigGui.Add("Text", "xm y+12 w80", "目标颜色：")

        this.ImageUseTransCtrl := this.ImageRecConfigGui.Add("CheckBox", "x+5 yp-3", "启用")

        this.ImageUseTransCtrl.Value := this.ImageUseTrans ? 1 : 0

        this.ImageUseTransCtrl.OnEvent("Click", (c, *) => (this.ImageUseTrans := c.Value ? 1 : 0, this.SaveSettings()))

        this.ImageTransColorCtrl := this.ImageRecConfigGui.Add("Edit", "x+8 yp w120", this.ImageTransColor)

        this.ImageTransColorCtrl.OnEvent("Change", (c, *) => (this.ImageTransColor := Trim(c.Value), this.SaveSettings()))

        this.ImageRecConfigGui.Add("Text", "x+8 yp+3 w230 cGray", "留空=黑色(000000)，示例: FFFF00 或 0xFFFF00")



        this.ImageRecConfigGui.Add("Button", "xm y+10 w80", "取色")

            .OnEvent("Click", this._cbStartColorPicker)

        this.ColorPickedCtrl := this.ImageRecConfigGui.Add("Edit", "x+8 yp w120 ReadOnly")

        this.ImageRecConfigGui.Add("Text", "x+8 yp+3 w230 cGray", "进入取色后：右键单击取色，Esc 取消")



        local debugCtrl := this.ImageRecConfigGui.Add("CheckBox", "xm y+10", "调试模式(提示命中/未命中)")

        debugCtrl.Value := this.ImageDebug ? 1 : 0

        debugCtrl.OnEvent("Click", (c, *) => (this.ImageDebug := c.Value ? 1 : 0, this.SaveSettings()))



        this.ImageRecConfigGui.Add("Button", "xm y+18 w100", "应用设置").OnEvent("Click", this._cbApplySettings)

        this.ImageRecConfigGui.Show("w520 h540")

    }



    StartColorPicker(*) {

        if this._pickingColor

            return

        this._pickingColor := true

        CoordMode "Mouse", "Screen"

        CoordMode "Pixel", "Screen"

        try Hotkey "RButton", this._cbColorPickRButton, "On"

        catch {

        }

        try Hotkey "Escape", this._cbColorPickEsc, "On"

        catch {

        }

        ToolTip "取色模式：右键单击取色，Esc 取消"

    }



    StopColorPicker() {

        this._pickingColor := false

        try Hotkey "RButton", "Off"

        catch {

        }

        try Hotkey "Escape", "Off"

        catch {

        }

        ToolTip()

    }



    ColorPickEsc(*) {

        if !this._pickingColor

            return

        this.StopColorPicker()

    }



    ColorPickRButton(*) {

        if !this._pickingColor

            return

        local x := 0, y := 0

        MouseGetPos &x, &y

        try {

            local c := PixelGetColor(x, y, "RGB")

        } catch {

            this.StopColorPicker()

            return

        }

        local hex := Format("0x{:06X}", c & 0xFFFFFF)

        Clipboard := hex

        if ObjHasOwnProp(this, "ColorPickedCtrl") {

            try if (this.ColorPickedCtrl)

                this.ColorPickedCtrl.Value := hex

        }

        ToolTip "已取色：" hex "（已复制）"

        SetTimer () => ToolTip(), -1200

        this.StopColorPicker()

    }



    OpenConfigManager(*) {

        if ObjHasOwnProp(this, "ConfigManagerGui") {

            try {

                this.ConfigManagerGui.Show()

                return

            } catch {

            }

        }

        this.ConfigManagerGui := Gui("+Owner" this.MyGui.Hwnd, "配置管理")

        this.ConfigManagerGui.SetFont("s10", "Microsoft YaHei")

        local tabs := this.ConfigManagerGui.Add("Tab3", "xm ym w520 h230", ["热键辅助", "图像识别"])

        tabs.UseTab(1)
        this.ConfigManagerGui.Add "Text", "xm+10 y+15 w120", "已存配置："
        this.HotkeyConfigListCtrl := this.ConfigManagerGui.Add("DropDownList", "x+5 yp-3 w200")
        this.ConfigManagerGui.Add("Button", "x+5 yp w80", "加载选中").OnEvent("Click", ObjBindMethod(this, "LoadSelectedHotkeyConfig"))
        this.ConfigManagerGui.Add("Button", "x+5 yp w70", "刷新").OnEvent("Click", ObjBindMethod(this, "RefreshHotkeyConfigList"))

        this.ConfigManagerGui.Add "Text", "xm+10 y+12 w120", "配置名称："
        this.HotkeyConfigNameCtrl := this.ConfigManagerGui.Add("Edit", "x+5 yp-3 w200")
        this.ConfigManagerGui.Add("Button", "x+5 yp w70", "保存").OnEvent("Click", ObjBindMethod(this, "SaveHotkeyConfig"))
        this.ConfigManagerGui.Add("Button", "x+5 yp w70", "删除").OnEvent("Click", ObjBindMethod(this, "DeleteSelectedHotkeyConfig"))

        tabs.UseTab(2)
        this.ConfigManagerGui.Add "Text", "xm+10 y+15 w120", "已存配置："
        this.ImageConfigListCtrl := this.ConfigManagerGui.Add("DropDownList", "x+5 yp-3 w200")
        this.ConfigManagerGui.Add("Button", "x+5 yp w80", "加载选中").OnEvent("Click", ObjBindMethod(this, "LoadSelectedImageConfig"))
        this.ConfigManagerGui.Add("Button", "x+5 yp w70", "刷新").OnEvent("Click", ObjBindMethod(this, "RefreshImageConfigList"))

        this.ConfigManagerGui.Add "Text", "xm+10 y+12 w120", "配置名称："
        this.ImageConfigNameCtrl := this.ConfigManagerGui.Add("Edit", "x+5 yp-3 w200")
        this.ConfigManagerGui.Add("Button", "x+5 yp w70", "保存").OnEvent("Click", ObjBindMethod(this, "SaveImageConfig"))
        this.ConfigManagerGui.Add("Button", "x+5 yp w70", "删除").OnEvent("Click", ObjBindMethod(this, "DeleteSelectedImageConfig"))

        tabs.UseTab()

        this.ConfigManagerGui.Show("w540 h250")

        this.RefreshHotkeyConfigList()

        this.RefreshImageConfigList()

    }



    ; -------------------------------

    ;      配置管理（热键辅助）

    ; -------------------------------

    ResolveHotkeyConfigSection(configName) {
        local hkSection := "HK_" configName
        local legacySection := "Config_" configName
        local existsHK := IniRead(this.configFile, hkSection, "Hotkey", "")
        if (existsHK != "")
            return hkSection
        local existsLegacy := IniRead(this.configFile, legacySection, "Hotkey", "")
        if (existsLegacy != "")
            return legacySection
        return ""
    }

    RefreshHotkeyConfigList(*) {
        try {
            local sections := IniRead(this.configFile)
            local configs := Map()
            if sections != "" {
                for line in StrSplit(sections, "`n") {
                    line := Trim(line)
                    if (line = "")
                        continue
                    if (InStr(line, "HK_") = 1)
                        configs[SubStr(line, 4)] := true
                    else if (InStr(line, "Config_") = 1)
                        configs[SubStr(line, 8)] := true
                }
            }

            this.HotkeyConfigListCtrl.Delete()
            for name, _ in configs
                this.HotkeyConfigListCtrl.Add([name])
        } catch {
            MsgBox "刷新热键辅助配置列表失败！", "错误", "Iconx"
        }
    }

    SaveHotkeyConfig(*) {
        this.GetCurrentValues()

        local rawName := Trim(this.HotkeyConfigNameCtrl.Value)
        local configName := this.SanitizeConfigName(rawName)
        if configName = "" {
            MsgBox "请输入配置名称！", "提示", "Icon!"
            return
        }
        if (rawName != configName)
            this.HotkeyConfigNameCtrl.Value := configName

        local section := "HK_" configName
        local exists := IniRead(this.configFile, section, "Hotkey", "")
        if (exists != "") {
            if MsgBox("配置 [" configName "] 已存在，是否覆盖？", "确认覆盖", "YesNo Icon?") != "Yes"
                return
        }

        try {
            IniWrite this.FireRate, this.configFile, section, "FireRate"
            IniWrite this.RecoilForce, this.configFile, section, "RecoilForce"
            IniWrite this.HorizontalRecoil, this.configFile, section, "HorizontalRecoil"
            IniWrite this.HorizontalPattern, this.configFile, section, "HorizontalPattern"
            IniWrite this.HotkeyCC, this.configFile, section, "Hotkey"
            IniWrite this.TriggerSideKey, this.configFile, section, "TriggerKey"
            IniWrite this.breathHold, this.configFile, section, "BreathHold"
            IniWrite (Trim(this.breathHoldKey) = "" ? "L" : this.breathHoldKey), this.configFile, section, "BreathHoldKey"
            IniWrite this.semiAutoMode, this.configFile, section, "SemiAutoMode"
            IniWrite this.ED, this.configFile, section, "ED"
            IniWrite (this.Cut31Enabled ? "1" : "0"), this.configFile, section, "Cut31Enabled"
            IniWrite this.Cut31Interval, this.configFile, section, "Cut31Interval"

            this.RefreshHotkeyConfigList()
            MsgBox "热键辅助配置 [" configName "] 已保存！", "提示", "Iconi"
        } catch {
            MsgBox "保存热键辅助配置失败！", "错误", "Iconx"
        }
    }

    LoadSelectedHotkeyConfig(*) {
        local configName := this.HotkeyConfigListCtrl.Text
        if configName = ""
            return

        local section := this.ResolveHotkeyConfigSection(configName)
        if (section = "") {
            MsgBox "未找到配置 [" configName "]！", "错误", "Iconx"
            return
        }

        try {
            this.FireRate := Integer(IniRead(this.configFile, section, "FireRate", this.FireRate))
            this.RecoilForce := Integer(IniRead(this.configFile, section, "RecoilForce", this.RecoilForce))
            this.HorizontalRecoil := Integer(IniRead(this.configFile, section, "HorizontalRecoil", this.HorizontalRecoil))
            this.HorizontalPattern := Integer(IniRead(this.configFile, section, "HorizontalPattern", this.HorizontalPattern))
            this.HotkeyCC := IniRead(this.configFile, section, "Hotkey", this.HotkeyCC)
            this.TriggerSideKey := IniRead(this.configFile, section, "TriggerKey", this.TriggerSideKey)
            if (this.TriggerSideKey != "XButton1" && this.TriggerSideKey != "XButton2" && this.TriggerSideKey != "RButton")
                this.TriggerSideKey := "XButton2"
            this.breathHold := Integer(IniRead(this.configFile, section, "BreathHold", this.breathHold))
            this.breathHoldKey := IniRead(this.configFile, section, "BreathHoldKey", this.breathHoldKey)
            if (Trim(this.breathHoldKey) = "")
                this.breathHoldKey := "L"
            this.semiAutoMode := Integer(IniRead(this.configFile, section, "SemiAutoMode", this.semiAutoMode))
            this.ED := Integer(IniRead(this.configFile, section, "ED", this.ED))
            this.Cut31Enabled := Integer(IniRead(this.configFile, section, "Cut31Enabled", this.Cut31Enabled ? 1 : 0)) != 0
            this.Cut31Interval := Integer(IniRead(this.configFile, section, "Cut31Interval", this.Cut31Interval))

            this.SaveSettings()
            this.UpdateGUIDisplay()
            this.UpdateStatusDisplay()
            this.SyncComboHotkey()
            this.SyncSideHotkey()
            this.SyncCut31Hotkey()
            this.HideAllConfigGuis()
        } catch {
            MsgBox "加载热键辅助配置失败！", "错误", "Iconx"
        }
    }

    DeleteSelectedHotkeyConfig(*) {
        local configName := this.HotkeyConfigListCtrl.Text
        if configName = ""
            return
        local section := "HK_" this.SanitizeConfigName(configName)
        if MsgBox("确认删除热键辅助配置 [" configName "]？", "确认删除", "YesNo Icon?") != "Yes"
            return
        try {
            IniDelete this.configFile, section
            this.HotkeyConfigNameCtrl.Value := ""
            this.RefreshHotkeyConfigList()
            MsgBox "热键辅助配置 [" configName "] 已删除！", "提示", "Iconi"
        } catch {
            MsgBox "删除热键辅助配置失败！", "错误", "Iconx"
        }
    }



    ; -------------------------------

    ;      配置管理（图像识别）

    ; -------------------------------

    RefreshImageConfigList(*) {
        try {
            local sections := IniRead(this.configFile)
            local configs := []
            if sections != "" {
                for line in StrSplit(sections, "`n") {
                    line := Trim(line)
                    if (line != "" && InStr(line, "IMG_") = 1)
                        configs.Push(SubStr(line, 5))
                }
            }
            this.ImageConfigListCtrl.Delete()
            if configs.Length > 0 {
                for name in configs
                    this.ImageConfigListCtrl.Add([name])
            }
        } catch {
            MsgBox "刷新图像识别配置列表失败！", "错误", "Iconx"
        }
    }

    SaveImageConfig(*) {
        this.GetCurrentValues()

        local rawName := Trim(this.ImageConfigNameCtrl.Value)
        local configName := this.SanitizeConfigName(rawName)
        if configName = "" {
            MsgBox "请输入配置名称！", "提示", "Icon!"
            return
        }
        if (rawName != configName)
            this.ImageConfigNameCtrl.Value := configName

        local section := "IMG_" configName
        local exists := IniRead(this.configFile, section, "ImageRecEnabled", "")
        if (exists != "") {
            if MsgBox("配置 [" configName "] 已存在，是否覆盖？", "确认覆盖", "YesNo Icon?") != "Yes"
                return
        }

        try {
            IniWrite (this.ImageRecEnabled ? "1" : "0"), this.configFile, section, "ImageRecEnabled"
            IniWrite this.SearchX1, this.configFile, section, "SearchX1"
            IniWrite this.SearchY1, this.configFile, section, "SearchY1"
            IniWrite this.SearchX2, this.configFile, section, "SearchX2"
            IniWrite this.SearchY2, this.configFile, section, "SearchY2"
            IniWrite this.ImageTolerance, this.configFile, section, "ImageTolerance"
            IniWrite this.ImageSearchInterval, this.configFile, section, "ImageSearchInterval"
            IniWrite this.TriggerKey, this.configFile, section, "ImageSendKey"
            IniWrite (this.ImageUseTrans ? "1" : "0"), this.configFile, section, "ImageUseTrans"
            IniWrite this.ImageTransColor, this.configFile, section, "ImageTransColor"
            IniWrite (this.ImageDebug ? "1" : "0"), this.configFile, section, "ImageDebug"
            IniWrite (this.ImageRecF2Enabled ? "1" : "0"), this.configFile, section, "ImageRecF2Enabled"
            IniWrite this.ImageHitStreakRequired, this.configFile, section, "ImageHitStreakRequired"
            IniWrite this.ImageTriggerMode, this.configFile, section, "ImageTriggerMode"

            this.RefreshImageConfigList()
            MsgBox "图像识别配置 [" configName "] 已保存！", "提示", "Iconi"
        } catch {
            MsgBox "保存图像识别配置失败！", "错误", "Iconx"
        }
    }

    LoadSelectedImageConfig(*) {
        local configName := this.ImageConfigListCtrl.Text
        if configName = ""
            return

        local section := "IMG_" configName
        local exists := IniRead(this.configFile, section, "ImageRecEnabled", "")
        if (exists = "") {
            MsgBox "未找到配置 [" configName "]！", "错误", "Iconx"
            return
        }

        try {
            this.ImageRecEnabled := Integer(IniRead(this.configFile, section, "ImageRecEnabled", this.ImageRecEnabled ? 1 : 0)) != 0
            this.SearchX1 := Integer(IniRead(this.configFile, section, "SearchX1", this.SearchX1))
            this.SearchY1 := Integer(IniRead(this.configFile, section, "SearchY1", this.SearchY1))
            this.SearchX2 := Integer(IniRead(this.configFile, section, "SearchX2", this.SearchX2))
            this.SearchY2 := Integer(IniRead(this.configFile, section, "SearchY2", this.SearchY2))
            this.ImageTolerance := Integer(IniRead(this.configFile, section, "ImageTolerance", this.ImageTolerance))
            this.ImageSearchInterval := Integer(IniRead(this.configFile, section, "ImageSearchInterval", this.ImageSearchInterval))
            this.TriggerKey := IniRead(this.configFile, section, "ImageSendKey", this.TriggerKey)
            this.ImageUseTrans := Integer(IniRead(this.configFile, section, "ImageUseTrans", this.ImageUseTrans ? 1 : 0)) != 0
            this.ImageTransColor := IniRead(this.configFile, section, "ImageTransColor", this.ImageTransColor)
            this.ImageDebug := Integer(IniRead(this.configFile, section, "ImageDebug", this.ImageDebug ? 1 : 0)) != 0
            this.ImageRecF2Enabled := Integer(IniRead(this.configFile, section, "ImageRecF2Enabled", this.ImageRecF2Enabled ? 1 : 0)) != 0
            this.ImageHitStreakRequired := Integer(IniRead(this.configFile, section, "ImageHitStreakRequired", this.ImageHitStreakRequired))
            this.ImageTriggerMode := Integer(IniRead(this.configFile, section, "ImageTriggerMode", this.ImageTriggerMode))

            this.SaveSettings()
            this.UpdateGUIDisplay()
            this.UpdateStatusDisplay()
            this.SyncImageRecHotkey()
            this.HideAllConfigGuis()
        } catch {
            MsgBox "加载图像识别配置失败！", "错误", "Iconx"
        }
    }

    DeleteSelectedImageConfig(*) {
        local configName := this.ImageConfigListCtrl.Text
        if configName = ""
            return
        local section := "IMG_" this.SanitizeConfigName(configName)
        if MsgBox("确认删除图像识别配置 [" configName "]？", "确认删除", "YesNo Icon?") != "Yes"
            return
        try {
            IniDelete this.configFile, section
            this.ImageConfigNameCtrl.Value := ""
            this.RefreshImageConfigList()
            MsgBox "图像识别配置 [" configName "] 已删除！", "提示", "Iconi"
        } catch {
            MsgBox "删除图像识别配置失败！", "错误", "Iconx"
        }
    }



    GuiSize(GuiObj, MinMax, Width, Height) {

        if (MinMax = -1 || !ObjHasOwnProp(this, "TrajectoryPicCtrl") || !this.TrajectoryPicCtrl)

            return

        local trajX := 388

        if (Width < trajX + this.TRAJ_WIDTH + 20) {

            try {

                this.TrajectoryTitleCtrl.Visible := false

                this.TrajectoryPicCtrl.Visible := false

                this.TrajectorySlopeCtrl.Visible := false

            } catch {

            }

        } else {

            try {

                this.TrajectoryTitleCtrl.Visible := true

                this.TrajectoryPicCtrl.Visible := true

                this.TrajectorySlopeCtrl.Visible := true

                this.TrajectoryTitleCtrl.Move(trajX, 35)

                this.TrajectoryPicCtrl.Move(trajX, 55)

                this.TrajectorySlopeCtrl.Move(trajX, 55 + this.TRAJ_HEIGHT + 2)

            } catch {

            }

        }

    }



    ShowMainWindow(*) {

        this.MyGui.Show()

    }



    CheckboxChanged(ctrlObj, *) {

        this.ED := ctrlObj.Value

        this.UpdateStatusDisplay()

        this.SyncComboHotkey()

        this.SyncSideHotkey()

        this.SyncCut31Hotkey()

        this.SyncImageRecHotkey()

        ToolTip this.ED ? "压枪已勾选" : "压枪已取消"

        SetTimer () => ToolTip(), -2000

    }



    Cut31Changed(ctrlObj, *) {

        this.Cut31Enabled := ctrlObj.Value ? 1 : 0

        this.SyncCut31Hotkey()

        ToolTip this.Cut31Enabled ? "31切枪已启用（滚轮下划）" : "31切枪已关闭"

        SetTimer () => ToolTip(), -1500

    }



    HotkeyChanged(ctrlObj, *) {

        local newHotkey := Trim(ctrlObj.Value)

        local oldHotkey := this.HotkeyCC

        if (newHotkey = "" || newHotkey = this.HotkeyCC)

            return

        try {

            Hotkey this.HotkeyCC, this._cbHotkeyToggle, "Off"

            Hotkey newHotkey, this._cbHotkeyToggle, "On"

            this.HotkeyCC := newHotkey

        } catch {

            this.HotkeyCC := oldHotkey

            this.HotkeyCtrl.Value := oldHotkey

            try Hotkey oldHotkey, this._cbHotkeyToggle, "On"

            catch {

            }

            MsgBox "热键设置失败，请检查热键格式或是否被占用！`n已恢复原热键。", "错误", "Iconx"

        }

    }



    TriggerKeyChanged(ctrlObj, *) {

        local label := ctrlObj.Text

        if InStr(label, "XButton2")

            this.TriggerSideKey := "XButton2"

        else if InStr(label, "XButton1")

            this.TriggerSideKey := "XButton1"

        else

            this.TriggerSideKey := "RButton"

        this.SyncComboHotkey()

        this.SyncSideHotkey()

    }



    TrajectoryPreviewDebounce(*) {

        SetTimer this._cbUpdateTrajectoryPreview, 0

        SetTimer this._cbUpdateTrajectoryPreview, -this.TRAJ_DEBOUNCE_MS

    }



    UpdateTrajectoryPreview(*) {

        local v, h

        try {

            v := this.RecoilForceCtrl.Value !== "" ? Integer(this.RecoilForceCtrl.Value) : this.RecoilForce

            h := this.HorizontalRecoilCtrl.Value !== "" ? Integer(this.HorizontalRecoilCtrl.Value) : this.HorizontalRecoil

        } catch {

            v := this.RecoilForce

            h := this.HorizontalRecoil

        }

        v := IsNumber(v) ? Integer(v) : 0

        h := IsNumber(h) ? Integer(h) : 0

        if (ObjHasOwnProp(this, "TrajectorySlopeCtrl") && this.TrajectorySlopeCtrl)

            this.TrajectorySlopeCtrl.Text := "垂直: " v "  横向: " h

        if (this.TrajectoryDrawHwnd)

            DllCall("InvalidateRect", "Ptr", this.TrajectoryDrawHwnd, "Ptr", 0, "Int", 1)

    }



    TrajectoryPaintWndProc(hwnd, uMsg, wParam, lParam) {

        if (uMsg != 0x0F)

            return DllCall("CallWindowProc", "Ptr", this._TrajOldWndProc, "Ptr", hwnd, "UInt", uMsg, "Ptr", wParam, "Ptr", lParam)



        local v := this.RecoilForce

        local h := this.HorizontalRecoil

        try {

            if (this.RecoilForceCtrl)

                v := this.RecoilForceCtrl.Value

            if (this.HorizontalRecoilCtrl)

                h := this.HorizontalRecoilCtrl.Value

        } catch {

        }

        v := IsNumber(v) ? Integer(v) : (IsInteger(this.RecoilForce) ? this.RecoilForce : 0)

        h := IsNumber(h) ? Integer(h) : (IsInteger(this.HorizontalRecoil) ? this.HorizontalRecoil : 0)



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

        y1 := this.TRAJ_START_Y

        W := r

        HBox := b

        len := Sqrt(h*h + v*v)

        scale := (len > 0) ? Min(this.TRAJ_SCALE_MAX, (HBox - this.TRAJ_START_Y * 2) / len) : 0

        x2 := Round(x1 - h * scale)

        y2 := Round(this.TRAJ_START_Y + v * scale)

        x2 := Max(this.TRAJ_MARGIN, Min(W - this.TRAJ_MARGIN, x2))

        y2 := Max(y1 + 2, Min(HBox - this.TRAJ_MARGIN, y2))



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

        helpContent := this.GetHelpText()

        HelpText := HelpGui.Add("Edit", "xm ym w600 h500 ReadOnly Multi VScroll", helpContent)

        HelpGui.Add("Button", "xm y+10 w100 Center", "关闭").OnEvent("Click", (*) => HelpGui.Destroy())

        HelpGui.OnEvent("Size", (GuiObj, MinMax, W, H) => this.SizeHelpEdit(GuiObj, MinMax, W, H, HelpText))

        HelpGui.Show "w620 h560"

    }



    SizeHelpEdit(GuiObj, MinMax, W, H, HelpText) {

        try

            HelpText.Move(,, W - 20, H - 50)

    }



    GetHelpText() {

        return "

    (

═══════════════════════════════════════════════════════════

        Legendary压枪助手 v2.4.9 - 操作指南

═══════════════════════════════════════════════════════════



【一、基本使用方法】

1. 确保「启用辅助」已勾选

2. 侧键+左键触发压枪

3. PgDn 快速启用/禁用

4. 「应用设置」使设置生效



【二、31切枪】

- 快捷键：滚轮下划 (WheelDown)

- 效果：等待(可调) → 3 → 10ms → 1

- 可勾选启用/关闭，可调「滚轮下划到执行31」的间隔(ms) 10-2000

- 默认 60ms，可按手感微调



【三、图像识别自动触发】(v2.4.9)

- 生效条件：

  1) 总开关启用（PgDn）

  2) 主界面勾选「图像识别自动触发」

  3) F2：图像识别独立开关为【开】

- 启用后，脚本会在指定区域执行像素颜色搜索（PixelSearch）

- 找到目标颜色时自动触发指定按键（默认 X 键）

- 可设置搜索区域、容差、搜索间隔、目标颜色等参数

- 防误触：可设置「连续命中 N 次才触发」(N=1 表示每次命中都触发)

- 触发方式：可选 点击(tap) / 按下(down) / 抬起(up) / 智能(auto)

  - 智能(auto)：如果检测到目标键当前处于按下状态，则发送 up，否则发送 tap

- 建议搜索区域不要过大，以提高性能

- 可使用「右键拖拽框选区域」快速框选（整屏坐标）



【四、取色功能】(v2.4.9)

- 在「图像识别配置」中点击「取色」进入取色模式

- 右键单击屏幕任意点：自动读取该像素颜色并复制到剪贴板

- Esc：取消取色



【五、其他参数】

射速、垂直/横向压枪、屏息、半自动等同 v2.3.9



═══════════════════════════════════════════════════════════

    )"

    }



    InitializeConfig() {

        if !FileExist(this.configFile)

            this.CreateDefaultConfig()

        try {

            this.LoadSettings()

        } catch as err {

            MsgBox "配置文件读取失败，将使用默认设置。`n错误信息：" err.Message, "警告", "Icon!"

            this.CreateDefaultConfig()

            this.LoadSettings()

        }

        this.assistantEnabled := true

    }



    SanitizeConfigName(name) {

        local s := StrReplace(name, "]", "_")

        s := StrReplace(s, "\\", "_")

        s := StrReplace(s, "`n", "_")

        s := StrReplace(s, "`r", "_")

        s := StrReplace(s, "`t", "_")

        return Trim(s)

    }



    GetCurrentValues() {

        try if (this.FireRateCtrl)

            this.FireRate := this.FireRateCtrl.Value

        try if (this.RecoilForceCtrl)

            this.RecoilForce := this.RecoilForceCtrl.Value

        try if (this.HorizontalRecoilCtrl)

            this.HorizontalRecoil := this.HorizontalRecoilCtrl.Value

        try if (this.HorizontalPatternCtrl)

            this.HorizontalPattern := this.HorizontalPatternCtrl.Value - 1



        try if (this.BreathHoldCtrl)

            this.breathHold := this.BreathHoldCtrl.Value

        try if (this.BreathHoldKeyCtrl) {

            local key := Trim(this.BreathHoldKeyCtrl.Value)

            this.breathHoldKey := (key = "") ? "L" : key

        }

        try if (this.SemiAutoModeCtrl)

            this.semiAutoMode := this.SemiAutoModeCtrl.Value

        try if (this.ED_Ctrl)

            this.ED := this.ED_Ctrl.Value

        try if (this.Cut31Ctrl)

            this.Cut31Enabled := this.Cut31Ctrl.Value ? 1 : 0

        try if (this.Cut31IntervalCtrl) {

            local ival := Trim(this.Cut31IntervalCtrl.Value)

            this.Cut31Interval := (ival != "" && IsNumber(ival)) ? Integer(ival) : 60

        }



        ; 图像识别相关

        try if (this.ImageRecCtrl)

            this.ImageRecEnabled := this.ImageRecCtrl.Value ? 1 : 0

        try if (this.SearchX1Ctrl)

            this.SearchX1 := this.ClampInt(this.SearchX1Ctrl.Value, 0, A_ScreenWidth, 0)

        try if (this.SearchY1Ctrl)

            this.SearchY1 := this.ClampInt(this.SearchY1Ctrl.Value, 0, A_ScreenHeight, 0)

        try if (this.SearchX2Ctrl)

            this.SearchX2 := this.ClampInt(this.SearchX2Ctrl.Value, 0, A_ScreenWidth, 200)

        try if (this.SearchY2Ctrl)

            this.SearchY2 := this.ClampInt(this.SearchY2Ctrl.Value, 0, A_ScreenHeight, 200)

        try if (this.ImageToleranceCtrl)

            this.ImageTolerance := this.ClampInt(this.ImageToleranceCtrl.Value, 0, 255, 30)

        try if (this.ImageSearchIntervalCtrl)

            this.ImageSearchInterval := this.ClampInt(this.ImageSearchIntervalCtrl.Value, 20, 200, 50)

        try if (this.ImageSendKeyCtrl) {

            this.TriggerKey := Trim(this.ImageSendKeyCtrl.Value)

            if (this.TriggerKey = "")

                this.TriggerKey := "x"

        }



        try if (this.ImageTriggerModeCtrl)

            this.ImageTriggerMode := this.ImageTriggerModeCtrl.Value - 1



        try if (this.ImageHitStreakCtrl)

            this.ImageHitStreakRequired := this.ClampInt(this.ImageHitStreakCtrl.Value, 1, 20, 3)



        try if (this.SideTriggerCtrl) {

            local label := this.SideTriggerCtrl.Text

            if InStr(label, "XButton2")

                this.TriggerSideKey := "XButton2"

            else if InStr(label, "XButton1")

                this.TriggerSideKey := "XButton1"

            else

                this.TriggerSideKey := "RButton"

        }

    }



    UpdateGUIDisplay() {

        try if (this.HotkeyCtrl)

            this.HotkeyCtrl.Value := this.HotkeyCC

        try if (this.FireRateCtrl)

            this.FireRateCtrl.Value := this.FireRate

        try if (this.RecoilForceCtrl)

            this.RecoilForceCtrl.Value := this.RecoilForce

        try if (this.HorizontalRecoilCtrl)

            this.HorizontalRecoilCtrl.Value := this.HorizontalRecoil

        try if (this.HorizontalPatternCtrl)

            this.HorizontalPatternCtrl.Choose(this.HorizontalPattern + 1)

        try if (this.BreathHoldCtrl)

            this.BreathHoldCtrl.Value := this.breathHold

        try if (this.BreathHoldKeyCtrl)

            this.BreathHoldKeyCtrl.Value := this.breathHoldKey

        try if (this.SemiAutoModeCtrl)

            this.SemiAutoModeCtrl.Value := this.semiAutoMode

        try if (this.ED_Ctrl)

            this.ED_Ctrl.Value := this.ED

        try if (this.Cut31Ctrl)

            this.Cut31Ctrl.Value := this.Cut31Enabled ? 1 : 0

        try if (this.Cut31IntervalCtrl)

            this.Cut31IntervalCtrl.Value := this.Cut31Interval



        ; 图像识别相关

        try if (this.ImageRecCtrl)

            this.ImageRecCtrl.Value := this.ImageRecEnabled ? 1 : 0

        try if (this.SearchX1Ctrl)

            this.SearchX1Ctrl.Value := this.SearchX1

        try if (this.SearchY1Ctrl)

            this.SearchY1Ctrl.Value := this.SearchY1

        try if (this.SearchX2Ctrl)

            this.SearchX2Ctrl.Value := this.SearchX2

        try if (this.SearchY2Ctrl)

            this.SearchY2Ctrl.Value := this.SearchY2

        try if (this.ImageToleranceCtrl)

            this.ImageToleranceCtrl.Value := this.ImageTolerance

        try if (this.ImageSearchIntervalCtrl)

            this.ImageSearchIntervalCtrl.Value := this.ImageSearchInterval

        try if (this.ImageSendKeyCtrl)

            this.ImageSendKeyCtrl.Value := this.TriggerKey

        try if (this.ImageUseTransCtrl)

            this.ImageUseTransCtrl.Value := this.ImageUseTrans ? 1 : 0

        try if (this.ImageTransColorCtrl)

            this.ImageTransColorCtrl.Value := this.ImageTransColor



        try if (this.ImageTriggerModeCtrl)

            this.ImageTriggerModeCtrl.Choose(this.ImageTriggerMode + 1)



        try if (this.ImageHitStreakCtrl)

            this.ImageHitStreakCtrl.Value := this.ImageHitStreakRequired



        try if (this.SideTriggerCtrl)

            this.SideTriggerCtrl.Choose(this.TriggerSideKey = "XButton1" ? 2 : (this.TriggerSideKey = "RButton" ? 3 : 1))

    }



    UpdateStatusDisplay() {

        local master := this.assistantEnabled ? "总开" : "总关"

        local mode := this.semiAutoMode ? "半自动" : "全自动"

        local hMode := (this.HorizontalPattern = 1) ? "左右交替" : "固定补偿"

        local cut31 := this.Cut31Enabled ? " 31✓" : ""

        local imgRec := (this.ImageRecEnabled && this.ImageRecF2Enabled) ? " 图像✓" : (this.ImageRecEnabled ? " 图像(关)" : "")

        this.StatusTextCtrl.Text := "状态：" master " (" mode "，横向：" hMode cut31 imgRec ")"

    }



    ClampInt(value, min, max, def) {

        try {

            if value = ""

                return def

            local v := Integer(value)

            if v < min

                return min

            if v > max

                return max

            return v

        } catch {

            return def

        }

    }



    MouseXY(x, y) {

        DllCall("mouse_event", "UInt", 0x01, "Int", x, "Int", y, "UInt", 0, "Ptr", 0)

    }



    CreateDefaultConfig() {

        try {

            IniWrite "PgDn", this.configFile, "Settings", "Hotkey"

            IniWrite "600", this.configFile, "Settings", "FireRate"

            IniWrite "5", this.configFile, "Settings", "RecoilForce"

            IniWrite "0", this.configFile, "Settings", "HorizontalRecoil"

            IniWrite "0", this.configFile, "Settings", "HorizontalPattern"

            IniWrite "XButton2", this.configFile, "Settings", "TriggerKey"

            IniWrite "0", this.configFile, "Settings", "BreathHold"

            IniWrite "L", this.configFile, "Settings", "BreathHoldKey"

            IniWrite "0", this.configFile, "Settings", "SemiAutoMode"

            IniWrite "1", this.configFile, "Settings", "ED"

            IniWrite "1", this.configFile, "Settings", "Cut31Enabled"

            IniWrite "60", this.configFile, "Settings", "Cut31Interval"

            ; 图像识别默认配置

            IniWrite "0", this.configFile, "Settings", "ImageRecEnabled"

            IniWrite "0", this.configFile, "Settings", "SearchX1"

            IniWrite "0", this.configFile, "Settings", "SearchY1"

            IniWrite "200", this.configFile, "Settings", "SearchX2"

            IniWrite "200", this.configFile, "Settings", "SearchY2"

            IniWrite "30", this.configFile, "Settings", "ImageTolerance"

            IniWrite "50", this.configFile, "Settings", "ImageSearchInterval"

            IniWrite "x", this.configFile, "Settings", "ImageSendKey"

            IniWrite "0", this.configFile, "Settings", "ImageUseTrans"

            IniWrite "", this.configFile, "Settings", "ImageTransColor"

            IniWrite "0", this.configFile, "Settings", "ImageDebug"

            IniWrite "1", this.configFile, "Settings", "ImageRecF2Enabled"

            IniWrite "3", this.configFile, "Settings", "ImageHitStreakRequired"

            IniWrite "0", this.configFile, "Settings", "ImageTriggerMode"

        } catch {

            MsgBox "创建默认配置文件失败！", "错误", "Iconx"

        }

    }



    LoadSettings() {

        try {

            this.HotkeyCC := IniRead(this.configFile, "Settings", "Hotkey", "PgDn")

            this.FireRate := Integer(IniRead(this.configFile, "Settings", "FireRate", 600))

            this.RecoilForce := Integer(IniRead(this.configFile, "Settings", "RecoilForce", 5))

            this.HorizontalRecoil := Integer(IniRead(this.configFile, "Settings", "HorizontalRecoil", 0))

            this.HorizontalPattern := Integer(IniRead(this.configFile, "Settings", "HorizontalPattern", 0))

            this.TriggerSideKey := IniRead(this.configFile, "Settings", "TriggerKey", "XButton2")

            if (this.TriggerSideKey != "XButton1" && this.TriggerSideKey != "XButton2" && this.TriggerSideKey != "RButton")

                this.TriggerSideKey := "XButton2"

            this.breathHold := Integer(IniRead(this.configFile, "Settings", "BreathHold", 0))

            this.breathHoldKey := IniRead(this.configFile, "Settings", "BreathHoldKey", "L")

            if (Trim(this.breathHoldKey) = "")

                this.breathHoldKey := "L"

            this.semiAutoMode := Integer(IniRead(this.configFile, "Settings", "SemiAutoMode", 0))

            this.ED := Integer(IniRead(this.configFile, "Settings", "ED", 1))

            this.Cut31Enabled := Integer(IniRead(this.configFile, "Settings", "Cut31Enabled", 1)) != 0

            this.Cut31Interval := Integer(IniRead(this.configFile, "Settings", "Cut31Interval", 60))

            

            ; 图像识别配置

            this.ImageRecEnabled := Integer(IniRead(this.configFile, "Settings", "ImageRecEnabled", 0)) != 0

            this.SearchX1 := Integer(IniRead(this.configFile, "Settings", "SearchX1", 0))

            this.SearchY1 := Integer(IniRead(this.configFile, "Settings", "SearchY1", 0))

            this.SearchX2 := Integer(IniRead(this.configFile, "Settings", "SearchX2", 200))

            this.SearchY2 := Integer(IniRead(this.configFile, "Settings", "SearchY2", 200))

            this.ImageTolerance := Integer(IniRead(this.configFile, "Settings", "ImageTolerance", 30))

            this.ImageSearchInterval := Integer(IniRead(this.configFile, "Settings", "ImageSearchInterval", 50))

            this.TriggerKey := IniRead(this.configFile, "Settings", "ImageSendKey", "x")

            this.ImageUseTrans := Integer(IniRead(this.configFile, "Settings", "ImageUseTrans", 0)) != 0

            this.ImageTransColor := IniRead(this.configFile, "Settings", "ImageTransColor", "")

            this.ImageDebug := Integer(IniRead(this.configFile, "Settings", "ImageDebug", 0)) != 0

            this.ImageRecF2Enabled := Integer(IniRead(this.configFile, "Settings", "ImageRecF2Enabled", 1)) != 0

            this.ImageHitStreakRequired := Integer(IniRead(this.configFile, "Settings", "ImageHitStreakRequired", 3))

            this.ImageTriggerMode := Integer(IniRead(this.configFile, "Settings", "ImageTriggerMode", 0))

            if (this.TriggerKey = "")

                this.TriggerKey := "x"



            this.FireRate := this.ClampInt(this.FireRate, 100, 2000, 600)

            this.RecoilForce := this.ClampInt(this.RecoilForce, 0, 30, 5)

            this.HorizontalRecoil := this.ClampInt(this.HorizontalRecoil, -15, 15, 0)

            this.HorizontalPattern := this.ClampInt(this.HorizontalPattern, 0, 1, 0)

            this.Cut31Interval := this.ClampInt(this.Cut31Interval, 10, 2000, 60)

            this.ImageTolerance := this.ClampInt(this.ImageTolerance, 0, 255, 30)

            this.ImageSearchInterval := this.ClampInt(this.ImageSearchInterval, 20, 200, 50)

            this.ImageHitStreakRequired := this.ClampInt(this.ImageHitStreakRequired, 1, 20, 3)

            this.ImageTriggerMode := this.ClampInt(this.ImageTriggerMode, 0, 3, 0)

        } catch as err {

            throw Error("配置文件读取失败: " err.Message)

        }

    }



    SaveSettings() {

        try {

            IniWrite this.HotkeyCC, this.configFile, "Settings", "Hotkey"

            IniWrite this.FireRate, this.configFile, "Settings", "FireRate"

            IniWrite this.RecoilForce, this.configFile, "Settings", "RecoilForce"

            IniWrite this.HorizontalRecoil, this.configFile, "Settings", "HorizontalRecoil"

            IniWrite this.HorizontalPattern, this.configFile, "Settings", "HorizontalPattern"

            IniWrite this.TriggerSideKey, this.configFile, "Settings", "TriggerKey"

            IniWrite this.breathHold, this.configFile, "Settings", "BreathHold"

            IniWrite (Trim(this.breathHoldKey) = "" ? "L" : this.breathHoldKey), this.configFile, "Settings", "BreathHoldKey"

            IniWrite this.semiAutoMode, this.configFile, "Settings", "SemiAutoMode"

            IniWrite this.ED, this.configFile, "Settings", "ED"

            IniWrite (this.Cut31Enabled ? "1" : "0"), this.configFile, "Settings", "Cut31Enabled"

            IniWrite this.Cut31Interval, this.configFile, "Settings", "Cut31Interval"

            

            ; 保存图像识别配置

            IniWrite (this.ImageRecEnabled ? "1" : "0"), this.configFile, "Settings", "ImageRecEnabled"

            IniWrite this.SearchX1, this.configFile, "Settings", "SearchX1"

            IniWrite this.SearchY1, this.configFile, "Settings", "SearchY1"

            IniWrite this.SearchX2, this.configFile, "Settings", "SearchX2"

            IniWrite this.SearchY2, this.configFile, "Settings", "SearchY2"

            IniWrite this.ImageTolerance, this.configFile, "Settings", "ImageTolerance"

            IniWrite this.ImageSearchInterval, this.configFile, "Settings", "ImageSearchInterval"

            IniWrite this.TriggerKey, this.configFile, "Settings", "ImageSendKey"

            IniWrite (this.ImageUseTrans ? "1" : "0"), this.configFile, "Settings", "ImageUseTrans"

            IniWrite this.ImageTransColor, this.configFile, "Settings", "ImageTransColor"

            IniWrite (this.ImageDebug ? "1" : "0"), this.configFile, "Settings", "ImageDebug"

            IniWrite (this.ImageRecF2Enabled ? "1" : "0"), this.configFile, "Settings", "ImageRecF2Enabled"

            IniWrite this.ImageHitStreakRequired, this.configFile, "Settings", "ImageHitStreakRequired"

            IniWrite this.ImageTriggerMode, this.configFile, "Settings", "ImageTriggerMode"

        } catch {

            MsgBox "保存设置失败！", "错误", "Iconx"

        }

    }



    ApplySettings(*) {

        local oldHotkey := this.HotkeyCC

        this.GetCurrentValues()

        if (this.HotkeyCC = this.TriggerSideKey) {

            if MsgBox("启用热键与触发键不宜相同，可能导致误触。是否仍要应用？", "提示", "YesNo Icon?") = "No"

                return

        }

        local newHotkey := this.HotkeyCtrl.Value

        if (newHotkey != "" && newHotkey != this.HotkeyCC) {

            try {

                Hotkey this.HotkeyCC, this._cbHotkeyToggle, "Off"

                Hotkey newHotkey, this._cbHotkeyToggle, "On"

                this.HotkeyCC := newHotkey

            } catch {

                this.HotkeyCC := oldHotkey

                this.HotkeyCtrl.Value := oldHotkey

                try Hotkey oldHotkey, this._cbHotkeyToggle, "On"

                catch {

                }

                MsgBox "热键设置失败！已恢复原热键。", "错误", "Iconx"

                return

            }

        }



        this.FireRate := this.ClampInt(this.FireRate, 100, 2000, 600)

        this.RecoilForce := this.ClampInt(this.RecoilForce, 0, 30, 5)

        this.HorizontalRecoil := this.ClampInt(this.HorizontalRecoil, -15, 15, 0)

        this.HorizontalPattern := this.ClampInt(this.HorizontalPattern, 0, 1, 0)

        this.Cut31Interval := this.ClampInt(this.Cut31Interval, 10, 2000, 60)

        this.ImageTolerance := this.ClampInt(this.ImageTolerance, 0, 255, 30)

        this.ImageSearchInterval := this.ClampInt(this.ImageSearchInterval, 20, 200, 50)



        this.SaveSettings()

        this.UpdateGUIDisplay()

        this.UpdateStatusDisplay()

        this.UpdateTrajectoryPreview()

        this.SyncComboHotkey()

        this.SyncSideHotkey()

        this.SyncCut31Hotkey()

        this.SyncImageRecHotkey()

        this.HideAllConfigGuis()

        ToolTip "设置已应用！"

        SetTimer () => ToolTip(), -1800

    }



    HideAllConfigGuis() {

        local props := ["RecoilConfigGui", "BreathConfigGui", "SemiAutoConfigGui", "Cut31ConfigGui", "ImageRecConfigGui", "ConfigManagerGui"]

        for p in props {

            if ObjHasOwnProp(this, p) {

                try {

                    local g := this.%p%

                    if IsSet(g) && g

                        g.Hide()

                } catch {

                }

            }

        }

    }



    RestoreDefaults(*) {

        this.CreateDefaultConfig()

        this.LoadSettings()

        this.UpdateGUIDisplay()

        this.UpdateStatusDisplay()

        this.UpdateTrajectoryPreview()

        this.SyncComboHotkey()

        this.SyncSideHotkey()

        this.SyncCut31Hotkey()

        this.SyncImageRecHotkey()

        MsgBox "默认设置已恢复！", "提示", "Iconi"

    }



    SaveCurrentConfig(*) {

        this.GetCurrentValues()

        local rawName := Trim(this.ConfigNameCtrl.Value)

        local configName := this.SanitizeConfigName(rawName)

        if configName = "" {

            MsgBox "请输入配置名称！", "提示", "Icon!"

            return

        }

        if (rawName != configName)

            this.ConfigNameCtrl.Value := configName

        local section := "Config_" configName

        local existingFireRate := IniRead(this.configFile, section, "FireRate", "")

        if existingFireRate != "" {

            if MsgBox("配置 [" configName "] 已存在，是否覆盖？", "确认覆盖", "YesNo Icon?") != "Yes"

                return

        }

        try {

            IniWrite this.FireRate, this.configFile, section, "FireRate"

            IniWrite this.RecoilForce, this.configFile, section, "RecoilForce"

            IniWrite this.HorizontalRecoil, this.configFile, section, "HorizontalRecoil"

            IniWrite this.HorizontalPattern, this.configFile, section, "HorizontalPattern"

            IniWrite this.HotkeyCC, this.configFile, section, "Hotkey"

            IniWrite this.TriggerSideKey, this.configFile, section, "TriggerKey"

            IniWrite this.breathHold, this.configFile, section, "BreathHold"

            IniWrite (Trim(this.breathHoldKey) = "" ? "L" : this.breathHoldKey), this.configFile, section, "BreathHoldKey"

            IniWrite this.semiAutoMode, this.configFile, section, "SemiAutoMode"

            IniWrite this.ED, this.configFile, section, "ED"

            IniWrite (this.Cut31Enabled ? "1" : "0"), this.configFile, section, "Cut31Enabled"

            IniWrite this.Cut31Interval, this.configFile, section, "Cut31Interval"

            

            ; 保存图像识别配置

            IniWrite (this.ImageRecEnabled ? "1" : "0"), this.configFile, section, "ImageRecEnabled"

            IniWrite this.SearchX1, this.configFile, section, "SearchX1"

            IniWrite this.SearchY1, this.configFile, section, "SearchY1"

            IniWrite this.SearchX2, this.configFile, section, "SearchX2"

            IniWrite this.SearchY2, this.configFile, section, "SearchY2"

            IniWrite this.ImageTolerance, this.configFile, section, "ImageTolerance"

            IniWrite this.ImageSearchInterval, this.configFile, section, "ImageSearchInterval"

            IniWrite this.TriggerKey, this.configFile, section, "ImageSendKey"

            IniWrite (this.ImageUseTrans ? "1" : "0"), this.configFile, section, "ImageUseTrans"

            IniWrite this.ImageTransColor, this.configFile, section, "ImageTransColor"

            IniWrite (this.ImageDebug ? "1" : "0"), this.configFile, section, "ImageDebug"

            IniWrite (this.ImageRecF2Enabled ? "1" : "0"), this.configFile, section, "ImageRecF2Enabled"

            IniWrite this.ImageHitStreakRequired, this.configFile, section, "ImageHitStreakRequired"

            IniWrite this.ImageTriggerMode, this.configFile, section, "ImageTriggerMode"

            

            this.RefreshConfigList()

            MsgBox "配置 [" configName "] 已保存！", "提示", "Iconi"

        } catch {

            MsgBox "保存配置失败！", "错误", "Iconx"

        }

    }



    LoadSelectedConfig(*) {

        local oldHotkey := this.HotkeyCC

        local configName := this.ConfigListCtrl.Text

        if configName = ""

            return

        local section := "Config_" configName

        try {

            local tempFireRate := IniRead(this.configFile, section, "FireRate", "")

            if tempFireRate = "" {

                MsgBox "未找到配置 [" configName "]！", "错误", "Iconx"

                return

            }

            this.FireRate := Integer(IniRead(this.configFile, section, "FireRate", this.FireRate))

            this.RecoilForce := Integer(IniRead(this.configFile, section, "RecoilForce", this.RecoilForce))

            this.HorizontalRecoil := Integer(IniRead(this.configFile, section, "HorizontalRecoil", this.HorizontalRecoil))

            this.HorizontalPattern := Integer(IniRead(this.configFile, section, "HorizontalPattern", this.HorizontalPattern))

            local tempHotkey := IniRead(this.configFile, section, "Hotkey", this.HotkeyCC)

            local tempTriggerKey := IniRead(this.configFile, section, "TriggerKey", this.TriggerSideKey)

            this.breathHold := Integer(IniRead(this.configFile, section, "BreathHold", this.breathHold))

            this.breathHoldKey := IniRead(this.configFile, section, "BreathHoldKey", this.breathHoldKey)

            if (Trim(this.breathHoldKey) = "")

                this.breathHoldKey := "L"

            this.semiAutoMode := Integer(IniRead(this.configFile, section, "SemiAutoMode", this.semiAutoMode))

            this.ED := Integer(IniRead(this.configFile, section, "ED", this.ED))

            this.Cut31Enabled := Integer(IniRead(this.configFile, section, "Cut31Enabled", 1)) != 0

            this.Cut31Interval := Integer(IniRead(this.configFile, section, "Cut31Interval", 60))

            this.TriggerSideKey := tempTriggerKey

            if (this.TriggerSideKey != "XButton1" && this.TriggerSideKey != "XButton2" && this.TriggerSideKey != "RButton")

                this.TriggerSideKey := "XButton2"



            ; 加载图像识别配置

            this.ImageRecEnabled := Integer(IniRead(this.configFile, section, "ImageRecEnabled", 0)) != 0

            this.SearchX1 := Integer(IniRead(this.configFile, section, "SearchX1", 0))

            this.SearchY1 := Integer(IniRead(this.configFile, section, "SearchY1", 0))

            this.SearchX2 := Integer(IniRead(this.configFile, section, "SearchX2", 200))

            this.SearchY2 := Integer(IniRead(this.configFile, section, "SearchY2", 200))

            this.ImageTolerance := Integer(IniRead(this.configFile, section, "ImageTolerance", 30))

            this.ImageSearchInterval := Integer(IniRead(this.configFile, section, "ImageSearchInterval", 50))

            this.TriggerKey := IniRead(this.configFile, section, "ImageSendKey", "x")

            this.ImageUseTrans := Integer(IniRead(this.configFile, section, "ImageUseTrans", 0)) != 0

            this.ImageTransColor := IniRead(this.configFile, section, "ImageTransColor", "")

            this.ImageDebug := Integer(IniRead(this.configFile, section, "ImageDebug", 0)) != 0

            this.ImageRecF2Enabled := Integer(IniRead(this.configFile, section, "ImageRecF2Enabled", 1)) != 0

            this.ImageHitStreakRequired := Integer(IniRead(this.configFile, section, "ImageHitStreakRequired", 3))

            this.ImageTriggerMode := Integer(IniRead(this.configFile, section, "ImageTriggerMode", 0))

            if (this.TriggerKey = "")

                this.TriggerKey := "x"



            this.FireRate := this.ClampInt(this.FireRate, 100, 2000, 600)

            this.RecoilForce := this.ClampInt(this.RecoilForce, 0, 30, 5)

            this.HorizontalRecoil := this.ClampInt(this.HorizontalRecoil, -15, 15, 0)

            this.HorizontalPattern := this.ClampInt(this.HorizontalPattern, 0, 1, 0)

            this.Cut31Interval := this.ClampInt(this.Cut31Interval, 10, 2000, 60)

            this.ImageTolerance := this.ClampInt(this.ImageTolerance, 0, 255, 30)

            this.ImageSearchInterval := this.ClampInt(this.ImageSearchInterval, 20, 200, 50)

            this.ImageHitStreakRequired := this.ClampInt(this.ImageHitStreakRequired, 1, 20, 3)

            this.ImageTriggerMode := this.ClampInt(this.ImageTriggerMode, 0, 3, 0)



            this.UpdateGUIDisplay()

            this.UpdateTrajectoryPreview()

            this.ConfigNameCtrl.Value := configName

            this.SyncCut31Hotkey()

            this.SyncImageRecHotkey()

            if tempHotkey != this.HotkeyCC {

                try {

                    Hotkey this.HotkeyCC, this._cbHotkeyToggle, "Off"

                    Hotkey tempHotkey, this._cbHotkeyToggle, "On"

                    this.HotkeyCC := tempHotkey

                } catch {

                    this.HotkeyCC := oldHotkey

                    try Hotkey oldHotkey, this._cbHotkeyToggle, "On"

                    catch {

                    }

                    MsgBox "配置已加载，但热键设置失败。已恢复原热键。", "警告", "Icon!"

                }

            }

            this.UpdateStatusDisplay()

            this.SyncComboHotkey()

            this.SyncSideHotkey()

            ToolTip "配置 [" configName "] 已加载！"

            SetTimer () => ToolTip(), -1500

        } catch as err {

            MsgBox "加载配置失败！`n错误信息：" err.Message, "错误", "Iconx"

        }

    }



    DeleteSelectedConfig(*) {

        local configToDelete

        local configName := Trim(this.ConfigNameCtrl.Value)

        local configList := this.ConfigListCtrl.Text

        if configName != ""

            configToDelete := this.SanitizeConfigName(configName)

        else if configList != ""

            configToDelete := configList

        else {

            MsgBox "请选择要删除的配置！", "提示", "Icon!"

            return

        }

        if MsgBox("是否确定删除配置 [" configToDelete "]？", "确认删除", "YesNo Icon?") = "Yes" {

            try {

                IniDelete this.configFile, "Config_" configToDelete

                this.ConfigNameCtrl.Value := ""

                this.RefreshConfigList()

                MsgBox "配置 [" configToDelete "] 已删除！", "提示", "Iconi"

            } catch {

                MsgBox "删除配置失败！", "错误", "Iconx"

            }

        }

    }



    RefreshConfigList(*) {

        try {

            local sections := IniRead(this.configFile)

            local configs := []

            if sections != "" {

                for line in StrSplit(sections, "`n") {

                    line := Trim(line)

                    if (line != "" && InStr(line, "Config_") = 1)

                        configs.Push(SubStr(line, 8))

                }

            }

            this.ConfigListCtrl.Delete()

            if configs.Length > 0 {

                for name in configs

                    this.ConfigListCtrl.Add([name])

            }

        } catch {

            MsgBox "刷新配置列表失败！", "错误", "Iconx"

        }

    }



    GuiClose(*) {

        this.Cleanup()

        ExitApp

    }



    Cleanup(*) {

        if this._cleaned

            return

        this._cleaned := true



        ; 停止图像搜索定时器

        SetTimer this._cbImageSearchTimer, 0



        if (this.TrajectoryDrawHwnd && this._TrajOldWndProc) {

            try

                DllCall("SetWindowLongPtr", "Ptr", this.TrajectoryDrawHwnd, "Int", -4, "Ptr", this._TrajOldWndProc, "Ptr")

            catch {

            }

        }

        if this._TrajWndProcCallback {

            try

                CallbackFree(this._TrajWndProcCallback)

            catch {

            }

        }

    }



    GuiEscape(*) {

        this.MyGui.Hide()

    }

}



EnsureAdmin() {

    if A_IsAdmin

        return

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



app := LegendaryApp()

app.Run()

