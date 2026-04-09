# =============================================================
#  GitHub IssueView for Rainmeter
#  FetchIssues.ps1
#  Fetches open issues & PRs per repo and generates IssueView.ini
# =============================================================
param([string]$SkinPath = '')

if (-not $SkinPath) { $SkinPath = Split-Path -Parent $MyInvocation.MyCommand.Path }
$Log = Join-Path $SkinPath 'debug_issues.log'

[System.IO.File]::WriteAllText($Log, '', [System.Text.UTF8Encoding]::new($false))
function L($m) {
    [System.IO.File]::AppendAllText($Log, "[$(Get-Date -f HH:mm:ss)] $m`r`n", [System.Text.UTF8Encoding]::new($false))
}
L '=== IssueView v1.1 ==='

# ------------------------------------------------------------------
# Concurrent execution guard (lock file)
# ------------------------------------------------------------------
$LockFile = Join-Path $SkinPath 'fetch_issues.lock'
if (Test-Path $LockFile) {
    $lockAge = (Get-Date) - (Get-Item $LockFile).LastWriteTime
    if ($lockAge.TotalMinutes -lt 3) {
        L 'WARNING: another instance is running (lock file exists) - skipping'
        exit 0
    }
    L 'WARNING: stale lock file detected - removing'
}
[System.IO.File]::WriteAllText($LockFile, (Get-Date).ToString(), [System.Text.UTF8Encoding]::new($false))
try {

$OutputIni = Join-Path $SkinPath 'IssueView.ini'

# ------------------------------------------------------------------
# Parse Settings.inc
# ------------------------------------------------------------------
$Token = ''; $Repo1 = ''; $Repo2 = ''; $Repo3 = ''; $Theme = 'Green'

$sf = Join-Path (Split-Path $SkinPath -Parent) 'Settings.inc'
if (Test-Path $sf) {
    foreach ($line in [System.IO.File]::ReadAllLines($sf, [System.Text.UTF8Encoding]::new($true))) {
        if ($line -match '^GitHubToken\s*=\s*(.+)$')  { $Token = $Matches[1].Trim() }
        if ($line -match '^Repo1\s*=\s*(.+)$')        { $Repo1 = $Matches[1].Trim() }
        if ($line -match '^Repo2\s*=\s*(.+)$')        { $Repo2 = $Matches[1].Trim() }
        if ($line -match '^Repo3\s*=\s*(.+)$')        { $Repo3 = $Matches[1].Trim() }
        if ($line -match '^ColorTheme\s*=\s*(.+)$')   { $Theme = $Matches[1].Trim() }
    }
    L 'Settings.inc loaded'
} else { L 'WARNING: Settings.inc not found' }

if ($Token -eq '' -or $Token -match '^ghp_x+$' -or $Token -eq 'ghp_your_token_here') { L 'ERROR: GitHubToken not set'; exit 1 }

# ------------------------------------------------------------------
# Theme colors
# ------------------------------------------------------------------
$cAccent = switch ($Theme) {
    'Purple' { '155,100,240,220' }
    'Blue'   { '40,125,245,220'  }
    'Red'    { '220,58,58,220'   }
    'Orange' { '235,125,0,220'   }
    'Pink'   { '235,0,140,220'   }
    'Mono'   { '155,155,155,220' }
    'Light'  { '48,161,78,220'   }
    'Mint'   { '0,188,160,220'   }
    'Yellow' { '220,195,0,220'   }
    'Cyan'   { '0,195,235,220'   }
    default  { '50,185,80,220'   }
}
# Issue badge: GitHub green (always), PR badge: purple (always) - visually distinct
$cIssue = '35,134,54,255'
$cPR    = '130,80,255,255'

L "Token=$(if($Token){'set'}else{'NOT SET'})  Repos=$Repo1,$Repo2,$Repo3  Theme=$Theme"

# ------------------------------------------------------------------
# Helpers
# ------------------------------------------------------------------
$Headers = @{
    Authorization = "Bearer $Token"
    'User-Agent'  = 'Rainmeter-GitHubGrass/1.0'
}
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12

function Get-RelativeTime($dateStr) {
    $diff = (Get-Date).ToUniversalTime() - [datetime]::Parse($dateStr).ToUniversalTime()
    if    ($diff.TotalMinutes -lt 60) { return "$([int]$diff.TotalMinutes)m ago" }
    elseif($diff.TotalHours   -lt 24) { return "$([int]$diff.TotalHours)h ago"   }
    elseif($diff.TotalDays    -lt 7)  { return "$([int]$diff.TotalDays)d ago"    }
    else                               { return "$([int]($diff.TotalDays/7))w ago" }
}

# ------------------------------------------------------------------
# Fetch issues & PRs (up to 5 each) per repo
# ------------------------------------------------------------------
$Groups      = [System.Collections.Generic.List[hashtable]]::new()
$configuredRepos = @($Repo1, $Repo2, $Repo3) | Where-Object { $_ -ne '' }
$successCount = 0
$totalIssues  = 0
$totalPRs     = 0

foreach ($repo in $configuredRepos) {
    L "Fetching: $repo"
    $repoName = ($repo -split '/')[1]
    $ghUrl    = 'https://github.com/' + $repo
    $issues   = @()
    $prs      = @()

    try {
        # /issues endpoint returns both issues and PRs; PRs have a 'pull_request' property
        $url = 'https://api.github.com/repos/' + $repo + '/issues?state=open&per_page=20'
        $wc  = New-Object System.Net.WebClient
        $wc.Encoding = [System.Text.Encoding]::UTF8
        foreach ($k in $Headers.Keys) { $wc.Headers[$k] = $Headers[$k] }
        $raw = ($wc.DownloadString($url)) | ConvertFrom-Json

        foreach ($item in $raw) {
            $isPR = $item.PSObject.Properties.Name -contains 'pull_request'
            $row  = @{
                num   = $item.number
                title = ($item.title -replace '#', '＃')
                time  = Get-RelativeTime $item.created_at
                url   = $item.html_url
                type  = if ($isPR) { 'PR' } else { 'I' }
            }
            if ($isPR) { $prs    += $row }
            else        { $issues += $row }
        }

        $issues = $issues | Select-Object -First 5
        $prs    = $prs    | Select-Object -First 5
        $totalIssues += $issues.Count
        $totalPRs    += $prs.Count
        $successCount++
        L "  OK  issues=$($issues.Count)  prs=$($prs.Count)"
    } catch {
        L ('  FAIL: ' + $_.Exception.Message)
        continue
    }

    $Groups.Add(@{ name=$repoName; url=$ghUrl; issues=$issues; prs=$prs })
}

L "Total: issues=$totalIssues  PRs=$totalPRs  success=$successCount/$($configuredRepos.Count)"

# Guard: keep old INI only if ALL repos failed (network/token issue)
if ($successCount -eq 0 -and $configuredRepos.Count -gt 0) {
    L 'WARNING: all repos failed - keeping existing IssueView.ini unchanged'
    L '=== DONE (no update) ==='
    exit 0
}
if ($successCount -lt $configuredRepos.Count) {
    L "WARNING: $($configuredRepos.Count - $successCount) repo(s) failed - regenerating with available data"
}

# ------------------------------------------------------------------
# Layout constants
# ------------------------------------------------------------------
$WW        = 500
$Padding   = 14
$HeaderH   = 22
$RowH      = 26
$TypeColW  = 26    # "I" or "PR"
$NumColW   = 44    # "#1234"
$AgeColW   = 68
$TitleColX = $Padding + $TypeColW + $NumColW + 4
$AgeColX   = $WW - $Padding - $AgeColW
$TitleColW = $AgeColX - $TitleColX - 6
$SummaryH  = 24
$BtnAreaH  = 28

$totalRows = $totalIssues + $totalPRs
$contentH  = if ($Groups.Count -eq 0) { 40 } else { $Groups.Count * $HeaderH + $totalRows * $RowH }
$WH        = $Padding * 2 + $contentH + $SummaryH + $BtnAreaH
$lineEndX  = $WW - $Padding

$isLight   = ($Theme -eq 'Light')
$cBG       = if ($isLight) { '245,247,250,240' } else { '13,17,23,240' }
$cStroke   = if ($isLight) { '208,215,222,255' } else { '48,54,61,255' }
$cTextName = if ($isLight) { '36,41,47,255'    } else { '175,185,195,255' }
$cTextBody = if ($isLight) { '57,62,68,255'    } else { '139,148,158,255' }
$cTextDim  = if ($isLight) { '110,119,129,200' } else { '88,96,105,200' }

# ------------------------------------------------------------------
# Generate IssueView.ini
# ------------------------------------------------------------------
$lines = [System.Collections.Generic.List[string]]::new()
function W($s) { $lines.Add($s) }

W ('; IssueView - Generated ' + (Get-Date -f 'yyyy-MM-dd HH:mm'))
W '; DO NOT EDIT - regenerated by run_issues.bat'
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

$gi = 0
$ri = 0
$y  = $Padding

if ($Groups.Count -eq 0) {
    W '[MEmpty]'
    W 'Meter=String'
    W "X=$Padding"
    W "Y=$y"
    W "W=$($WW - $Padding * 2)"
    W 'H=40'
    W 'Text=No open issues or pull requests'
    W 'FontColor=88,96,105,200'
    W 'FontSize=10'
    W 'FontFace=Segoe UI'
    W 'AntiAlias=1'
    W ''
    $y += 40
} else {
    foreach ($g in $Groups) {
        # Section header: repo name (left) + divider line (right)
        $lineY = $y + [int]($HeaderH / 2)

        W "[MHdr${gi}Line]"
        W 'Meter=Shape'
        W "X=$TitleColX"
        W "Y=$lineY"
        W ('Shape=Line 0,0,' + ($lineEndX - $TitleColX) + ',0 | StrokeWidth 1 | Stroke Color ' + $cAccent)
        W ''

        W "[MHdr${gi}Name]"
        W 'Meter=String'
        W "X=$Padding"
        W "Y=$y"
        W 'W=130'
        W "H=$HeaderH"
        W "Text=$($g.name)"
        W "FontColor=$cTextName"
        W 'FontSize=9'
        W 'FontFace=Segoe UI'
        W 'StringStyle=Bold'
        W 'AntiAlias=1'
        W 'ClipString=2'
        W ('LeftMouseUpAction=["' + $g.url + '/issues"]')
        W ''

        $y += $HeaderH

        # Issues first, then PRs
        $allRows = @()
        foreach ($issue in $g.issues) { $allRows += $issue }
        foreach ($pr    in $g.prs)    { $allRows += $pr    }

        foreach ($row in $allRows) {
            $action    = '["' + $row.url + '"]'
            $isIssue   = ($row.type -eq 'I')
            $typeTxt   = $row.type
            $typeColor = if ($isIssue) { $cIssue } else { $cPR }
            $numTxt    = '#' + $row.num

            W "[MRow${ri}Type]"
            W 'Meter=String'
            W "X=$Padding"
            W "Y=$y"
            W "W=$TypeColW"
            W "H=$RowH"
            W "Text=$typeTxt"
            W "FontColor=$typeColor"
            W 'FontSize=9'
            W 'FontFace=Segoe UI'
            W 'StringStyle=Bold'
            W 'AntiAlias=1'
            W "LeftMouseUpAction=$action"
            W ''

            W "[MRow${ri}Num]"
            W 'Meter=String'
            W "X=$($Padding + $TypeColW)"
            W "Y=$y"
            W "W=$NumColW"
            W "H=$RowH"
            W "Text=$numTxt"
            W 'FontColor=88,96,105,220'
            W 'FontSize=9'
            W 'FontFace=Segoe UI'
            W 'AntiAlias=1'
            W "LeftMouseUpAction=$action"
            W ''

            W "[MRow${ri}Title]"
            W 'Meter=String'
            W "X=$TitleColX"
            W "Y=$y"
            W "W=$TitleColW"
            W "H=$RowH"
            W "Text=$($row.title)"
            W "FontColor=$cTextBody"
            W 'FontSize=10'
            W 'FontFace=Segoe UI'
            W 'AntiAlias=1'
            W 'ClipString=2'
            W "LeftMouseUpAction=$action"
            W ''

            W "[MRow${ri}Age]"
            W 'Meter=String'
            W "X=$AgeColX"
            W "Y=$y"
            W "W=$AgeColW"
            W "H=$RowH"
            W "Text=$($row.time)"
            W "FontColor=$cTextDim"
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
}

# Summary line
W '[MSummary]'
W 'Meter=String'
W "X=$Padding"
W "Y=$($y + 4)"
W "W=$($WW - $Padding * 2)"
W 'H=20'
W ("Text=$totalIssues open issues  |  $totalPRs open PRs")
W "FontColor=$cTextDim"
W 'FontSize=9'
W 'FontFace=Segoe UI'
W 'AntiAlias=1'
W ''

# Icon buttons
$ry  = $y + $SummaryH + [int](($BtnAreaH - 20) / 2)
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
W ('LeftMouseUpAction=["wscript.exe" "#CURRENTPATH#launcher_issues.vbs"]')
W 'ToolTipText=Click to reload issues'
W ''

# ------------------------------------------------------------------
# Save - write to temp then rename atomically to prevent partial reads
# ------------------------------------------------------------------
$content = [string]::Join("`r`n", $lines)
$tempIni = $OutputIni + '.tmp'
$savedOk = $false
try {
    [System.IO.File]::WriteAllText($tempIni, $content, [System.Text.Encoding]::Unicode)
    Move-Item -Path $tempIni -Destination $OutputIni -Force -ErrorAction Stop
    $savedOk = $true
    L ('Saved: ' + $OutputIni + '  groups=' + $Groups.Count + '  rows=' + $ri + '  WH=' + $WH)
} catch {
    L ('ERROR: failed to save IssueView.ini - ' + $_.Exception.Message)
    if (Test-Path $tempIni) { Remove-Item $tempIni -Force -ErrorAction SilentlyContinue }
}

# ------------------------------------------------------------------
# Trigger Rainmeter skin refresh (only if save succeeded)
# ------------------------------------------------------------------
if ($savedOk) {
    $config  = (Split-Path (Split-Path $SkinPath -Parent) -Leaf) + '\' + (Split-Path $SkinPath -Leaf)
    $iniFile = 'IssueView.ini'
    $rmExe   = "$env:ProgramFiles\Rainmeter\Rainmeter.exe"
    if (-not (Test-Path $rmExe)) { $rmExe = "${env:ProgramFiles(x86)}\Rainmeter\Rainmeter.exe" }
    if (Test-Path $rmExe) {
        Start-Process $rmExe -ArgumentList "!Refresh `"$config`" `"$iniFile`"" -ErrorAction SilentlyContinue
        L "Rainmeter refresh triggered: $config\$iniFile"
    } else { L 'WARNING: Rainmeter.exe not found' }
}

L '=== DONE ==='
} finally {
    # Always release the lock
    Remove-Item $LockFile -Force -ErrorAction SilentlyContinue
}
