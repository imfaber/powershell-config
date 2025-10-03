# PowerShell Configuration

This repository contains a customized PowerShell configuration with enhanced functionality, theming, and productivity features.

## ✨ Features

### 🎨 Visual Enhancements
- **Oh My Posh**: Beautiful and informative command prompt with git integration
- **Terminal Icons**: File and folder icons in directory listings
- **PSReadLine**: Enhanced command-line editing with syntax highlighting and predictions
- **Theme Detection**: Automatic light/dark theme detection for optimal visibility

### ⚡ Aliases & Functions

#### General Purpose
- `ll` → `ls` - Quick directory listing
- `rmrf` → `rm -Force -Recurse` - Force remove files/directories
- `grep` → `findstr` - Text search
- `vim`, `v` → `nvim` - Neovim editor shortcuts

#### .NET Development
- `dn` → `dotnet` - .NET CLI shortcut
- `dntest` → `dotnet test --collect "XPlat Code coverage"` - Run tests with coverage
- `dntestreport` → Generate and open HTML coverage reports
- `dntr` → Execute test report script

#### Git Workflow
| Alias | Command | Description |
|-------|---------|-------------|
| `g` | `git` | Git base command |
| `gs` | `git status -sb` | Short status with branch info |
| `ga` | `git add` | Stage files |
| `gaa` | `git add --all` | Stage all changes |
| `gc` | `git commit -ev` | Commit with editor |
| `gci` | `git commit -ev --interactive` | Interactive commit |
| `gca` | `git commit -aev` | Commit all with editor |
| `gps` | `git push` | Push changes |
| `gpl` | `git pull` | Pull changes |
| `gf` | `git fetch` | Fetch from remote |
| `gco` | `git checkout` | Switch branches |
| `gcom` | `git checkout main` | Switch to main branch |
| `gcob` | `git checkout -b` | Create and switch to new branch |
| `gcop` | `git checkout -` | Switch to previous branch |
| `gb` | `git branch` | List branches |
| `gbd` | `Remove-GitBranch` | Delete branch(es) with pattern support |
| `gm` | `git merge` | Merge branches |
| `gr` | `git remote -v` | Show remotes |
| `grsh` | `git reset --hard` | Hard reset |
| `gd` | `git diff` | Show differences |
| `glog` | Formatted git log | Beautiful git history tree |

### 🔧 Special Features

#### Smart Branch Deletion
The `gbd` (git branch delete) function supports:
- Single branch deletion: `gbd feature-branch`
- Pattern matching: `gbd feature*` (deletes all branches starting with "feature")

#### Enhanced Git Log
`glog` provides a colorized, graph-based git history with:
- Commit hash (red)
- Branch/tag info (yellow)
- Commit message
- Relative time (green)
- Author name (blue)

## 🚀 Setup

### Prerequisites
1. **PowerShell 7+** - Modern PowerShell version
2. **Oh My Posh** - Install via:
   ```powershell
   winget install JanDeDobbeleer.OhMyPosh
   ```
3. **Nerd Font** - Required for icons (e.g., "FiraCode Nerd Font")

### Installation
1. Clone or copy these files to your PowerShell profile directory:
   ```powershell
   $PROFILE | Split-Path
   ```
2. Restart PowerShell or run:
   ```powershell
   . $PROFILE
   ```

### Optional Dependencies
- **Neovim** - For `vim`/`v` aliases
- **.NET SDK** - For `dn*` aliases
- **ReportGenerator** - For coverage reports:
  ```powershell
  dotnet tool install -g dotnet-reportgenerator-globaltool
  ```

## 🎯 Customization

### Modifying Aliases
Edit `Aliases.ps1` to add your own shortcuts and functions.

### Changing Themes
- Switch Oh My Posh themes by modifying the config path in `Microsoft.PowerShell_profile.ps1`
- Browse themes: [Oh My Posh Themes](https://ohmyposh.dev/docs/themes)

### PSReadLine Colors
The configuration automatically detects Windows theme (light/dark) and adjusts colors accordingly. Modify `PSReadLineProfile.ps1` for custom colors.

## 📋 Key Bindings

PSReadLine is configured with Emacs-style key bindings:
- **Ctrl+A** - Beginning of line
- **Ctrl+E** - End of line
- **Ctrl+F** - Forward character
- **Ctrl+B** - Backward character
- **Ctrl+P** - Previous history
- **Ctrl+N** - Next history
