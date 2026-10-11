; modules/VideoModule.ahk - 视频播放与监控模块
; Requires AutoHotkey v2.0

class VideoModule {
    ; 跨循环状态：上次记录的播放进度（秒），-1 表示尚未初始化
    static lastProgressSec := -1
    static lastTotalSec := 0
    static pausedCount := 0  ; 连续暂停次数

    ; 黑屏检测配置
    static blackScreenPoints := [      ; 采样点（相对视频区域比例 0.0~1.0，避开正中央播放按钮）
        {x: 0.15, y: 0.15},   ; 左上
        {x: 0.85, y: 0.15},   ; 右上
        {x: 0.15, y: 0.50},   ; 左中
        {x: 0.85, y: 0.50},   ; 右中
        {x: 0.15, y: 0.85},   ; 左下
        {x: 0.85, y: 0.85}    ; 右下
    ]
    static blackScreenThreshold := 30  ; RGB 各分量低于此值视为黑色
    static blackScreenMinPoints := 4   ; 采样点中至少 N 个为黑色才判定为黑屏

    ; 解析时间字符串 "03:03" 为秒数
    static ParseTimeToSeconds(timeStr) {
        parts := StrSplit(timeStr, ":")
        if (parts.Length == 2) {
            return Integer(parts[1]) * 60 + Integer(parts[2])
        }
        return 0
    }

    ; 检测视频区域是否为黑屏
    ; 在视频窗口采样多个点，若大部分为黑色则判定为黑屏（视频未播放）
    static DetectBlackScreen(winTitle, videoArea) {
        if !WinExist(winTitle) {
            return false
        }
        WinGetClientPos &winX, &winY, &winW, &winH, winTitle

        blackCount := 0
        for p in this.blackScreenPoints {
            ; p.x, p.y 是相对视频区域的比例 (0.0~1.0)，转换为窗口绝对比例
            absX := videoArea.x + videoArea.w * p.x
            absY := videoArea.y + videoArea.h * p.y
            px := winX + Round(winW * absX)
            py := winY + Round(winH * absY)
            color := PixelGetColor(px, py)
            ; PixelGetColor 返回 BGR 格式，提取各分量
            r := color & 0xFF
            g := (color >> 8) & 0xFF
            b := (color >> 16) & 0xFF
            if (r < this.blackScreenThreshold && g < this.blackScreenThreshold && b < this.blackScreenThreshold) {
                blackCount += 1
            }
        }

        isBlack := (blackCount >= this.blackScreenMinPoints)
        WriteLog("[DetectBlackScreen] 采样 " . this.blackScreenPoints.Length . " 点，黑色 " . blackCount . " 点，判定: " . (isBlack ? "黑屏" : "非黑屏"))
        return isBlack
    }

    ; 防挂机并监测进度
    ; 返回 true 表示当前处于视频播放界面（识别到进度条，或黑屏=播放器存在仅未播放）；
    ; 返回 false 表示不在视频播放界面（进度条 OCR 为空且非黑屏，可能是文档页/章节列表/异常页）
    static MonitorVideo(winTitle, progressArea, durationArea, videoArea) {
        onVideoInterface := false
        ; 1. 移动鼠标到视频窗口内（防挂机 + 唤出进度条文本）
        WinGetClientPos &winX, &winY, &winW, &winH, winTitle
        randX := winX + Round(winW * (videoArea.x + videoArea.w * Random(0.3, 0.7)))
        randY := winY + Round(winH * (videoArea.y + videoArea.h * Random(0.3, 0.7)))
        MouseMove randX, randY, 3
        Sleep 300
        ; 关键：截图前再次微移鼠标，重置播放器控制栏的自动隐藏倒计时。
        ; 超星播放器在鼠标静止约 0.5~3 秒后就隐藏进度栏，单次滑动后固定等待，
        ; 截图时进度栏可能已开始隐藏，导致 OCR 时有时无。
        MouseMove randX + 6, randY + 4, 0
        Sleep 150
        MouseMove randX + 2, randY + 8, 0
        Sleep 120

        ; 2. 截图识别当前播放时间（最后一次微移后进度栏处于显示状态）
        screenPath := "screenshots\progress.png"
        ScreenshotTool.CaptureGameArea(durationArea, screenPath, winTitle)
        timeText := OcrTool.OcrToText(screenPath)
        if (timeText = "") {
            ; 未识别到 → 再唤出一次进度条并重拍，避免单次时序抖动造成误判
            MouseMove randX + 12, randY + 6, 0
            Sleep 150
            MouseMove randX, randY, 0
            Sleep 150
            ScreenshotTool.CaptureGameArea(durationArea, screenPath, winTitle)
            timeText := OcrTool.OcrToText(screenPath)
        }
        WriteLog("[MonitorVideo] 进度条OCR: '" . timeText . "' 截图: " . screenPath)

        currentSec := -1
        totalSec := 0
        currentTimeStr := ""
        totalTimeStr := ""

        if RegExMatch(timeText, "(\d{1,2}:\d{2})\s*/\s*(\d{1,2}:\d{2})", &m) {
            currentTimeStr := m[1]
            totalTimeStr := m[2]
            currentSec := this.ParseTimeToSeconds(m[1])
            totalSec := this.ParseTimeToSeconds(m[2])
        }

        ; 3. 状态检测与自动恢复播放
        if (currentSec >= 0) {
            ; OCR 成功识别到进度条 → 处于视频播放界面
            onVideoInterface := true
            if (this.lastProgressSec < 0) {
                ; 初始状态：新视频加载，点击中央播放
                WriteLog("[MonitorVideo] 初始状态：将鼠标移到视频窗口中央，点击播放")
                ToolTip("初始状态，点击播放...")
                WinGetClientPos &cx_wX, &cx_wY, &cx_wW, &cx_wH, winTitle
                centerX := cx_wX + Round(cx_wW * (videoArea.x + videoArea.w / 2))
                centerY := cx_wY + Round(cx_wH * (videoArea.y + videoArea.h / 2))
                MouseMove centerX, centerY, 3
                Sleep 200
                Click centerX, centerY
                Sleep 1000
            } else if (currentSec == this.lastProgressSec) {
                ; 进度停滞，视频已暂停 → 鼠标移到视频中央并点击播放
                this.pausedCount += 1
                WriteLog("[MonitorVideo] *** 检测到视频暂停 *** 进度停滞在 " . currentTimeStr . "，自动点击播放 (连续暂停次数: " . this.pausedCount . ")")
                ToolTip("检测到暂停，自动恢复播放...")
                WinGetClientPos &cx_wX, &cx_wY, &cx_wW, &cx_wH, winTitle
                centerX := cx_wX + Round(cx_wW * (videoArea.x + videoArea.w / 2))
                centerY := cx_wY + Round(cx_wH * (videoArea.y + videoArea.h / 2))
                MouseMove centerX, centerY, 3
                Sleep 200
                Click centerX, centerY
                Sleep 1000
            } else {
                this.pausedCount := 0
            }

            ; 记录状态日志
            progressPct := (totalSec > 0) ? Round(currentSec / totalSec * 100) : 0
            WriteLog("[MonitorVideo] 播放中 " . currentTimeStr . " / " . totalTimeStr . " (" . progressPct . "%) | 上次: " . this.lastProgressSec . "s 当前: " . currentSec . "s")

            ; 更新进度记录
            this.lastProgressSec := currentSec
            this.lastTotalSec := totalSec
        } else {
            ; OCR 未识别到进度条，检测是否黑屏
            if (this.DetectBlackScreen(winTitle, videoArea)) {
                ; 黑屏 = 播放器存在只是未播放，仍算视频播放界面
                onVideoInterface := true
                WriteLog("[MonitorVideo] 检测到黑屏（视频未播放），将鼠标移到视频窗口中央，点击播放")
                ToolTip("黑屏检测，点击播放...")
                WinGetClientPos &cx_wX, &cx_wY, &cx_wW, &cx_wH, winTitle
                centerX := cx_wX + Round(cx_wW * (videoArea.x + videoArea.w / 2))
                centerY := cx_wY + Round(cx_wH * (videoArea.y + videoArea.h / 2))
                MouseMove centerX, centerY, 3
                Sleep 200
                Click centerX, centerY
                Sleep 1000
            } else {
                WriteLog("[MonitorVideo] 警告: 未识别到进度条，OCR文本: " . timeText)
                ToolTip("未识别到进度条，尝试调整...")
            }
        }

        return onVideoInterface
    }
}
