; ScreenshotTool.ahk - 截图模块
; Requires AutoHotkey v2.0
#Include ../../home/ahk2_lib/CGdip.ahk ; 确保路径正确，或者直接将CGdip.ahk放在同级目录并改为 #Include CGdip.ahk

class ScreenshotTool {
    static pToken := 0
    
    static InitGdip() {
        if !this.pToken {
            if !DllCall("LoadLibrary", "str", "gdiplus") {
                MsgBox "无法加载Gdip库，请确保系统已安装GDI+"
                return false
            }
            si := Buffer(A_PtrSize = 8 ? 24 : 16, 0)
            NumPut("uint", 1, si)
            if DllCall("gdiplus\GdiplusStartup", "ptr*", &pToken:=0, "ptr", si, "ptr", 0) != 0 {
                MsgBox "GDI+初始化失败"
                return false
            }
            this.pToken := pToken
        }
        return true
    }
    
    static CaptureArea(x, y, width, height, filename := "") {
        if !this.InitGdip() {
            return false
        }
        
        hdcScreen := DllCall("GetDC", "ptr", 0, "ptr")
        hdcMem := DllCall("CreateCompatibleDC", "ptr", hdcScreen, "ptr")
        hBitmap := DllCall("CreateCompatibleBitmap", "ptr", hdcScreen, "int", width, "int", height, "ptr")
        DllCall("SelectObject", "ptr", hdcMem, "ptr", hBitmap)
        
        DllCall("BitBlt", "ptr", hdcMem, "int", 0, "int", 0, "int", width, "int", height,
                "ptr", hdcScreen, "int", x, "int", y, "uint", 0x00CC0020)
        
        if (filename = "") {
            folderPath := "screenshots"
            if !DirExist(folderPath) {
                DirCreate(folderPath)
            }
            TimeString := FormatTime(, "yyyyMMdd_HHmmss")
            filename := folderPath . "\screenshot_" . TimeString . ".png"
        }

        pBitmap := 0
        DllCall("gdiplus\GdipCreateBitmapFromHBITMAP", "ptr", hBitmap, "ptr", 0, "ptr*", &pBitmap)

        encoderCLSID := Buffer(16)
        DllCall("ole32\CLSIDFromString", "wstr", "{557CF406-1A04-11D3-9A73-0000F81EF32E}", "ptr", encoderCLSID)

        filenameW := filename
        if DllCall("gdiplus\GdipSaveImageToFile", "ptr", pBitmap, "ptr", StrPtr(filenameW), 
                "ptr", encoderCLSID, "ptr", 0) = 0 {
            success := true
        } else {
            success := false
        }

        if pBitmap {
            DllCall("gdiplus\GdipDisposeImage", "ptr", pBitmap)
        }
        DllCall("DeleteObject", "ptr", hBitmap)
        DllCall("DeleteDC", "ptr", hdcMem)
        DllCall("ReleaseDC", "ptr", 0, "ptr", hdcScreen)

        return success
    }
    
    ; 修改为支持传入窗口标题
    static CaptureGameArea(areaObj, filename := "", winTitle := "ahk_exe chrome.exe") {
        if !WinExist(winTitle) {
            return false
        }
        ; 确保目录存在
        if (filename != "") {
            dir := RegExReplace(filename, "^(.*)\\[^\\]+$", "$1")
            if (dir != "" && !DirExist(dir)) {
                DirCreate(dir)
            }
        }
        WinGetClientPos &clientX, &clientY, &clientW, &clientH, winTitle
        x := clientX + Round(clientW * areaObj.x)
        y := clientY + Round(clientH * areaObj.y)
        width := Round(clientW * areaObj.w)
        height := Round(clientH * areaObj.h)
        
        return this.CaptureArea(x, y, width, height, filename)
    }
}