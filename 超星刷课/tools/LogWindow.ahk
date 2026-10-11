; tools/LogWindow.ahk - 屏幕右侧日志悬浮窗口模块（F4 显示/隐藏）
; Requires AutoHotkey v2.0

class LogWindow {
    static gui := 0
    static editCtrl := 0
    static visible := false
    static width := 400
    static margin := 250  ; 距屏幕右边缘的边距

    ; F4 切换显示/隐藏
    static Toggle() {
        if (this.visible) {
            this.Hide()
        } else {
            this.Show()
        }
    }

    static Show() {
        if !this.gui {
            this.Build()
        }
        h := A_ScreenHeight // 2
        ; NA = 不抢焦点，避免干扰浏览器窗口激活状态
        this.gui.Show("x" . (A_ScreenWidth - this.width - this.margin) . " y0 w" . this.width . " h" . h . " NA")
        this.visible := true
        this.Refresh()
        SetTimer () => this.Refresh(), 1000  ; 每秒刷新日志内容
    }

    static Hide() {
        if this.gui {
            this.gui.Hide()
        }
        this.visible := false
        SetTimer () => this.Refresh(), 0  ; 停止刷新定时器
    }

    ; 构建窗口：置顶、无边框、屏幕右侧半屏高、深色只读编辑框
    static Build() {
        this.gui := Gui("+AlwaysOnTop -Caption +ToolWindow", "运行日志")
        this.gui.BackColor := "1E1E1E"
        this.editCtrl := this.gui.Add("Edit", "Multi ReadOnly -E0x200 -VScroll x0 y0 w" . this.width . " h" . (A_ScreenHeight // 2) . " Background1E1E1E")
        this.editCtrl.SetFont("s9 cD4D4D4", "Consolas")
    }

    ; 读取今日日志文件并滚动到底部
    static Refresh() {
        if (!this.gui || !this.visible) {
            return
        }
        logFile := A_ScriptDir . "\logs\cx_" . FormatTime(, "yyyyMMdd") . ".log"
        content := ""
        if FileExist(logFile) {
            try content := FileRead(logFile, "UTF-8")
        } else {
            content := "暂无今日日志: " . logFile
        }
        this.editCtrl.Value := content
        SendMessage 0x115, 7, 0,, "ahk_id " . this.editCtrl.Hwnd  ; WM_VSCROLL + SB_BOTTOM 滚动到底部
    }
}
