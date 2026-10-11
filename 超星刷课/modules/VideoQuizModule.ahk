; modules/VideoQuizModule.ahk - 视频中随机弹出答题界面的自动作答模块
; Requires AutoHotkey v2.0
; 支持三种题型：判断题（对/错）、单选题（A~D 逐个试）、多选题（组合序列逐个试）

class VideoQuizModule {
    ; 处理视频中随机弹出的答题界面
    ; 流程：OCR 题目识别区判断题型 → 按题型生成候选答案组合
    ;      → 依次勾选并提交 → 答题界面仍存在则视为答错，换下一组合，直到通过或组合用尽
    ; 返回 true 表示本轮处理了答题（主循环跳过其余检测）
    static AnswerVideoQuiz(winTitle, quizArea, optionAreas, submitArea, wrongArea) {
        ; 1. 识别题型，生成候选答案组合（选项序号 1~4 对应 A~D）
        ScreenshotTool.CaptureGameArea(quizArea, "screenshots\quiz_title.png", winTitle)
        titleText := OcrTool.OcrToText("screenshots\quiz_title.png")
        combos := this.BuildCombos(titleText)
        if (combos.Length == 0) {
            return false
        }
        WriteLog("[AnswerVideoQuiz] 检测到答题界面 (OCR: " . titleText . "，题型候选 " . combos.Length . " 种)，开始答题")
        ToolTip("检测到答题界面，开始答题...")

        ; 2. 依次尝试每个候选组合：取消上一轮勾选 → 勾选本轮 → 提交 → 判定
        prevCombo := []
        for _, combo in combos {
            for _, idx in prevCombo   ; 取消上一轮已勾选的选项（点击为切换语义）
                this.ClickAreaCenter(winTitle, optionAreas[idx])
            for _, idx in combo       ; 勾选本轮组合
                this.ClickAreaCenter(winTitle, optionAreas[idx])
            prevCombo := combo
            Sleep 500
            this.ClickAreaCenter(winTitle, submitArea)
            WriteLog("[AnswerVideoQuiz] 选择 " . this.ComboLabel(combo) . " 并提交")
            Sleep 2500

            ; 3. 双重判定答错：错误提示区 OCR 到"错误"，或题目识别区仍能识别到答题界面
            ;    （错误提示可能短暂显示导致 OCR 为空，题目界面存续是更可靠的依据）
            ScreenshotTool.CaptureGameArea(wrongArea, "screenshots\quiz_wrong.png", winTitle)
            wrongText := OcrTool.OcrToText("screenshots\quiz_wrong.png")
            ScreenshotTool.CaptureGameArea(quizArea, "screenshots\quiz_title.png", winTitle)
            reopenText := OcrTool.OcrToText("screenshots\quiz_title.png")
            quizStillOpen := this.BuildCombos(reopenText).Length > 0
            if (!InStr(wrongText, "错误") && !quizStillOpen) {
                WriteLog("[AnswerVideoQuiz] 答题通过（选项 " . this.ComboLabel(combo) . "），答题界面已关闭")
                return true
            }
            WriteLog("[AnswerVideoQuiz] 判定答错 (错误提示OCR: '" . wrongText . "' 界面OCR: '" . reopenText . "')，换下一组合")
        }

        ; 4. 组合全部尝试完毕仍未通过，本轮结束，下轮循环重新检测再从头试
        WriteLog("[AnswerVideoQuiz] 所有候选答案已尝试，等待下轮重试")
        return true
    }

    ; 根据题型 OCR 文本生成候选答案组合；无法识别题型时返回空数组
    static BuildCombos(titleText) {
        if (InStr(titleText, "多选")) {
            ; 多选题：先双选、再三选、最后全选
            return [
                [1,2], [1,3], [1,4], [2,3], [2,4], [3,4],
                [1,2,3], [1,2,4], [1,3,4], [2,3,4],
                [1,2,3,4]
            ]
        }
        if (InStr(titleText, "单选") || InStr(titleText, "选择题")) {
            return [[1], [2], [3], [4]]
        }
        if (InStr(titleText, "判断")) {
            ; 判断题：对/错两项，对应 A、B 选项位置
            return [[1], [2]]
        }
        return []
    }

    ; 组合序号转标签（如 [1,3] → "AC"）
    static ComboLabel(combo) {
        label := ""
        for _, idx in combo
            label .= Chr(64 + idx)
        return label
    }

    ; 辅助：点击区域中心点（区域为窗口比例）
    static ClickAreaCenter(winTitle, area) {
        WinGetClientPos &winX, &winY, &winW, &winH, winTitle
        clickX := winX + Round(winW * (area.x + area.w / 2))
        clickY := winY + Round(winH * (area.y + area.h / 2))
        MouseMove clickX, clickY, 3
        Sleep 150
        Click clickX, clickY
    }
}
