Dim shell, skinPath, cmd
Set shell   = CreateObject("WScript.Shell")
skinPath    = CreateObject("Scripting.FileSystemObject").GetParentFolderName(WScript.ScriptFullName)
cmd = "powershell.exe -ExecutionPolicy Bypass -NoProfile -WindowStyle Hidden -NonInteractive" & _
      " -File """ & skinPath & "\FetchCommits.ps1"""
shell.Run cmd, 0, False
