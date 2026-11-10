; ============================================================
; Filelink  v1.0  (AutoHotkey v2)
; 在 WPS 窗口中一键复制当前文档的本地完整路径
;
; - 只在 WPS（文字/表格/演示/PDF）窗口激活时显示透明悬浮图标
; - 单击图标：复制当前文档的本地完整路径
; - 按住图标拖动：移动位置，松手后自动固定并记住该位置
; - 右键图标：固定 / 恢复跟随窗口、退出
; - 位置保存在脚本同目录 settings.ini，重启后自动恢复
; ============================================================
#Requires AutoHotkey v2.0
#SingleInstance Force
Persistent
A_IconHidden := true

; ---------- 可调整参数 ----------
BTN_OFFSET_RIGHT := 60    ; 跟随模式：图标距 WPS 窗口右边缘的像素
BTN_OFFSET_TOP   := 90    ; 跟随模式：图标距 WPS 窗口顶部的像素
ICON_SIZE        := 36    ; 透明方块尺寸（逻辑像素）
CHECK_INTERVAL   := 400
INI := A_ScriptDir "\settings.ini"

PROC2BRANCH := Map(
    "wps.exe",    "wps",
    "et.exe",     "et",
    "wpp.exe",    "wpp",
    "wpspdf.exe", "pdf"
)
ALL_BRANCHES := ["wps", "et", "wpp", "pdf"]

; ---------- 读取已保存的固定位置 ----------
global FixedMode := IniRead(INI, "Settings", "FixedMode", "0") = "1"
global FixedX := Integer(IniRead(INI, "Settings", "PosX", "0"))
global FixedY := Integer(IniRead(INI, "Settings", "PosY", "0"))

; ---------- 透明方块图标按钮 ----------
; 原理：窗口背景设为品红并整体抠除（透明且点击穿透），只留 🔗 图标可见可点
global BtnGui := Gui("+AlwaysOnTop -Caption +ToolWindow +E0x08000000")
BtnGui.BackColor := "0xFF00FF"
BtnGui.SetFont("s20", "Segoe UI Emoji")
BtnGui.MarginX := 0
BtnGui.MarginY := 0
btnText := BtnGui.Add("Text", "BackgroundTrans Center w" ICON_SIZE " h" ICON_SIZE " 0x200", "🔗")
btnText.OnEvent("Click", OnBtnClick)
btnText.OnEvent("ContextMenu", ShowBtnMenu)
BtnGui.Show("Hide")            ; 先实例化但不显示
WinSetTransColor("0xFF00FF", BtnGui.Hwnd)

; ---------- 拖动逻辑（按住移动，松手固定） ----------
global dragging := false, dragMoved := false, dragDX := 0, dragDY := 0
OnMessage(0x201, OnLButtonDown)   ; WM_LBUTTONDOWN

OnLButtonDown(wParam, lParam, msg, hwnd) {
    global dragging, dragMoved, dragDX, dragDY
    if (hwnd != btnText.Hwnd && hwnd != BtnGui.Hwnd)
        return
    dragging := true
    dragMoved := false
    MouseGetPos(&mx, &my)
    WinGetPos(&gx, &gy,,, BtnGui.Hwnd)
    dragDX := mx - gx
    dragDY := my - gy
    SetTimer(DragTrack, 15)
}

DragTrack() {
    global dragging, dragMoved, FixedMode, FixedX, FixedY
    if !GetKeyState("LButton", "P") {
        SetTimer(DragTrack, 0)
        dragging := false
        if dragMoved {
            WinGetPos(&gx, &gy,,, BtnGui.Hwnd)
            FixedX := gx
            FixedY := gy
            FixedMode := true
            IniWrite("1", INI, "Settings", "FixedMode")
            IniWrite(gx, INI, "Settings", "PosX")
            IniWrite(gy, INI, "Settings", "PosY")
            FlashTip("位置已固定并记住（右键图标可恢复跟随窗口）")
            SetTimer(() => (dragMoved := false), -600)
        }
        return
    }
    MouseGetPos(&mx, &my)
    WinGetPos(&gx, &gy,,, BtnGui.Hwnd)
    nx := mx - dragDX
    ny := my - dragDY
    if (!dragMoved && (Abs(nx - gx) > 4 || Abs(ny - gy) > 4))
        dragMoved := true
    if dragMoved
        BtnGui.Move(nx, ny)
}

OnBtnClick(*) {
    global dragMoved
    if dragMoved {          ; 刚拖完，忽略本次点击
        dragMoved := false
        return
    }
    CopyCurrentPath()
}

; ---------- 右键菜单 ----------
ShowBtnMenu(*) {
    m := Menu()
    if FixedMode
        m.Add("恢复跟随窗口右上角", (*) => SetFixed(false))
    else
        m.Add("固定在当前位置", (*) => SetFixed(true))
    m.Add("退出", (*) => ExitApp())
    m.Show()
}

SetFixed(f) {
    global FixedMode, FixedX, FixedY, BtnVisible
    if f {
        WinGetPos(&gx, &gy,,, BtnGui.Hwnd)
        FixedX := gx
        FixedY := gy
        FixedMode := true
        IniWrite("1", INI, "Settings", "FixedMode")
        IniWrite(gx, INI, "Settings", "PosX")
        IniWrite(gy, INI, "Settings", "PosY")
        FlashTip("已固定在当前位置")
    } else {
        FixedMode := false
        IniWrite("0", INI, "Settings", "FixedMode")
        BtnGui.Hide()
        BtnVisible := false
        FlashTip("已恢复跟随窗口右上角")
    }
}

; ---------- 定时检测：仅在 WPS 激活时显示 ----------
global BtnVisible := false
SetTimer(CheckActiveWindow, CHECK_INTERVAL)

CheckActiveWindow() {
    global BtnVisible, FixedMode, FixedX, FixedY
    if dragging
        return
    hwnd := WinActive("A")
    proc := ""
    try proc := WinGetProcessName(hwnd)
    if (hwnd && PROC2BRANCH.Has(proc)) {
        if FixedMode {
            x := FixedX
            y := FixedY
            ; 分辨率变化导致跑出屏幕时，回退到跟随模式
            if (x < -50 || y < -50 || x > A_ScreenWidth - 20 || y > A_ScreenHeight - 20) {
                FixedMode := false
                IniWrite("0", INI, "Settings", "FixedMode")
            }
        }
        if !FixedMode {
            WinGetPos(&wx, &wy, &ww, &wh, hwnd)
            x := wx + ww - BTN_OFFSET_RIGHT - ICON_SIZE
            y := wy + BTN_OFFSET_TOP
            if !BtnVisible {
                BtnGui.Show("NoActivate x" x " y" y)
                BtnVisible := true
            } else {
                BtnGui.Move(x, y)
            }
        } else if !BtnVisible {
            BtnGui.Show("NoActivate x" x " y" y)
            BtnVisible := true
        }
        ; WPS 的透明阴影边框窗口可能盖住图标，每轮把图标重新置顶
        DllCall("SetWindowPos", "ptr", BtnGui.Hwnd, "ptr", -1, "int", 0, "int", 0, "int", 0, "int", 0, "uint", 0x0013)
    } else if BtnVisible {
        BtnGui.Hide()
        BtnVisible := false
    }
}

; ---------- 核心：取当前文档本地路径并复制 ----------
CopyCurrentPath() {
    hwnd := WinActive("A")
    title := ""
    try title := WinGetTitle(hwnd)
    fileName := RegExReplace(title, "\s+-\s+WPS.*$", "")
    fileName := RegExReplace(fileName, "^(只读|\[只读\])\s*", "")
    fileName := Trim(fileName)

    if (fileName = "" || !RegExMatch(fileName, "\.[A-Za-z0-9]{1,5}$")) {
        FlashTip("当前页面不是本地文档")
        return
    }

    proc := ""
    try proc := WinGetProcessName(hwnd)
    path := FindPathInRegistry(fileName, PROC2BRANCH.Has(proc) ? PROC2BRANCH[proc] : "")

    if (path != "") {
        A_Clipboard := path
        FlashTip("已复制：`n" path)
    } else {
        FlashTip("未找到本地路径（可能是云文档）")
    }
}

FindPathInRegistry(fileName, preferBranch) {
    branches := []
    if (preferBranch != "")
        branches.Push(preferBranch)
    for b in ALL_BRANCHES
        if (b != preferBranch)
            branches.Push(b)

    target := StrLower(fileName)
    for branch in branches {
        base := "HKCU\Software\Kingsoft\Office\6.0\" branch "\RecentFiles\files"
        Loop 100 {
            p := ""
            try p := RegRead(base "\" A_Index, "path")
            if (p = "")
                continue
            SplitPath(p, &name)
            if (StrLower(name) = target && FileExist(p))
                return p
        }
    }
    return ""
}

; ---------- 提示气泡 ----------
global TipGui := ""
FlashTip(msg) {
    global TipGui
    try TipGui.Destroy()
    TipGui := Gui("+AlwaysOnTop -Caption +ToolWindow +E0x08000000")
    TipGui.BackColor := "0x323232"
    TipGui.SetFont("s9 cFFFFFF", "Microsoft YaHei UI")
    TipGui.Add("Text", "w360", msg)
    MouseGetPos(&mx, &my)
    TipGui.Show("NoActivate x" (mx + 16) " y" (my + 16))
    tg := TipGui
    SetTimer(() => tg.Destroy(), -1600)
}
