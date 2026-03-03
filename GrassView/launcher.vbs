Dim shell, skinPath, cmd
Set shell   = CreateObject("WScript.Shell")
skinPath    = CreateObject("Scripting.FileSystemObject").GetParentFolderName(WScript.ScriptFullName)

If WScript.Arguments.Count > 0 Then
    cmd = "powershell.exe -ExecutionPolicy Bypass -NoProfile -WindowStyle Hidden -NonInteractive" & _
          " -File """ & skinPath & "\FetchAndBuild.ps1""" & _
          " -WeeksOverride " & WScript.Arguments(0)
Else
    cmd = "powershell.exe -ExecutionPolicy Bypass -NoProfile -WindowStyle Hidden -NonInteractive" & _
          " -File """ & skinPath & "\FetchAndBuild.ps1"""
End If

shell.Run cmd, 0, False
