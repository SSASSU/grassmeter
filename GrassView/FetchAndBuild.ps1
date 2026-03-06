# =============================================================
#  GitHub Grass for Rainmeter
#  FetchAndBuild.ps1
#  Fetches GitHub contribution data and generates GrassView.ini
# =============================================================
param(
    [string]$SkinPath     = '',
    [string]$OutputIni    = '',
    [int]$WeeksOverride   = 0
)

if (-not $SkinPath)  { $SkinPath  = Split-Path -Parent $MyInvocation.MyCommand.Path }
if (-not $OutputIni) { $OutputIni = Join-Path $SkinPath 'GrassView.ini' }

$Log = Join-Path $SkinPath 'debug.log'
[System.IO.File]::WriteAllText($Log, '', [System.Text.UTF8Encoding]::new($false))
function L($m) {
    [System.IO.File]::AppendAllText($Log, "[$(Get-Date -f HH:mm:ss)] $m`r`n", [System.Text.UTF8Encoding]::new($false))
}
L '=== GitHub Grass v1.0 ==='

# ------------------------------------------------------------------
# Parse Settings.inc
# ------------------------------------------------------------------
$Username = ''; $Token = ''; $Weeks = 52; $CellSize = 11
$CellGap  = 2;  $Padding = 14; $Theme = 'Green'
$Repo1 = ''; $Repo2 = ''; $Repo3 = ''

$sf = Join-Path (Split-Path $SkinPath -Parent) 'Settings.inc'
if (Test-Path $sf) {
    foreach ($line in [System.IO.File]::ReadAllLines($sf, [System.Text.UTF8Encoding]::new($true))) {
        if ($line -match '^GitHubUsername\s*=\s*(.+)$') { $Username = $Matches[1].Trim() }
        if ($line -match '^GitHubToken\s*=\s*(.+)$')    { $Token    = $Matches[1].Trim() }
        if ($line -match '^WeeksToShow\s*=\s*(\d+)')    { $Weeks    = [int]$Matches[1] }
        if ($line -match '^CellSize\s*=\s*(\d+)')       { $CellSize = [int]$Matches[1] }
        if ($line -match '^CellGap\s*=\s*(\d+)')        { $CellGap  = [int]$Matches[1] }
        if ($line -match '^Padding\s*=\s*(\d+)')        { $Padding  = [int]$Matches[1] }
        if ($line -match '^ColorTheme\s*=\s*(.+)$')     { $Theme    = $Matches[1].Trim() }
        if ($line -match '^Repo1\s*=\s*(.+)$')          { $Repo1    = $Matches[1].Trim() }
        if ($line -match '^Repo2\s*=\s*(.+)$')          { $Repo2    = $Matches[1].Trim() }
        if ($line -match '^Repo3\s*=\s*(.+)$')          { $Repo3    = $Matches[1].Trim() }
    }
    L 'Settings.inc loaded'
} else {
    L 'WARNING: Settings.inc not found, using defaults'
}
L "Username=$Username  Weeks=$Weeks  Theme=$Theme  CellSize=$CellSize"

# Apply WeeksOverride and persist to Settings.inc
if ($WeeksOverride -gt 0) {
    $Weeks = $WeeksOverride
    if (Test-Path $sf) {
        $sfc = [System.IO.File]::ReadAllText($sf, [System.Text.UTF8Encoding]::new($true))
        $sfc = $sfc -replace 'WeeksToShow=\d+', ('WeeksToShow=' + $Weeks)
        [System.IO.File]::WriteAllText($sf, $sfc, [System.Text.UTF8Encoding]::new($true))
        L "WeeksOverride=$Weeks (Settings.inc updated)"
    }
}

if ($Username -eq '' -or $Username -eq 'your_username') { L 'ERROR: GitHubUsername not set'; exit 1 }
if ($Token    -eq '' -or $Token    -eq 'ghp_your_token_here') { L 'ERROR: GitHubToken not set'; exit 1 }

# ------------------------------------------------------------------
# Color themes
# ------------------------------------------------------------------
$cBG='13,17,23,240'; $cL0='33,38,46,255'; $cL1='14,90,52,255'; $cL2='0,135,62,255'; $cL3='50,185,80,255'; $cL4='70,225,95,255'
if     ($Theme -eq 'Purple') { $cBG='13,17,23,240'; $cL0='33,38,46,255'; $cL1='55,20,115,255'; $cL2='105,35,180,255'; $cL3='155,100,240,255'; $cL4='210,170,255,255' }
elseif ($Theme -eq 'Blue')   { $cBG='13,17,23,240'; $cL0='33,38,46,255'; $cL1='15,45,85,255';  $cL2='15,80,190,255';  $cL3='40,125,245,255'; $cL4='100,180,255,255'  }
elseif ($Theme -eq 'Red')    { $cBG='13,17,23,240'; $cL0='33,38,46,255'; $cL1='90,30,30,255';  $cL2='165,32,32,255';  $cL3='220,58,58,255';  $cL4='255,130,130,255' }
elseif ($Theme -eq 'Orange') { $cBG='13,17,23,240'; $cL0='33,38,46,255'; $cL1='95,48,0,255';   $cL2='180,92,0,255';   $cL3='235,125,0,255';  $cL4='255,180,30,255'  }
elseif ($Theme -eq 'Pink')   { $cBG='13,17,23,240'; $cL0='33,38,46,255'; $cL1='95,0,48,255';   $cL2='180,0,100,255';  $cL3='235,0,140,255';  $cL4='255,125,195,255' }
elseif ($Theme -eq 'Mono')   { $cBG='13,17,23,240'; $cL0='33,38,46,255'; $cL1='55,55,55,255';  $cL2='100,100,100,255';$cL3='155,155,155,255';$cL4='210,210,210,255' }
L "Theme=$Theme  L0=[$cL0]  L4=[$cL4]"

# ------------------------------------------------------------------
# GitHub GraphQL API
# ------------------------------------------------------------------
$End   = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
$Start = (Get-Date).AddDays(-($Weeks * 7)).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
$Body  = '{"query":"query($login:String!,$from:DateTime!,$to:DateTime!){user(login:$login){contributionsCollection(from:$from,to:$to){contributionCalendar{totalContributions weeks{contributionDays{contributionCount date weekday}}}}}}","variables":{"login":"' + $Username + '","from":"' + $Start + '","to":"' + $End + '"}}'
$Headers = @{
    Authorization  = "Bearer $Token"
    'Content-Type' = 'application/json'
    'User-Agent'   = 'Rainmeter-GitHubGrass/1.0'
}

L 'Calling GitHub API...'
try {
    $R = Invoke-RestMethod -Uri 'https://api.github.com/graphql' -Method POST -Headers $Headers -Body $Body -ErrorAction Stop
    if ($R.errors) { L ("GraphQL error: " + $R.errors[0].message); exit 1 }
    $Cal   = $R.data.user.contributionsCollection.contributionCalendar
    $Total = $Cal.totalContributions
    L "API OK  total=$Total"
} catch {
    L ("API failed: " + $_.Exception.Message)
    exit 1
}

# Build date->count map
$Map = @{}
$Max = 0
foreach ($w in $Cal.weeks) {
    foreach ($d in $w.contributionDays) {
        $Map[$d.date] = [int]$d.contributionCount
        if ([int]$d.contributionCount -gt $Max) { $Max = [int]$d.contributionCount }
    }
}
L "Max daily commits=$Max"

# ------------------------------------------------------------------
# Streak calculation
# ------------------------------------------------------------------
$todayStr = (Get-Date).Date.ToString('yyyy-MM-dd')

# Current streak: count consecutive days with contributions, backward from today
# If today has no contributions, streak may still be alive from yesterday
$curStreak = 0
$chkDate   = (Get-Date).Date
if (-not $Map.ContainsKey($todayStr) -or $Map[$todayStr] -eq 0) {
    $chkDate = $chkDate.AddDays(-1)
}
while ($true) {
    $ds = $chkDate.ToString('yyyy-MM-dd')
    if ($Map.ContainsKey($ds) -and $Map[$ds] -gt 0) {
        $curStreak++
        $chkDate = $chkDate.AddDays(-1)
    } else { break }
}

# Longest streak from all fetched data
$longestStreak = 0
$runStreak     = 0
foreach ($ds in ($Map.Keys | Sort-Object)) {
    if ($Map[$ds] -gt 0) {
        $runStreak++
        if ($runStreak -gt $longestStreak) { $longestStreak = $runStreak }
    } else { $runStreak = 0 }
}
L "Streak: current=$curStreak  best=$longestStreak"

# ------------------------------------------------------------------
# Star count for configured repos
# ------------------------------------------------------------------
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12
$TotalStars     = -1
$configuredRepos = @($Repo1, $Repo2, $Repo3) | Where-Object { $_ -ne '' }
if ($configuredRepos.Count -gt 0) {
    $TotalStars = 0
    foreach ($repo in $configuredRepos) {
        try {
            $wc = New-Object System.Net.WebClient
            $wc.Encoding = [System.Text.Encoding]::UTF8
            $wc.Headers['Authorization'] = "Bearer $Token"
            $wc.Headers['User-Agent']    = 'Rainmeter-GitHubGrass/1.0'
            $rd = ($wc.DownloadString('https://api.github.com/repos/' + $repo)) | ConvertFrom-Json
            $TotalStars += [int]$rd.stargazers_count
            L "Stars: $repo = $($rd.stargazers_count)"
        } catch {
            L ("Stars fetch failed ($repo): " + $_.Exception.Message)
            $TotalStars = -1
            break
        }
    }
}
L "TotalStars=$TotalStars"

# ------------------------------------------------------------------
# Layout calculations
# ------------------------------------------------------------------
$Step    = $CellSize + $CellGap
$DLW     = 28
$MonthH  = 22
$TotalH  = 44   # 20px contributions line + 20px streak line + 4px gap
$BtnRowH  = 26
$LegendH  = 24   # bottom row: icons (left) + Less/More (center) + star (right)
$GW      = $Weeks * $Step - $CellGap
$GH      = 7 * $Step - $CellGap
$WW      = $Padding * 2 + $DLW + $GW
$WH      = $Padding * 2 + $MonthH + $GH + $TotalH + $BtnRowH + $LegendH
$OX      = $Padding + $DLW
$OY      = $Padding + $MonthH

# Period selector
$Periods = @(
    @{label='1W'; weeks=1},
    @{label='1M'; weeks=4},
    @{label='3M'; weeks=13},
    @{label='6M'; weeks=26},
    @{label='1Y'; weeks=52}
)
$PBtnW   = 26
$PBtnGap = 6
$PTotalW = $Periods.Count * $PBtnW + ($Periods.Count - 1) * $PBtnGap

$ContentW = [Math]::Max($GW, $PTotalW)
$WW       = $Padding * 2 + $DLW + $ContentW

L "Widget size: ${WW}x${WH}"

# Build grid (col=week, row=weekday 0=Sun)
# Start from Sunday of current week minus (Weeks-1) weeks, so last column always = current week
$TodaySun = (Get-Date).Date.AddDays(-([int](Get-Date).DayOfWeek))
$SD = $TodaySun.AddDays(-(($Weeks - 1) * 7))
$Grid = @{}
$cur  = $SD
for ($c = 0; $c -lt $Weeks; $c++) {
    for ($r = 0; $r -lt 7; $r++) {
        $ds  = $cur.ToString('yyyy-MM-dd')
        $cnt = if ($Map.ContainsKey($ds)) { $Map[$ds] } else { 0 }
        $Grid["$c,$r"] = @{ date = $ds; count = $cnt; future = ($cur -gt (Get-Date)) }
        $cur = $cur.AddDays(1)
    }
}

# Month label positions
$MN = @('','Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec')
$ML = @{}
$PM = -1
for ($c = 0; $c -lt $Weeks; $c++) {
    $d = $Grid["$c,0"]
    if ($d) {
        $m = [int](Get-Date $d.date).Month
        if ($m -ne $PM) { $ML[$c] = $MN[$m]; $PM = $m }
    }
}

# ------------------------------------------------------------------
# Generate GrassView.ini
# ------------------------------------------------------------------
$lines = [System.Collections.Generic.List[string]]::new()
function W($s) { $lines.Add($s) }

W ("; GitHub Grass - Generated " + (Get-Date -f 'yyyy-MM-dd HH:mm'))
W "; DO NOT EDIT - regenerated by run.bat"
W ""
W "[Rainmeter]"
W "Update=30000"
W "AccurateText=1"
W ""
W "[Variables]"
W ("SkinFolder=" + $SkinPath)
W ""

# (RunCommand measures removed - buttons call powershell directly)

# Background
W "[MeterBG]"
W "Meter=Shape"
W "X=0"
W "Y=0"
W ("Shape=Rectangle 0,0," + $WW + "," + $WH + ",8 | Fill Color " + $cBG + " | StrokeWidth 1 | Stroke Color 48,54,61,255")
W ""

# Month labels
$mi = 0
foreach ($c in ($ML.Keys | Sort-Object { [int]$_ })) {
    $x = $OX + $c * $Step
    W "[MML$mi]"
    W "Meter=String"
    W "X=$x"
    W "Y=$Padding"
    W "W=40"
    W "H=$MonthH"
    W ("Text=" + $ML[$c])
    W "FontColor=139,148,158,255"
    W "FontSize=9"
    W "FontFace=Segoe UI"
    W "AntiAlias=1"
    W ""
    $mi++
}

# Day labels (Sun - Sat)
$DayNames = @('Sun','Mon','Tue','Wed','Thu','Fri','Sat')
for ($r = 0; $r -lt 7; $r++) {
    $y = $OY + $r * $Step
    W "[MDL$r]"
    W "Meter=String"
    W "X=$Padding"
    W "Y=$y"
    W "W=$DLW"
    W ("H=" + ($CellSize + 2))
    W ("Text=" + $DayNames[$r])
    W "FontColor=139,148,158,255"
    W "FontSize=8"
    W "FontFace=Segoe UI"
    W "AntiAlias=1"
    W ""
}

# Contribution cells
$idx = 0
for ($c = 0; $c -lt $Weeks; $c++) {
    for ($r = 0; $r -lt 7; $r++) {
        $cell = $Grid["$c,$r"]
        $cnt  = $cell.count

        if ($cell.future -or $cnt -le 0) {
            $clr = $cL0
        } elseif ($Max -eq 0) {
            $clr = $cL1
        } else {
            $pct = [double]$cnt / [double]$Max
            if     ($pct -le 0.10) { $clr = $cL1 }
            elseif ($pct -le 0.30) { $clr = $cL2 }
            elseif ($pct -le 0.60) { $clr = $cL3 }
            else                   { $clr = $cL4 }
        }

        $x        = $OX + $c * $Step
        $y        = $OY + $r * $Step
        $diffDays = [int]((Get-Date).Date - (Get-Date $cell.date).Date).TotalDays
        if     ($cell.future)        { $tipDate = $cell.date }
        elseif ($diffDays -eq 0)     { $tipDate = "Today" }
        elseif ($diffDays -eq 1)     { $tipDate = "Yesterday" }
        else                         { $tipDate = "$diffDays days ago" }
        $tip = "$tipDate  -  $cnt contributions"

        W "[MC$idx]"
        W "Meter=Shape"
        W "X=$x"
        W "Y=$y"
        if ($cell.date -eq $todayStr) {
            W ("Shape=Rectangle 0,0," + $CellSize + "," + $CellSize + ",2 | Fill Color " + $clr + " | StrokeWidth 1.5 | Stroke Color 200,200,200,180")
        } else {
            W ("Shape=Rectangle 0,0," + $CellSize + "," + $CellSize + ",2 | Fill Color " + $clr + " | StrokeWidth 0")
        }
        W "ToolTipText=$tip"
        W ""
        $idx++
    }
}

# Period buttons (right-aligned, directly below grass grid)
$bby = $OY + $GH + 4
$bbx = $OX + $ContentW - $PTotalW
$pi  = 0
foreach ($p in $Periods) {
    $pl  = $p.label; $pw = $p.weeks
    $bxi = $bbx + $pi * ($PBtnW + $PBtnGap)
    $isAct  = ($pw -eq $Weeks)
    $fclr   = if ($isAct) { '220,220,220,255' } else { '88,96,105,180' }
    $bstyle = if ($isAct) { 'Bold' } else { 'Normal' }

    W ("[MBtnP" + $pl + "]")
    W "Meter=String"
    W "X=$bxi"
    W "Y=$bby"
    W "W=$PBtnW"
    W "H=$BtnRowH"
    W "Text=$pl"
    W "FontColor=$fclr"
    W "FontSize=9"
    W "FontFace=Segoe UI"
    W "AntiAlias=1"
    W "StringAlign=Center"
    W "StringStyle=$bstyle"
    W ("LeftMouseUpAction=[`"wscript.exe`" `"#CURRENTPATH#launcher.vbs`" " + $pw + "]")
    W ("ToolTipText=Show contributions for last " + $pl)
    W ""
    $pi++
}

# Total contributions text (below period buttons)
$ty = $bby + $BtnRowH + 6
W "[MTotal]"
W "Meter=String"
W "X=$Padding"
W "Y=$ty"
W "W=$($WW - $Padding * 2)"
W "H=20"
W ("Text=" + $Total + " contributions in the last " + $Weeks + " weeks")
W "FontColor=139,148,158,255"
W "FontSize=10"
W "FontFace=Segoe UI"
W "AntiAlias=1"
W ""

# Streak counter - own line below total, left-aligned with settings button
$streakText = if ($curStreak -gt 0) { "$curStreak day streak  |  Best: $longestStreak days" } else { "Best: $longestStreak days" }
W "[MStreak]"
W "Meter=String"
W "X=$Padding"
W "Y=$($ty + 20)"
W "W=$($WW - $Padding * 2)"
W "H=20"
W "Text=$streakText"
W "FontColor=139,148,158,200"
W "FontSize=10"
W "FontFace=Segoe UI"
W "AntiAlias=1"
W ""

# Bottom row: icons (left) + Less/More legend (center) + star (right)
# All three elements share the same $legY row
$legCS      = [Math]::Min($CellSize, 10)
$legCG      = 2
$legTW      = 26
$legCellsW  = 5 * $legCS + 4 * $legCG
$legTotalW  = $legTW + 4 + $legCellsW + 4 + $legTW
$legX       = [int](($WW - $legTotalW) / 2)
$legY       = $ty + $TotalH
$legCY      = $legY + [int](($LegendH - $legCS) / 2)
$legColors  = @($cL0, $cL1, $cL2, $cL3, $cL4)

# Icon buttons - left side, vertically centered in LegendH row
$iy  = $legY + [int](($LegendH - 20) / 2)
$rix = $Padding + 26

W "[MSettings]"
W "Meter=Image"
W "ImageName=#ROOTCONFIGPATH#@Resources\Icons\settings.png"
W "X=$Padding"
W "Y=$iy"
W "W=20"
W "H=20"
W "LeftMouseUpAction=[`"wscript.exe`" `"#ROOTCONFIGPATH#launch_settings.vbs`"]"
W "ToolTipText=Open Settings"
W ""

W "[MRefresh]"
W "Meter=Image"
W "ImageName=#ROOTCONFIGPATH#@Resources\Icons\refresh.png"
W "X=$rix"
W "Y=$iy"
W "W=20"
W "H=20"
W "LeftMouseUpAction=[`"wscript.exe`" `"#CURRENTPATH#launcher.vbs`"]"
W "ToolTipText=Click to reload (applies Settings.inc changes)"
W ""

W "[MLegLess]"
W "Meter=String"
W "X=$legX"
W "Y=$legY"
W "W=$legTW"
W "H=$($LegendH - 4)"
W "Text=Less"
W "FontColor=88,96,105,180"
W "FontSize=8"
W "FontFace=Segoe UI"
W "AntiAlias=1"
W "StringAlign=Right"
W ""

$legCX = $legX + $legTW + 4
for ($li = 0; $li -lt 5; $li++) {
    $lcx = $legCX + $li * ($legCS + $legCG)
    W "[MLegC$li]"
    W "Meter=Shape"
    W "X=$lcx"
    W "Y=$legCY"
    W ("Shape=Rectangle 0,0," + $legCS + "," + $legCS + ",2 | Fill Color " + $legColors[$li] + " | StrokeWidth 0")
    W ""
}

$legMoreX = $legCX + $legCellsW + 4
W "[MLegMore]"
W "Meter=String"
W "X=$legMoreX"
W "Y=$legY"
W "W=$legTW"
W "H=$($LegendH - 4)"
W "Text=More"
W "FontColor=88,96,105,180"
W "FontSize=8"
W "FontFace=Segoe UI"
W "AntiAlias=1"
W ""

# Star count - right-aligned under the period buttons (shares same X zone)
if ($TotalStars -ge 0) {
    # Place star starting at the 1Y button's left edge
    $starChar = [char]0x2605
    $starX    = $WW - $Padding - $PBtnW
    $starW    = $PBtnW + $Padding
    W "[MStarCount]"
    W "Meter=String"
    W "X=$starX"
    W "Y=$legY"
    W "W=$starW"
    W "H=$($LegendH - 4)"
    W ("Text=" + $starChar + " " + $TotalStars)
    W "FontColor=210,175,55,220"
    W "FontSize=10"
    W "FontFace=Segoe UI"
    W "AntiAlias=1"
    W ("ToolTipText=Total stars: " + ($configuredRepos -join ', '))
    W ""
}

# Save - UTF-16 LE for proper Unicode support (★ etc.), atomic write
$content = [string]::Join("`r`n", $lines)
$tempIni = $OutputIni + '.tmp'
[System.IO.File]::WriteAllText($tempIni, $content, [System.Text.Encoding]::Unicode)
Move-Item -Path $tempIni -Destination $OutputIni -Force
L ("Saved: " + $OutputIni + "  cells=" + $idx)

# Trigger Rainmeter skin refresh automatically
$config  = (Split-Path (Split-Path $SkinPath -Parent) -Leaf) + '\' + (Split-Path $SkinPath -Leaf)
$iniFile = [System.IO.Path]::GetFileName($OutputIni)
$rmExe   = "$env:ProgramFiles\Rainmeter\Rainmeter.exe"
if (-not (Test-Path $rmExe)) { $rmExe = "${env:ProgramFiles(x86)}\Rainmeter\Rainmeter.exe" }
if (Test-Path $rmExe) {
    Start-Process $rmExe -ArgumentList "!Refresh `"$config`" `"$iniFile`""
    L "Rainmeter refresh triggered: $config\$iniFile"
} else {
    L "WARNING: Rainmeter.exe not found - refresh manually"
}

L '=== DONE ==='
Write-Output ("SUCCESS:" + $Total)