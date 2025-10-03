function Install-ToolIfNeeded {
    param (
        [string]$toolName,
        [string]$installCommand
    )

    if (-not (dotnet tool list -g | Select-String -Pattern $toolName)) {
        Write-Host "Installing $toolName..." -ForegroundColor Yellow
        Invoke-Expression $installCommand
    }
}

function Remove-PreviousTestResults {
    Get-ChildItem -Path "./**/TestResults" -Recurse | Remove-Item -Recurse -Force
}

function Get-TestFilter {
    param (
        [string]$testFilter
    )

    if (-not $testFilter -or $testFilter -eq "") {
        $solutionFile = Get-ChildItem -Path "./" -Filter "*.sln" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
        $projectFile = Get-ChildItem -Path "./" -Filter "*.csproj" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1

        if ($solutionFile) {
            return $solutionFile.FullName
        } elseif ($projectFile) {
            return $projectFile.FullName
        } else {
            Write-Host "No solution or project file found. Exiting..." -ForegroundColor Red
            exit 1
        }
    }

    return $testFilter
}

function Run-Tests {
    param (
        [string]$testFilter
    )

    Write-Host "Running tests for $testFilter"
    $testCommand = "dotnet test --collect 'XPlat Code coverage' --verbosity m $testFilter"
    $testOutput = ""
    Write-Host "Comamnd: $testCommand"

    Invoke-Expression -Command $testCommand 2>&1 | ForEach-Object {
        $testOutput += $_ + "`n"
        if ($_ -match "Passed") {
            Write-Host $_ -ForegroundColor Green
        } elseif ($_ -match "Failed") {
            Write-Host $_ -ForegroundColor Red
        } else {
            Write-Host $_
        }
    }

    return $testOutput
}

function Get-CoverageResults {
    param (
        [string]$testOutput
    )

    $attachments = (($testOutput -split "Attachments:", 2)[1].Trim() -split "\r?\n" | ForEach-Object { $_.Trim() }) -join ";"

    if (-not $attachments) {
        Write-Host "No coverage files found. Exiting..." -ForegroundColor Red
        exit 1
    }

    return $attachments
}

function Generate-Report {
    param (
        [string]$attachments
    )

    Write-Host ""
    Write-Host "Generating report..."
    reportgenerator -targetdir:"./.coverage" -verbosity:"Info" -reporttypes:Html -Reports:"$attachments"
    Start-Process "./.coverage/index.html"
    Write-Host "Done!"
}

# Main script execution
Install-ToolIfNeeded -toolName "coverlet.console" -installCommand "dotnet tool install --global coverlet.console"
Install-ToolIfNeeded -toolName "reportgenerator" -installCommand "dotnet tool install --global reportgenerator"
Remove-PreviousTestResults

$testFilter = Get-TestFilter -testFilter ([string]::Join(' ', $args))
$testOutput = Run-Tests -testFilter $testFilter
$attachments = Get-CoverageResults -testOutput $testOutput
Generate-Report -attachments $attachments