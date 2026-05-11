#Requires -Version 5.1
<#
.SYNOPSIS
    Symlink ShruggieTech skills into the user's personal Claude skills
    directory on Windows 11.

.DESCRIPTION
    Source:      <repo>\skills\<skill-name>\
    Destination: %USERPROFILE%\.claude\skills\<skill-name>\

    Skips the _template directory. Re-running is safe: existing correct
    symlinks are reported and left alone. Use -Force to replace symlinks
    that point elsewhere. Refuses to clobber real files or directories.

    Symlink creation on Windows 11 requires either an elevated PowerShell
    session or Developer Mode enabled at:
    Settings > Privacy and security > For developers > Developer Mode.

.PARAMETER Force
    Replace existing symlinks that point somewhere else.

.EXAMPLE
    .\install.ps1
    .\install.ps1 -Force
#>

[CmdletBinding()]
param(
    [switch]$Force
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot  = Split-Path -Parent $ScriptDir
$SkillsSrc = Join-Path $RepoRoot 'skills'
$SkillsDst = Join-Path $env:USERPROFILE '.claude\skills'

if (-not (Test-Path -LiteralPath $SkillsSrc)) {
    Write-Error "Source directory not found: $SkillsSrc"
    exit 1
}

if (-not (Test-Path -LiteralPath $SkillsDst)) {
    New-Item -ItemType Directory -Force -Path $SkillsDst | Out-Null
}

$skillDirs = Get-ChildItem -LiteralPath $SkillsSrc -Directory -ErrorAction SilentlyContinue

if (-not $skillDirs -or $skillDirs.Count -eq 0) {
    Write-Host "No skills found in $SkillsSrc"
    exit 0
}

Write-Host "Installing skills from: $SkillsSrc"
Write-Host "                   to: $SkillsDst"
Write-Host ""

$linked   = 0
$replaced = 0
$skipped  = 0
$failed   = 0
$privilegeWarned = $false

function Get-ExistingSymlinkTarget {
    param([string]$Path)

    $item = Get-Item -LiteralPath $Path -Force -ErrorAction SilentlyContinue
    if (-not $item) { return $null }
    if ($item.LinkType -ne 'SymbolicLink') { return $null }

    # .Target is a string array in PS 5.1 and a string in PS 7+; normalize.
    $raw = $item.Target
    if ($null -eq $raw) { return $null }
    return @($raw)[0]
}

function New-SkillLink {
    param(
        [string]$Target,
        [string]$Source
    )

    try {
        New-Item -ItemType SymbolicLink -Path $Target -Target $Source -ErrorAction Stop | Out-Null
        return $true
    }
    catch {
        $msg = $_.Exception.Message
        Write-Warning ("  failed    {0}: {1}" -f (Split-Path -Leaf $Target), $msg)
        if (-not $script:privilegeWarned) {
            Write-Warning "  Hint: symlink creation on Windows 11 requires elevated PowerShell or Developer Mode."
            Write-Warning "        Settings > Privacy and security > For developers > Developer Mode"
            $script:privilegeWarned = $true
        }
        return $false
    }
}

foreach ($skill in $skillDirs) {
    $skillName = $skill.Name
    $sourceAbs = $skill.FullName
    $target    = Join-Path $SkillsDst $skillName

    if ($skillName -eq '_template') {
        continue
    }

    $existingTarget = Get-ExistingSymlinkTarget -Path $target

    if ($null -ne $existingTarget) {
        if ($existingTarget -eq $sourceAbs) {
            Write-Host ("  ok        {0} (already linked)" -f $skillName)
            $skipped++
            continue
        }

        if ($Force) {
            Remove-Item -LiteralPath $target -Force
            if (New-SkillLink -Target $target -Source $sourceAbs) {
                Write-Host ("  replaced  {0} (was -> {1})" -f $skillName, $existingTarget)
                $replaced++
            }
            else {
                $failed++
            }
            continue
        }

        Write-Warning ("  skip      {0} (existing symlink to {1}; use -Force to replace)" -f $skillName, $existingTarget)
        $skipped++
        continue
    }

    if (Test-Path -LiteralPath $target) {
        Write-Warning ("  skip      {0} (existing file or directory at target; refusing to clobber)" -f $skillName)
        $skipped++
        continue
    }

    if (New-SkillLink -Target $target -Source $sourceAbs) {
        Write-Host ("  linked    {0}" -f $skillName)
        $linked++
    }
    else {
        $failed++
    }
}

Write-Host ""
Write-Host ("Done. Linked: {0}, Replaced: {1}, Skipped: {2}, Failed: {3}" -f $linked, $replaced, $skipped, $failed)

if ($failed -gt 0) {
    exit 1
}
