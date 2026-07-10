$ps_profile_home = "$Env:USERPROFILE\Documents\PowerShell"

Set-Alias -Name ll -Value ls

function Remove { & rm @args -Force -Recurse }
Set-Alias -Name rmrf -Value Remove

# Grep
function Find {
    [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
    $input | & findstr -i @args
}
Set-Alias -Name grep -Value Find
