$ps_profile_home = "$Env:USERPROFILE\Documents\PowerShell"

# PSReadLine
. "$ps_profile_home\PSReadLine\PSReadLineProfile.ps1"

# Oh My Posh profile
# oh-my-posh init pwsh --config "$env:POSH_THEMES_PATH/spaceship.omp.json" | Invoke-Expression
# oh-my-posh init pwsh --config "$env:POSH_THEMES_PATH/agnoster-minimal.omp.json" | Invoke-Expression
# oh-my-posh init pwsh --config "$ps_profile_home/oh-my-posh/themes/custom-agnoster-minimal.json" | Invoke-Expression
oh-my-posh init pwsh --config "$ps_profile_home/oh-my-posh/themes/custom-spaceship.json" | Invoke-Expression

# Icons
Import-Module -Name Terminal-Icons

# Aliases
. "$ps_profile_home\Aliases.ps1"
