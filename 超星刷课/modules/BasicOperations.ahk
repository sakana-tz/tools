; BasicOperations.ahk - 基础操作模块
; Requires AutoHotkey v2.0

; 相对点击（传入 0.0 到 1.0 的比例）
ClickRelative(relX, relY, winTitle) {
    if WinExist(winTitle) {
        WinGetClientPos &X, &Y, &Width, &Height, winTitle
        if (Width > 0 && Height > 0) {
            clickX := X + Width * relX
            clickY := Y + Height * relY
            Click clickX, clickY
            return true
        }
    }
    return false
}

; 防切屏检测：微小移动鼠标，防止视频暂停
PreventIdle(winTitle) {
    if WinExist(winTitle) {
        MouseGetPos &startX, &startY
        MouseMove startX + 2, startY + 2, 0
        Sleep 100
        MouseMove startX, startY, 0
    }
}

; 写入状态日志（按日期分文件，UTF-8 编码，存于脚本目录下的 logs 文件夹）
WriteLog(msg) {
    logDir := A_ScriptDir . "\logs"
    if !DirExist(logDir) {
        DirCreate(logDir)
    }
    logFile := logDir . "\cx_" . FormatTime(, "yyyyMMdd") . ".log"
    timestamp := FormatTime(, "yyyy-MM-dd HH:mm:ss")
    f := FileOpen(logFile, "a", "UTF-8")
    f.Write("[" . timestamp . "] " . msg . "`n")
    f.Close()
}