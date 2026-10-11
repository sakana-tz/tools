; DebugAreaTool.ahk - 区域可视化调试工具
; Requires AutoHotkey v2.0

global DebugGuiArray := []

; 绘制调试区域
; @param winTitle 浏览器窗口标题
; @param areas 包含区域信息的数组，格式: [{name: "区域名", color: "Red", x: 0.1, y: 0.1, w: 0.2, h: 0.1}]
DrawDebugAreas(winTitle, areas) {
    global DebugGuiArray
    
    ; 先清除旧的框
    ClearDebugBoxes()
    
    if !WinExist(winTitle) {
        MsgBox "未找到目标窗口: " winTitle
        return
    }
    
    ; 【修复点】颜色名称映射表
    ; AHK 的 Progress 控件默认只认基本颜色，我们在这里兼容更多颜色，并将其转成十六进制
    colorMap := Map(
        "Orange", "0xFFA500",
        "Purple", "0x800080",
        "Cyan",   "0x00FFFF",
        "Pink",   "0xFFC0CB",
        "Brown",  "0xA52A2A",
        "DarkRed","0x8B0000"
    )
    
    ; 获取浏览器客户区位置（去掉标题栏和地址栏的高度）
    WinGetClientPos &clientX, &clientY, &clientW, &clientH, winTitle
    
    for index, area in areas {
        ; 计算绝对坐标
        absX := clientX + Round(clientW * area.x)
        absY := clientY + Round(clientH * area.y)
        absW := Round(clientW * area.w)
        absH := Round(clientH * area.h)
        
        ; 检查颜色是否在映射表中，如果在则替换，不在则使用原值
        actualColor := colorMap.Has(area.color) ? colorMap[area.color] : area.color
        
        ; 创建无边框、置顶、透明、鼠标穿透的 GUI
        myGui := Gui("-Caption -Border +ToolWindow +AlwaysOnTop +E0x20 +E0x80000 -DPIScale")
        myGui.MarginX := 0
        myGui.MarginY := 0
        
        ; 绘制底色方块 (使用转换后的 actualColor)
        ctrl := myGui.Add("Progress", "w" absW " h" absH " Background" actualColor)
        
        ; 添加文字标签显示区域名称
        myGui.SetFont("s12 Bold", "Microsoft YaHei")
        myGui.Add("Text", "x5 y5 BackgroundTrans cWhite", area.name)
        
        ; 设置 120 的透明度，并设置鼠标穿透（+0x20）
        WinSetTransparent(120, myGui)
        WinSetExStyle("+0x20", myGui)
        
        ; 显示
        myGui.Show("x" absX " y" absY " w" absW " h" absH " NoActivate")
        
        DebugGuiArray.Push(myGui)
    }
    
    ToolTip("调试方框已绘制！按 F3 清除。")
    SetTimer () => ToolTip(), -2000
}

; 清除所有调试方框
ClearDebugBoxes() {
    global DebugGuiArray
    for guiObj in DebugGuiArray {
        try {
            guiObj.Destroy()
        }
    }
    DebugGuiArray := []
}