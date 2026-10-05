# Claude Code status line (Windows PowerShell)
# Line 1: model, folder, context window usage
# Line 2: 5-hour and weekly plan limits with reset times

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$j = $input | Out-String | ConvertFrom-Json

$esc    = [char]27
$reset  = "${esc}[0m"
$dim    = "${esc}[2m"
$cyan   = "${esc}[36m"
$green  = "${esc}[32m"
$yellow = "${esc}[33m"
$red    = "${esc}[31m"

# Bar characters (built from char codes so this file stays plain ASCII)
$full  = [string][char]0x2588
$empty = [string][char]0x2591

function Get-Tint($pct) {
    if ($pct -ge 90) { return $red }
    if ($pct -ge 70) { return $yellow }
    return $green
}

function Get-Bar($pct, $width = 10) {
    $p = [math]::Max(0, [math]::Min(100, [double]$pct))
    $filled = [int][math]::Floor($p * $width / 100)
    $tint = Get-Tint $p
    return $tint + ($full * $filled) + $dim + ($empty * ($width - $filled)) + $reset
}

function Get-Left($ts) {
    $s = [long]$ts - [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
    if ($s -le 0) { return "now" }
    $d = [int][math]::Floor($s / 86400)
    $h = [int][math]::Floor(($s % 86400) / 3600)
    $m = [int][math]::Floor(($s % 3600) / 60)
    if ($d -gt 0) { return "${d}d ${h}h" }
    if ($h -gt 0) { return "${h}h ${m}m" }
    return "${m}m"
}

function Get-At($ts, $fmt) {
    $culture = [System.Globalization.CultureInfo]::InvariantCulture
    return [DateTimeOffset]::FromUnixTimeSeconds([long]$ts).ToLocalTime().ToString($fmt, $culture)
}

# ---- Line 1: model | folder | context ----
$model = "Claude"
if ($j.model.display_name) { $model = $j.model.display_name }

$line1 = "${cyan}[${model}]${reset}"
if ($j.workspace.current_dir) {
    $line1 += " " + (Split-Path $j.workspace.current_dir -Leaf)
}

$ctx = $j.context_window.used_percentage
if ($null -ne $ctx) {
    $line1 += "  |  Context " + (Get-Bar $ctx) + " " + [math]::Round($ctx) + "%"
}

Write-Host $line1

# ---- Line 2: plan limits ----
$parts = @()

$h5 = $j.rate_limits.five_hour
if ($h5 -and $null -ne $h5.used_percentage) {
    $t = "5-hour limit " + (Get-Bar $h5.used_percentage) + " " + [math]::Round($h5.used_percentage) + "%"
    if ($h5.resets_at) {
        $t += "  resets in " + (Get-Left $h5.resets_at) + " (" + (Get-At $h5.resets_at "HH:mm") + ")"
    }
    $parts += $t
}

$wk = $j.rate_limits.seven_day
if ($wk -and $null -ne $wk.used_percentage) {
    $t = "Weekly limit " + (Get-Bar $wk.used_percentage) + " " + [math]::Round($wk.used_percentage) + "%"
    if ($wk.resets_at) {
        $t += "  resets in " + (Get-Left $wk.resets_at) + " (" + (Get-At $wk.resets_at "ddd dd MMM, HH:mm") + ")"
    }
    $parts += $t
}

if ($parts.Count -gt 0) {
    Write-Host ($parts -join "  |  ")
}
