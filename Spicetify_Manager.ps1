#Requires -Version 5.1
<#
.SYNOPSIS
    Spicetify Manager — Interactive control panel for Spicetify + Spotify Desktop.

.DESCRIPTION
    Comprehensive wrapper around Spicetify CLI with modern TUI. Manage themes,
    extensions, Marketplace, Spotify Desktop installation, backups, and repairs
    through an elegant interactive menu system.

    Designed as a single-file deliverable: download the .ps1, run it,
    pick an action, done. No manual steps. Persistent settings survive
    across sessions in $HOME/.spicetify-manager/.

.NOTES
    File Name      : Spicetify_Manager.ps1
    Project        : Spicetify Manager
    Version        : 2.1.0
    Author         : Israleche
    License        : MIT
    Prerequisite   : PowerShell 5.1+ (Windows 10/11)
    Encoding       : UTF-8 with BOM (required for box-drawing chars on PS 5.1)

.EXAMPLE
    .\Spicetify_Manager.ps1
    Launches the interactive main menu.

.EXAMPLE
    .\Spicetify_Manager.ps1 -Silent
    Runs the full auto-flow non-interactively.

.EXAMPLE
    .\Spicetify_Manager.ps1 -NoPersist
    Runs without loading or saving the settings JSON file.
#>

[CmdletBinding()]
param(
    [switch]$Silent,
    [int]$ShowProgress = -1,
    [int]$EnableDebug  = -1,
    [int]$AutoFix      = -1,
    [int]$AutoOpen     = -1,
    [switch]$NoPersist,
    [switch]$ShowAbout
)

# ============================================================================
# 1. BOOTSTRAP: Encoding, error preferences, version detection
# ============================================================================
$ErrorActionPreference = 'Stop'
$ProgressPreference    = 'SilentlyContinue'

# Force UTF-8 on the console layer. The .ps1 file itself is saved as
# UTF-8 with BOM so that Windows PowerShell 5.1 parses box-drawing chars
# correctly (without BOM, PS 5.1 falls back to ANSI and corrupts them).
try {
    $utf8 = New-Object System.Text.UTF8Encoding $false
    [Console]::OutputEncoding = $utf8
    [Console]::InputEncoding  = $utf8
    $OutputEncoding = $utf8
    $null = & chcp.com 65001 2>$null
} catch {}
$PSDefaultParameterValues['Out-File:Encoding'] = 'utf8'
try { $Host.UI.RawUI.WindowTitle = 'Spicetify Manager' } catch {}

# Detect PowerShell version (used for graceful feature toggling later)
$Script:PSVersion = $PSVersionTable.PSVersion
$Script:IsPS7     = $Script:PSVersion.Major -ge 7
$Script:IsCore    = $Script:PSVersion.PSEdition -eq 'Core'

# ============================================================================
# 2. METADATA & PATHS
# ============================================================================
$Script:AppName      = 'Spicetify Manager'
$Script:AppVersion   = '2.1.0'
$Script:AppAuthor    = 'Israleche'
$Script:ScriptDir    = Split-Path -Parent $MyInvocation.MyCommand.Path
if (-not $Script:ScriptDir) { $Script:ScriptDir = $PWD.Path }

# Config lives at the USER'S ROOT ($HOME), not next to the script. This way
# settings survive even if the .ps1 is moved or re-downloaded. A hidden
# .spicetify-manager folder keeps the home directory tidy.
$Script:AppDir       = Join-Path $HOME '.spicetify-manager'
$Script:SettingsFile = Join-Path $Script:AppDir 'settings.json'
$Script:BackupDir    = Join-Path $Script:AppDir 'backups'

# Spicetify external URLs and paths
$Script:SpicetifyInstallUrl   = 'https://raw.githubusercontent.com/spicetify/cli/main/install.ps1'
$Script:MarketplaceInstallUrl = 'https://raw.githubusercontent.com/spicetify/marketplace/main/resources/install.ps1'
$Script:SpotifyInstallerUrl   = 'https://download.scdn.co/SpotifySetup.exe'
$Script:UserDir               = Join-Path $env:APPDATA 'spicetify'

# ============================================================================
# 3. SETTINGS MANAGEMENT (JSON persistence)
# ============================================================================
$Script:Settings = [ordered]@{
    ShowProgress      = $true
    DebugMode         = $false
    AutoFixSpotify    = $true
    AutoOpenSpotify   = $true
    LastUsed          = $null
}

function Import-Settings {
    [CmdletBinding()] param()
    if ($NoPersist) { return }
    if (-not (Test-Path -LiteralPath $Script:SettingsFile)) { return }
    try {
        $json = Get-Content -LiteralPath $Script:SettingsFile -Raw -Encoding UTF8 |
            ConvertFrom-Json
        if ($null -ne $json.ShowProgress)    { $Script:Settings.ShowProgress    = [bool]$json.ShowProgress }
        if ($null -ne $json.DebugMode)       { $Script:Settings.DebugMode       = [bool]$json.DebugMode }
        if ($null -ne $json.AutoFixSpotify)  { $Script:Settings.AutoFixSpotify  = [bool]$json.AutoFixSpotify }
        if ($null -ne $json.AutoOpenSpotify) { $Script:Settings.AutoOpenSpotify = [bool]$json.AutoOpenSpotify }
        if ($null -ne $json.LastUsed)        { $Script:Settings.LastUsed        = [string]$json.LastUsed }
    } catch {
        Write-Debug "Settings load failed: $($_.Exception.Message)"
    }
}

function Export-Settings {
    [CmdletBinding()] param()
    if ($NoPersist) { return }
    try {
        # Make sure $HOME/.spicetify-manager exists before we try to write into it.
        $parent = Split-Path -Parent $Script:SettingsFile
        if ($parent -and -not (Test-Path -LiteralPath $parent)) {
            New-Item -ItemType Directory -Path $parent -Force | Out-Null
        }
        $obj = [PSCustomObject]@{
            ShowProgress    = $Script:Settings.ShowProgress
            DebugMode       = $Script:Settings.DebugMode
            AutoFixSpotify  = $Script:Settings.AutoFixSpotify
            AutoOpenSpotify = $Script:Settings.AutoOpenSpotify
            LastUsed        = $Script:Settings.LastUsed
        }
        $obj | ConvertTo-Json -Depth 5 |
            Set-Content -LiteralPath $Script:SettingsFile -Encoding UTF8
    } catch {
        Write-Debug "Settings save failed: $($_.Exception.Message)"
    }
}

# Load settings at startup
Import-Settings

# Apply parameter overrides (allow runtime to override persisted settings)
if ($ShowProgress -ge 0) { $Script:Settings.ShowProgress = [bool]$ShowProgress }
if ($EnableDebug  -ge 0) { $Script:Settings.DebugMode    = [bool]$EnableDebug }
if ($AutoFix      -ge 0) { $Script:Settings.AutoFixSpotify      = [bool]$AutoFix }
if ($AutoOpen     -ge 0) { $Script:Settings.AutoOpenSpotify     = [bool]$AutoOpen }

# ============================================================================
# 4. COLOR PALETTE & BOX-DRAWING GLYPHS
# ============================================================================
# Single source of truth for every color and border glyph used in the UI.
# Tweak these tables to re-skin the whole script without touching rendering
# functions. All glyphs are referenced by code point so the source file
# remains pure ASCII (portable across encodings).
$Script:Palette = @{
    Logo    = 'Magenta'    # ASCII banner
    Primary = 'White'      # Regular text inside frames
    Muted   = 'DarkGray'   # Borders, dividers, secondary traces
    Accent  = 'Cyan'       # Highlights, key labels, focused items
    On      = 'Green'      # Active / affirmative state
    Off     = 'DarkGray'   # Inactive / off state
    Success = 'Green'      # [+] success messages
    Warning = 'Yellow'     # [!] warning messages
    Danger  = 'Red'        # [x] error messages
    Info    = 'Cyan'       # [i] informational messages
    Prompt  = 'White'      # Input prompts
}

# Modern curved box-drawing set (compatible with L2/L3 terminals).
# Stored as [string] (not [char]) so the '*' repeat operator works directly.
$Script:Box = @{
    TopLeft  = [string][char]0x256D   # ╭
    TopRight = [string][char]0x256E   # ╮
    BotLeft  = [string][char]0x2570   # ╰
    BotRight = [string][char]0x256F   # ╯
    H        = [string][char]0x2500   # ─
    V        = [string][char]0x2502   # │
    CrossL   = [string][char]0x251C   # ├
    CrossR   = [string][char]0x2524   # ┤
}

# ============================================================================
# 5. UI HELPERS: Inline status markers
# ============================================================================
# Convention: every status helper indents 2 spaces and uses a 3-char bracket
# marker so visual scanning is consistent across the whole script.
function Write-Step {
    [CmdletBinding()] param([Parameter(Mandatory)][string]$Text)
    Write-Host ("  > $Text") -ForegroundColor $Script:Palette.Muted
}

function Write-Ok {
    [CmdletBinding()] param([Parameter(Mandatory)][string]$Text)
    Write-Host ("  [+] $Text") -ForegroundColor $Script:Palette.Success
}

function Write-Warn {
    [CmdletBinding()] param([Parameter(Mandatory)][string]$Text)
    Write-Host ("  [!] $Text") -ForegroundColor $Script:Palette.Warning
}

function Write-Err {
    [CmdletBinding()] param([Parameter(Mandatory)][string]$Text)
    Write-Host ("  [x] $Text") -ForegroundColor $Script:Palette.Danger
}

function Write-Info {
    [CmdletBinding()] param([Parameter(Mandatory)][string]$Text)
    Write-Host ("  [i] $Text") -ForegroundColor $Script:Palette.Info
}

function Write-Log {
    [CmdletBinding()] param([Parameter(Mandatory)][string]$Text)
    if ($Script:Settings.DebugMode) {
        $ts = (Get-Date).ToString('HH:mm:ss')
        Write-Host ("  [LOG $ts] $Text") -ForegroundColor DarkGray
    }
}

# ============================================================================
# 6. BOX RENDERING: Modern curved borders with adaptive width
# ============================================================================

$Script:BoxWidth = 62

function Update-BoxWidth {
    $width = 62
    try {
        $cw = $Host.UI.RawUI.WindowSize.Width
        if ($cw -gt 40 -and $cw -lt 200) { $width = [Math]::Min(80, $cw - 4) }
    } catch {}
    if ($width -lt 50) { $width = 50 }
    $Script:BoxWidth = $width
}

function Write-BoxTop {
    param([Parameter(Mandatory)][string]$Title)
    Update-BoxWidth
    $width = $Script:BoxWidth
    $title = [string]$Title
    $innerSpan = $width - 2
    if ($title.Length -gt ($innerSpan - 4)) { $title = $title.Substring(0, $innerSpan - 4) }
    $decoLen = $innerSpan - $title.Length - 2
    $sideLen = [int][Math]::Floor($decoLen / 2)
    $rightLen = $decoLen - $sideLen
    $line = $Script:Box.TopLeft + ($Script:Box.H * $sideLen) + ' ' + $title + ' ' + ($Script:Box.H * $rightLen) + $Script:Box.TopRight
    Write-Host ('  ' + $line) -ForegroundColor $Script:Palette.Muted
}

function Write-BoxLine {
    param([string]$Text = '')
    $width = $Script:BoxWidth
    $inner = $width - 4
    $t = if ($null -eq $Text) { '' } else { [string]$Text }
    while ($t.Length -gt $inner) {
        $chunk = $t.Substring(0, $inner)
        $lastSpace = $chunk.LastIndexOf(' ')
        if ($lastSpace -gt 20) { $chunk = $t.Substring(0, $lastSpace); $t = $t.Substring($lastSpace + 1) }
        else { $t = $t.Substring($inner) }
        $pad = $inner - $chunk.Length
        Write-Host (
            "  " + $Script:Box.V + " " + $chunk + (' ' * $pad) + " " + $Script:Box.V
        ) -ForegroundColor $Script:Palette.Primary
    }
    $pad = $inner - $t.Length
    Write-Host (
        "  " + $Script:Box.V + " " + $t + (' ' * $pad) + " " + $Script:Box.V
    ) -ForegroundColor $Script:Palette.Primary
}

function Write-BoxBottom {
    $width = $Script:BoxWidth
    $innerSpan = $width - 2
    $line = $Script:Box.BotLeft + ($Script:Box.H * $innerSpan) + $Script:Box.BotRight
    Write-Host ('  ' + $line) -ForegroundColor $Script:Palette.Muted
}

function Read-YesNo {
    param([string]$Prompt)
    $ans = (Read-Host $Prompt).Trim().ToLower()
    return ($ans -eq 'y' -or $ans -eq 'yes')
}

# ============================================================================
# 7. ADVANCED UI: Interactive input & progress indicators
# ============================================================================

function Read-AnyKey {
    param([string]$Prompt = '  Press any key to continue...')
    Write-Host $Prompt -ForegroundColor $Script:Palette.Muted -NoNewline
    $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
    Write-Host ''
}

function Test-InteractiveConsole {
    try { $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown,AllowCtrlC'); return $true } catch { return $false }
}

function Initialize-ConsoleSize {
    try {
        $rawUI = $Host.UI.RawUI
        $currentSize = $rawUI.BufferSize
        # Try to grow to 50 rows, wider buffer for scrollback
        $rawUI.BufferSize = New-Object System.Management.Automation.Host.Size(120, 9999)
        $rawUI.WindowSize = New-Object System.Management.Automation.Host.Size(100, 50)
    } catch {
        Write-Debug "Console resize failed: $($_.Exception.Message)"
    }
}

function Read-MenuSelection {
    param([string[]]$Items, [int]$DefaultIdx = 0, [string]$Prompt = 'Select')
    Write-BoxTop $Prompt
    $idx = $DefaultIdx
    while ($true) {
        Clear-Host
        Write-BoxTop $Prompt
        for ($i = 0; $i -lt $Items.Count; $i++) {
            $marker = if ($i -eq $idx) { '→ ' } else { '  ' }
            $color = if ($i -eq $idx) { $Script:Palette.Accent } else { $Script:Palette.Primary }
            Write-Host ($marker + $Items[$i]) -ForegroundColor $color
        }
        Write-BoxBottom
        
        $key = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown').VirtualKeyCode
        switch ($key) {
            38 { $idx = ($idx - 1 + $Items.Count) % $Items.Count } # Up arrow
            40 { $idx = ($idx + 1) % $Items.Count }                 # Down arrow
            13 { return $idx }                                       # Enter
            27 { return -1 }                                         # Esc
        }
    }
}

# Progress bar with 4 styles: Blocks, Dots, Arrow, Solid
function Write-ProgressBar {
    param(
        [int]$Percent = 0,
        [int]$Width = 30,
        [ValidateSet('Blocks', 'Dots', 'Arrow', 'Solid')][string]$Style = 'Blocks',
        [string]$Label = ''
    )
    $Percent = [Math]::Min(100, [Math]::Max(0, $Percent))
    $filled = [int]($Width * $Percent / 100)
    $empty  = $Width - $filled
    
    $barChar   = switch ($Style) { 'Blocks' { '█' }; 'Dots' { '●' }; 'Arrow' { '▶' }; 'Solid' { '▓' } }
    $emptyChar = '░'
    
    $bar = ($barChar * $filled) + ($emptyChar * $empty)
    $display = if ($Label) { "$Label [$bar] $Percent%" } else { "[$bar] $Percent%" }
    Write-Host $display -ForegroundColor $Script:Palette.Accent
}

$Script:SpinnerChars = @('⠋', '⠙', '⠹', '⠸', '⠼', '⠴', '⠦', '⠧', '⠇', '⠏')
$Script:SpinnerIdx = 0

function New-Spinner {
    param([string]$Message = 'Working...')
    $Script:SpinnerIdx = 0
    return @{ Message = $Message; Started = (Get-Date) }
}

function Update-Spinner {
    param([hashtable]$Spinner)
    $spin = $Script:SpinnerChars[$Script:SpinnerIdx % $Script:SpinnerChars.Count]
    Write-Host ("`r  $spin $($Spinner.Message)") -ForegroundColor $Script:Palette.Accent -NoNewline
    $Script:SpinnerIdx++
}

function Complete-Spinner {
    param([hashtable]$Spinner, [string]$Status = 'Done')
    Write-Host "`r  [+] $Status" -ForegroundColor $Script:Palette.Success
}

# About screen
function Show-About {
    Clear-Host
    Write-BoxTop 'ABOUT'
    Write-BoxLine "Spicetify Manager v$Script:AppVersion"
    Write-BoxLine "Author: $Script:AppAuthor"
    Write-BoxLine ''
    Write-BoxLine 'Professional Spotify + Spicetify CLI wrapper'
    Write-BoxLine 'Manage themes, extensions, marketplace, & more'
    Write-BoxLine ''
    Write-BoxLine 'Modern TUI with persistent JSON settings'
    Write-BoxLine 'Settings saved to: $HOME\.spicetify-manager'
    Write-BoxLine ''
    Write-BoxLine 'GitHub: github.com/Israleche/SpicetifyManager'
    Write-BoxLine ''
    Write-BoxLine 'License: MIT'
    Write-BoxBottom
    Read-AnyKey
}

# Fade-in effect for banner lines
function Write-FadeIn {
    param(
        [Parameter(Mandatory)][string[]]$Lines,
        [int]$DelayMs = 50,
        [string]$Color = 'Red'
    )
    foreach ($line in $Lines) {
        Write-Host $line -ForegroundColor $Color
        if ($DelayMs -gt 0) { Start-Sleep -Milliseconds $DelayMs }
    }
}

# Banner
function Write-Banner {
    Clear-Host
    Write-Host ''
    Write-Host '  ================================================================================' -ForegroundColor $Script:Palette.Muted
    Write-Host ''

    # Single SPICETIFY block in RED
    $bannerLines = @(
        '          ███████╗██████╗ ██╗ ██████╗███████╗████████╗██╗███████╗██╗   ██╗',
        '          ██╔════╝██╔══██╗██║██╔════╝██╔════╝╚══██╔══╝██║██╔════╝╚██╗ ██╔╝',
        '          ███████╗██████╔╝██║██║     █████╗     ██║   ██║█████╗   ╚████╔╝ ',
        '          ╚════██║██╔═══╝ ██║██║     ██╔══╝     ██║   ██║██╔══╝    ╚██╔╝  ',
        '          ███████║██║     ██║╚██████╗███████╗   ██║   ██║██║        ██║   ',
        '          ╚══════╝╚═╝     ╚═╝ ╚═════╝╚══════╝   ╚═╝   ╚═╝╚═╝        ╚═╝   '
    )
    Write-FadeIn -Lines $bannerLines -DelayMs 50 -Color $Script:Palette.Logo

    Write-Host ''
    Write-Host '                                      MANAGER'
    Write-Host '                                    By Israleche'
	Write-Host ''
    Write-Host '  ================================================================================' -ForegroundColor $Script:Palette.Muted

    $prog = if ($Script:Settings.ShowProgress) { 'ON' } else { 'OFF' }
    $fix  = if ($Script:Settings.AutoFixSpotify)      { 'ON' } else { 'OFF' }
    $open = if ($Script:Settings.AutoOpenSpotify)     { 'ON' } else { 'OFF' }

    Write-Host -NoNewline '  progress:' -ForegroundColor $Script:Palette.Muted
    if ($prog -eq 'ON') { Write-Host -NoNewline $prog -ForegroundColor $Script:Palette.On }
    else { Write-Host -NoNewline $prog -ForegroundColor $Script:Palette.Off }
    Write-Host -NoNewline '  autofix:' -ForegroundColor $Script:Palette.Muted
    if ($fix -eq 'ON') { Write-Host -NoNewline $fix -ForegroundColor $Script:Palette.On }
    else { Write-Host -NoNewline $fix -ForegroundColor $Script:Palette.Off }
    Write-Host -NoNewline '  autoopen:' -ForegroundColor $Script:Palette.Muted
    if ($open -eq 'ON') { Write-Host -NoNewline $open -ForegroundColor $Script:Palette.On }
    else { Write-Host -NoNewline $open -ForegroundColor $Script:Palette.Off }
    Write-Host ''
    Write-Host '  ================================================================================' -ForegroundColor $Script:Palette.Muted
    Write-Host ''
}

# Admin check
function Test-RunningAsAdmin {
    try {
        $id = [Security.Principal.WindowsIdentity]::GetCurrent()
        $pr = New-Object Security.Principal.WindowsPrincipal($id)
        return $pr.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    } catch { return $false }
}

function Test-PowerShellVersion {
    try {
        $v = $PSVersionTable.PSVersion
        if ($v.Major -lt 5) { return $false }
        if ($v.Major -eq 5 -and $v.Minor -lt 1) { return $false }
        return $true
    } catch { return $false }
}

# Spicetify detection
function Test-SpicetifyInstalled { return [bool](Get-Command spicetify -ErrorAction SilentlyContinue) }

function Get-SpicetifyVersion {
    if (-not (Test-SpicetifyInstalled)) { return '' }
    try { $r = & spicetify -v 2>$null; return ($r | Out-String).Trim() } catch { return '' }
}

# Spotify detection
function Get-SpotifyExeCandidates {
    $list = @(
        (Join-Path $env:APPDATA 'Spotify\Spotify.exe'),
        (Join-Path $env:LOCALAPPDATA 'Spotify\Spotify.exe'),
        (Join-Path $env:LOCALAPPDATA 'Programs\Spotify\Spotify.exe'),
        (Join-Path $env:ProgramFiles 'Spotify\Spotify.exe')
    )
    if (${env:ProgramFiles(x86)}) { $list += (Join-Path ${env:ProgramFiles(x86)} 'Spotify\Spotify.exe') }
    return $list | Where-Object { $_ -and (Test-Path $_) }
}

function Get-SpotifyDirCandidates {
    $list = @(
        (Join-Path $env:APPDATA 'Spotify'),
        (Join-Path $env:LOCALAPPDATA 'Spotify'),
        (Join-Path $env:LOCALAPPDATA 'Programs\Spotify'),
        (Join-Path $env:ProgramFiles 'Spotify')
    )
    if (${env:ProgramFiles(x86)}) { $list += (Join-Path ${env:ProgramFiles(x86)} 'Spotify') }
    return $list | Where-Object { $_ -and (Test-Path $_) }
}

function Get-SpotifyPrefsCandidates {
    $list = @(
        (Join-Path $env:APPDATA 'Spotify\prefs'),
        (Join-Path $env:LOCALAPPDATA 'Spotify\prefs')
    )
    return $list | Where-Object { $_ -and (Test-Path $_) }
}

function Test-SpotifyDesktopInstalled { return [bool](Get-SpotifyExeCandidates | Select-Object -First 1) }

function Test-SpotifyStoreInstalled {
    try { $pkg = Get-AppxPackage -Name 'SpotifyAB.SpotifyMusic' -ErrorAction SilentlyContinue; if ($pkg) { return $true } } catch {}
    $alias = Join-Path $env:LOCALAPPDATA 'Microsoft\WindowsApps\Spotify.exe'
    if (Test-Path $alias) { if (-not (Test-SpotifyDesktopInstalled)) { return $true } }
    return $false
}

function Get-SpotifyState {
    if (Test-SpotifyDesktopInstalled) { return 'desktop' }
    if (Test-SpotifyStoreInstalled)   { return 'store' }
    return 'missing'
}

function Test-SpotifyHasBeenOpened { return [bool](Get-SpotifyPrefsCandidates | Select-Object -First 1) }

function Stop-SpotifyProcess {
    Write-Step 'Closing Spotify...'
    try { Get-Process -Name Spotify, SpotifyWebHelper -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue } catch {}
    Start-Sleep -Milliseconds 800
}

function Start-SpotifyProcess {
    if (-not $Script:Settings.AutoOpenSpotify) { return }
    $exe = Get-SpotifyExeCandidates | Select-Object -First 1
    if ($exe) {
        Write-Step 'Opening Spotify...'
        try { Start-Process -FilePath $exe -ErrorAction Stop | Out-Null } catch { Write-Warn 'Could not open Spotify.' }
    }
}

# Spicetify invocation
function Invoke-Spicetify {
    param([Parameter(Mandatory)][string[]]$Args, [switch]$AllowFailure, [switch]$Quiet)
    $cmd = "spicetify $($Args -join ' ')"
    if (-not $Quiet -and $Script:Settings.ShowProgress) {
        Write-Host "  > $cmd" -ForegroundColor $Script:Palette.Muted
    }
    try {
        $out = & spicetify @Args 2>&1 | Out-String
        if (-not $Quiet -and $Script:Settings.ShowProgress -and $out.Trim()) {
            Write-Host $out -ForegroundColor DarkGray
        }
        return @{ Success = $true; Output = $out }
    } catch {
        if ($AllowFailure) { return @{ Success = $false; Output = $_.Exception.Message } }
        throw
    }
}

function Repair-SpicetifyPaths {
    Write-Step 'Repairing Spicetify paths...'
    $exe = Get-SpotifyExeCandidates | Select-Object -First 1
    if ($exe) {
        $null = Invoke-Spicetify -Args @('config','spotify_path',$exe) -AllowFailure -Quiet
        Write-Ok "spotify_path = $exe"
    } else { Write-Warn 'No Spotify executable found.' }
    $prefs = Get-SpotifyPrefsCandidates | Select-Object -First 1
    if ($prefs) {
        $null = Invoke-Spicetify -Args @('config','prefs_path',$prefs) -AllowFailure -Quiet
        Write-Ok "prefs_path = $prefs"
    } else { Write-Warn 'No prefs file. Open Spotify once.' }
}

# Install Spicetify
function Install-Spicetify {
    Write-Step 'Installing Spicetify CLI...'
    try {
        $null = Invoke-WebRequest -UseBasicParsing -Uri $Script:SpicetifyInstallUrl | Invoke-Expression
        $env:PATH = [Environment]::GetEnvironmentVariable('PATH','Machine') + ';' + [Environment]::GetEnvironmentVariable('PATH','User')
        if (Test-SpicetifyInstalled) { Write-Ok 'Spicetify installed.'; return $true }
        else { Write-Err 'Installed but not on PATH.'; return $false }
    } catch { Write-Err $_.Exception.Message; return $false }
}

function Install-Marketplace {
    Write-Step 'Installing Marketplace...'
    try {
        $null = Invoke-WebRequest -UseBasicParsing -Uri $Script:MarketplaceInstallUrl | Invoke-Expression
        Write-Ok 'Marketplace installed.'; return $true
    } catch { Write-Err $_.Exception.Message; return $false }
}

# Install Spotify Desktop
function Install-SpotifyDesktop {
    Write-Step 'Removing Store Spotify alias...'
    try {
        $alias = Join-Path $env:LOCALAPPDATA 'Microsoft\WindowsApps\Spotify.exe'
        if (Test-Path $alias) { Remove-Item $alias -Force -ErrorAction SilentlyContinue }
        Get-AppxPackage -Name 'SpotifyAB.SpotifyMusic' -ErrorAction SilentlyContinue |
            ForEach-Object { try { Remove-AppxPackage -Package $_.PackageFullName -ErrorAction SilentlyContinue } catch {} }
    } catch {}

    Write-Step 'Downloading Spotify Desktop...'
    $installer = Join-Path $env:TEMP 'SpotifySetup.exe'
    try { Invoke-WebRequest -UseBasicParsing -Uri $Script:SpotifyInstallerUrl -OutFile $installer -ErrorAction Stop }
    catch { Write-Err $_.Exception.Message; return $false }

    Write-Step 'Installing Spotify Desktop...'
    try { Start-Process -FilePath $installer -Wait -ErrorAction Stop | Out-Null }
    catch { Write-Err $_.Exception.Message; return $false }

    $maxWait = 60; $waited = 0
    while (-not (Test-SpotifyDesktopInstalled) -and $waited -lt $maxWait) { Start-Sleep -Seconds 2; $waited += 2 }
    if (-not (Test-SpotifyDesktopInstalled)) { Write-Err 'Spotify Desktop did not install.'; return $false }
    Write-Ok 'Spotify Desktop installed.'

    if (-not (Test-SpotifyHasBeenOpened)) {
        Write-Step 'Opening Spotify once to initialize prefs...'
        $exe = Get-SpotifyExeCandidates | Select-Object -First 1
        if ($exe) {
            try { Start-Process -FilePath $exe | Out-Null } catch {}
            $maxWait = 30; $waited = 0
            while (-not (Test-SpotifyHasBeenOpened) -and $waited -lt $maxWait) { Start-Sleep -Seconds 2; $waited += 2 }
            if (Test-SpotifyHasBeenOpened) { Write-Ok 'Spotify initialized.' }
            else { Write-Warn 'Open Spotify manually, log in, close it, then re-run.' }
        }
    }
    return $true
}

# Core operations
function Invoke-AutoLaunch {
    Write-Banner
    Write-Step 'Running spicetify auto...'
    Stop-SpotifyProcess
    $res = Invoke-Spicetify -Args @('auto')
    if ($res.Success) { Write-Ok 'Auto completed.' }
    else { Write-Warn 'Auto had issues. Try option 2.' }
    Read-Host '  Press ENTER' | Out-Null
}

function Invoke-QuickRepair {
    Write-Banner
    Write-Step 'Quick repair: backup apply...'
    Stop-SpotifyProcess
    $res = Invoke-Spicetify -Args @('backup','apply')
    if ($res.Success) { Write-Ok 'Quick repair done.'; Start-SpotifyProcess }
    else { Write-Warn 'Quick repair had issues. Try option 2.' }
    Read-Host '  Press ENTER' | Out-Null
}

function Invoke-FullRestore {
    Write-Banner
    Write-Step 'Full restore + repair...'
    Stop-SpotifyProcess
    Write-Step '[1/3] spicetify restore backup...'
    $null = Invoke-Spicetify -Args @('restore','backup') -AllowFailure
    Write-Step '[2/3] spicetify backup...'
    $res = Invoke-Spicetify -Args @('backup')
    if (-not $res.Success) { Write-Warn 'Backup failed. Open Spotify once then re-run.'; Read-Host '  Press ENTER' | Out-Null; return }
    Write-Step '[3/3] spicetify apply...'
    $res = Invoke-Spicetify -Args @('apply')
    if ($res.Success) { Write-Ok 'Full restore done.'; Start-SpotifyProcess }
    else { Write-Warn 'Apply failed.' }
    Read-Host '  Press ENTER' | Out-Null
}

function Invoke-Upgrade {
    Write-Banner
    Write-Step 'Upgrading Spicetify CLI...'
    try {
        $null = Invoke-WebRequest -UseBasicParsing -Uri $Script:SpicetifyInstallUrl | Invoke-Expression
        $env:PATH = [Environment]::GetEnvironmentVariable('PATH','Machine') + ';' + [Environment]::GetEnvironmentVariable('PATH','User')
        $v = Get-SpicetifyVersion
        Write-Ok "Spicetify: $v"
    } catch { Write-Err $_.Exception.Message }
    Read-Host '  Press ENTER' | Out-Null
}

function Invoke-MarketplaceInstall {
    Write-Banner
    if (-not (Test-SpicetifyInstalled)) { Write-Warn 'Spicetify not installed.'; Read-Host '  Press ENTER' | Out-Null; return }
    $null = Install-Marketplace
    Read-Host '  Press ENTER' | Out-Null
}

# Themes menu
function Show-ThemesMenu {
    while ($true) {
        Write-Banner
        Write-BoxTop 'THEMES / EXTENSIONS / APPS'
        Write-BoxLine '[1] List installed themes'
        Write-BoxLine '[2] Apply a theme by name'
        Write-BoxLine '[3] List extensions'
        Write-BoxLine '[4] Enable extension'
        Write-BoxLine '[5] List custom apps'
        Write-BoxLine '[6] Install Marketplace'
        Write-BoxLine '[0] Back'
        Write-BoxBottom
        $c = Read-Host '  Choose'
        switch ($c) {
            '1' { Write-Banner; $res = Invoke-Spicetify -Args @('config','current_theme') -AllowFailure -Quiet; Write-Host $res.Output; Read-Host '  Press ENTER' | Out-Null }
            '2' { $name = Read-Host '  Theme name'; if ($name) { $null = Invoke-Spicetify -Args @('config','current_theme',$name); Write-Ok "Theme set to $name. Run [1] Auto to apply." }; Read-Host '  Press ENTER' | Out-Null }
            '3' { Write-Banner; $null = Invoke-Spicetify -Args @('config','extensions') -AllowFailure; Read-Host '  Press ENTER' | Out-Null }
            '4' { $name = Read-Host '  Extension name'; if ($name) { $null = Invoke-Spicetify -Args @('extension',$name); Write-Ok "$name enabled. Run [1] Auto." }; Read-Host '  Press ENTER' | Out-Null }
            '5' { Write-Banner; $null = Invoke-Spicetify -Args @('config','custom_apps') -AllowFailure; Read-Host '  Press ENTER' | Out-Null }
            '6' { $null = Install-Marketplace; Read-Host '  Press ENTER' | Out-Null }
            '0' { return }
            default { Write-Warn 'Invalid.'; Start-Sleep -Milliseconds 400 }
        }
    }
}

# Status
function Show-Status {
    Write-Banner
    Write-BoxTop 'STATUS & INFO'
    Write-BoxLine ''
    Write-BoxLine 'Spicetify:'
    Write-BoxLine ('  installed: ' + $(if (Test-SpicetifyInstalled) { 'YES' } else { 'NO' }))
    Write-BoxLine ('  version:   ' + (Get-SpicetifyVersion))
    Write-BoxLine ''
    Write-BoxLine 'Spotify:'
    Write-BoxLine ('  state:     ' + (Get-SpotifyState))
    Write-BoxLine ('  desktop:   ' + $(if (Test-SpotifyDesktopInstalled) { 'YES' } else { 'NO' }))
    Write-BoxLine ('  store:     ' + $(if (Test-SpotifyStoreInstalled) { 'YES' } else { 'NO' }))
    Write-BoxLine ('  opened:    ' + $(if (Test-SpotifyHasBeenOpened) { 'YES' } else { 'NO' }))
    Write-BoxLine ''
    Write-BoxLine 'Paths:'
    Write-BoxBottom
    $exes = Get-SpotifyExeCandidates
    if ($exes) { foreach ($e in $exes) { Write-Host "    $e" -ForegroundColor DarkGray } }
    $prefs = Get-SpotifyPrefsCandidates
    if ($prefs) { foreach ($p in $prefs) { Write-Host "    $p" -ForegroundColor DarkGray } }
    Write-Host ''
    Read-Host '  Press ENTER' | Out-Null
}

# Settings menu
function Show-SettingsMenu {
    while ($true) {
        Write-Banner
        Write-BoxTop 'SETTINGS'
        Write-BoxLine '[1] Toggle command output'
        Write-BoxLine '[2] Toggle auto-fix Spotify'
        Write-BoxLine '[3] Toggle auto-open Spotify'
        Write-BoxLine '[0] Back'
        Write-BoxBottom
        $c = Read-Host '  Choose'
        switch ($c) {
            '1' { $Script:Settings.ShowProgress = -not $Script:Settings.ShowProgress; Write-Ok 'Toggled.'; Start-Sleep -Milliseconds 500 }
            '2' { $Script:Settings.AutoFixSpotify = -not $Script:Settings.AutoFixSpotify; Write-Ok 'Toggled.'; Start-Sleep -Milliseconds 500 }
            '3' { $Script:Settings.AutoOpenSpotify = -not $Script:Settings.AutoOpenSpotify; Write-Ok 'Toggled.'; Start-Sleep -Milliseconds 500 }
            '0' { return }
            default { Write-Warn 'Invalid.'; Start-Sleep -Milliseconds 400 }
        }
    }
}

# Advanced menu
function Show-AdvancedMenu {
    while ($true) {
        Write-Banner
        Write-BoxTop 'ADVANCED'
        Write-BoxLine '[1] spicetify restore backup'
        Write-BoxLine '[2] spicetify backup'
        Write-BoxLine '[3] spicetify apply'
        Write-BoxLine '[4] Open Spicetify config folder'
        Write-BoxLine '[5] Repair Spicetify paths'
        Write-BoxLine '[0] Back'
        Write-BoxBottom
        $c = Read-Host '  Choose'
        switch ($c) {
            '1' { Write-Banner; Stop-SpotifyProcess; $null = Invoke-Spicetify -Args @('restore','backup') -AllowFailure; Read-Host '  Press ENTER' | Out-Null }
            '2' { Write-Banner; Stop-SpotifyProcess; $null = Invoke-Spicetify -Args @('backup'); Read-Host '  Press ENTER' | Out-Null }
            '3' { Write-Banner; Stop-SpotifyProcess; $null = Invoke-Spicetify -Args @('apply'); Start-SpotifyProcess; Read-Host '  Press ENTER' | Out-Null }
            '4' { Write-Banner; try { $res = Invoke-Spicetify -Args @('-c') -AllowFailure -Quiet; $path = $res.Output.Trim(); if ($path -and (Test-Path $path)) { Invoke-Item (Split-Path -Parent $path) } else { Invoke-Item $Script:UserDir } } catch { Write-Err $_.Exception.Message }; Read-Host '  Press ENTER' | Out-Null }
            '5' { Write-Banner; $null = Repair-SpicetifyPaths; Read-Host '  Press ENTER' | Out-Null }
            '0' { return }
            default { Write-Warn 'Invalid.'; Start-Sleep -Milliseconds 400 }
        }
    }
}

# Help menu
function Show-HelpMenu {
    while ($true) {
        Write-Banner
        Write-BoxTop 'HELP & DOCS'
        Write-BoxLine '[1] What is Spicetify?'
        Write-BoxLine '[2] How this manager works'
        Write-BoxLine '[3] First-time install guide'
        Write-BoxLine '[4] Common problems & fixes'
        Write-BoxLine '[5] Menu options explained'
        Write-BoxLine '[0] Back'
        Write-BoxBottom
        $c = Read-Host '  Choose'
        switch ($c) {
            '1' { Show-HelpTopic 'whatis' }
            '2' { Show-HelpTopic 'how' }
            '3' { Show-HelpTopic 'install' }
            '4' { Show-HelpTopic 'problems' }
            '5' { Show-HelpTopic 'menu' }
            '0' { return }
            default { Write-Warn 'Invalid.'; Start-Sleep -Milliseconds 400 }
        }
    }
}

function Show-HelpTopic {
    param([string]$Topic)
    Write-Banner
    switch ($Topic) {
        'whatis' {
            Write-BoxTop 'WHAT IS SPICETIFY'
            Write-BoxLine 'Spicetify is a CLI tool that lets you customize the'
            Write-BoxLine 'Spotify desktop client: themes, extensions, custom'
            Write-BoxLine 'apps, and color schemes.'
            Write-BoxLine ''
            Write-BoxLine 'It works by patching Spotify files after a backup.'
            Write-BoxLine 'Revert with: spicetify restore backup'
            Write-BoxLine ''
            Write-BoxLine 'github.com/spicetify/cli'
            Write-BoxBottom
        }
        'how' {
            Write-BoxTop 'HOW THIS MANAGER WORKS'
            Write-BoxLine 'This is a PowerShell wrapper around spicetify CLI.'
            Write-BoxLine 'It runs spicetify commands for you and handles'
            Write-BoxLine 'the Spotify Desktop repair flow.'
            Write-BoxLine ''
            Write-BoxLine 'Config is per-session (not saved to disk).'
            Write-BoxBottom
        }
        'install' {
            Write-BoxTop 'FIRST-TIME INSTALL'
            Write-BoxLine '1. Have Spotify DESKTOP (not Store).'
            Write-BoxLine '   Use option [9] if unsure.'
            Write-BoxLine ''
            Write-BoxLine '2. Open Spotify ONCE and log in.'
            Write-BoxLine '   This generates the prefs file.'
            Write-BoxLine ''
            Write-BoxLine '3. Close Spotify completely.'
            Write-BoxLine ''
            Write-BoxLine '4. Run [1] Auto. Done.'
            Write-BoxBottom
        }
        'problems' {
            Write-BoxTop 'COMMON PROBLEMS'
            Write-BoxLine 'Black window: you ran as Administrator.'
            Write-BoxLine '  Fix: re-run as normal user.'
            Write-BoxLine ''
            Write-BoxLine '"no backup available"'
            Write-BoxLine '  Fix: open Spotify once, close, run [2].'
            Write-BoxLine ''
            Write-BoxLine 'Store Spotify detected'
            Write-BoxLine '  Fix: use option [9] to switch.'
            Write-BoxBottom
        }
        'menu' {
            Write-BoxTop 'MENU OPTIONS'
            Write-BoxLine '[1] Auto: backup + apply + open'
            Write-BoxLine '[2] Full restore: revert, backup, apply'
            Write-BoxLine '[3] Quick repair: backup apply'
            Write-BoxLine '[4] Manage themes/extensions/apps'
            Write-BoxLine '[5] Install/repair Marketplace'
            Write-BoxLine '[6] Upgrade Spicetify CLI'
            Write-BoxLine '[7] Open config folder'
            Write-BoxLine '[8] View status & info'
            Write-BoxLine '[9] Install/fix Spotify Desktop'
            Write-BoxLine '[S] Settings'
            Write-BoxLine '[A] Advanced'
            Write-BoxLine '[H] Help & docs'
            Write-BoxLine '[0] Exit'
            Write-BoxBottom
        }
    }
    Read-Host '  Press ENTER' | Out-Null
}

# Main menu
function Show-MainMenu {
    while ($true) {
        Write-Banner
        $state = Get-SpotifyState
        if ($state -eq 'store') {
            Write-Warn 'Microsoft Store Spotify detected! Use option 9.'
            Write-Host ''
        }
        if ($state -eq 'desktop' -and -not (Test-SpotifyHasBeenOpened)) {
            Write-Warn 'Spotify never opened. Open it once before backup.'
            Write-Host ''
        }

        Write-BoxTop 'MAIN MENU'
        Write-BoxLine '[1] Auto (spicetify auto: backup/apply/launch)'
        Write-BoxLine '[2] Full restore & repair (restore + backup + apply)'
        Write-BoxLine '[3] Quick repair (backup apply)'
        Write-BoxLine '[4] Manage themes / extensions / apps'
        Write-BoxLine '[5] Install / repair Marketplace'
        Write-BoxLine '[6] Upgrade Spicetify CLI'
        Write-BoxLine '[7] Open Spicetify config folder'
        Write-BoxLine '[8] View status & info'
        Write-BoxLine '[9] Install / fix desktop Spotify'
        Write-BoxLine '[S] Settings'
        Write-BoxLine '[A] Advanced options'
        Write-BoxLine '[H] Help & documentation'
        Write-BoxLine '[0] Exit'
        Write-BoxBottom

        $c = Read-Host '  Choose an option'
        try {
            switch ($c.ToUpper()) {
                '1' { Invoke-AutoLaunch }
                '2' { Invoke-FullRestore }
                '3' { Invoke-QuickRepair }
                '4' { Show-ThemesMenu }
                '5' { Invoke-MarketplaceInstall }
                '6' { Invoke-Upgrade }
                '7' { Write-Banner; try { $res = Invoke-Spicetify -Args @('-c') -AllowFailure -Quiet; $path = $res.Output.Trim(); if ($path -and (Test-Path $path)) { Invoke-Item (Split-Path -Parent $path) } else { Invoke-Item $Script:UserDir } } catch { Write-Err $_.Exception.Message }; Read-Host '  Press ENTER' | Out-Null }
                '8' { Show-Status }
                '9' { Write-Banner; Write-Step 'Checking Spotify...'; $null = Install-SpotifyDesktop; if (Test-SpicetifyInstalled) { $null = Repair-SpicetifyPaths }; Read-Host '  Press ENTER' | Out-Null }
                'S' { Show-SettingsMenu }
                'A' { Show-AdvancedMenu }
                'H' { Show-HelpMenu }
                '0' { Write-Host ''; Write-Host '  Goodbye!' -ForegroundColor $Script:Palette.Success; Start-Sleep -Milliseconds 400; exit 0 }
                default { Write-Warn 'Invalid option.'; Start-Sleep -Milliseconds 500 }
            }
        } catch {
            Write-Host ''
            Write-Err ('Error: ' + $_.Exception.Message)
            Read-Host '  Press ENTER' | Out-Null
        }
    }
}

# Entry point
function Start-App {
    if (-not (Test-PowerShellVersion)) {
        Write-Err 'PowerShell 5.1+ required.'
        if (-not $Silent) { Read-Host '  ENTER' | Out-Null }
        exit 1
    }
    if (Test-RunningAsAdmin) {
        Write-Err 'Do NOT run as Administrator.'
        Write-Host 'Spicetify refuses admin and Spotify shows a black window.' -ForegroundColor $Script:Palette.Warning
        if (-not $Silent) { Read-Host '  ENTER' | Out-Null }
        exit 1
    }

    if (-not (Test-SpicetifyInstalled)) {
        if ($Silent) {
            Write-Step 'Silent mode: Installing Spicetify...'
            if (-not (Install-Spicetify)) { Write-Err 'Cannot continue.'; exit 1 }
        } else {
            Write-Banner
            Write-Warn 'Spicetify is not installed.'
            $ok = Read-YesNo '  Install it now? (y/n)'
            if ($ok) { if (-not (Install-Spicetify)) { Write-Err 'Cannot continue.'; Read-Host '  ENTER' | Out-Null; exit 1 } }
            else { exit 0 }
        }
    }

    if ($Script:Settings.AutoFixSpotify) {
        $state = Get-SpotifyState
        if ($state -ne 'desktop') {
            if ($Silent) {
                Write-Step 'Silent mode: Fixing Spotify installation...'
                $null = Install-SpotifyDesktop
                if (Test-SpicetifyInstalled) { $null = Repair-SpicetifyPaths }
            } else {
                Write-Banner
                if ($state -eq 'store') { Write-Warn 'Store Spotify detected.' }
                else { Write-Warn 'Spotify not detected.' }
                $ok = Read-YesNo '  Install Desktop Spotify? (y/n)'
                if ($ok) { $null = Install-SpotifyDesktop; if (Test-SpicetifyInstalled) { $null = Repair-SpicetifyPaths } }
            }
        } elseif (-not (Test-SpotifyHasBeenOpened)) {
            if ($Silent) {
                Write-Step 'Silent mode: Initializing Spotify...'
                $exe = Get-SpotifyExeCandidates | Select-Object -First 1
                if ($exe) { try { Start-Process -FilePath $exe | Out-Null } catch {} }
                $maxWait = 30; $waited = 0
                while (-not (Test-SpotifyHasBeenOpened) -and $waited -lt $maxWait) { Start-Sleep -Seconds 2; $waited += 2 }
                if (Test-SpotifyHasBeenOpened) { Write-Ok 'Initialized' }
            } else {
                Write-Banner
                Write-Warn 'Spotify never opened.'
                Write-Step 'Opening Spotify to initialize...'
                $exe = Get-SpotifyExeCandidates | Select-Object -First 1
                if ($exe) { try { Start-Process -FilePath $exe | Out-Null } catch {} }
                $maxWait = 30; $waited = 0
                while (-not (Test-SpotifyHasBeenOpened) -and $waited -lt $maxWait) { Start-Sleep -Seconds 2; $waited += 2 }
                if (Test-SpotifyHasBeenOpened) { Write-Ok 'Initialized. Close it then continue.' }
                Read-Host '  Press ENTER' | Out-Null
            }
        }
    }

    # Export settings before main menu
    Export-Settings

    if ($Silent) {
        Write-Step 'Silent mode: Running auto...'
        Invoke-AutoLaunch
        Write-Ok 'Done.'
        exit 0
    }

    Show-MainMenu
}

try { Start-App }
catch {
    Write-Host ''
    Write-Err ("FATAL: " + $_.Exception.Message)
    try { Write-Host $_.ScriptStackTrace -ForegroundColor DarkGray } catch {}
    Read-Host '  Press ENTER to exit' | Out-Null
    exit 1
}
