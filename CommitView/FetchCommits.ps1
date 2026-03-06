# =============================================================
#  GitHub CommitView for Rainmeter
#  FetchCommits.ps1
#  Fetches latest commits per repo and generates CommitView.ini
# =============================================================
param([string]$SkinPath = '')

if (-not $SkinPath) { $SkinPath = Split-Path -Parent $MyInvocation.MyCommand.Path }
$Log = Join-Path $SkinPath 'debug_commits.log'

[System.IO.File]::WriteAllText($Log, '', [System.Text.UTF8Encoding]::new($false))
function L($m) {
    [System.IO.File]::AppendAllText($Log, "[$(Get-Date -f HH:mm:ss)] $m`r`n", [System.Text.UTF8Encoding]::new($false))
}
L '=== CommitView v1.2 ==='

$OutputIni = Join-Path $SkinPath 'CommitView.ini'

# ------------------------------------------------------------------
# Parse Settings.inc
# ------------------------------------------------------------------
$Token = ''; $Repo1 = ''; $Repo2 = ''; $Repo3 = ''; $AutoRefreshMin = 0; $Theme = 'Green'

$sf = Join-Path (Split-Path $SkinPath -Parent) 'Settings.inc'
if (Test-Path $sf) {
    foreach ($line in [System.IO.File]::ReadAllLines($sf, [System.Text.UTF8Encoding]::new($true))) {
        if ($line -match '^GitHubToken\s*=\s*(.+)$')      { $Token         = $Matches[1].Trim() }
        if ($line -match '^Repo1\s*=\s*(.+)$')            { $Repo1         = $Matches[1].Trim() }
        if ($line -match '^Repo2\s*=\s*(.+)$')            { $Repo2         = $Matches[1].Trim() }
        if ($line -match '^Repo3\s*=\s*(.+)$')            { $Repo3         = $Matches[1].Trim() }
        if ($line -match '^AutoRefreshMin\s*=\s*(\d+)$')  { $AutoRefreshMin = [int]$Matches[1] }
        if ($line -match '^ColorTheme\s*=\s*(.+)$')       { $Theme         = $Matches[1].Trim() }
    }
    L 'Settings.inc loaded'
} else {
    L 'WARNING: Settings.inc not found'
}
if ($AutoRefreshMin -gt 0 -and $AutoRefreshMin -lt 1) { $AutoRefreshMin = 1 }

# Theme accent color for section divider lines (medium brightness, semi-transparent)
$cAccent = switch ($Theme) {
    'Purple' { '155,100,240,220' }
    'Blue'   { '40,125,245,220'  }
    'Red'    { '220,58,58,220'   }
    'Orange' { '235,125,0,220'   }
    'Pink'   { '235,0,140,220'   }
    'Mono'   { '155,155,155,220' }
    default  { '50,185,80,220'   }  # Green
}
L "Token=$(if($Token){'set'}else{'NOT SET'})  Repo1=$Repo1  Repo2=$Repo2  Repo3=$Repo3  AutoRefreshMin=$AutoRefreshMin  Theme=$Theme"

if ($Token -eq '' -or $Token -eq 'ghp_your_token_here') { L 'ERROR: GitHubToken not set'; exit 1 }

# ------------------------------------------------------------------
# Helpers
# ------------------------------------------------------------------
$Headers = @{
    Authorization = "Bearer $Token"
    'User-Agent'  = 'Rainmeter-GitHubGrass/1.0'
}

function Get-RelativeTime($dateStr) {
    $diff = (Get-Date).ToUniversalTime() - [datetime]::Parse($dateStr).ToUniversalTime()
    if    ($diff.TotalMinutes -lt 60) { return "$([int]$diff.TotalMinutes)m ago" }
    elseif($diff.TotalHours   -lt 24) { return "$([int]$diff.TotalHours)h ago"   }
    elseif($diff.TotalDays    -lt 7)  { return "$([int]$diff.TotalDays)d ago"    }
    else                               { return "$([int]($diff.TotalDays/7))w ago" }
}

# ------------------------------------------------------------------
# Fetch up to 10 commits per repo
# ------------------------------------------------------------------
$Rows = [System.Collections.Generic.List[hashtable]]::new()

# Ensure TLS 1.2 for GitHub API
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12

$configuredRepos = @($Repo1, $Repo2, $Repo3) | Where-Object { $_ -ne '' }
$successCount    = 0

foreach ($repo in $configuredRepos) {
    L "Fetching: $repo"
    try {
        $url  = 'https://api.github.com/repos/' + $repo + '/commits?per_page=5'
        # Use WebClient with explicit UTF-8 to correctly decode Korean/CJK commit messages
        $wc   = New-Object System.Net.WebClient
        $wc.Encoding = [System.Text.Encoding]::UTF8
        foreach ($key in $Headers.Keys) { $wc.Headers[$key] = $Headers[$key] }
        $commits = ($wc.DownloadString($url)) | ConvertFrom-Json
        $name    = ($repo -split '/')[1]
        $ghUrl   = 'https://github.com/' + $repo
        foreach ($c in $commits) {
            $msg    = ($c.commit.message -split "`n")[0].Trim()
            $rel    = Get-RelativeTime $c.commit.author.date
            $author = if ($c.author -and $c.author.login) { $c.author.login } else { $c.commit.author.name }
            $Rows.Add(@{ name=$name; msg=$msg; time=$rel; url=$ghUrl; author=$author })
        }
        $successCount++
        L "  OK  $($commits.Count) commits"
    } catch {
        L ('  FAIL: ' + $_.Exception.Message)
    }
}

L ("Total rows: $($Rows.Count)  success=$successCount/$($configuredRepos.Count)")

# Guard: keep old INI only if ALL repos failed (network/token issue)
# Partial failure → regenerate with successful repos so the widget stays accurate
if ($successCount -eq 0 -and $configuredRepos.Count -gt 0) {
    L 'WARNING: all repos failed - keeping existing CommitView.ini unchanged'
    L '=== DONE (no update) ==='
    exit 0
}
if ($successCount -lt $configuredRepos.Count) {
    L "WARNING: $($configuredRepos.Count - $successCount) repo(s) failed - regenerating with available data"
}

# ------------------------------------------------------------------
# Layout constants
# ------------------------------------------------------------------
$WW          = 500
$Padding     = 14
$HeaderH     = 20          # repo section header height
$RowH        = 26
$AuthorColW  = 90
$MsgColX     = $Padding + $AuthorColW + 8   # = 112
$TimeColW    = 68
$TimeColX    = $WW - $Padding - $TimeColW   # = 418
$MsgColW     = $TimeColX - $MsgColX - 8    # = 298
$BtnAreaH    = 28

# Group rows by repo (order preserved; repos are fetched sequentially)
$Groups   = [System.Collections.Generic.List[hashtable]]::new()
$curGroup = $null
foreach ($row in $Rows) {
    if ($null -eq $curGroup -or $curGroup.name -ne $row.name) {
        $curGroup = @{ name=$row.name; url=$row.url; rows=[System.Collections.Generic.List[hashtable]]::new() }
        $Groups.Add($curGroup)
    }
    $curGroup.rows.Add($row)
}

$WH = $Padding * 2 + $Groups.Count * $HeaderH + $Rows.Count * $RowH + $BtnAreaH

$cBG     = '13,17,23,240'
$cStroke = '48,54,61,255'

# ------------------------------------------------------------------
# Generate CommitView.ini
# ------------------------------------------------------------------
$lines = [System.Collections.Generic.List[string]]::new()
function W($s) { $lines.Add($s) }

W ('; CommitView - Generated ' + (Get-Date -f 'yyyy-MM-dd HH:mm'))
W '; DO NOT EDIT - regenerated by run_commits.bat'
W ''
W '[Rainmeter]'
W 'Update=60000'
W 'AccurateText=1'
W ''
W '[Variables]'
W ('SkinFolder=' + $SkinPath)
W ''

# Background
W '[MeterBG]'
W 'Meter=Shape'
W 'X=0'
W 'Y=0'
W ('Shape=Rectangle 0,0,' + $WW + ',' + $WH + ',8 | Fill Color ' + $cBG + ' | StrokeWidth 1 | Stroke Color ' + $cStroke)
W ''

# Repo sections: header + commits
$gi  = 0   # group index (for unique meter names)
$ri  = 0   # row index
$y   = $Padding
$lineStartX = $Padding + 130 + 8   # line begins after text area
$lineEndX   = $WW - $Padding

foreach ($g in $Groups) {
    # -- Section header: repo name (left) + divider line (right) --
    $lineY = $y + [int]($HeaderH / 2)

    W "[MHdr${gi}Line]"
    W 'Meter=Shape'
    W "X=$lineStartX"
    W "Y=$lineY"
    W ('Shape=Line 0,0,' + ($lineEndX - $lineStartX) + ',0 | StrokeWidth 1 | Stroke Color ' + $cAccent)
    W ''

    W "[MHdr${gi}Name]"
    W 'Meter=String'
    W "X=$Padding"
    W "Y=$y"
    W 'W=130'
    W "H=$HeaderH"
    W "Text=$($g.name)"
    W 'FontColor=175,185,195,255'
    W 'FontSize=9'
    W 'FontFace=Segoe UI'
    W 'StringStyle=Bold'
    W 'AntiAlias=1'
    W ('LeftMouseUpAction=["' + $g.url + '"]')
    W ''

    $y += $HeaderH

    # -- Commit rows for this repo --
    foreach ($row in $g.rows) {
        $action = '["' + $row.url + '"]'

        W "[MRow${ri}Author]"
        W 'Meter=String'
        W "X=$Padding"
        W "Y=$y"
        W "W=$AuthorColW"
        W "H=$RowH"
        W "Text=$($row.author)"
        W 'FontColor=140,150,160,255'
        W 'FontSize=10'
        W 'FontFace=Segoe UI'
        W 'AntiAlias=1'
        W 'ClipString=2'
        W "LeftMouseUpAction=$action"
        W ''

        W "[MRow${ri}Msg]"
        W 'Meter=String'
        W "X=$MsgColX"
        W "Y=$y"
        W "W=$MsgColW"
        W "H=$RowH"
        W "Text=$($row.msg)"
        W 'FontColor=139,148,158,255'
        W 'FontSize=10'
        W 'FontFace=Segoe UI'
        W 'AntiAlias=1'
        W 'ClipString=2'
        W "LeftMouseUpAction=$action"
        W ''

        W "[MRow${ri}Time]"
        W 'Meter=String'
        W "X=$TimeColX"
        W "Y=$y"
        W "W=$TimeColW"
        W "H=$RowH"
        W "Text=$($row.time)"
        W 'FontColor=88,96,105,200'
        W 'FontSize=9'
        W 'FontFace=Segoe UI'
        W 'AntiAlias=1'
        W "LeftMouseUpAction=$action"
        W ''

        $y += $RowH
        $ri++
    }

    $gi++
}

# Auto-refresh measure (hidden, fires every AutoRefreshMin minutes)
if ($AutoRefreshMin -ge 1) {
    W '[MAutoRefresh]'
    W 'Measure=Calc'
    W 'Formula=0'
    W "UpdateDivider=$AutoRefreshMin"
    W ('OnUpdateAction=["wscript.exe" "#CURRENTPATH#launcher_commits.vbs"]')
    W ''
}

# Icon buttons - bottom-left
$ry  = $y + [int](($BtnAreaH - 20) / 2)
$rix = $Padding + 26

W '[MSettings]'
W 'Meter=Image'
W 'ImageName=#ROOTCONFIGPATH#@Resources\Icons\settings.png'
W "X=$Padding"
W "Y=$ry"
W 'W=20'
W 'H=20'
W ('LeftMouseUpAction=["wscript.exe" "#ROOTCONFIGPATH#launch_settings.vbs"]')
W 'ToolTipText=Open Settings'
W ''

W '[MRefresh]'
W 'Meter=Image'
W 'ImageName=#ROOTCONFIGPATH#@Resources\Icons\refresh.png'
W "X=$rix"
W "Y=$ry"
W 'W=20'
W 'H=20'
W ('LeftMouseUpAction=["wscript.exe" "#CURRENTPATH#launcher_commits.vbs"]')
W 'ToolTipText=Click to reload commits'
W ''

# ------------------------------------------------------------------
# Save - write to temp then rename atomically to prevent partial reads
# ------------------------------------------------------------------
$content = [string]::Join("`r`n", $lines)
$tempIni = $OutputIni + '.tmp'
[System.IO.File]::WriteAllText($tempIni, $content, [System.Text.Encoding]::Unicode)
Move-Item -Path $tempIni -Destination $OutputIni -Force
L ('Saved: ' + $OutputIni + '  groups=' + $Groups.Count + '  rows=' + $Rows.Count + '  WH=' + $WH)

# ------------------------------------------------------------------
# Trigger Rainmeter skin refresh
# ------------------------------------------------------------------
$config  = (Split-Path (Split-Path $SkinPath -Parent) -Leaf) + '\' + (Split-Path $SkinPath -Leaf)
$iniFile = 'CommitView.ini'
$rmExe   = "$env:ProgramFiles\Rainmeter\Rainmeter.exe"
if (-not (Test-Path $rmExe)) { $rmExe = "${env:ProgramFiles(x86)}\Rainmeter\Rainmeter.exe" }
if (Test-Path $rmExe) {
    Start-Process $rmExe -ArgumentList "!Refresh `"$config`" `"$iniFile`""
    L "Rainmeter refresh triggered: $config\$iniFile"
} else {
    L 'WARNING: Rainmeter.exe not found'
}

L '=== DONE ==='
