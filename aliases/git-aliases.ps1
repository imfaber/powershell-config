# GIT

<#
.SYNOPSIS
    Runs git with any arguments.
.EXAMPLE
    g status
    g log --oneline
#>
function Get-Git { & git $args }
New-Alias -Name g -Value Get-Git -Force -Option AllScope

<#
.SYNOPSIS
    Shows a short, branch-aware git status.
.EXAMPLE
    gs
    # Output: ## main...origin/main
    #          M src/app.ts
#>
function Get-GitStatus { & git status -sb $args }
New-Alias -Name gs -Value Get-GitStatus -Force -Option AllScope

function Get-GitGeneratedMessage {
    param([string]$Diff)

    $apiKey = $env:GEMINI_API_KEY
    if ($apiKey) { $apiKey = $apiKey.Trim() }
    if (-not $apiKey -or -not $Diff) { return $null }

    # Truncate to avoid exceeding token limits
    $maxChars = 8000
    if ($Diff.Length -gt $maxChars) {
        $Diff = $Diff.Substring(0, $maxChars) + "`n... (diff truncated)"
    }

    Write-Host "Generating commit message..." -ForegroundColor Cyan
    try {
        $prompt = @"
Generate a single git commit message in conventional commit format for the following diff.
Format: type(scope): short description
Types: feat, fix, docs, style, refactor, test, chore, perf, ci, build
- The scope is optional; omit it if not clearly applicable.
- Keep the description under 72 characters total.
- Output only the commit message line, nothing else.

$Diff
"@
        $body = @{
            contents         = @(
                @{
                    parts = @(
                        @{ text = $prompt }
                    )
                }
            )
            generationConfig = @{
                temperature     = 0.2
                maxOutputTokens = 100
            }
        } | ConvertTo-Json -Depth 6

        # gemini-flash-latest is a moving alias that is frequently
        # overloaded (503); pin stable models and fall back when needed.
        $models = @('gemini-3.5-flash', 'gemini-flash-lite-latest', 'gemini-3.1-flash-lite')
        if ($env:GEMINI_MODEL) { $models = @($env:GEMINI_MODEL) + $models | Select-Object -Unique }

        $response = $null
        foreach ($model in $models) {
            for ($attempt = 1; $attempt -le 2; $attempt++) {
                try {
                    $response = Invoke-RestMethod `
                        -Uri "https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent" `
                        -Method Post `
                        -Headers @{ "X-goog-api-key" = $apiKey } `
                        -ContentType "application/json" `
                        -Body $body `
                        -TimeoutSec 15
                    break
                }
                catch {
                    $status = if ($_.Exception.Response) { [int]$_.Exception.Response.StatusCode } else { 0 }
                    $retryable = $status -eq 0 -or $status -in 429, 500, 502, 503, 504
                    if (-not $retryable) { throw }
                    if ($attempt -lt 2) {
                        Start-Sleep -Seconds 2
                        continue
                    }
                    break   # fall back to the next model
                }
            }
            if ($response) { break }
        }

        if (-not $response) {
            throw "All Gemini models are currently unavailable. Try again shortly."
        }

        $generated = $response.candidates[0].content.parts[0].text.Trim()
        if (-not $generated) { return $null }

        $generated = ($generated -split "`r?`n" | Where-Object { $_ -and $_.Trim() -ne "" } | Select-Object -First 1).Trim()
        $generated = $generated -replace '^[`"''\s]+|[`"''\s]+$', ''

        Write-Host "Suggested : $generated" -ForegroundColor Green
        $confirm = Read-Host "Accept? [Y=yes (default) / E=edit / N=enter manually]"

        switch -Regex ($confirm.Trim().ToLower()) {
            '^$|^y' { return $generated }
            '^e' {
                Write-Host "Editing (clear and retype, or press Enter to keep):" -ForegroundColor Cyan
                Write-Host "  $generated" -ForegroundColor DarkGray
                $edited = Read-Host -Prompt "Commit message"
                if ($edited) { return $edited }
                return $generated
            }
            default { return $null }
        }
    }
    catch {
        if ($_.Exception.Response -and [int]$_.Exception.Response.StatusCode -eq 401) {
            Write-Host "AI generation failed: 401 Unauthorized. Check `$env:GEMINI_API_KEY and API key restrictions." -ForegroundColor Yellow
        }
        else {
            Write-Host "AI generation failed: $($_.Exception.Message)" -ForegroundColor Yellow
        }
        return $null
    }
}

function Select-GitChangedFiles {
    param(
        [Parameter(Mandatory)][object[]]$Files,
        [string[]]$Deselected = @(),
        [string]$Title = 'Select files to commit:',
        [string]$ConfirmLabel = 'commit'
    )

    if ([Console]::IsInputRedirected -or [Console]::IsOutputRedirected) {
        throw "File selection needs an interactive console. Use -All to process every changed file."
    }

    $isSelected = @{}
    foreach ($f in $Files) { $isSelected[$f.Path] = -not ($Deselected -contains $f.Path) }

    $cursor = 0
    $offset = 0
    $width = [Math]::Max(20, [Console]::WindowWidth - 1)
    $height = [Math]::Max(1, [Math]::Min($Files.Count, [Console]::WindowHeight - 6))
    $pathWidth = [Math]::Max(4, $width - 10)

    Write-Host $Title -ForegroundColor Cyan
    $blockTop = [Console]::CursorTop
    $cancelled = $false
    $done = $false
    $cursorVisible = [Console]::CursorVisible

    try {
        [Console]::CursorVisible = $false
        while (-not $done) {
            if ($cursor -lt $offset) { $offset = $cursor }
            if ($cursor -ge $offset + $height) { $offset = $cursor - $height + 1 }

            [Console]::SetCursorPosition(0, $blockTop)

            $count = @($Files | Where-Object { $isSelected[$_.Path] }).Count
            $title = "  $count/$($Files.Count) selected   Up/Down move   Space toggle   A all   Enter $ConfirmLabel   Esc cancel"
            if ($title.Length -gt $width) { $title = $title.Substring(0, $width) }
            Write-Host $title.PadRight($width) -ForegroundColor DarkGray

            for ($row = 0; $row -lt $height; $row++) {
                $i = $offset + $row
                if ($i -ge $Files.Count) {
                    Write-Host (' ' * $width)
                    continue
                }

                $file = $Files[$i]
                $checked = [bool]$isSelected[$file.Path]

                if ($i -eq $cursor) { Write-Host '>' -NoNewline -ForegroundColor Cyan }
                else { Write-Host ' ' -NoNewline }
                Write-Host ' ' -NoNewline
                if ($checked) { Write-Host '[x]' -NoNewline -ForegroundColor Green }
                else { Write-Host '[ ]' -NoNewline -ForegroundColor DarkGray }
                Write-Host ' ' -NoNewline

                $color = switch ($file.Status.Substring(0, 1)) {
                    ' ' { 'Yellow' }
                    '?' { 'DarkGray' }
                    'A' { 'Green' }
                    'D' { 'Red' }
                    'R' { 'Cyan' }
                    'C' { 'Cyan' }
                    'U' { 'Magenta' }
                    default { 'Yellow' }
                }
                Write-Host $file.Status.PadRight(2) -NoNewline -ForegroundColor $color
                Write-Host ' ' -NoNewline

                $text = $file.Path
                if ($text.Length -gt $pathWidth) {
                    $text = '...' + $text.Substring($text.Length - ($pathWidth - 3))
                }
                Write-Host $text -NoNewline -ForegroundColor $(if ($checked) { 'White' } else { 'DarkGray' })
                Write-Host (' ' * ($pathWidth - $text.Length))
            }

            $key = [Console]::ReadKey($true)
            switch ($key.Key) {
                'UpArrow' { if ($cursor -gt 0) { $cursor-- } }
                'DownArrow' { if ($cursor -lt $Files.Count - 1) { $cursor++ } }
                'Spacebar' { $isSelected[$Files[$cursor].Path] = -not $isSelected[$Files[$cursor].Path] }
                'Enter' { $done = $true }
                'Escape' { $cancelled = $true; $done = $true }
                default {
                    switch ($key.KeyChar) {
                        'k' { if ($cursor -gt 0) { $cursor-- } }
                        'j' { if ($cursor -lt $Files.Count - 1) { $cursor++ } }
                        { $_ -in 'a', 'A' } {
                            $allChecked = @($Files | Where-Object { -not $isSelected[$_.Path] }).Count -eq 0
                            foreach ($f in $Files) { $isSelected[$f.Path] = -not $allChecked }
                        }
                        { $_ -in 'q', 'Q' } { $cancelled = $true; $done = $true }
                    }
                }
            }
        }
    }
    finally {
        [Console]::CursorVisible = $cursorVisible
        [Console]::SetCursorPosition(0, $blockTop)
        for ($row = 0; $row -le $height; $row++) { Write-Host (' ' * $width) }
        [Console]::SetCursorPosition(0, $blockTop)
    }

    return [pscustomobject]@{
        Cancelled = $cancelled
        Paths     = @($Files | Where-Object { $isSelected[$_.Path] } | ForEach-Object { $_.Path })
    }
}

function Get-GitWorkingTreeChanges {
    param([Parameter(Mandatory)][string]$Root)

    $raw = (& git -C $Root status --porcelain=v1 -z --untracked-files=all) -join ''
    $items = @()
    if ($raw) {
        $parts = $raw -split "`0"
        for ($i = 0; $i -lt $parts.Count; $i++) {
            $entry = $parts[$i]
            if (-not $entry) { continue }
            $status = $entry.Substring(0, 2)
            $path = $entry.Substring(3)
            $originalPath = $null
            # Renames/copies carry the original path as an extra NUL-terminated field.
            if ($entry[0] -eq 'R' -or $entry[0] -eq 'C') {
                $originalPath = $parts[++$i]
            }
            $items += [pscustomobject]@{
                Status       = $status
                Path         = $path
                OriginalPath = $originalPath
            }
        }
    }
    return $items
}

function Get-GitRememberedSelection {
    param([Parameter(Mandatory)][string]$StatePath)

    if (Test-Path -LiteralPath $StatePath) {
        return @(Get-Content -LiteralPath $StatePath | Where-Object { $_ })
    }
    return @()
}

function Set-GitRememberedSelection {
    param(
        [Parameter(Mandatory)][string]$StatePath,
        [string[]]$Deselected = @()
    )

    if ($Deselected.Count -gt 0) {
        Set-Content -LiteralPath $StatePath -Value $Deselected -Encoding utf8
    }
    elseif (Test-Path -LiteralPath $StatePath) {
        Remove-Item -LiteralPath $StatePath -ErrorAction SilentlyContinue
    }
}

<#
.SYNOPSIS
    Commits only the files you select, remembering files you leave unselected.
    The AI-generated message is based on the selected files' diff only.
.EXAMPLE
    gc          # pick files interactively, then commit
    gc "feat: add selective commit"
    gc -All     # commit every changed file
    gc -Forget  # clear the remembered unselected files
#>
function Get-GitCommit {
    [CmdletBinding()]
    param(
        [Parameter(Position = 0)]
        [string]$Message,
        [switch]$All,
        [switch]$Forget
    )

    $root = & git rev-parse --show-toplevel 2>$null
    if ($LASTEXITCODE -ne 0 -or -not $root) {
        Write-Host 'Not inside a git repository.' -ForegroundColor Yellow
        return
    }

    $statePath = & git -C $root rev-parse --git-path git-commit-unselected
    if (-not [System.IO.Path]::IsPathRooted($statePath)) {
        $statePath = Join-Path $root $statePath
    }
    $statePath = [System.IO.Path]::GetFullPath($statePath)

    if ($Forget) {
        Remove-Item -LiteralPath $statePath -ErrorAction SilentlyContinue
        Write-Host 'Cleared remembered unselected files.' -ForegroundColor Cyan
        return
    }

    $raw = (& git -C $root status --porcelain=v1 -z --untracked-files=all) -join ''
    $files = @()
    if ($raw) {
        $parts = $raw -split "`0"
        for ($i = 0; $i -lt $parts.Count; $i++) {
            $entry = $parts[$i]
            if (-not $entry) { continue }
            $files += [pscustomobject]@{
                Status = $entry.Substring(0, 2)
                Path   = $entry.Substring(3)
            }
            # Renames/copies carry the original path as an extra NUL-terminated field.
            if ($entry[0] -eq 'R' -or $entry[0] -eq 'C') { $i++ }
        }
    }

    if ($files.Count -eq 0) {
        Write-Host 'Nothing to commit, working tree clean.' -ForegroundColor Yellow
        return
    }

    $remembered = @()
    if (Test-Path -LiteralPath $statePath) {
        $remembered = @(Get-Content -LiteralPath $statePath | Where-Object { $_ })
    }

    if ($All) {
        $selected = @($files | ForEach-Object { $_.Path })
    }
    else {
        $choice = Select-GitChangedFiles -Files $files -Deselected $remembered
        if ($choice.Cancelled) {
            Write-Host 'Commit cancelled.' -ForegroundColor Yellow
            return
        }
        $selected = @($choice.Paths)
    }

    # Remember what was left unselected, pruning paths that no longer changed.
    $deselected = @($files | Where-Object { $selected -notcontains $_.Path } | ForEach-Object { $_.Path })
    if ($deselected.Count -gt 0) {
        Set-Content -LiteralPath $statePath -Value $deselected -Encoding utf8
    }
    elseif (Test-Path -LiteralPath $statePath) {
        Remove-Item -LiteralPath $statePath -ErrorAction SilentlyContinue
    }

    if ($selected.Count -eq 0) {
        Write-Host 'No files selected, nothing to commit.' -ForegroundColor Yellow
        return
    }

    # Make the index contain exactly the selected files.
    $toUnstage = @($files | Where-Object {
            $deselected -contains $_.Path -and $_.Status.Substring(0, 1) -notin @(' ', '?')
        } | ForEach-Object { $_.Path })
    if ($toUnstage.Count -gt 0) {
        & git --literal-pathspecs -C $root restore --staged -- $toUnstage 2>$null | Out-Null
    }

    & git --literal-pathspecs -C $root add -A -- $selected
    if ($LASTEXITCODE -ne 0) {
        Write-Host 'Failed to stage the selected files.' -ForegroundColor Red
        return
    }

    if (-not $Message) {
        $diff = (& git -C $root diff --cached --no-color) -join "`n"
        $Message = Get-GitGeneratedMessage -Diff $diff
        if (-not $Message) {
            $Message = Read-Host -Prompt 'Commit message'
        }
        if (-not $Message) {
            Write-Host 'Aborting commit: empty message' -ForegroundColor Yellow
            return
        }
    }

    & git -C $root commit -m $Message
}
New-Alias -Name gc -Value Get-GitCommit -Force -Option AllScope

<#
.SYNOPSIS
    Opens an interactive commit that lets you select hunks to include.
.EXAMPLE
    gci
#>
function Get-GitCommitInteractive { & git commit -ev --interactive $args }
New-Alias -Name gci -Value Get-GitCommitInteractive -Force -Option AllScope

<#
.SYNOPSIS
    Stages all tracked changes and commits with a message.
    When no message is given, attempts to auto-generate one via the Gemini API
    in conventional commit format (requires $env:GEMINI_API_KEY).
.EXAMPLE
    gca "fix: correct null-check in parser"
    gca          # auto-generates a message, then prompts to accept/edit/skip
#>
function Get-GitCommitAll {
    param(
        [string]$Message
    )
    & git add --all

    if (-not $Message -or $Message -eq "") {
        $diff = (& git diff --cached --no-color) -join "`n"
        $Message = Get-GitGeneratedMessage -Diff $diff

        if (-not $Message -or $Message -eq "") {
            $Message = Read-Host -Prompt "Commit message"
            if (-not $Message -or $Message -eq "") {
                Write-Host "Aborting commit: empty message" -ForegroundColor Yellow
                return
            }
        }
    }

    & git commit -av -m $Message
}
New-Alias -Name gca -Value Get-GitCommitAll -Force -Option AllScope

# <#
# .SYNOPSIS
#     Stages all tracked changes and commits with a message.
#     When no message is given, attempts to auto-generate one via the OpenAI API
#     in conventional commit format (requires $env:OPENAI_API_KEY).
# .EXAMPLE
#     gca "fix: correct null-check in parser"
#     gca          # auto-generates a message, then prompts to accept/edit/skip
# #>
# function Get-GitCommitAll {
#     param(
#         [string]$Message
#     )

#     & git add --all

#     if (-not $Message -or $Message -eq "") {
#         $apiKey = $env:GITHUB_TOKEN
#         if ($apiKey) {
#             # Capture what will be committed (-a stages all tracked changes)
#             $diff = & git diff HEAD 2>$null
#             if (-not $diff) { $diff = & git diff --cached 2>$null }

#             if ($diff) {
#                 # Truncate to avoid exceeding token limits
#                 $maxChars = 8000
#                 if ($diff.Length -gt $maxChars) {
#                     $diff = $diff.Substring(0, $maxChars) + "`n... (diff truncated)"
#                 }

#                 Write-Host "Generating commit message..." -ForegroundColor Cyan
#                 try {
#                     $prompt = @"
# Generate a single git commit message in conventional commit format for the following diff.
# Format: type(scope): short description
# Types: feat, fix, docs, style, refactor, test, chore, perf, ci, build
# - The scope is optional; omit it if not clearly applicable.
# - Keep the description under 72 characters total.
# - Output only the commit message line, nothing else.

# $diff
# "@
#                     $body = @{
#                         model    = "gpt-4o-mini"
#                         messages = @(@{ role = "user"; content = $prompt })
#                         max_tokens  = 80
#                         temperature = 0.3
#                     } | ConvertTo-Json -Depth 5

#                     $response = Invoke-RestMethod `
#                         -Uri "https://models.inference.ai.azure.com/chat/completions" `
#                         -Method Post `
#                         -Headers @{ Authorization = "Bearer $apiKey"; "Content-Type" = "application/json" } `
#                         -Body $body

#                     $generated = $response.choices[0].message.content.Trim()
#                     Write-Host "Suggested : $generated" -ForegroundColor Green
#                     $confirm = Read-Host "Accept? [Y=yes (default) / E=edit / N=enter manually]"

#                     switch -Regex ($confirm.Trim().ToLower()) {
#                         '^$|^y' { $Message = $generated }
#                         '^e'    {
#                             Write-Host "Editing (clear and retype, or press Enter to keep):" -ForegroundColor Cyan
#                             Write-Host "  $generated" -ForegroundColor DarkGray
#                             $edited = Read-Host -Prompt "Commit message"
#                             $Message = if ($edited) { $edited } else { $generated }
#                         }
#                         default { <# fall through to manual prompt below #> }
#                     }
#                 }
#                 catch {
#                     Write-Host "AI generation failed: $($_.Exception.Message)" -ForegroundColor Yellow
#                 }
#             }
#         }

#         if (-not $Message -or $Message -eq "") {
#             $Message = Read-Host -Prompt "Commit message"
#             if (-not $Message -or $Message -eq "") {
#                 Write-Host "Aborting commit: empty message" -ForegroundColor Yellow
#                 return
#             }
#         }
#     }

#     & git commit -av -m $Message
# }
# New-Alias -Name gca -Value Get-GitCommitAll -Force -Option AllScope

<#
.SYNOPSIS
    Stages specific files or paths.
.EXAMPLE
    ga src/app.ts
    ga .
#>
function Get-GitAdd { & git add $args }
New-Alias -Name ga -Value Get-GitAdd -Force -Option AllScope

<#
.SYNOPSIS
    Stages all changes (new, modified, and deleted files).
.EXAMPLE
    gaa
#>
function Get-GitAddAll { & git add --all $args }
New-Alias -Name gaa -Value Get-GitAddAll -Force -Option AllScope

<#
.SYNOPSIS
    Displays a colorized, decorated commit graph.
.EXAMPLE
    glog
    glog --all
#>
function Get-GitTree { & git log --color --graph --pretty=format:'%Cred%h%Creset -%C(yellow)%d%Creset %s %Cgreen(%cr) %C(bold blue)<%an>%Creset' --abbrev-commit --decorate $args }
New-Alias -Name glog -Value Get-GitTree -Force -Option AllScope

<#
.SYNOPSIS
    Pushes the current branch to its remote.
.EXAMPLE
    gps
    gps origin feature/my-branch
    gps --force-with-lease
#>
function Get-GitPush { & git push $args }
New-Alias -Name gps -Value Get-GitPush -Force -Option AllScope

<#
.SYNOPSIS
    Pulls changes from the remote into the current branch.
.EXAMPLE
    gpl
    gpl --rebase
#>
function Get-GitPull { & git pull $args }
New-Alias -Name gpl -Value Get-GitPull -Force -Option AllScope

<#
.SYNOPSIS
    Fetches all remotes without merging.
.EXAMPLE
    gf
    gf origin
#>
function Get-GitFetch { & git fetch $args }
New-Alias -Name gf -Value Get-GitFetch -Force -Option AllScope

<#
.SYNOPSIS
    Checks out a branch, file, or commit.
.EXAMPLE
    gco feature/my-branch
    gco -- src/app.ts    # restore a file to HEAD
#>
function Get-GitCheckout { & git checkout $args }
New-Alias -Name gco -Value Get-GitCheckout -Force -Option AllScope

<#
.SYNOPSIS
    Checks out the main branch.
.EXAMPLE
    gcom
#>
function Get-GitCheckoutMain { & git checkout main $args }
New-Alias -Name gcom -Value Get-GitCheckoutMain -Force -Option AllScope

<#
.SYNOPSIS
    Merges a branch into the current branch.
.EXAMPLE
    gm feature/my-branch
    gm --no-ff feature/my-branch
#>
function Get-GitMerge { & git merge $args }
New-Alias -Name gm -Value Get-GitMerge -Force -Option AllScope

<#
.SYNOPSIS
    Creates and switches to a new branch.
.EXAMPLE
    gcob feature/my-branch
    gcob hotfix/null-ref origin/main    # branch off a specific starting point
#>
function Get-GitCheckoutBranch { & git checkout -b $args }
New-Alias -Name gcob -Value Get-GitCheckoutBranch -Force -Option AllScope

<#
.SYNOPSIS
    Lists, creates, or deletes branches.
.EXAMPLE
    gb                          # list local branches
    gb -a                       # list all branches including remote
    gb -d feature/my-branch     # delete a merged branch
#>
function Get-GitBranch { & git branch $args }
New-Alias -Name gb -Value Get-GitBranch -Force -Option AllScope

<#
.SYNOPSIS
    Lists all remotes with their fetch/push URLs.
.EXAMPLE
    gr
#>
function Get-GitRemote { & git remote -v $args }
New-Alias -Name gr -Value Get-GitRemote -Force -Option AllScope

<#
.SYNOPSIS
    Discards local changes for the files you select, restoring them to a commit.
    Files you leave unselected are remembered per repository.
    WARNING: discarding is irreversible, especially for untracked files.
.EXAMPLE
    grsh             # pick files to discard, restoring them to HEAD
    grsh HEAD~1      # pick files to discard, restoring them to HEAD~1
    grsh -All        # discard every tracked change (classic hard reset)
    grsh -Forget     # clear the remembered unselected files
#>
function Get-GitResetHard {
    [CmdletBinding()]
    param(
        [Parameter(Position = 0)]
        [string]$Commit = 'HEAD',
        [switch]$All,
        [switch]$Forget,
        [switch]$Force
    )

    $root = & git rev-parse --show-toplevel 2>$null
    if ($LASTEXITCODE -ne 0 -or -not $root) {
        Write-Host 'Not inside a git repository.' -ForegroundColor Yellow
        return
    }

    $statePath = & git -C $root rev-parse --git-path git-reset-unselected
    if (-not [System.IO.Path]::IsPathRooted($statePath)) {
        $statePath = Join-Path $root $statePath
    }
    $statePath = [System.IO.Path]::GetFullPath($statePath)

    if ($Forget) {
        Remove-Item -LiteralPath $statePath -ErrorAction SilentlyContinue
        Write-Host 'Cleared remembered unselected files.' -ForegroundColor Cyan
        return
    }

    & git -C $root rev-parse --verify --quiet "$Commit^{commit}" | Out-Null
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Unknown commit: $Commit" -ForegroundColor Red
        return
    }

    if ($All) {
        & git -C $root reset --hard $Commit
        return
    }

    $files = @(Get-GitWorkingTreeChanges -Root $root)

    if ($files.Count -eq 0) {
        Write-Host 'Nothing to discard, working tree clean.' -ForegroundColor Yellow
        return
    }

    $remembered = @(Get-GitRememberedSelection -StatePath $statePath)

    $choice = Select-GitChangedFiles -Files $files -Deselected $remembered -Title 'Select files to discard:' -ConfirmLabel 'discard'
    if ($choice.Cancelled) {
        Write-Host 'Discard cancelled.' -ForegroundColor Yellow
        return
    }
    $selected = @($choice.Paths)

    # Remember what was left unselected, pruning paths that no longer changed.
    $deselected = @($files | Where-Object { $selected -notcontains $_.Path } | ForEach-Object { $_.Path })
    Set-GitRememberedSelection -StatePath $statePath -Deselected $deselected

    if ($selected.Count -eq 0) {
        Write-Host 'No files selected, nothing to discard.' -ForegroundColor Yellow
        return
    }

    if (-not $Force) {
        $answer = Read-Host "Discard changes in $($selected.Count) file(s) and restore them to $Commit? [y/N]"
        if ($answer.Trim().ToLower() -notin @('y', 'yes')) {
            Write-Host 'Discard cancelled.' -ForegroundColor Yellow
            return
        }
    }

    # Untracked files have no entry in the target commit, so delete them.
    $selectedEntries = @($files | Where-Object { $selected -contains $_.Path })
    $untracked = @($selectedEntries | Where-Object { $_.Status -eq '??' } | ForEach-Object { $_.Path })
    if ($untracked.Count -gt 0) {
        & git --literal-pathspecs -C $root clean -f -d -- $untracked
    }

    # Restore tracked files in both index and working tree. Renames need both sides.
    $tracked = @($selectedEntries | Where-Object { $_.Status -ne '??' } | ForEach-Object {
            $_.Path
            if ($_.Status[0] -eq 'R' -and $_.OriginalPath) { $_.OriginalPath }
        })
    if ($tracked.Count -gt 0) {
        & git --literal-pathspecs -C $root restore --source=$Commit --staged --worktree -- $tracked
        if ($LASTEXITCODE -ne 0) {
            Write-Host 'Failed to discard the selected files.' -ForegroundColor Red
        }
    }
}
New-Alias -Name grsh -Value Get-GitResetHard -Force -Option AllScope

<#
.SYNOPSIS
    Discards selected changes whether tracked or untracked (git reset --hard + git clean -df).
    Files you leave unselected are remembered per repository.
    WARNING: discarding is irreversible, including untracked files.
.EXAMPLE
    gwipe             # pick files to discard, restoring tracked files and deleting untracked ones
    gwipe HEAD~1      # same, restoring tracked files to HEAD~1
    gwipe -All        # discard everything: git reset --hard + git clean -df
    gwipe -Forget     # clear the remembered unselected files
#>
function Get-GitWipe {
    [CmdletBinding()]
    param(
        [Parameter(Position = 0)]
        [string]$Commit = 'HEAD',
        [switch]$All,
        [switch]$Forget,
        [switch]$Force
    )

    $root = & git rev-parse --show-toplevel 2>$null
    if ($LASTEXITCODE -ne 0 -or -not $root) {
        Write-Host 'Not inside a git repository.' -ForegroundColor Yellow
        return
    }

    $statePath = & git -C $root rev-parse --git-path git-wipe-unselected
    if (-not [System.IO.Path]::IsPathRooted($statePath)) {
        $statePath = Join-Path $root $statePath
    }
    $statePath = [System.IO.Path]::GetFullPath($statePath)

    if ($Forget) {
        Remove-Item -LiteralPath $statePath -ErrorAction SilentlyContinue
        Write-Host 'Cleared remembered unselected files.' -ForegroundColor Cyan
        return
    }

    & git -C $root rev-parse --verify --quiet "$Commit^{commit}" | Out-Null
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Unknown commit: $Commit" -ForegroundColor Red
        return
    }

    if ($All) {
        if (-not $Force) {
            $answer = Read-Host "Discard ALL changes, including untracked files, and restore to $Commit? [y/N]"
            if ($answer.Trim().ToLower() -notin @('y', 'yes')) {
                Write-Host 'Discard cancelled.' -ForegroundColor Yellow
                return
            }
        }
        & git -C $root reset --hard $Commit
        if ($LASTEXITCODE -ne 0) { return }
        & git -C $root clean -f -d
        return
    }

    $files = @(Get-GitWorkingTreeChanges -Root $root)
    if ($files.Count -eq 0) {
        Write-Host 'Nothing to discard, working tree clean.' -ForegroundColor Yellow
        return
    }

    $remembered = @(Get-GitRememberedSelection -StatePath $statePath)

    $choice = Select-GitChangedFiles -Files $files -Deselected $remembered -Title 'Select files to discard:' -ConfirmLabel 'discard'
    if ($choice.Cancelled) {
        Write-Host 'Discard cancelled.' -ForegroundColor Yellow
        return
    }
    $selected = @($choice.Paths)

    # Remember what was left unselected, pruning paths that no longer changed.
    $deselected = @($files | Where-Object { $selected -notcontains $_.Path } | ForEach-Object { $_.Path })
    Set-GitRememberedSelection -StatePath $statePath -Deselected $deselected

    if ($selected.Count -eq 0) {
        Write-Host 'No files selected, nothing to discard.' -ForegroundColor Yellow
        return
    }

    if (-not $Force) {
        $answer = Read-Host "Discard changes in $($selected.Count) file(s), including untracked ones, and restore them to $Commit? [y/N]"
        if ($answer.Trim().ToLower() -notin @('y', 'yes')) {
            Write-Host 'Discard cancelled.' -ForegroundColor Yellow
            return
        }
    }

    # Untracked files have no entry in the target commit, so delete them.
    $selectedEntries = @($files | Where-Object { $selected -contains $_.Path })
    $untracked = @($selectedEntries | Where-Object { $_.Status -eq '??' } | ForEach-Object { $_.Path })
    if ($untracked.Count -gt 0) {
        & git --literal-pathspecs -C $root clean -f -d -- $untracked
    }

    # Restore tracked files in both index and working tree. Renames need both sides.
    $tracked = @($selectedEntries | Where-Object { $_.Status -ne '??' } | ForEach-Object {
            $_.Path
            if ($_.Status[0] -eq 'R' -and $_.OriginalPath) { $_.OriginalPath }
        })
    if ($tracked.Count -gt 0) {
        & git --literal-pathspecs -C $root restore --source=$Commit --staged --worktree -- $tracked
        if ($LASTEXITCODE -ne 0) {
            Write-Host 'Failed to discard the selected files.' -ForegroundColor Red
        }
    }
}
New-Alias -Name gwipe -Value Get-GitWipe -Force -Option AllScope

<#
.SYNOPSIS
    Switches back to the previously checked-out branch.
.EXAMPLE
    gcop    # equivalent to: git checkout -
#>
function Get-GitCheckoutPreviousBranch { & git checkout - $args}
New-Alias -Name gcop -Value Get-GitCheckoutPreviousBranch

<#
.SYNOPSIS
    Shows changes between commits, the index, or the working tree.
.EXAMPLE
    gd                          # unstaged changes
    gd --staged                 # staged changes
    gd HEAD~1 HEAD              # diff between last two commits
    gd src/app.ts               # diff a specific file
#>
function Get-GitDiff { & git diff $args}
New-Alias -Name gd -Value Get-GitDiff

<#
.SYNOPSIS
    Force-deletes a local branch or all branches matching a prefix pattern.
    Use a trailing '*' to delete all branches with a given prefix.
.EXAMPLE
    gbd feature/my-branch       # delete a single branch
    gbd feature/*               # delete all branches starting with 'feature/'
#>
function Remove-GitBranch {
    param (
        [string]$BranchPattern
    )

    if ($BranchPattern -like '*`**') {
        # If the pattern contains *, delete all branches matching the pattern
        $pattern = $BranchPattern -replace '\*$', ''  # Remove the trailing *
        git branch | Where-Object { $_ -match "^\s*$pattern" } | ForEach-Object {
            $branchName = ($_ -replace '^\s*', '')
            git branch -D $branchName
        }
    }
    else {
        # Delete a single branch
        git branch -D $BranchPattern
    }
}
New-Alias -Name gbd -Value Remove-GitBranch -Force -Option AllScope

<#
.SYNOPSIS
    Updates main from remote and merges it into the current branch.
    Equivalent to: gcom && gpl && gco <current-branch> && gm main
.EXAMPLE
    # While on feat-a:
    gmm
    # Switches to main, pulls, switches back to feat-a, merges main into feat-a.
#>
function Merge-MainIntoCurrent {
    $defaultBranch = git symbolic-ref refs/remotes/origin/HEAD 2>$null | ForEach-Object { $_ -replace '^refs/remotes/origin/', '' }

    $currentBranch = git rev-parse --abbrev-ref HEAD
    if ($LASTEXITCODE -ne 0) { return }
    if ($currentBranch -eq $defaultBranch) {
        Write-Host "Already on $defaultBranch. Just pulling." -ForegroundColor Yellow
        & git pull
        return
    }
    & git checkout $defaultBranch &&
    & git pull &&
    & git checkout $currentBranch &&
    & git merge $defaultBranch
}
New-Alias -Name gmm -Value Merge-MainIntoCurrent -Force -Option AllScope
