param(
    [string]$Path,
    [string]$Time = "2h"
)

# usage + path input
if (-not $Path) {
    Write-Host "Usage: .\script.ps1 -Path <folder> [-Time 2h|30m|10s]" -ForegroundColor Yellow
    Write-Host "Default Time: 2h" -ForegroundColor Gray
    $Path = Read-Host "Enter path"
}

if (-not $Path) {
    Write-Host "No path provided. Exit."
    exit
}

# default time handling
if (-not $Time -or $Time.Trim() -eq "") {
    $Time = "2h"
}

# parse time safely
switch -Regex ($Time.ToLower()) {
    '^(\d+)\s*h$' { $cutoff = (Get-Date).AddHours(-$matches[1]); break }
    '^(\d+)\s*m$' { $cutoff = (Get-Date).AddMinutes(-$matches[1]); break }
    '^(\d+)\s*s$' { $cutoff = (Get-Date).AddSeconds(-$matches[1]); break }
    '^0s$'        { $cutoff = (Get-Date).AddYears(100); break }
    default {
        Write-Host "Invalid Time format. Use 2h, 30m, 10s, 0s" -ForegroundColor Red
        exit
    }
}

# helper: show only end of path
function Tail-Path($p, $depth = 2) {
    $parts = $p -split "\\"
    if ($parts.Length -le $depth) { return $p }
    return "...\\" + ($parts[-$depth..-1] -join "\")
}

Write-Host "Path: $Path"
Write-Host "Cutoff: $cutoff`n"
Write-Host "`nScanning 4 locks..." -ForegroundColor Cyan

# SMB locks (active)
$smb = Get-SmbOpenFile | Where-Object {
    $_.LastAccessTime -lt $cutoff
}

# Office lock files (~$)
$files = Get-ChildItem -Path $Path -Recurse -Force -ErrorAction SilentlyContinue |
Where-Object {
    $_.Name -like "~$*" -and $_.LastWriteTime -lt $cutoff
}

# build table
$table = @()

$table += $smb | ForEach-Object {
    [PSCustomObject]@{
        Type    = "SMB LOCK"
        User    = $_.ClientUserName
        Machine = $_.ClientComputerName
        Path    = Tail-Path $_.Path
        Time    = $_.LastAccessTime
    }
}

$table += $files | ForEach-Object {
    [PSCustomObject]@{
        Type    = "OFFICE LOCK"
        User    = "-"
        Machine = "-"
        Path    = Tail-Path $_.FullName
        Time    = $_.LastWriteTime
    }
}

# output
$table = $table | Sort-Object Time

$table | Format-Table -AutoSize

# summary
Write-Host "`nSummary:"
Write-Host "SMB Locks   : $($smb.Count)"
Write-Host "Office Locks: $($files.Count)"

# confirm action
$ans = Read-Host "`nDelete ALL locks (y/n)"

if ($ans -eq "y") {

    if ($smb) {
        Write-Host "Closing SMB locks..." -ForegroundColor Red
        $smb | Close-SmbOpenFile -Force
    }

    if ($files) {
        Write-Host "Deleting Office lock files..." -ForegroundColor Red
        $files | Remove-Item -Force -ErrorAction SilentlyContinue
    }

    Write-Host "Done." -ForegroundColor Green
}
else {
    Write-Host "Cancelled." -ForegroundColor Gray
}
