; 超星学习通自动学习脚本 - ChaoXingAuto.ahk (主入口)
; Requires AutoHotkey v2.0
#SingleInstance Force
#Warn VarUnset, Off  ; ClickRelative/WriteLog 是全局函数，AHK 在类方法内误判为局部变量

; 请求管理员权限
if not A_IsAdmin
{
    try
    {
        Run '*RunAs "' A_ScriptFullPath '"'
        ExitApp
    }
}

; 导入基础操作 (相对点击，防挂机等) — 必须先加载，模块内需调用 ClickRelative / WriteLog
#Include modules\BasicOperations.ahk

; 导入工具与模块
#Include ..\home\ahk2_lib\JSON.ahk
#Include tools\ScreenshotTool.ahk
#Include tools\OcrTool.ahk
#Include tools\DebugAreaTool.ahk
#Include tools\LogWindow.ahk
#Include modules\VideoModule.ahk
#Include modules\VideoQuizModule.ahk
#Include modules\NavigationModule.ahk

; ================= 配置区域 =================
global TargetWindow := "ahk_exe msedge.exe" ; 改为你的浏览器进程，如 msedge.exe 或 chrome.exe
global Toggle := false

; --- 配置加载 (config.json 为唯一来源：areas 供 F2 画框与逻辑判定共用，clicks 为导航点击点) ---
; JSON.parse 第三参 as_map=false：对象转 Object（支持 area.name 点访问；v2 Object 不支持 [] 取键，根键用点访问）
global Config := JSON.parse(FileRead(A_ScriptDir "\config.json", "UTF-8"), false, false)
global DebugAreas := Config.areas
global NavClicks := Config.clicks
global WatchdogCfg := Config.watchdog

; 看门狗运行状态：NoVideoStart=0 表示当前在视频界面；RecoverAttempts 为已执行的自动跳转次数
global NoVideoStart := 0
global RecoverAttempts := 0

; 按名称取区域（x/y/w/h 均为窗口比例）
GetArea(name) {
    global DebugAreas
    for area in DebugAreas {
        if (area.name == name)
            return area
    }
    throw Error("config.json 中未找到区域: " name)
}

global VideoWindowArea := GetArea("视频窗口")
global ProgressArea := GetArea("进度条识别区")
global PopupArea := GetArea("弹窗识别区")
global TaskCompletedArea := GetArea("任务已完成识别区")
global VideoQuizArea := GetArea("视频中题目识别区")
global VideoQuizOptions := [
    GetArea("视频中题目选项A"),
    GetArea("视频中题目选项B"),
    GetArea("视频中题目选项C"),
    GetArea("视频中题目选项D")
]
global VideoQuizSubmitArea := GetArea("视频中题目提交")
global VideoQuizWrongArea := GetArea("视频中题目回答错误")
; ============================================

if WinExist(TargetWindow)
    WinActivate TargetWindow
else {
    MsgBox "未找到浏览器窗口，请先打开超星学习页面。`n请修改脚本中的 TargetWindow 变量。"
    ExitApp
}

; --- 热键 ---
F1:: {
    global Toggle, NoVideoStart, RecoverAttempts
    Toggle := !Toggle
    if (Toggle) {
        NoVideoStart := 0   ; 每次启动重置看门狗，暂停期间不计入等待时间
        RecoverAttempts := 0
        ToolTip("超星自动学习已启动 (F1暂停, F2画框, F3清框, F4日志)")
        WriteLog("========== 脚本启动，每10秒检查播放状态 ==========")
        SetTimer AutoStudyLoop, 10000
    } else {
        ToolTip("超星自动学习已暂停")
        WriteLog("========== 脚本暂停 ==========")
        SetTimer AutoStudyLoop, 0
    }
}

F2:: {
    global TargetWindow, DebugAreas
    WinActivate TargetWindow
    Sleep 200
    DrawDebugAreas(TargetWindow, DebugAreas)
}

F3:: {
    ClearDebugBoxes()
    ToolTip("已清除调试方框")
    SetTimer () => ToolTip(), -1000
}

F4:: {
    LogWindow.Toggle()
    ToolTip(LogWindow.visible ? "日志窗口已显示 (F4隐藏)" : "日志窗口已隐藏")
    SetTimer () => ToolTip(), -1500
}

P::ExitApp

; --- 核心自动化循环 ---
AutoStudyLoop() {
    global TargetWindow, ProgressArea, PopupArea, VideoWindowArea, TaskCompletedArea
    global VideoQuizArea, VideoQuizOptions, VideoQuizSubmitArea, VideoQuizWrongArea, NavClicks
    global NoVideoStart, RecoverAttempts, WatchdogCfg

    if !WinExist(TargetWindow) {
        WriteLog("[Loop] 警告: 未找到浏览器窗口")
        ToolTip("警告：未找到浏览器窗口！")
        return
    }

    ; 超星有防切屏机制，每次循环先激活窗口
    WinActivate TargetWindow
    Sleep 500

    ; 1. 检测视频中随机弹出的答题界面（优先级最高，答题期间跳过其余状态检测）
    if (VideoQuizModule.AnswerVideoQuiz(TargetWindow, VideoQuizArea, VideoQuizOptions, VideoQuizSubmitArea, VideoQuizWrongArea)) {
        WriteLog("[Loop] 处理了视频答题")
        NoVideoStart := 0   ; 答题界面属于视频播放界面，看门狗续期
        return
    }

    ; 2. 处理任务点提示弹窗 (如图2的“未完成，去学习”)
    if (NavigationModule.HandleTaskPrompt(TargetWindow, PopupArea, NavClicks)) {
        WriteLog("[Loop] 处理了任务点提示弹窗")
        NoVideoStart := 0   ; 已执行导航动作，重新给一个完整计时周期
        return
    }

    ; 3. 检测任务点已完成标识（OCR 识别"已完成"文字）
    screenPath := "screenshots\completed.png"
    ScreenshotTool.CaptureGameArea(TaskCompletedArea, screenPath, TargetWindow)
    completedText := OcrTool.OcrToText(screenPath)
    WriteLog("[Loop] 任务已完成OCR: '" . completedText . "' 截图: " . screenPath)
    ; 容错匹配：OCR 常把"已"识别成"己"、"成"识别成"戍"，命中"完成"或"已完"即视为完成；
    ; 含"未"则排除（"任务点未完成"同样含"完成"两字）
    isCompleted := (InStr(completedText, "未") == 0) && (InStr(completedText, "完成") || InStr(completedText, "已完"))
    if (isCompleted) {
        WriteLog("[Loop] 检测到任务点已完成，跳转下一节 (OCR: " . completedText . ")")
        NavigationModule.GoToNextVideo(TargetWindow, NavClicks)
        NoVideoStart := 0       ; 正常完成跳转，看门狗状态全部清零
        RecoverAttempts := 0
        Sleep(5000)
        return
    }

    ; 4. 监控视频进度与播放状态（包含暂停检测与自动恢复播放）
    ;    返回 false = 不在视频播放界面（进度条无 OCR 且非黑屏），交给看门狗处理
    onVideo := VideoModule.MonitorVideo(TargetWindow, ProgressArea, ProgressArea, VideoWindowArea)
    if (onVideo) {
        if (RecoverAttempts > 0)
            WriteLog("[看门狗] 已恢复到视频播放界面，恢复计数清零")
        NoVideoStart := 0
        RecoverAttempts := 0
        ToolTip("视频播放中，持续监控...")
        return
    }

    ; --- 看门狗：持续不在视频播放界面 ---
    now := A_TickCount
    if (NoVideoStart = 0) {
        NoVideoStart := now
        WriteLog("[看门狗] 未检测到视频播放界面，开始计时（" . WatchdogCfg.noVideoTimeoutMs . "ms 后尝试跳转下一节）")
        ToolTip("未检测到视频播放界面，看门狗计时中...")
        return
    }

    elapsed := now - NoVideoStart
    if (elapsed < WatchdogCfg.noVideoTimeoutMs) {
        remainSec := Round((WatchdogCfg.noVideoTimeoutMs - elapsed) / 1000)
        WriteLog("[看门狗] 仍未检测到视频播放界面，已等待 " . elapsed . "ms，" . remainSec . " 秒后尝试跳转")
        ToolTip("未检测到视频播放界面，" . remainSec . " 秒后自动跳转下一节...")
        return
    }

    ; 超时：先计数，超过上限直接退出；否则执行跳转并重新给一个完整计时周期
    RecoverAttempts += 1
    if (RecoverAttempts > WatchdogCfg.maxRecoverAttempts) {
        AbortScript("连续 " . (RecoverAttempts - 1) . " 次跳转下一节后仍未检测到视频播放界面，判定无法自动恢复")
        return
    }
    WriteLog("[看门狗] 连续 " . Round(elapsed / 1000) . " 秒未检测到视频播放界面，第 " . RecoverAttempts . "/" . WatchdogCfg.maxRecoverAttempts . " 次执行跳转下一节")
    ToolTip("看门狗：第 " . RecoverAttempts . "/" . WatchdogCfg.maxRecoverAttempts . " 次尝试跳转下一节...")
    NavigationModule.GoToNextVideo(TargetWindow, NavClicks)
    NoVideoStart := A_TickCount
    Sleep(5000)
}

; --- 看门狗终止：停止定时循环并退出脚本 ---
AbortScript(reason) {
    global Toggle
    Toggle := false
    SetTimer AutoStudyLoop, 0
    WriteLog("[看门狗] " . reason . "，脚本退出")
    ToolTip("脚本退出：" . reason)
    Sleep 3000
    ExitApp
}