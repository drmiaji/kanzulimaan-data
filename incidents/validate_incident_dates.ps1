# validate_incident_dates.ps1
param(
    [string]$Folder = "D:\Quran_v4\kanzulimaan-data\incidents"
)

$ErrorCount = 0
$WarningCount = 0

function Add-Err([string]$msg) {
    $script:ErrorCount++
    Write-Host "ERROR: $msg" -ForegroundColor Red
}

function Add-Warn([string]$msg) {
    $script:WarningCount++
    Write-Host "WARN : $msg" -ForegroundColor Yellow
}

if (-not (Test-Path $Folder)) {
    Write-Host "Folder not found: $Folder" -ForegroundColor Red
    exit 2
}

$files = Get-ChildItem -Path $Folder -Filter "incidents_*.json" | Sort-Object Name
if (-not $files) {
    Write-Host "No incidents_*.json files found in $Folder" -ForegroundColor Red
    exit 2
}

foreach ($file in $files) {
    Write-Host "`nChecking $($file.Name) ..." -ForegroundColor Cyan

    try {
        $items = Get-Content -Raw -Encoding UTF8 $file.FullName | ConvertFrom-Json
    } catch {
        Add-Err "$($file.Name): invalid JSON. $($_.Exception.Message)"
        continue
    }

    if (-not $items) {
        Add-Warn "$($file.Name): file is empty"
        continue
    }

    $seen = @{}

    for ($i = 0; $i -lt $items.Count; $i++) {
        $it = $items[$i]
        $id = [string]$it.id
        $tag = "$($file.Name) [index=$i id=$id]"

        if ([string]::IsNullOrWhiteSpace($id)) {
            Add-Err "$tag missing 'id'"
            continue
        }

        if ($seen.ContainsKey($id)) {
            Add-Err "$tag duplicate id (already seen at index $($seen[$id]))"
        } else {
            $seen[$id] = $i
        }

        $dateType = ([string]$it.dateType).Trim().ToUpperInvariant()
        if ([string]::IsNullOrWhiteSpace($dateType)) {
            $dateType = "HIJRI" # backward-compatible default
        }

        if ($dateType -ne "HIJRI" -and $dateType -ne "GREGORIAN") {
            Add-Err "$tag invalid dateType='$($it.dateType)' (allowed: HIJRI, GREGORIAN)"
            continue
        }

        if ($dateType -eq "GREGORIAN") {
            if ($null -eq $it.gregorianMonth -or $it.gregorianMonth -lt 1 -or $it.gregorianMonth -gt 12) {
                Add-Err "$tag GREGORIAN requires gregorianMonth in 1..12"
            }
            if ($null -eq $it.gregorianDay -or $it.gregorianDay -lt 1 -or $it.gregorianDay -gt 31) {
                Add-Err "$tag GREGORIAN requires gregorianDay in 1..31"
            }

            # Soft check only (recommended, not required)
            if (($it.hijriMonth -ne 0) -or ($it.hijriDay -ne 0) -or ($it.hijriYear -ne 0)) {
                Add-Warn "$tag GREGORIAN entry should usually keep hijriMonth/hijriDay/hijriYear as 0"
            }
        }
        else {
            # HIJRI
            if ($null -eq $it.hijriMonth -or $it.hijriMonth -lt 1 -or $it.hijriMonth -gt 12) {
                Add-Err "$tag HIJRI requires hijriMonth in 1..12"
            }
            if ($null -eq $it.hijriDay -or $it.hijriDay -lt 1 -or $it.hijriDay -gt 30) {
                Add-Err "$tag HIJRI requires hijriDay in 1..30"
            }
            if ($null -eq $it.hijriYear -or $it.hijriYear -lt 0) {
                Add-Err "$tag HIJRI requires hijriYear >= 0"
            }

            # Soft check: Gregorian fields should be null/absent for HIJRI entries
            if ($null -ne $it.gregorianMonth -or $null -ne $it.gregorianDay) {
                Add-Warn "$tag HIJRI entry has gregorianMonth/day; usually keep them null/absent"
            }
        }
    }
}

Write-Host "`nValidation complete. Errors=$ErrorCount Warnings=$WarningCount" -ForegroundColor White

if ($ErrorCount -gt 0) {
    exit 1
}
exit 0