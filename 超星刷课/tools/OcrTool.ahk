; OcrTool.ahk - 文字识别模块
; Requires AutoHotkey v2.0
#Include ../../home/ahk2_lib/RapidOcr/RapidOcr.ahk ; 请确保路径与你的实际环境一致

class OcrTool {
    static OcrFromFile(imagePath, includePosition := true, includeConfidence := false) {
        if !FileExist(imagePath) {
            return []
        }
        try {
            ocr := RapidOcr()
            res := ocr.ocr_from_file(imagePath,, true)
            if !res || res.Length = 0 {
                return []
            }
            ocrResults := []
            Loop res.Length {
                block := res[A_Index]
                text := block.text
                result := Map()
                result["text"] := text
                if includePosition && block.HasProp("boxPoint") {
                    points := block.boxPoint
                    if points.Length >= 4 {
                        result["x"] := points[1].x
                        result["y"] := points[1].y
                    }
                }
                if includeConfidence && block.HasProp("score") {
                    result["confidence"] := block.score
                }
                result["line"] := A_Index
                ocrResults.Push(result)
            }
            return ocrResults
        } catch Error as e {
            return []
        }
    }
    
    static OcrToText(imagePath, separator := "`n") {
        results := this.OcrFromFile(imagePath, false, false)
        if results.Length = 0 {
            return ""
        }
        textLines := ""
        for index, result in results {
            if index > 1
                textLines .= separator
            textLines .= result["text"]
        }
        return textLines
    }
}