$ps_profile_home = "$Env:USERPROFILE\Documents\PowerShell"

Set-Alias -Name ll -Value ls

function Remove { & rm @args -Force -Recurse }
Set-Alias -Name rmrf -Value Remove

# Touch
function New-TouchFile {
    param([Parameter(ValueFromRemainingArguments)][string[]]$Path)

    if (-not $Path) {
        Write-Error "touch: missing file operand"
        return
    }

    foreach ($p in $Path) {
        if (Test-Path -LiteralPath $p) {
            (Get-Item -LiteralPath $p).LastWriteTime = Get-Date
        }
        else {
            New-Item -ItemType File -Path $p | Out-Null
        }
    }
}
Set-Alias -Name touch -Value New-TouchFile

# Grep
function Find {
    [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
    $input | & findstr -i @args
}
Set-Alias -Name grep -Value Find
