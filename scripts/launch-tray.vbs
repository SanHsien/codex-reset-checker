Set WshShell = CreateObject("WScript.Shell")
scriptDir = CreateObject("Scripting.FileSystemObject").GetParentFolderName(WScript.ScriptFullName)
psScript = scriptDir & "\codex-reset-tray.ps1"

' Prefer PowerShell 7 (pwsh); fall back to the built-in Windows PowerShell 5.1 when pwsh is not on PATH.
psHost = "powershell.exe"
If WshShell.Run("cmd /c where pwsh >nul 2>nul", 0, True) = 0 Then psHost = "pwsh"

If WScript.Arguments.Count > 0 Then
    If WScript.Arguments(0) = "--print-shell" Then
        WScript.Echo psHost
        WScript.Quit 0
    End If
End If

WshShell.Run psHost & " -NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File """ & psScript & """", 0, False
