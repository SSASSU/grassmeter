# =============================================================
#  grassmeter - Settings.ps1
#  Opens a GUI dialog to edit Settings.inc
#  No external dependencies - uses built-in .NET / WinForms
# =============================================================
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()
[System.Windows.Forms.Application]::SetCompatibleTextRenderingDefault($false)

$root         = Split-Path -Parent $MyInvocation.MyCommand.Path
$settingsFile = Join-Path $root 'Settings.inc'

# ------------------------------------------------------------------
# Parse Settings.inc
# ------------------------------------------------------------------
$cfg = [ordered]@{
    GitHubUsername = ''
    GitHubToken    = ''
    ColorTheme     = 'Green'
    Opacity        = '200'
    CellSize       = '11'
    CellGap        = '2'
    Padding        = '14'
    WeeksToShow    = '52'
    Repo1          = ''
    Repo2          = ''
    Repo3          = ''
    AutoRefreshMin = '5'
}

if (Test-Path $settingsFile) {
    foreach ($line in [System.IO.File]::ReadAllLines($settingsFile, [System.Text.UTF8Encoding]::new($true))) {
        foreach ($key in $cfg.Keys) {
            if ($line -match "^$key\s*=\s*(.*)$") {
                $cfg[$key] = $Matches[1].Trim()
            }
        }
    }
}

# ------------------------------------------------------------------
# Colors
# ------------------------------------------------------------------
$clrBg      = [System.Drawing.Color]::FromArgb(22, 27, 34)
$clrBg2     = [System.Drawing.Color]::FromArgb(33, 38, 46)
$clrInput   = [System.Drawing.Color]::FromArgb(13, 17, 23)
$clrText    = [System.Drawing.Color]::FromArgb(201, 209, 217)
$clrMuted   = [System.Drawing.Color]::FromArgb(139, 148, 158)
$clrGreen   = [System.Drawing.Color]::FromArgb(35, 134, 54)
$clrBorder  = [System.Drawing.Color]::FromArgb(48, 54, 61)

# ------------------------------------------------------------------
# Helpers
# ------------------------------------------------------------------
function New-Label($text, $x, $y, $w = 110, $h = 22) {
    $l = New-Object System.Windows.Forms.Label
    $l.Text = $text; $l.Left = $x; $l.Top = $y; $l.Width = $w; $l.Height = $h
    $l.ForeColor = $clrMuted; $l.BackColor = [System.Drawing.Color]::Transparent
    $l.TextAlign = 'MiddleLeft'
    return $l
}

function New-TextBox($text, $x, $y, $w = 180) {
    $t = New-Object System.Windows.Forms.TextBox
    $t.Text = $text; $t.Left = $x; $t.Top = $y; $t.Width = $w
    $t.BackColor = $clrInput; $t.ForeColor = $clrText; $t.BorderStyle = 'FixedSingle'
    return $t
}

function New-Panel($x, $y, $w, $h) {
    $p = New-Object System.Windows.Forms.Panel
    $p.Left = $x; $p.Top = $y; $p.Width = $w; $p.Height = $h
    $p.BackColor = $clrBg2
    $p.BorderStyle = [System.Windows.Forms.BorderStyle]::None
    return $p
}

function New-SectionLabel($text, $x, $y) {
    $l = New-Object System.Windows.Forms.Label
    $l.Text = $text; $l.Left = $x; $l.Top = $y; $l.AutoSize = $true
    $l.ForeColor = $clrText
    $l.Font = New-Object System.Drawing.Font('Segoe UI', 9, [System.Drawing.FontStyle]::Bold)
    $l.BackColor = [System.Drawing.Color]::Transparent
    return $l
}

# ------------------------------------------------------------------
# Form
# ------------------------------------------------------------------
$form = New-Object System.Windows.Forms.Form
$form.Text            = 'grassmeter Settings'
$form.ClientSize      = New-Object System.Drawing.Size(400, 620)
$form.StartPosition   = 'CenterScreen'
$form.FormBorderStyle = 'FixedDialog'
$form.MaximizeBox     = $false
$form.MinimizeBox     = $false
$form.BackColor       = $clrBg
$form.ForeColor       = $clrText
$form.Font            = New-Object System.Drawing.Font('Segoe UI', 9)

$py = 12  # current Y position

# ------------------------------------------------------------------
# Section: GitHub
# ------------------------------------------------------------------
$form.Controls.Add((New-SectionLabel 'GitHub' 14 $py)); $py += 24

$pGitHub = New-Panel 10 $py 380 64; $form.Controls.Add($pGitHub); $py += 72
$pGitHub.Controls.Add((New-Label 'Username' 10 8))
$txtUser = New-TextBox $cfg['GitHubUsername'] 120 7 240
$pGitHub.Controls.Add($txtUser)
$pGitHub.Controls.Add((New-Label 'Token' 10 36))
$txtToken = New-TextBox $cfg['GitHubToken'] 120 35 240
$pGitHub.Controls.Add($txtToken)

# ------------------------------------------------------------------
# Section: Appearance
# ------------------------------------------------------------------
$form.Controls.Add((New-SectionLabel 'Appearance' 14 $py)); $py += 24

$pApp = New-Panel 10 $py 380 118; $form.Controls.Add($pApp); $py += 126
$pApp.Controls.Add((New-Label 'Theme' 10 8))
$cboTheme = New-Object System.Windows.Forms.ComboBox
$cboTheme.DropDownStyle = 'DropDownList'
$cboTheme.Left = 120; $cboTheme.Top = 7; $cboTheme.Width = 140
$cboTheme.BackColor = $clrInput; $cboTheme.ForeColor = $clrText; $cboTheme.FlatStyle = 'Flat'
@('Green','Purple','Blue','Red','Orange','Pink','Mono','Mint','Yellow','Cyan','Light') | ForEach-Object { $cboTheme.Items.Add($_) | Out-Null }
$idx = $cboTheme.Items.IndexOf($cfg['ColorTheme']); if ($idx -ge 0) { $cboTheme.SelectedIndex = $idx } else { $cboTheme.SelectedIndex = 0 }
$pApp.Controls.Add($cboTheme)

$pApp.Controls.Add((New-Label 'Opacity (0-255)' 10 36))
$txtOpacity = New-TextBox $cfg['Opacity'] 120 35 60; $pApp.Controls.Add($txtOpacity)

$pApp.Controls.Add((New-Label 'Cell Size (px)' 10 64))
$txtCellSize = New-TextBox $cfg['CellSize'] 120 63 55; $pApp.Controls.Add($txtCellSize)
$pApp.Controls.Add((New-Label 'Cell Gap (px)' 200 64))
$txtCellGap = New-TextBox $cfg['CellGap'] 310 63 55; $pApp.Controls.Add($txtCellGap)

$pApp.Controls.Add((New-Label 'Padding (px)' 10 92))
$txtPadding = New-TextBox $cfg['Padding'] 120 91 55; $pApp.Controls.Add($txtPadding)

# ------------------------------------------------------------------
# Section: Period
# ------------------------------------------------------------------
$form.Controls.Add((New-SectionLabel 'Period' 14 $py)); $py += 24

$pPeriod = New-Panel 10 $py 380 36; $form.Controls.Add($pPeriod); $py += 44
$pPeriod.Controls.Add((New-Label 'Weeks to show' 10 7))
$lblWeeksHint = New-Label '(52=1Y  26=6M  13=3M)' 200 7 170 22
$lblWeeksHint.ForeColor = [System.Drawing.Color]::FromArgb(88, 96, 105)
$pPeriod.Controls.Add($lblWeeksHint)
$txtWeeks = New-TextBox $cfg['WeeksToShow'] 120 7 55; $pPeriod.Controls.Add($txtWeeks)

# ------------------------------------------------------------------
# Section: Repositories
# ------------------------------------------------------------------
$form.Controls.Add((New-SectionLabel 'Repositories' 14 $py)); $py += 24

# Panel is background-only; TextBoxes go directly on the form to avoid panel clipping/interaction bugs
$repoAbsY = $py
$pRepo = New-Panel 10 $py 380 150; $form.Controls.Add($pRepo); $py += 158

$lblRepoHint = New-Label 'owner/repo format' 10 6 200 18
$lblRepoHint.ForeColor = [System.Drawing.Color]::FromArgb(88, 96, 105)
$lblRepoHint.Font = New-Object System.Drawing.Font('Segoe UI', 8)
$pRepo.Controls.Add($lblRepoHint)
$pRepo.Controls.Add((New-Label 'Repo 1' 10 32))
$pRepo.Controls.Add((New-Label 'Repo 2' 10 68))
$pRepo.Controls.Add((New-Label 'Repo 3' 10 104))

$txtRepo1 = New-TextBox $cfg['Repo1'] 90 ($repoAbsY + 30) 280
$txtRepo2 = New-TextBox $cfg['Repo2'] 90 ($repoAbsY + 66) 280
$txtRepo3 = New-TextBox $cfg['Repo3'] 90 ($repoAbsY + 102) 280
$form.Controls.Add($txtRepo1)
$form.Controls.Add($txtRepo2)
$form.Controls.Add($txtRepo3)
$pRepo.SendToBack()  # Panel goes behind form-level TextBoxes

# ------------------------------------------------------------------
# Section: CommitView
# ------------------------------------------------------------------
$form.Controls.Add((New-SectionLabel 'CommitView' 14 $py)); $py += 24

$pCommit = New-Panel 10 $py 380 36; $form.Controls.Add($pCommit); $py += 44
$pCommit.Controls.Add((New-Label 'Auto-refresh (min)' 10 7))
$lblARHint = New-Label '(0 = disabled)' 210 7 120 22
$lblARHint.ForeColor = [System.Drawing.Color]::FromArgb(88, 96, 105)
$pCommit.Controls.Add($lblARHint)
$txtAR = New-TextBox $cfg['AutoRefreshMin'] 170 7 55; $pCommit.Controls.Add($txtAR)

# ------------------------------------------------------------------
# Buttons
# ------------------------------------------------------------------
$py += 8
$btnSave = New-Object System.Windows.Forms.Button
$btnSave.Text      = 'Save & Refresh'
$btnSave.Left      = 130; $btnSave.Top = $py; $btnSave.Width = 140; $btnSave.Height = 32
$btnSave.BackColor = $clrGreen; $btnSave.ForeColor = $clrText; $btnSave.FlatStyle = 'Flat'
$btnSave.FlatAppearance.BorderSize = 0
$btnSave.Font = New-Object System.Drawing.Font('Segoe UI', 9, [System.Drawing.FontStyle]::Bold)
$form.Controls.Add($btnSave)

$btnCancel = New-Object System.Windows.Forms.Button
$btnCancel.Text      = 'Cancel'
$btnCancel.Left      = 282; $btnCancel.Top = $py; $btnCancel.Width = 80; $btnCancel.Height = 32
$btnCancel.BackColor = $clrBg2; $btnCancel.ForeColor = $clrMuted; $btnCancel.FlatStyle = 'Flat'
$btnCancel.FlatAppearance.BorderSize = 1
$btnCancel.FlatAppearance.BorderColor = $clrBorder
$form.Controls.Add($btnCancel)

# ------------------------------------------------------------------
# Save action
# ------------------------------------------------------------------
$btnSave.Add_Click({
    $newCfg = @{
        GitHubUsername = $txtUser.Text.Trim()
        GitHubToken    = $txtToken.Text.Trim()
        ColorTheme     = if ($cboTheme.SelectedItem) { $cboTheme.SelectedItem.ToString() } else { 'Green' }
        Opacity        = $txtOpacity.Text.Trim()
        CellSize       = $txtCellSize.Text.Trim()
        CellGap        = $txtCellGap.Text.Trim()
        Padding        = $txtPadding.Text.Trim()
        WeeksToShow    = $txtWeeks.Text.Trim()
        Repo1          = $txtRepo1.Text.Trim()
        Repo2          = $txtRepo2.Text.Trim()
        Repo3          = $txtRepo3.Text.Trim()
        AutoRefreshMin = $txtAR.Text.Trim()
    }

    $content = @"
; =====================================================
;  grassmeter - Settings.inc
;  Managed by Settings.ps1 - or edit manually
; =====================================================

[Variables]

; GitHub Account
GitHubUsername=$($newCfg.GitHubUsername)
GitHubToken=$($newCfg.GitHubToken)

; Color theme: Green / Purple / Blue / Red / Orange / Pink / Mono / Mint / Yellow / Cyan / Light
ColorTheme=$($newCfg.ColorTheme)

; Opacity (0-255, 200 = slightly transparent)
Opacity=$($newCfg.Opacity)

; Cell size in pixels (recommended: 10-14)
CellSize=$($newCfg.CellSize)
; Gap between cells (recommended: 2-3)
CellGap=$($newCfg.CellGap)
; Widget outer padding
Padding=$($newCfg.Padding)

; Weeks to display (52 = 1 year, 26 = 6 months, 13 = 3 months)
WeeksToShow=$($newCfg.WeeksToShow)

; Repositories to track (owner/repo format, leave blank to hide)
Repo1=$($newCfg.Repo1)
Repo2=$($newCfg.Repo2)
Repo3=$($newCfg.Repo3)

; CommitView auto-refresh interval in minutes (0 = disabled)
AutoRefreshMin=$($newCfg.AutoRefreshMin)
"@

    [System.IO.File]::WriteAllText($settingsFile, $content, [System.Text.UTF8Encoding]::new($true))

    # Refresh all three skins directly (bypass VBS to avoid path/encoding issues)
    $psArgs = '-ExecutionPolicy Bypass -NoProfile -WindowStyle Hidden -NonInteractive'
    @(
        @{ ps1 = 'GrassView\FetchAndBuild.ps1'; skin = 'GrassView' },
        @{ ps1 = 'CommitView\FetchCommits.ps1'; skin = 'CommitView' },
        @{ ps1 = 'IssueView\FetchIssues.ps1';  skin = 'IssueView' }
    ) | ForEach-Object {
        $ps1  = Join-Path $root $_.ps1
        $skin = Join-Path $root $_.skin
        if (Test-Path $ps1) {
            Start-Process 'powershell.exe' -ArgumentList "$psArgs -File `"$ps1`" -SkinPath `"$skin`"" -WindowStyle Hidden
        }
    }

    $form.Close()
})

$btnCancel.Add_Click({ $form.Close() })
$form.CancelButton = $btnCancel

# ------------------------------------------------------------------
# Show
# ------------------------------------------------------------------
$form.ShowDialog() | Out-Null
