Set WshShell = CreateObject("WScript.Shell")
scriptDir = CreateObject("Scripting.FileSystemObject").GetParentFolderName(WScript.ScriptFullName)
psScript = scriptDir & "\codex-reset-tray.ps1"
WshShell.Run "pwsh -NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File """ & psScript & """", 0, False
