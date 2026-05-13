#Requires -Version 5.1

<#
.SYNOPSIS
    Cut a formal release of the ShruggieTech skills repo on Windows 11.

.DESCRIPTION
    Rolls the Keep a Changelog Unreleased section into a new versioned
    section, generates release notes, builds one zip per skill in
    dist\vX.Y.Z\, computes SHA256 sums, commits, tags, and pushes.

    Defaults: patch bump, branch=main, zip artifacts built, push at end.
    Use -WhatIf to preview without writing anything; preflight still runs
    so wrong-branch / dirty-tree / tag-exists conditions are caught.

    Version selection flags (-Major, -Minor, -Patch, -Version) are
    mutually exclusive. With no prior tags, all of them resolve to
    1.0.0 unless -Version overrides.

.PARAMETER Major
    Bump the MAJOR segment (X.0.0); resets minor and patch.

.PARAMETER Minor
    Bump the MINOR segment (X.Y.0); resets patch.

.PARAMETER Patch
    Bump the PATCH segment (X.Y.Z). This is the default if no version
    selection flag is supplied.

.PARAMETER Version
    Use an explicit version (e.g. '2.0.0'). Must be strictly greater
    than the highest existing tag.

.PARAMETER NotesSummary
    Optional summary paragraph inserted between the H1 and the first
    section in the release notes file. Default: no summary line.

.PARAMETER Branch
    Branch to release from. Default: main.

.PARAMETER Quiet
    Suppress all non-error output. Mutually exclusive with -Verbose.

.PARAMETER NoZip
    Skip building per-skill zips.

.PARAMETER NoPush
    Skip both git pushes at the end (leaves the commit and tag local).

.PARAMETER GhRelease
    After pushing, create a GitHub release with `gh release create`.
    Attaches the zips and SHA256SUMS.txt. Requires `gh` on PATH and an
    authenticated session.

.PARAMETER WhatIf
    Built-in. Preview every step without performing any writes, commits,
    tags, or pushes. Preflight still runs.

.PARAMETER Verbose
    Built-in. Print each preflight check and substep.

.EXAMPLE
    .\release.ps1 -WhatIf -Verbose

    Preview a patch release.

.EXAMPLE
    .\release.ps1

    Cut a patch release using the default settings.

.EXAMPLE
    .\release.ps1 -Minor

    Cut a minor release.

.EXAMPLE
    .\release.ps1 -Version '2.0.0'

    Cut an explicit version 2.0.0 release.

.EXAMPLE
    .\release.ps1 -Major -NoPush

    Bump major locally without pushing, so the commit and tag can be
    reviewed before publishing.

.EXAMPLE
    .\release.ps1 -GhRelease

    Cut a patch release and create a GitHub release with the zips
    attached.

.NOTES
    See CONTRIBUTING.md "Cutting a Release" for the full release
    workflow.
#>

[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
param(
    [switch]$Major,
    [switch]$Minor,
    [switch]$Patch,
    [string]$Version,
    [string]$NotesSummary,
    [string]$Branch = 'main',
    [switch]$Quiet,
    [switch]$NoZip,
    [switch]$NoPush,
    [switch]$GhRelease
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$ScriptDir       = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot        = Split-Path -Parent $ScriptDir
$SkillsSrc       = Join-Path $RepoRoot 'skills'
$ChangelogPath   = Join-Path $RepoRoot 'CHANGELOG.md'
$ReleaseNotesDir = Join-Path $RepoRoot 'release-notes'
$DistDir         = Join-Path $RepoRoot 'dist'

# -----------------------------------------------------------------------
# Argument validation
# -----------------------------------------------------------------------
$bumpFlagCount = 0
if ($Major)    { $bumpFlagCount++ }
if ($Minor)    { $bumpFlagCount++ }
if ($Patch)    { $bumpFlagCount++ }
if ($Version)  { $bumpFlagCount++ }
if ($bumpFlagCount -gt 1) {
    throw '-Major, -Minor, -Patch, and -Version are mutually exclusive.'
}
$bump = if ($Major) { 'major' } elseif ($Minor) { 'minor' } else { 'patch' }

if ($Quiet -and ($VerbosePreference -ne 'SilentlyContinue')) {
    throw '-Quiet and -Verbose are mutually exclusive.'
}

$DryRun = [bool]$WhatIfPreference

# -----------------------------------------------------------------------
# Output helpers
# -----------------------------------------------------------------------
function Write-Info {
    param([Parameter(Mandatory)][string]$Message)
    if (-not $Quiet) {
        Write-Host $Message
    }
}

function Write-Verbose2 {
    param([Parameter(Mandatory)][string]$Message)
    Write-Verbose "  [verbose] $Message"
}

function Write-DryRun {
    param([Parameter(Mandatory)][string]$Message)
    Write-Info "[WhatIf] $Message"
}

# -----------------------------------------------------------------------
# Preflight helpers
# -----------------------------------------------------------------------
function Test-CommandExists {
    param([Parameter(Mandatory)][string]$Name)
    return [bool](Get-Command -Name $Name -ErrorAction SilentlyContinue)
}

function Assert-CommandExists {
    param([Parameter(Mandatory)][string]$Name)
    if (-not (Test-CommandExists -Name $Name)) {
        throw "$Name not on PATH"
    }
}

function Invoke-Git {
    param([Parameter(Mandatory)][string[]]$Args)
    $output = & git -C $RepoRoot @Args 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw ("git " + ($Args -join ' ') + " failed: $output")
    }
    return $output
}

function Test-UnreleasedSectionPopulated {
    param([Parameter(Mandatory)][string]$Path)

    $content = Get-Content -LiteralPath $Path -Raw
    $lines = $content -split "`r?`n"

    $inSection = $false
    $hasContent = $false
    foreach ($line in $lines) {
        if ($line -match '^## (\[)?Unreleased(\])?\s*$') {
            $inSection = $true
            continue
        }
        if ($inSection -and $line -match '^## ') {
            break
        }
        if ($inSection -and $line.Trim().Length -gt 0) {
            $hasContent = $true
        }
    }
    return $hasContent
}

function Get-LatestSemverTag {
    $raw = & git -C $RepoRoot tag --list 'v*.*.*' 2>$null
    if (-not $raw) { return $null }

    $tags = @($raw) | Where-Object { $_ -match '^v\d+\.\d+\.\d+$' }
    if ($tags.Count -eq 0) { return $null }

    # Sort by version segments (numeric, descending) and pick the top.
    $sorted = $tags | Sort-Object -Property @{
        Expression = {
            $parts = ($_ -replace '^v', '') -split '\.'
            [int[]]@($parts[0], $parts[1], $parts[2])
        }
    }
    return $sorted[-1]
}

function Compare-Semver {
    param(
        [Parameter(Mandatory)][string]$A,
        [Parameter(Mandatory)][string]$B
    )
    $pa = $A -split '\.' | ForEach-Object { [int]$_ }
    $pb = $B -split '\.' | ForEach-Object { [int]$_ }
    for ($i = 0; $i -lt 3; $i++) {
        if ($pa[$i] -gt $pb[$i]) { return 1 }
        if ($pa[$i] -lt $pb[$i]) { return -1 }
    }
    return 0
}

function Test-SemverString {
    param([Parameter(Mandatory)][string]$Value)
    return ($Value -match '^\d+\.\d+\.\d+$')
}

function Get-RepoSlug {
    $url = & git -C $RepoRoot config --get remote.origin.url 2>$null
    if (-not $url) { throw "no remote 'origin' configured" }
    $url = $url -replace '\.git$', ''

    if ($url -match '^git@github\.com:(.+)$')           { return $Matches[1] }
    if ($url -match '^https://github\.com/(.+)$')       { return $Matches[1] }
    if ($url -match '^ssh://git@github\.com/(.+)$')     { return $Matches[1] }

    throw "could not parse owner/repo from remote URL: $url"
}

function Assert-TagDoesNotExist {
    param([Parameter(Mandatory)][string]$Tag)

    $localCheck = & git -C $RepoRoot rev-parse $Tag 2>$null
    if ($LASTEXITCODE -eq 0) {
        throw "tag $Tag already exists locally"
    }

    $remoteRaw = & git -C $RepoRoot ls-remote --tags origin "refs/tags/$Tag" 2>$null
    if ($remoteRaw -and ($remoteRaw -match "refs/tags/$([Regex]::Escape($Tag))$")) {
        throw "tag $Tag already exists on origin"
    }
}

# -----------------------------------------------------------------------
# Main flow
# -----------------------------------------------------------------------
function Invoke-Preflight {
    Write-Info 'Preflight checks...'
    Assert-CommandExists -Name 'git'
    Write-Verbose2 'git ok'

    if (-not (Get-Command -Name 'Compress-Archive' -ErrorAction SilentlyContinue)) {
        throw 'Compress-Archive cmdlet not available (PowerShell 5.1+ ships it)'
    }
    Write-Verbose2 'Compress-Archive ok'

    $inTree = & git -C $RepoRoot rev-parse --is-inside-work-tree 2>$null
    if ($LASTEXITCODE -ne 0 -or $inTree -ne 'true') {
        throw 'not inside a git work tree'
    }
    Write-Verbose2 'inside git tree ok'

    Write-Verbose2 'fetching origin (tags + refs)'
    & git -C $RepoRoot fetch origin --tags --quiet 2>$null
    if ($LASTEXITCODE -ne 0) {
        throw 'git fetch origin failed (network or auth issue?)'
    }

    $currentBranch = (& git -C $RepoRoot rev-parse --abbrev-ref HEAD).Trim()
    if ($currentBranch -ne $Branch) {
        throw "current branch is '$currentBranch', expected '$Branch'"
    }
    Write-Verbose2 "on branch $Branch ok"

    $porcelain = & git -C $RepoRoot status --porcelain
    if ($porcelain) {
        throw "working tree is not clean:`n$($porcelain -join [Environment]::NewLine)"
    }
    Write-Verbose2 'working tree clean ok'

    $localSha = (& git -C $RepoRoot rev-parse HEAD).Trim()
    $originSha = & git -C $RepoRoot rev-parse "origin/$Branch" 2>$null
    if ($LASTEXITCODE -ne 0) {
        throw "origin/$Branch not found; has the branch been pushed?"
    }
    $originSha = $originSha.Trim()
    if ($localSha -ne $originSha) {
        $shortL = $localSha.Substring(0, 7)
        $shortR = $originSha.Substring(0, 7)
        throw "local $Branch ($shortL) is not in sync with origin/$Branch ($shortR)"
    }
    Write-Verbose2 "in sync with origin/$Branch ok"

    if (-not (Test-Path -LiteralPath $ChangelogPath)) {
        throw "CHANGELOG.md not found at $ChangelogPath"
    }
    if (-not (Test-UnreleasedSectionPopulated -Path $ChangelogPath)) {
        throw 'CHANGELOG.md ## Unreleased section is missing or empty'
    }
    Write-Verbose2 'CHANGELOG Unreleased section ok'

    if ($GhRelease) {
        Assert-CommandExists -Name 'gh'
        & gh auth status 2>$null | Out-Null
        if ($LASTEXITCODE -ne 0) {
            throw "gh is not authenticated (run 'gh auth login')"
        }
        Write-Verbose2 'gh authenticated ok'
    }
}

function Get-NextVersion {
    $latestTag = Get-LatestSemverTag
    $latestVersion = if ($latestTag) { $latestTag.Substring(1) } else { $null }
    $latestDisplay = if ($latestTag) { $latestTag } else { '<none>' }
    Write-Verbose2 "latest tag: $latestDisplay"

    if ($Version) {
        if (-not (Test-SemverString -Value $Version)) {
            throw "invalid semver: $Version"
        }
        if ($latestVersion) {
            if ((Compare-Semver -A $Version -B $latestVersion) -le 0) {
                throw "-Version $Version is not greater than current $latestVersion"
            }
        }
        Write-Verbose2 "explicit version requested: $Version"
        return $Version
    }

    if (-not $latestVersion) {
        Write-Verbose2 'no prior tags found, defaulting to first release: 1.0.0'
        return '1.0.0'
    }

    $parts = $latestVersion -split '\.' | ForEach-Object { [int]$_ }
    switch ($bump) {
        'major' { $parts[0]++; $parts[1] = 0; $parts[2] = 0 }
        'minor' { $parts[1]++; $parts[2] = 0 }
        'patch' { $parts[2]++ }
    }
    $next = "$($parts[0]).$($parts[1]).$($parts[2])"
    Write-Verbose2 "bump=$bump, next version: $next"
    return $next
}

function Get-ChangelogLines {
    return Get-Content -LiteralPath $ChangelogPath
}

function Get-UnreleasedBody {
    param([Parameter(Mandatory)][string[]]$Lines)

    $inSection = $false
    $out = New-Object System.Collections.Generic.List[string]
    foreach ($line in $Lines) {
        if ($line -match '^## (\[)?Unreleased(\])?\s*$') {
            $inSection = $true
            continue
        }
        if ($inSection -and $line -match '^## ') {
            break
        }
        if ($inSection) {
            $out.Add($line)
        }
    }
    return ,$out.ToArray()
}

function Update-Changelog {
    param(
        [Parameter(Mandatory)][string]$NewVersion,
        [Parameter(Mandatory)][string]$DateStr,
        [Parameter(Mandatory)][string]$RepoSlug
    )

    Write-Info 'Rolling CHANGELOG.md...'

    $allLines = Get-ChangelogLines

    # Strip trailing footer link block: walk backwards over blank and
    # [...]: ... lines.
    $endIdx = $allLines.Length - 1
    while ($endIdx -ge 0) {
        $line = $allLines[$endIdx]
        if ($line -match '^\s*$' -or $line -match '^\[[^\]]+\]:\s') {
            $endIdx--
        } else {
            break
        }
    }
    $bodyLines = if ($endIdx -ge 0) { $allLines[0..$endIdx] } else { @() }

    # Promote Unreleased heading.
    $newLines = New-Object System.Collections.Generic.List[string]
    $rolled = $false
    foreach ($line in $bodyLines) {
        if (-not $rolled -and $line -match '^## (\[)?Unreleased(\])?\s*$') {
            $newLines.Add('## [Unreleased]')
            $newLines.Add('')
            $newLines.Add("## [$NewVersion] - $DateStr")
            $rolled = $true
        } else {
            $newLines.Add($line)
        }
    }
    if (-not $rolled) {
        throw 'could not find ## Unreleased heading in CHANGELOG.md'
    }

    # Collect every released-version heading in order (newest first).
    $versions = New-Object System.Collections.Generic.List[string]
    foreach ($line in $newLines) {
        if ($line -match '^## \[(\d+\.\d+\.\d+)\]') {
            $versions.Add($Matches[1])
        }
    }

    # Build the new footer link block.
    $footer = New-Object System.Collections.Generic.List[string]
    $footer.Add("[unreleased]: https://github.com/$RepoSlug/compare/v$($versions[0])...HEAD")
    for ($i = 0; $i -lt $versions.Count; $i++) {
        $cur = $versions[$i]
        if ($i + 1 -lt $versions.Count) {
            $prev = $versions[$i + 1]
            $footer.Add("[$cur]: https://github.com/$RepoSlug/compare/v$prev...v$cur")
        } else {
            $footer.Add("[$cur]: https://github.com/$RepoSlug/releases/tag/v$cur")
        }
    }

    $bodyJoined = ($newLines -join "`n").TrimEnd("`n")
    $footerJoined = $footer -join "`n"
    $final = "$bodyJoined`n`n$footerJoined`n"

    if ($DryRun) {
        $lineCount = ($final -split "`n").Length
        Write-DryRun "would write CHANGELOG.md ($lineCount lines)"
        if ($VerbosePreference -ne 'SilentlyContinue') {
            Write-Verbose '----- CHANGELOG preview (first 40 lines) -----'
            ($final -split "`n") | Select-Object -First 40 | ForEach-Object { Write-Verbose $_ }
            Write-Verbose '----- (end preview) -----'
        }
        return
    }

    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($ChangelogPath, $final, $utf8NoBom)
    Write-Info '  wrote     CHANGELOG.md'
}

function New-ReleaseNotes {
    param(
        [Parameter(Mandatory)][string]$NewVersion,
        [Parameter(Mandatory)][string]$DateStr
    )

    Write-Info 'Writing release notes...'
    $notesFile = Join-Path $ReleaseNotesDir "v$NewVersion.md"

    # Source body: in dry-run we read from Unreleased (CHANGELOG unchanged);
    # in real run we read from the just-written ## [VERSION] section.
    $allLines = Get-ChangelogLines
    $sectionLines = if ($DryRun) {
        Get-UnreleasedBody -Lines $allLines
    } else {
        $headingPrefix = "## [$NewVersion] - "
        $inSection = $false
        $out = New-Object System.Collections.Generic.List[string]
        foreach ($line in $allLines) {
            if (-not $inSection -and $line.StartsWith($headingPrefix)) {
                $inSection = $true
                continue
            }
            if ($inSection -and $line -match '^## ') {
                break
            }
            if ($inSection) {
                $out.Add($line)
            }
        }
        ,$out.ToArray()
    }

    # Promote ### headings to ## headings.
    $promoted = $sectionLines | ForEach-Object {
        if ($_ -match '^### ') { $_ -replace '^### ', '## ' } else { $_ }
    }

    # Trim leading and trailing blank lines from $promoted.
    $promotedList = @($promoted)
    $start = 0
    while ($start -lt $promotedList.Count -and $promotedList[$start].Trim() -eq '') { $start++ }
    $end = $promotedList.Count - 1
    while ($end -ge $start -and $promotedList[$end].Trim() -eq '') { $end-- }
    if ($end -ge $start) {
        $promotedTrimmed = $promotedList[$start..$end]
    } else {
        $promotedTrimmed = @()
    }

    $notesContent = "# v$NewVersion - $DateStr`n"
    if ($NotesSummary) {
        $notesContent += "`n$NotesSummary`n"
    }
    $notesContent += "`n" + (($promotedTrimmed) -join "`n") + "`n"

    if ($DryRun) {
        $lineCount = ($notesContent -split "`n").Length
        Write-DryRun "would write release-notes/v$NewVersion.md ($lineCount lines)"
        if ($VerbosePreference -ne 'SilentlyContinue') {
            Write-Verbose '----- release-notes preview -----'
            ($notesContent -split "`n") | ForEach-Object { Write-Verbose $_ }
            Write-Verbose '----- (end preview) -----'
        }
        return
    }

    if (-not (Test-Path -LiteralPath $ReleaseNotesDir)) {
        New-Item -ItemType Directory -Path $ReleaseNotesDir | Out-Null
    }
    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($notesFile, $notesContent, $utf8NoBom)
    Write-Info "  wrote     release-notes/v$NewVersion.md"
}

function Build-SkillZips {
    param([Parameter(Mandatory)][string]$NewVersion)

    if ($NoZip) {
        Write-Info 'Skipping zip build (-NoZip).'
        return
    }

    Write-Info 'Building per-skill zips...'
    $versionDist = Join-Path $DistDir "v$NewVersion"

    if (-not $DryRun -and -not (Test-Path -LiteralPath $versionDist)) {
        New-Item -ItemType Directory -Path $versionDist -Force | Out-Null
    }

    $skillDirs = @(Get-ChildItem -LiteralPath $SkillsSrc -Directory -ErrorAction SilentlyContinue)
    $zipped = 0; $skipped = 0; $failed = 0

    foreach ($skill in $skillDirs) {
        $skillName = $skill.Name
        if ($skillName -eq '_template') {
            Write-Verbose2 'skipped _template'
            $skipped++
            continue
        }

        $zipName = "$skillName-v$NewVersion.zip"
        $zipFull = Join-Path $versionDist $zipName

        if ($DryRun) {
            Write-DryRun "would zip skills/$skillName -> dist/v$NewVersion/$zipName"
            $zipped++
            continue
        }

        if (Test-Path -LiteralPath $zipFull) {
            Remove-Item -LiteralPath $zipFull -Force
        }

        try {
            Compress-Archive -Path $skill.FullName -DestinationPath $zipFull -Force -ErrorAction Stop
            $size = (Get-Item -LiteralPath $zipFull).Length
            Write-Info ("  zipped    {0} ({1} bytes)" -f $zipName, $size)
            $zipped++
        }
        catch {
            Write-Warning ("  failed    {0}: {1}" -f $zipName, $_.Exception.Message)
            $failed++
        }
    }

    Write-Info "Zipped $zipped, Skipped $skipped, Failed $failed."
    if ($failed -gt 0) {
        throw 'one or more zip operations failed'
    }
}

function Set-SkillChecksums {
    param([Parameter(Mandatory)][string]$NewVersion)

    if ($NoZip) { return }

    Write-Info 'Computing SHA256 checksums...'
    $versionDist = Join-Path $DistDir "v$NewVersion"
    $sumsPath = Join-Path $versionDist 'SHA256SUMS.txt'

    if ($DryRun) {
        Write-DryRun "would write dist/v$NewVersion/SHA256SUMS.txt"
        return
    }

    $lines = New-Object System.Collections.Generic.List[string]
    $zips = Get-ChildItem -LiteralPath $versionDist -Filter '*.zip' | Sort-Object Name
    foreach ($z in $zips) {
        $hash = (Get-FileHash -LiteralPath $z.FullName -Algorithm SHA256).Hash.ToLower()
        $lines.Add("$hash  $($z.Name)")
    }
    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($sumsPath, ($lines -join "`n") + "`n", $utf8NoBom)
    Write-Info "  wrote     dist/v$NewVersion/SHA256SUMS.txt"
}

function Invoke-ReleaseCommit {
    param([Parameter(Mandatory)][string]$NewVersion)

    Write-Info 'Committing release...'
    $msg = "chore(release): cut v$NewVersion"
    $notesRel = "release-notes/v$NewVersion.md"

    if ($DryRun) {
        Write-DryRun "would: git add CHANGELOG.md $notesRel"
        Write-DryRun "would: git commit -m `"$msg`""
        return
    }

    & git -C $RepoRoot add 'CHANGELOG.md' $notesRel
    if ($LASTEXITCODE -ne 0) { throw 'git add failed' }

    $fullMsg = @"
$msg

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
"@
    & git -C $RepoRoot commit -m $fullMsg | Out-Null
    if ($LASTEXITCODE -ne 0) { throw 'git commit failed' }

    $sha = (& git -C $RepoRoot rev-parse HEAD).Trim()
    Write-Info ("  commit    {0} {1}" -f $sha.Substring(0, 7), $msg)
}

function New-ReleaseTag {
    param([Parameter(Mandatory)][string]$NewVersion)

    Write-Info 'Tagging...'
    $tag = "v$NewVersion"
    $notesFile = Join-Path $ReleaseNotesDir "v$NewVersion.md"

    if ($DryRun) {
        Write-DryRun "would: git tag -a $tag -F $notesFile"
        return
    }

    & git -C $RepoRoot tag -a $tag -F $notesFile
    if ($LASTEXITCODE -ne 0) { throw 'git tag failed' }
    Write-Info "  tag       $tag (annotated)"
}

function Push-Release {
    param([Parameter(Mandatory)][string]$NewVersion)

    if ($NoPush) {
        Write-Info 'Skipping push (-NoPush).'
        return
    }

    Write-Info 'Pushing to origin...'
    $tag = "v$NewVersion"

    if ($DryRun) {
        Write-DryRun "would: git push origin $Branch"
        Write-DryRun "would: git push origin $tag"
        return
    }

    & git -C $RepoRoot push origin $Branch
    if ($LASTEXITCODE -ne 0) { throw 'git push branch failed' }
    & git -C $RepoRoot push origin $tag
    if ($LASTEXITCODE -ne 0) { throw 'git push tag failed' }
    Write-Info "  pushed    $Branch and $tag"
}

function Invoke-GhRelease {
    param([Parameter(Mandatory)][string]$NewVersion)

    if (-not $GhRelease) { return }

    Write-Info 'Creating GitHub release...'
    $tag = "v$NewVersion"
    $notesFile = Join-Path $ReleaseNotesDir "v$NewVersion.md"
    $versionDist = Join-Path $DistDir "v$NewVersion"

    $assets = @()
    if (-not $NoZip) {
        $assets += @(Get-ChildItem -LiteralPath $versionDist -Filter '*.zip' -ErrorAction SilentlyContinue | ForEach-Object { $_.FullName })
        $sumsPath = Join-Path $versionDist 'SHA256SUMS.txt'
        if (Test-Path -LiteralPath $sumsPath) {
            $assets += $sumsPath
        }
    }

    if ($DryRun) {
        $assetList = if ($assets.Count -gt 0) { $assets -join ' ' } else { '' }
        Write-DryRun "would: gh release create $tag --title $tag --notes-file $notesFile $assetList"
        return
    }

    $args = @('release', 'create', $tag, '--title', $tag, '--notes-file', $notesFile) + $assets
    & gh @args
    if ($LASTEXITCODE -ne 0) {
        throw 'gh release create failed'
    }
    Write-Info "  released  $tag on GitHub"
}

function Show-Summary {
    param([Parameter(Mandatory)][string]$NewVersion)
    Write-Info ''
    if ($DryRun) {
        Write-Info "Dry run complete. Target version: v$NewVersion. No changes were made."
    } else {
        Write-Info "Release v$NewVersion cut successfully."
        if ($NoPush) {
            Write-Info "Local-only (-NoPush). Push with: git push origin $Branch && git push origin v$NewVersion"
        }
    }
}

# -----------------------------------------------------------------------
# Run
# -----------------------------------------------------------------------
Write-Info "release.ps1: cutting release from $RepoRoot"
Invoke-Preflight

$nextVersion = Get-NextVersion
Assert-TagDoesNotExist -Tag "v$nextVersion"

$repoSlug = Get-RepoSlug
$dateStr = [DateTime]::UtcNow.ToString('yyyy-MM-dd')
Write-Verbose2 "repo slug: $repoSlug"
Write-Verbose2 "release date (UTC): $dateStr"

Update-Changelog       -NewVersion $nextVersion -DateStr $dateStr -RepoSlug $repoSlug
New-ReleaseNotes       -NewVersion $nextVersion -DateStr $dateStr
Build-SkillZips        -NewVersion $nextVersion
Set-SkillChecksums     -NewVersion $nextVersion
Invoke-ReleaseCommit   -NewVersion $nextVersion
New-ReleaseTag         -NewVersion $nextVersion
Push-Release           -NewVersion $nextVersion
Invoke-GhRelease       -NewVersion $nextVersion
Show-Summary           -NewVersion $nextVersion
