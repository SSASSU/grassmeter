Dim fso, root
Set fso  = CreateObject("Scripting.FileSystemObject")
root     = fso.GetParentFolderName(WScript.ScriptFullName)

Dim launchers(2)
launchers(0) = root & "\GrassView\launcher.vbs"
launchers(1) = root & "\CommitView\launcher_commits.vbs"
launchers(2) = root & "\IssueView\launcher_issues.vbs"

Dim shell, i
Set shell = CreateObject("WScript.Shell")
For i = 0 To 2
    If fso.FileExists(launchers(i)) Then
        shell.Run "wscript.exe """ & launchers(i) & """", 0, False
    End If
Next
