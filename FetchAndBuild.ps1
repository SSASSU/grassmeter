# =============================================================
#  GitHub Grass for Rainmeter
#  FetchAndBuild.ps1
#  Fetches GitHub contribution data and generates GrassView.ini
# =============================================================
param(
    [string]$SkinPath  = '',
    [string]$OutputIni = ''
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

$sf = Join-Path $SkinPath 'Settings.inc'
if (Test-Path $sf) {
    foreach ($line in [System.IO.File]::ReadAllLines($sf, [System.Text.UTF8Encoding]::new($true))) {
        if ($line -match '^GitHubUsername\s*=\s*(.+)$') { $Username = $Matches[1].Trim() }
        if ($line -match '^GitHubToken\s*=\s*(.+)$')    { $Token    = $Matches[1].Trim() }
        if ($line -match '^WeeksToShow\s*=\s*(\d+)')    { $Weeks    = [int]$Matches[1] }
        if ($line -match '^CellSize\s*=\s*(\d+)')       { $CellSize = [int]$Matches[1] }
        if ($line -match '^CellGap\s*=\s*(\d+)')        { $CellGap  = [int]$Matches[1] }
        if ($line -match '^Padding\s*=\s*(\d+)')        { $Padding  = [int]$Matches[1] }
        if ($line -match '^ColorTheme\s*=\s*(.+)$')     { $Theme    = $Matches[1].Trim() }
    }
    L 'Settings.inc loaded'
} else {
    L 'WARNING: Settings.inc not found, using defaults'
}
L "Username=$Username  Weeks=$Weeks  Theme=$Theme  CellSize=$CellSize"

if ($Username -eq '' -or $Username -eq 'your_username') { L 'ERROR: GitHubUsername not set'; exit 1 }
if ($Token    -eq '' -or $Token    -eq 'ghp_your_token_here') { L 'ERROR: GitHubToken not set'; exit 1 }

# ------------------------------------------------------------------
# Color themes
# ------------------------------------------------------------------
$cBG='13,17,23,240'; $cL0='22,27,34,255'; $cL1='14,68,41,255'; $cL2='0,109,50,255'; $cL3='38,166,65,255'; $cL4='57,211,83,255'
if     ($Theme -eq 'Purple') { $cBG='13,17,23,240'; $cL0='22,27,34,255'; $cL1='45,17,96,255';  $cL2='90,30,153,255';  $cL3='137,87,229,255'; $cL4='196,155,255,255' }
elseif ($Theme -eq 'Blue')   { $cBG='13,17,23,240'; $cL0='22,27,34,255'; $cL1='12,37,67,255';  $cL2='13,65,157,255';  $cL3='31,111,235,255'; $cL4='88,166,255,255'  }
elseif ($Theme -eq 'Red')    { $cBG='13,17,23,240'; $cL0='22,27,34,255'; $cL1='75,28,28,255';  $cL2='139,26,26,255';  $cL3='207,46,46,255';  $cL4='255,107,107,255' }
elseif ($Theme -eq 'Orange') { $cBG='13,17,23,240'; $cL0='22,27,34,255'; $cL1='77,38,0,255';   $cL2='153,77,0,255';   $cL3='224,108,0,255';  $cL4='255,165,0,255'   }
elseif ($Theme -eq 'Pink')   { $cBG='13,17,23,240'; $cL0='22,27,34,255'; $cL1='77,0,38,255';   $cL2='153,0,82,255';   $cL3='224,0,122,255';  $cL4='255,105,180,255' }
elseif ($Theme -eq 'Mono')   { $cBG='13,17,23,240'; $cL0='22,27,34,255'; $cL1='42,42,42,255';  $cL2='85,85,85,255';   $cL3='136,136,136,255';$cL4='204,204,204,255' }
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
# Layout calculations
# ------------------------------------------------------------------
$Step   = $CellSize + $CellGap
$DLW    = 28
$MonthH = 20
$TotalH = 22
$GW     = $Weeks * $Step - $CellGap
$GH     = 7 * $Step - $CellGap
$WW     = $Padding * 2 + $DLW + $GW
$WH     = $Padding * 2 + $MonthH + $GH + $TotalH
$OX     = $Padding + $DLW
$OY     = $Padding + $MonthH
L "Widget size: ${WW}x${WH}"

# Build grid (col=week, row=weekday 0=Sun)
$SD  = (Get-Date).AddDays(-($Weeks * 7))
$SD  = $SD.AddDays(-([int]$SD.DayOfWeek))
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

# Reload measure (R button triggers this)
W "[MeasureReload]"
W "Measure=Plugin"
W "Plugin=RunCommand"
W ("Program=" + $SkinPath + "\run.bat")
W "State=0"
W "FinishAction=[!Refresh]"
W ""

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
    W "FontSize=8"
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
    W "FontSize=7"
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
            if     ($pct -le 0.25) { $clr = $cL1 }
            elseif ($pct -le 0.50) { $clr = $cL2 }
            elseif ($pct -le 0.75) { $clr = $cL3 }
            else                   { $clr = $cL4 }
        }

        $x   = $OX + $c * $Step
        $y   = $OY + $r * $Step
        $tip = $cell.date + ": " + $cnt + " contributions"

        W "[MC$idx]"
        W "Meter=Shape"
        W "X=$x"
        W "Y=$y"
        W ("Shape=Rectangle 0,0," + $CellSize + "," + $CellSize + ",2 | Fill Color " + $clr + " | StrokeWidth 0")
        W "ToolTipText=$tip"
        W ""
        $idx++
    }
}

# Total contributions text
$ty = $OY + $GH + 6
W "[MTotal]"
W "Meter=String"
W "X=$OX"
W "Y=$ty"
W "W=$GW"
W "H=$TotalH"
W ("Text=" + $Total + " contributions in the last " + $Weeks + " weeks")
W "FontColor=139,148,158,255"
W "FontSize=8"
W "FontFace=Segoe UI"
W "AntiAlias=1"
W ""

# Refresh button
$rx = $WW - $Padding - 18
W "[MRefresh]"
W "Meter=String"
W "X=$rx"
W "Y=$Padding"
W "W=18"
W "H=$MonthH"
W "Text=R"
W "FontColor=88,96,105,200"
W "FontSize=9"
W "FontFace=Segoe UI"
W "AntiAlias=1"
W "LeftMouseUpAction=[!CommandMeasure MeasureReload 'Run']"
W "ToolTipText=Click to reload (applies Settings.inc changes)"
W ""

# Save with UTF-8 BOM
$content = [string]::Join("`r`n", $lines)
[System.IO.File]::WriteAllText($OutputIni, $content, [System.Text.UTF8Encoding]::new($true))
L ("Saved: " + $OutputIni + "  cells=" + $idx)
L '=== DONE ==='
Write-Output ("SUCCESS:" + $Total)