; modules/NavigationModule.ahk - 页面跳转与提示处理模块
; Requires AutoHotkey v2.0
; 所有点击点/滚动点均来自 config.json 的 clicks 段（x/y 为窗口比例）

class NavigationModule {
    ; 处理任务点未完成弹窗 (如"当前章节还有任务点未完成，是否去完成？")
    static HandleTaskPrompt(winTitle, popupArea, clicks) {
        ScreenshotTool.CaptureGameArea(popupArea, "screenshots\popup.png", winTitle)
        popupText := OcrTool.OcrToText("screenshots\popup.png")

        if (InStr(popupText, "未完成") && InStr(popupText, "去学习")) {
            ToolTip("检测到任务点未完成提示，点击[去学习]")
            WriteLog("[HandleTaskPrompt] 检测到任务点未完成，点击[去学习]")
            this.ClickPosWithRetry(winTitle, clicks.goLearn)
            Sleep(2000)
            return true
        }
        return false
    }

    ; 辅助：带容错的点击（以配置点为中心，在上下左右四角多点位点击，防止按钮没按到）
    static ClickPosWithRetry(winTitle, point) {
        WinGetClientPos &winX, &winY, &winW, &winH, winTitle
        ; 偏移阵列：原点 + 上下左右 + 四角，确保覆盖按钮区域
        offsets := [
            {dx: 0,      dy: 0},       ; 原点
            {dx: 0.015,  dy: 0},       ; 右
            {dx: -0.015, dy: 0},       ; 左
            {dx: 0,      dy: 0.015},    ; 下
            {dx: 0,      dy: -0.015},   ; 上
            {dx: 0.015,  dy: 0.015},    ; 右下
            {dx: -0.015, dy: 0.015},    ; 左下
            {dx: 0.015,  dy: -0.015},   ; 右上
            {dx: -0.015, dy: -0.015}    ; 左上
        ]
        for off in offsets {
            clickX := winX + Round(winW * (point.x + off.dx))
            clickY := winY + Round(winH * (point.y + off.dy))
            MouseMove clickX, clickY, 1
            Click clickX, clickY
            Sleep 50
        }
    }

    ; 辅助：滚轮到底部（鼠标移到配置的滚动点后滚动）
    static ScrollToBottom(winTitle, scrollPoint) {
        WinGetClientPos &winX, &winY, &winW, &winH, winTitle
        scrollX := winX + Round(winW * scrollPoint.x)
        scrollY := winY + Round(winH * scrollPoint.y)
        MouseMove scrollX, scrollY, 3
        Sleep 300
        ; 第一轮滚动
        Loop 15 {
            Click "WheelDown"
            Sleep 200
        }
        Sleep 500
        ; 第二轮滚动（确保到底）
        Loop 15 {
            Click "WheelDown"
            Sleep 200
        }
    }

    ; 跳转下一节 - 四步流程（带容错）
    static GoToNextVideo(winTitle, clicks) {
        WriteLog("[GoToNextVideo] 开始跳转下一节流程")

        ; 步骤1：滚轮滑到底，点下一节
        ToolTip("步骤1：滚轮滑到底，点下一节")
        WriteLog("[GoToNextVideo] 步骤1：滚轮滑到底，点下一节")
        this.ScrollToBottom(winTitle, clicks.scrollPoint)
        Sleep 500
        this.ClickPosWithRetry(winTitle, clicks.nextStep1)
        Sleep 2000

        ; 步骤2：在弹出的对话框中点"下一节"
        ToolTip("步骤2：在弹窗中点下一节")
        WriteLog("[GoToNextVideo] 步骤2：在弹窗中点下一节")
        this.ClickPosWithRetry(winTitle, clicks.nextDialog1)
        Sleep 3000

        ; 步骤3：新界面滚轮到底部，点下一节（按钮比步骤1更靠下）
        ToolTip("步骤3：新界面滚轮到底部，点下一节")
        WriteLog("[GoToNextVideo] 步骤3：新界面滚轮到底部，点下一节")
        this.ScrollToBottom(winTitle, clicks.scrollPoint)
        Sleep 500
        this.ClickPosWithRetry(winTitle, clicks.nextStep2)
        Sleep 2000

        ; 步骤4：在再弹出的对话框中点"下一节"
        ToolTip("步骤4：在再弹出的对话框中点下一节")
        WriteLog("[GoToNextVideo] 步骤4：在再弹出的对话框中点下一节")
        this.ClickPosWithRetry(winTitle, clicks.nextDialog2)
        Sleep 3000

        WriteLog("[GoToNextVideo] 跳转下一节流程完成")
        return true
    }
}
