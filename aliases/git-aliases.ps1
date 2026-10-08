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

<#
.SYNOPSIS
    Opens the commit editor with verbose diff output.
.EXAMPLE
    gc
    gc --amend
#>
function Get-GitCommit { & git commit -ev $args }
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
        $apiKey = $env:GEMINI_API_KEY
        if ($apiKey) { $apiKey = $apiKey.Trim() }
        if ($apiKey) {
            # Capture what will be committed (-a stages all tracked changes)
            $diff = & git diff HEAD 2>$null
            if (-not $diff) { $diff = & git diff --cached 2>$null }

            if ($diff) {
                # Truncate to avoid exceeding token limits
                $maxChars = 4000
                if ($diff.Length -gt $maxChars) {
                    $diff = $diff.Substring(0, $maxChars) + "`n... (diff truncated)"
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

$diff
"@
                    $body = @{

                        contents = @(
                            @{
                                parts = @(
                                    @{ text = $prompt }
                                )
                            }
                        )
                    } | ConvertTo-Json -Depth 6

                    $response = Invoke-RestMethod `
                        -Uri "https://generativelanguage.googleapis.com/v1beta/models/gemini-flash-latest:generateContent" `
                        -Method Post `
                        -Headers @{ "X-goog-api-key" = $apiKey } `
                        -ContentType "application/json" `
                        -Body $body

                    $generated = $response.candidates[0].content.parts[0].text.Trim()
                    if ($generated) {
                        $generated = ($generated -split "`r?`n" | Where-Object { $_ -and $_.Trim() -ne "" } | Select-Object -First 1).Trim()
                        $generated = $generated -replace '^[`"''\s]+|[`"''\s]+$',''
                    }
                    Write-Host "Suggested : $generated" -ForegroundColor Green
                    $confirm = Read-Host "Accept? [Y=yes (default) / E=edit / N=enter manually]"

                    switch -Regex ($confirm.Trim().ToLower()) {
                        '^$|^y' { $Message = $generated }
                        '^e'    {
                            Write-Host "Editing (clear and retype, or press Enter to keep):" -ForegroundColor Cyan
                            Write-Host "  $generated" -ForegroundColor DarkGray
                            $edited = Read-Host -Prompt "Commit message"
                            $Message = if ($edited) { $edited } else { $generated }
                        }
                        default { <# fall through to manual prompt below #> }
                    }
                }
                catch {
                    if ($_.Exception.Response -and [int]$_.Exception.Response.StatusCode -eq 401) {
                        Write-Host "AI generation failed: 401 Unauthorized. Check `$env:GEMINI_API_KEY and API key restrictions." -ForegroundColor Yellow
                    }
                    else {
                        Write-Host "AI generation failed: $($_.Exception.Message)" -ForegroundColor Yellow
                    }
                }
            }
        }

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
    Hard-resets the working tree and index to a commit.
    WARNING: discards all uncommitted changes.
.EXAMPLE
    grsh HEAD        # discard all local changes
    grsh HEAD~1      # reset to the previous commit
    grsh abc1234     # reset to a specific commit
#>
function Get-GitResetHard { & git reset --hard $args }
New-Alias -Name grsh -Value Get-GitResetHard

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
