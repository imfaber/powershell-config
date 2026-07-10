Set-Alias -Name dn -Value dotnet

<#
.SYNOPSIS
    dotnet run
#>
function Get-DotnetRun { & dn run $args }
New-Alias -Name dnr -Value Get-DotnetRun

<#
.SYNOPSIS
    dotnet clean
#>
function Get-DotnetClean { & dn clean $args }
New-Alias -Name dnc -Value Get-DotnetClean

<#
.SYNOPSIS
    dotnet build
#>
function Get-DotnetBuild { & dn build $args }
New-Alias -Name dnb -Value Get-DotnetBuild

<#
.SYNOPSIS
    dotnet restore
#>
function Get-DotnetRestore { & dn restore $args }
New-Alias -Name dnrs -Value Get-DotnetRestore

<#
.SYNOPSIS
    dotnet test with code coverage
.EXAMPLE
    dntest
    dntest --filter "FullyQualifiedName~MyTests"
#>
function Dotnet-Test { & dn test --collect "XPlat Code coverage" $args }
New-Alias -Name dntest -Value Dotnet-Test -Force -Option AllScope

<#
.SYNOPSIS
    Generates a code coverage report from the test results.
.EXAMPLE
    dntestreport "./**/coverage.cobertura.xml"
#>
function Dotnet-Report { & reportgenerator -targetdir:"./.coverage" -reporttypes:Html -Reports:"$args" && start ./.coverage\index.html }
New-Alias -Name dntestreport -Value Dotnet-Report -Force -Option AllScope

Set-Alias dntr "$Env:USERPROFILE\Documents\PowerShell\dotnet-test-report.ps1"
