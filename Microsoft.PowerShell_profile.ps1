$ps_profile_home = "$Env:USERPROFILE\Documents\PowerShell"

# PSReadLine
. "$ps_profile_home\PSReadLine\PSReadLineProfile.ps1"

# Oh My Posh profile
# oh-my-posh init pwsh --config "$env:POSH_THEMES_PATH/spaceship.omp.json" | Invoke-Expression
# oh-my-posh init pwsh --config "$env:POSH_THEMES_PATH/agnoster-minimal.omp.json" | Invoke-Expression

# Detect Windows theme (dark/light) and set Oh My Posh theme accordingly
$theme = Get-ItemPropertyValue -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize" -Name "AppsUseLightTheme"
if ($theme -eq 0) {
    oh-my-posh init pwsh --config "$ps_profile_home/oh-my-posh/themes/custom-spaceship-dark.json" | Invoke-Expression
} else {
    oh-my-posh init pwsh --config "$ps_profile_home/oh-my-posh/themes/custom-spaceship-light.json" | Invoke-Expression
}


# Icons
Import-Module -Name Terminal-Icons

# Aliases
. "$ps_profile_home\Aliases.ps1"
