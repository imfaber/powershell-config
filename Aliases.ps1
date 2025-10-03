$ps_profile_home = "$Env:USERPROFILE\Documents\PowerShell"

Set-Alias -Name ll -Value ls

function Remove { & rm @args -Force -Recurse }
Set-Alias -Name rmrf -Value Remove

# Grep
Set-Alias -Name grep -Value findstr

# Neovim
Set-Alias -Name vim -Value nvim
Set-Alias -Name v -Value nvim

# Dotnet
Set-Alias -Name dn -Value dotnet

function Dotnet-Test { & dn test --collect "XPlat Code coverage" $args }
New-Alias -Name dntest -Value Dotnet-Test -Force -Option AllScope

function Dotnet-Report { & reportgenerator -targetdir:"./.coverage" -reporttypes:Html -Reports:"$args" && start ./.coverage\index.html }
New-Alias -Name dntestreport -Value Dotnet-Report -Force -Option AllScope

Set-Alias dntr "$Env:USERPROFILE\Documents\PowerShell\dotnet-test-report.ps1"

# GIT
function Get-Git { & git $args }
New-Alias -Name g -Value Get-Git -Force -Option AllScope

function Get-GitStatus { & git status -sb $args }
New-Alias -Name gs -Value Get-GitStatus -Force -Option AllScope

function Get-GitCommit { & git commit -ev $args }
New-Alias -Name gc -Value Get-GitCommit -Force -Option AllScope

function Get-GitCommitInteractive { & git commit -ev --interactive $args }
New-Alias -Name gci -Value Get-GitCommitInteractive -Force -Option AllScope

function Get-GitCommitAll { & git commit -aev $args }
New-Alias -Name gca -Value Get-GitCommitAll -Force -Option AllScope

function Get-GitAdd { & git add $args }
New-Alias -Name ga -Value Get-GitAdd -Force -Option AllScope

function Get-GitAddAll { & git add --all $args }
New-Alias -Name gaa -Value Get-GitAddAll -Force -Option AllScope

function Get-GitTree { & git log --color --graph --pretty=format:'%Cred%h%Creset -%C(yellow)%d%Creset %s %Cgreen(%cr) %C(bold blue)<%an>%Creset' --abbrev-commit --decorate $args }
New-Alias -Name glog -Value Get-GitTree -Force -Option AllScope

function Get-GitPush { & git push $args }
New-Alias -Name gps -Value Get-GitPush -Force -Option AllScope

function Get-GitPull { & git pull $args }
New-Alias -Name gpl -Value Get-GitPull -Force -Option AllScope

function Get-GitFetch { & git fetch $args }
New-Alias -Name gf -Value Get-GitFetch -Force -Option AllScope

function Get-GitCheckout { & git checkout $args }
New-Alias -Name gco -Value Get-GitCheckout -Force -Option AllScope

function Get-GitCheckoutMain { & git checkout main $args }
New-Alias -Name gcom -Value Get-GitCheckoutMain -Force -Option AllScope

function Get-GitMerge { & git merge $args }
New-Alias -Name gm -Value Get-GitMerge -Force -Option AllScope

function Get-GitCheckoutBranch { & git checkout -b $args }
New-Alias -Name gcob -Value Get-GitCheckoutBranch -Force -Option AllScope

function Get-GitBranch { & git branch $args }
New-Alias -Name gb -Value Get-GitBranch -Force -Option AllScope

function Get-GitRemote { & git remote -v $args }
New-Alias -Name gr -Value Get-GitRemote -Force -Option AllScope

function Get-GitResetHard { & git reset --hard $args }
New-Alias -Name grsh -Value Get-GitResetHard

function Get-GitCheckoutPreviousBranch { & git checkout - $args}
New-Alias -Name gcop -Value Get-GitCheckoutPreviousBranch

function Get-GitDiff { & git diff $args}
New-Alias -Name gd -Value Get-GitDiff

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

