#Requires AutoHotkey v2.0+
#SingleInstance Force
/*
  -------------------------
    Legendary压枪助手v2.3
  -------------------------
  */     
Persistent
SetWorkingDir A_ScriptDir
ProcessSetPriority "High"
SendMode "Input"

; 全局变量
global configFile := A_ScriptDir "\AutoFire.ini"
global lastFireTime := 0
global isFiring := false
global autoFireActive := false
global assistantEnabled := false

; 配置变量
global HotkeyCC := "PgDn"
global FireRate := 600
global RecoilForce := 5
global HorizontalRecoil := 0
global HorizontalPattern := 0
global breathHold := 0
global semiAutoMode := 0
global ED := 1

; GUI引用
global MyGui
global FireRateCtrl, RecoilForceCtrl, HorizontalRecoilCtrl, HorizontalPatternCtrl
global BreathHoldCtrl, SemiAutoModeCtrl, ED_Ctrl, ConfigNameCtrl, ConfigListCtrl, StatusTextCtrl

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

; 托盘菜单
A_TrayMenu.Add "显示主界面", ShowMainWindow
A_TrayMenu.Add "退出程序", GuiClose
A_TrayMenu.Default := "显示主界面"
A_IconTip := "Legendary压枪助手v2.3"

; 热键初始化
Hotkey HotkeyCC, HotkeyToggle, "On"

; -------------------------------
;          热键部分
; -------------------------------

HotkeyToggle(*) {
    global assistantEnabled, ED
    assistantEnabled := !assistantEnabled
    ED := assistantEnabled
    ED_Ctrl.Value := ED
    UpdateStatusDisplay()
    
    ToolTip assistantEnabled ? "辅助功能已启用" : "辅助功能已禁用"
    SetTimer () => ToolTip(), -2000
}

; 屏息功能
~XButton2:: {
    global ED, assistantEnabled, breathHold
    if !ED || !assistantEnabled
        return
    
    if breathHold {
        Send "{Blind}{L down}"
        KeyWait "XButton2"
        Send "{Blind}{L up}"
    } else {
        KeyWait "XButton2"
    }
}

; 半自动模式全自动开火（单独左键）
~LButton:: {
    global ED, assistantEnabled, semiAutoMode, autoFireActive
    global FireRate, RecoilForce, HorizontalRecoil, HorizontalPattern
    
    if !ED || !assistantEnabled || !semiAutoMode || autoFireActive
        return
    
    autoFireActive := true
    GetCurrentValues()
    local fireInterval := Round(60000 / FireRate)
    local baseRecoil := RecoilForce
    local lastFireTimeLocal := A_TickCount - fireInterval
    
    while GetKeyState("LButton", "P") && ED && assistantEnabled && semiAutoMode {
        if A_TickCount - lastFireTimeLocal >= fireInterval {
            SendInput "{Blind}{LButton down}"
            Sleep (fireInterval < 50) ? 5 : 10
            SendInput "{Blind}{LButton up}"
            
            local randRecoil := Random(-0.5, 0.5)
            local randHoriz := Random(-0.3, 0.3)
            local hComp := HorizontalRecoil + randHoriz
            MouseXY(Round(hComp), Round(baseRecoil * 0.9 + randRecoil))
            
            lastFireTimeLocal := A_TickCount
        }
        Sleep 1
    }
    autoFireActive := false
}

; 双模式核心逻辑（侧键+左键）
~XButton2 & LButton:: {
    global ED, assistantEnabled, isFiring, semiAutoMode
    global FireRate, RecoilForce, HorizontalRecoil, HorizontalPattern
    
    if !ED || !assistantEnabled || isFiring
        return
    
    isFiring := true
    GetCurrentValues()
    
    local fireInterval := Round(60000 / FireRate)
    local baseRecoil := RecoilForce
    local lastFireTimeLocal := A_TickCount - fireInterval
    
    if semiAutoMode {
        ; 半自动模式 - 侧键+左键：全自动开火
        local shotCount := 0
        SendInput "{Blind}{LButton down}"
        
        while GetKeyState("XButton2", "P") && GetKeyState("LButton", "P") && ED && assistantEnabled && semiAutoMode {
            if A_TickCount - lastFireTimeLocal >= fireInterval {
                SendInput "{Blind}{LButton up}"
                Sleep (fireInterval < 50) ? 5 : 10
                SendInput "{Blind}{LButton down}"
                
                local randRecoil := Random(-0.5, 0.5)
                local randHoriz := Random(-0.3, 0.3)
                local hComp := HorizontalRecoil + randHoriz
                MouseXY(Round(hComp), Round(baseRecoil * 0.9 + randRecoil))
                
                lastFireTimeLocal := A_TickCount
                shotCount += 1
            }
            Sleep 1
        }
        SendInput "{Blind}{LButton up}"
    } else {
        ; 全自动模式 - 侧键+左键：持续开火并处理后坐力
        SendInput "{Blind}{LButton down}"
        local shotCount := 0
        
        while GetKeyState("XButton2", "P") && GetKeyState("LButton", "P") && ED && assistantEnabled && !semiAutoMode {
            if A_TickCount - lastFireTimeLocal >= fireInterval {
                local randRecoil := Random(-1, 1)
                local randHoriz := Random(-0.5, 0.5)
                local hComp
                
                if HorizontalPattern = 1 {
                    hComp := HorizontalRecoil + randHoriz
                } else if HorizontalPattern = 2 {
                    if Mod(shotCount, 2) = 0
                        hComp := HorizontalRecoil
                    else
                        hComp := -HorizontalRecoil
                    hComp += randHoriz
                } else {
                    hComp := HorizontalRecoil + randHoriz
                }
                
                MouseXY(Round(hComp), Round(baseRecoil + randRecoil))
                shotCount += 1
                lastFireTimeLocal := A_TickCount
            }
            Sleep 1
        }
        SendInput "{Blind}{LButton up}"
    }
    
    isFiring := false
}

; -------------------------------
;          GUI与事件
; -------------------------------

CreateGUI() {
    global MyGui, FireRateCtrl, RecoilForceCtrl, HorizontalRecoilCtrl, HorizontalPatternCtrl
    global BreathHoldCtrl, SemiAutoModeCtrl, ED_Ctrl, ConfigNameCtrl, ConfigListCtrl, StatusTextCtrl
    global HotkeyCC, FireRate, RecoilForce, HorizontalRecoil, HorizontalPattern
    global breathHold, semiAutoMode, ED
    
    MyGui := Gui("+Resize", "Legendary压枪助手 v2.3")
    MyGui.OnEvent("Close", GuiClose)
    MyGui.OnEvent("Escape", GuiEscape)
    MyGui.SetFont("s10", "Microsoft YaHei")
    
    ; 热键设置
    MyGui.Add "Text", "xm ym+5 w80", "启用/禁用热键："
    local hotkeyCtrl := MyGui.Add("Hotkey", "x+5 yp-3 w200", HotkeyCC)
    hotkeyCtrl.OnEvent("Change", HotkeyChanged)
    
    ; 射速设置
    MyGui.Add "Text", "xm y+15 w80", "射速 (RPM)："
    FireRateCtrl := MyGui.Add("Edit", "x+5 yp-3 w200 Number", FireRate)
    
    ; 垂直压枪力度
    MyGui.Add "Text", "xm y+15 w80", "垂直压枪力度："
    RecoilForceCtrl := MyGui.Add("Edit", "x+5 yp-3 w200 Number", RecoilForce)
    MyGui.Add "Text", "x+10 yp+3 w80 cGray", "(1-30)"
    
    ; 横向补偿力度 - 修复：允许负值输入
    MyGui.Add "Text", "xm y+15 w80", "横向补偿力度："
    ; 使用 Edit 控件而不是 Number，这样允许输入负号
    HorizontalRecoilCtrl := MyGui.Add("Edit", "x+5 yp-3 w200", HorizontalRecoil)
    MyGui.Add "Text", "x+10 yp+3 w80 cRed", "(-15~15，负值=向右)"
    
    ; 横向补偿模式
    MyGui.Add "Text", "xm y+15 w80", "横向模式："
    HorizontalPatternCtrl := MyGui.Add("DropDownList", "x+5 yp-3 w200", ["固定向左补偿", "左右交替", "完全随机"])
    HorizontalPatternCtrl.Choose(HorizontalPattern + 1)
    
    ; 功能选项
    BreathHoldCtrl := MyGui.Add("CheckBox", "xm y+15", "启用屏息")
    BreathHoldCtrl.Value := breathHold
    
    SemiAutoModeCtrl := MyGui.Add("CheckBox", "xm y+10", "半自动模式")
    SemiAutoModeCtrl.Value := semiAutoMode
    
    ED_Ctrl := MyGui.Add("CheckBox", "xm y+15", "启用辅助")
    ED_Ctrl.Value := ED
    ED_Ctrl.OnEvent("Click", CheckboxChanged)
    
    ; 状态显示
    StatusTextCtrl := MyGui.Add("Text", "xm y+15", "状态：未启用")
    
    ; 配置管理
    MyGui.Add "Text", "xm y+20 w80", "已存配置："
    ConfigListCtrl := MyGui.Add("DropDownList", "x+5 yp-3 w150")
    MyGui.Add("Button", "x+5 yp w70", "加载选中").OnEvent("Click", LoadSelectedConfig)
    MyGui.Add("Button", "x+5 yp w60", "刷新").OnEvent("Click", RefreshConfigList)
    
    MyGui.Add "Text", "xm y+15 w80", "配置名称："
    ConfigNameCtrl := MyGui.Add("Edit", "x+5 yp-3 w150")
    MyGui.Add("Button", "x+5 yp w60", "保存").OnEvent("Click", SaveCurrentConfig)
    MyGui.Add("Button", "x+5 yp w60", "删除").OnEvent("Click", DeleteSelectedConfig)
    
    ; 操作按钮
    MyGui.Add("Button", "xm y+20 w100", "应用设置").OnEvent("Click", ApplySettings)
    MyGui.Add("Button", "x+10 yp w100", "恢复默认").OnEvent("Click", RestoreDefaults)
    
    MyGui.Show "w420 h520"
}

ShowMainWindow(*) {
    MyGui.Show()
}

CheckboxChanged(ctrlObj, *) {
    global ED, assistantEnabled
    ED := ctrlObj.Value
    assistantEnabled := ED
    UpdateStatusDisplay()
    
    ToolTip ED ? "辅助功能已启用" : "辅助功能已禁用"
    SetTimer () => ToolTip(), -2000
}

HotkeyChanged(ctrlObj, *) {
    global HotkeyCC
    local newHotkey := ctrlObj.Value
    
    if newHotkey != HotkeyCC {
        try {
            Hotkey HotkeyCC, HotkeyToggle, "Off"
            Hotkey newHotkey, HotkeyToggle, "On"
            HotkeyCC := newHotkey
        } catch as err {
            MsgBox "热键设置失败，请检查热键格式！", "错误", "Iconx"
        }
    }
}

; -------------------------------
;          核心功能函数
; -------------------------------

InitializeConfig() {
    global configFile
    
    if !FileExist(configFile)
        CreateDefaultConfig()
    
    LoadSettings()
    global ED, assistantEnabled
    assistantEnabled := ED
}

GetCurrentValues() {
    global FireRate, RecoilForce, HorizontalRecoil, HorizontalPattern
    global breathHold, semiAutoMode, ED
    global FireRateCtrl, RecoilForceCtrl, HorizontalRecoilCtrl, HorizontalPatternCtrl
    global BreathHoldCtrl, SemiAutoModeCtrl, ED_Ctrl
    
    FireRate := FireRateCtrl.Value
    RecoilForce := RecoilForceCtrl.Value
    HorizontalRecoil := HorizontalRecoilCtrl.Value
    HorizontalPattern := HorizontalPatternCtrl.Value - 1  ; 下拉列表索引从1开始
    breathHold := BreathHoldCtrl.Value
    semiAutoMode := SemiAutoModeCtrl.Value
    ED := ED_Ctrl.Value
}

UpdateGUIDisplay() {
    global FireRate, RecoilForce, HorizontalRecoil, HorizontalPattern
    global breathHold, semiAutoMode, ED
    global FireRateCtrl, RecoilForceCtrl, HorizontalRecoilCtrl, HorizontalPatternCtrl
    global BreathHoldCtrl, SemiAutoModeCtrl, ED_Ctrl
    
    FireRateCtrl.Value := FireRate
    RecoilForceCtrl.Value := RecoilForce
    HorizontalRecoilCtrl.Value := HorizontalRecoil
    HorizontalPatternCtrl.Choose(HorizontalPattern + 1)
    BreathHoldCtrl.Value := breathHold
    SemiAutoModeCtrl.Value := semiAutoMode
    ED_Ctrl.Value := ED
}

UpdateStatusDisplay() {
    global ED, assistantEnabled, semiAutoMode, HorizontalPattern
    global StatusTextCtrl
    
    local status := (ED && assistantEnabled) ? "已启用" : "未启用"
    local mode := semiAutoMode ? "半自动" : "全自动"
    local hMode
    
    if HorizontalPattern = 1
        hMode := "固定补偿"
    else if HorizontalPattern = 2
        hMode := "左右交替"
    else
        hMode := "随机"
    
    StatusTextCtrl.Text := "状态：" status " (" mode "，横向：" hMode ")"
}

Validate(name, min, max, def) {
    global
    local value := %name%
    ; 允许负值输入，所以需要特殊处理
    if value = "" 
        %name% := def
    else if IsNumber(value) {
        if value < min || value > max
            %name% := def
    } else {
        ; 如果不是数字，设置为默认值
        %name% := def
    }
}

MouseXY(x, y) {
    DllCall "mouse_event", "UInt", 0x01, "Int", x, "Int", y, "UInt", 0, "Ptr", 0
}

; -------------------------------
;          配置管理
; -------------------------------

CreateDefaultConfig() {
    global configFile
    
    IniWrite "PgDn", configFile, "Settings", "Hotkey"
    IniWrite "600", configFile, "Settings", "FireRate"
    IniWrite "5", configFile, "Settings", "RecoilForce"
    IniWrite "0", configFile, "Settings", "HorizontalRecoil"
    IniWrite "0", configFile, "Settings", "HorizontalPattern"
    IniWrite "0", configFile, "Settings", "BreathHold"
    IniWrite "0", configFile, "Settings", "SemiAutoMode"
    IniWrite "1", configFile, "Settings", "ED"
}

LoadSettings() {
    global configFile
    global HotkeyCC, FireRate, RecoilForce, HorizontalRecoil, HorizontalPattern
    global breathHold, semiAutoMode, ED
    
    HotkeyCC := IniRead(configFile, "Settings", "Hotkey", "PgDn")
    FireRate := Integer(IniRead(configFile, "Settings", "FireRate", 600))
    RecoilForce := Integer(IniRead(configFile, "Settings", "RecoilForce", 5))
    HorizontalRecoil := Integer(IniRead(configFile, "Settings", "HorizontalRecoil", 0))
    HorizontalPattern := Integer(IniRead(configFile, "Settings", "HorizontalPattern", 0))
    breathHold := Integer(IniRead(configFile, "Settings", "BreathHold", 0))
    semiAutoMode := Integer(IniRead(configFile, "Settings", "SemiAutoMode", 0))
    ED := Integer(IniRead(configFile, "Settings", "ED", 1))
    
    ; 参数校验
    Validate("FireRate", 100, 2000, 600)
    Validate("RecoilForce", 1, 30, 5)
    Validate("HorizontalRecoil", -15, 15, 0)
    Validate("HorizontalPattern", 0, 2, 0)
}

SaveSettings() {
    global configFile
    global HotkeyCC, FireRate, RecoilForce, HorizontalRecoil, HorizontalPattern
    global breathHold, semiAutoMode, ED
    
    IniWrite HotkeyCC, configFile, "Settings", "Hotkey"
    IniWrite FireRate, configFile, "Settings", "FireRate"
    IniWrite RecoilForce, configFile, "Settings", "RecoilForce"
    IniWrite HorizontalRecoil, configFile, "Settings", "HorizontalRecoil"
    IniWrite HorizontalPattern, configFile, "Settings", "HorizontalPattern"
    IniWrite breathHold, configFile, "Settings", "BreathHold"
    IniWrite semiAutoMode, configFile, "Settings", "SemiAutoMode"
    IniWrite ED, configFile, "Settings", "ED"
}

ApplySettings(*) {
    GetCurrentValues()
    
    Validate("FireRate", 100, 2000, 600)
    Validate("RecoilForce", 1, 30, 5)
    Validate("HorizontalRecoil", -15, 15, 0)
    Validate("HorizontalPattern", 0, 2, 0)
    
    SaveSettings()
    UpdateGUIDisplay()
    UpdateStatusDisplay()
    MsgBox "设置已应用！", "提示", "Iconi T2"
}

RestoreDefaults(*) {
    CreateDefaultConfig()
    LoadSettings()
    global ED, assistantEnabled
    assistantEnabled := ED
    UpdateGUIDisplay()
    UpdateStatusDisplay()
    MsgBox "默认设置已恢复！", "提示", "Iconi"
}

SaveCurrentConfig(*) {
    global configFile
    global FireRate, RecoilForce, HorizontalRecoil, HorizontalPattern
    global HotkeyCC, breathHold, semiAutoMode, ED
    global ConfigNameCtrl
    
    GetCurrentValues()
    local configName := ConfigNameCtrl.Value
    
    if configName = "" {
        MsgBox "请输入配置名称！", "提示", "Icon!"
        return
    }
    
    local section := "Config_" configName
    IniWrite FireRate, configFile, section, "FireRate"
    IniWrite RecoilForce, configFile, section, "RecoilForce"
    IniWrite HorizontalRecoil, configFile, section, "HorizontalRecoil"
    IniWrite HorizontalPattern, configFile, section, "HorizontalPattern"
    IniWrite HotkeyCC, configFile, section, "Hotkey"
    IniWrite breathHold, configFile, section, "BreathHold"
    IniWrite semiAutoMode, configFile, section, "SemiAutoMode"
    IniWrite ED, configFile, section, "ED"
    
    RefreshConfigList()
    MsgBox "配置 [" configName "] 已保存！", "提示", "Iconi"
}

LoadSelectedConfig(*) {
    global configFile
    global FireRate, RecoilForce, HorizontalRecoil, HorizontalPattern
    global breathHold, semiAutoMode, ED, HotkeyCC, assistantEnabled
    global ConfigListCtrl, ConfigNameCtrl
    
    local configName := ConfigListCtrl.Text  ; 修复：使用.Text而不是.Value
    
    if configName = "" {
        return
    }
    
    local section := "Config_" configName
    local tempFireRate := IniRead(configFile, section, "FireRate", "")
    
    if tempFireRate = "" {
        MsgBox "未找到配置 [" configName "]！", "错误", "Iconx"
        return
    }
    
    ; 读取配置
    FireRate := Integer(IniRead(configFile, section, "FireRate", FireRate))
    RecoilForce := Integer(IniRead(configFile, section, "RecoilForce", RecoilForce))
    HorizontalRecoil := Integer(IniRead(configFile, section, "HorizontalRecoil", HorizontalRecoil))
    HorizontalPattern := Integer(IniRead(configFile, section, "HorizontalPattern", HorizontalPattern))
    local tempHotkey := IniRead(configFile, section, "Hotkey", HotkeyCC)
    breathHold := Integer(IniRead(configFile, section, "BreathHold", breathHold))
    semiAutoMode := Integer(IniRead(configFile, section, "SemiAutoMode", semiAutoMode))
    ED := Integer(IniRead(configFile, section, "ED", ED))
    
    ; 更新界面
    UpdateGUIDisplay()
    assistantEnabled := ED
    ConfigNameCtrl.Value := configName
    
    ; 更新热键
    if tempHotkey != HotkeyCC {
        try {
            Hotkey HotkeyCC, HotkeyToggle, "Off"
            Hotkey tempHotkey, HotkeyToggle, "On"
            HotkeyCC := tempHotkey
        } catch as err {
            ; 忽略热键错误
        }
    }
    
    UpdateStatusDisplay()
    MsgBox "配置 [" configName "] 已加载！", "提示", "Iconi"
}

DeleteSelectedConfig(*) {
    global configFile
    global ConfigNameCtrl, ConfigListCtrl
    
    local configToDelete
    local configName := ConfigNameCtrl.Value
    local configList := ConfigListCtrl.Text  ; 修复：使用.Text而不是.Value
    
    if configName != "" {
        configToDelete := configName
    } else if configList != "" {
        configToDelete := configList
    } else {
        MsgBox "请选择要删除的配置！", "提示", "Icon!"
        return
    }
    
    if MsgBox("是否确定删除配置 [" configToDelete "]？", "确认删除", "YesNo Icon?") = "Yes" {
        IniDelete configFile, "Config_" configToDelete
        ConfigNameCtrl.Value := ""
        RefreshConfigList()
        MsgBox "配置 [" configToDelete "] 已删除！", "提示", "Iconi"
    }
}

RefreshConfigList(*) {
    global configFile
    global ConfigListCtrl
    
    local sections := IniRead(configFile)
    local configs := []
    
    if sections != "" {
        for line in StrSplit(sections, "`n") {
            if InStr(line, "Config_") = 1 {
                local configName := SubStr(line, 8)
                configs.Push(configName)
            }
        }
    }
    
    ConfigListCtrl.Delete()
    if configs.Length > 0 {
        for name in configs {
            ConfigListCtrl.Add([name])
        }
    }
}

; -------------------------------
;          GUI事件
; -------------------------------

GuiClose(*) {
    ExitApp
}

GuiEscape(*) {
    global MyGui
    MyGui.Hide()
}