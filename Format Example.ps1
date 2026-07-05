#Requires -Version 5.1
<#
.SYNOPSIS
    Console TUI Template - Official style guide for tool scripts.

.DESCRIPTION
    Reference implementation of an interactive Text User Interface (TUI) for
    PowerShell tool scripts. Provides adaptive box drawing with modern curved
    borders, a unified color palette, progress indicators, spinners, arrow-key
    menu navigation, and JSON-backed persistent settings.

    Designed as a reusable visual language so that any tool script based on
    this template keeps a consistent look-and-feel across projects. Suitable
    for both human developers and AI agents learning the house style.

    The companion files ABECEDARIO_ASCII.txt and ENCYCLOPEDIA_TUI.md contain
    the full visual reference (6-line ASCII shadow alphabet + TUI components
    encyclopedia). Read them when you need to extend or restyle this template.

.NOTES
    File Name      : Ejemplo_De_Formato.ps1
    Author         : Israleche (refactored)
    Prerequisite   : PowerShell 5.1+ (PS 7+ features used when available)
    Encoding       : UTF-8 with BOM (required for box-drawing chars on PS 5.1)

.LINK
    ENCYCLOPEDIA_TUI.md - Full visual reference for TUI components.
    ABECEDARIO_ASCII.txt - 6-line ASCII shadow alphabet and symbols.
    README.md - How to use and extend this template.

.EXAMPLE
    .\Ejemplo_De_Formato.ps1
    Launches the interactive main menu with arrow-key navigation.

.EXAMPLE
    .\Ejemplo_De_Formato.ps1 -ShowProgress 0 -EnableDebug 1
    Launches with progress output disabled and debug mode enabled.

.EXAMPLE
    .\Ejemplo_De_Formato.ps1 -NoPersist
    Launches without loading or saving the settings JSON file.
#>

[CmdletBinding()]
param(
    [int]$ShowProgress = -1,
    [int]$EnableDebug  = -1,
    [switch]$NoPersist
)

# ============================================================================
# 1. BOOTSTRAP: Encoding, error preferences, version detection
# ============================================================================
$ErrorActionPreference = 'Stop'
$ProgressPreference    = 'SilentlyContinue'

# Force UTF-8 on the console layer. The .ps1 file itself SHOULD be saved as
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
try { $Host.UI.RawUI.WindowTitle = 'TUI Template - Console Style Guide' } catch {}

# Detect PowerShell version (used for graceful feature toggling later)
$Script:PSVersion = $PSVersionTable.PSVersion
$Script:IsPS7     = $Script:PSVersion.Major -ge 7

# ============================================================================
# 2. METADATA & PATHS
# ============================================================================
$Script:AppName      = 'TUI Template'
$Script:AppVersion   = '5.0.0'
$Script:AppAuthor    = 'Israleche'
$Script:ScriptDir    = Split-Path -Parent $MyInvocation.MyCommand.Path
$Script:SettingsFile = Join-Path $Script:ScriptDir 'Ejemplo_De_Formato.settings.json'

# ============================================================================
# 3. SETTINGS MANAGEMENT (JSON persistence)
# ============================================================================
# Single source of truth for runtime-tunable behavior. Persisted to disk so
# that user preferences survive across sessions (use -NoPersist to disable).
$Script:Settings = [ordered]@{
    ShowProgress = $true
    DebugMode    = $false
}

function Import-Settings {
    <#
    .SYNOPSIS
        Loads persisted settings from the JSON file next to the script.
    .DESCRIPTION
        Silently ignores missing or corrupt files so the app always boots.
    #>
    [CmdletBinding()] param()
    if ($NoPersist) { return }
    if (-not (Test-Path -LiteralPath $Script:SettingsFile)) { return }
    try {
        $json = Get-Content -LiteralPath $Script:SettingsFile -Raw -Encoding UTF8 |
            ConvertFrom-Json
        if ($null -ne $json.ShowProgress) {
            $Script:Settings.ShowProgress = [bool]$json.ShowProgress
        }
        if ($null -ne $json.DebugMode) {
            $Script:Settings.DebugMode = [bool]$json.DebugMode
        }
    } catch {
        Write-Debug "Settings load failed: $($_.Exception.Message)"
    }
}

function Export-Settings {
    <#
    .SYNOPSIS
        Saves current settings to the JSON file next to the script.
    #>
    [CmdletBinding()] param()
    if ($NoPersist) { return }
    try {
        $obj = [PSCustomObject]@{
            ShowProgress = $Script:Settings.ShowProgress
            DebugMode    = $Script:Settings.DebugMode
        }
        $obj | ConvertTo-Json -Depth 5 |
            Set-Content -LiteralPath $Script:SettingsFile -Encoding UTF8
    } catch {
        Write-Debug "Settings save failed: $($_.Exception.Message)"
    }
}

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
    Bullet   = [string][char]0x25BA   # ► (selection marker)
}

# ============================================================================
# 5. UI HELPERS: Inline status markers
# ============================================================================
# Convention: every status helper indents 2 spaces and uses a 3-char bracket
# marker so visual scanning is consistent across the whole script.
function Write-Step {
    <#.SYNOPSIS Prints a muted step line.#>
    [CmdletBinding()] param([Parameter(Mandatory)][string]$Text)
    Write-Host ("  > $Text") -ForegroundColor $Script:Palette.Muted
}

function Write-Ok {
    <#.SYNOPSIS Prints a success line ([+]).#>
    [CmdletBinding()] param([Parameter(Mandatory)][string]$Text)
    Write-Host ("  [+] $Text") -ForegroundColor $Script:Palette.Success
}

function Write-Warn {
    <#.SYNOPSIS Prints a warning line ([!]).#>
    [CmdletBinding()] param([Parameter(Mandatory)][string]$Text)
    Write-Host ("  [!] $Text") -ForegroundColor $Script:Palette.Warning
}

function Write-Err {
    <#.SYNOPSIS Prints an error line ([x]).#>
    [CmdletBinding()] param([Parameter(Mandatory)][string]$Text)
    Write-Host ("  [x] $Text") -ForegroundColor $Script:Palette.Danger
}

function Write-Info {
    <#.SYNOPSIS Prints an informational line ([i]).#>
    [CmdletBinding()] param([Parameter(Mandatory)][string]$Text)
    Write-Host ("  [i] $Text") -ForegroundColor $Script:Palette.Info
}

function Write-Log {
    <#.SYNOPSIS Prints a verbose log line, only when DebugMode is on.#>
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
    <#.SYNOPSIS Recomputes $Script:BoxWidth from the current console window.#>
    $width = 62
    try {
        $cw = $Host.UI.RawUI.WindowSize.Width
        if ($cw -gt 40 -and $cw -lt 200) { $width = [Math]::Min(80, $cw - 4) }
    } catch {}
    if ($width -lt 50) { $width = 50 }
    $Script:BoxWidth = $width
}

function Write-BoxTop {
    <#
    .SYNOPSIS
        Renders the top frame of a box with a centered title.
    .DESCRIPTION
        Layout: ╭──── Title ────╮  (curved corners, single line).
    #>
    [CmdletBinding()] param([Parameter(Mandatory)][string]$Title)
    Update-BoxWidth
    $width    = $Script:BoxWidth
    $title    = [string]$Title
    $innerSpan = $width - 2  # space between the two corners
    if ($title.Length -gt ($innerSpan - 4)) {
        $title = $title.Substring(0, $innerSpan - 4)
    }
    $decoLen  = $innerSpan - $title.Length - 2
    $sideLen  = [int][Math]::Floor($decoLen / 2)
    $rightLen = $decoLen - $sideLen
    $line = $Script:Box.TopLeft +
            ($Script:Box.H * $sideLen) +
            ' ' + $title + ' ' +
            ($Script:Box.H * $rightLen) +
            $Script:Box.TopRight
    Write-Host ('  ' + $line) -ForegroundColor $Script:Palette.Muted
}

function Write-BoxLine {
    <#
    .SYNOPSIS
        Renders one line of body content, wrapping long lines at word
        boundaries when possible.
    #>
    [CmdletBinding()] param([string]$Text = '')
    $width = $Script:BoxWidth
    $inner = $width - 4  # content area inside │ and │
    $t = if ($null -eq $Text) { '' } else { [string]$Text }
    while ($t.Length -gt $inner) {
        $chunk = $t.Substring(0, $inner)
        $lastSpace = $chunk.LastIndexOf(' ')
        if ($lastSpace -gt 20) {
            $chunk = $t.Substring(0, $lastSpace)
            $t = $t.Substring($lastSpace + 1)
        } else {
            $t = $t.Substring($inner)
        }
        $pad = $inner - $chunk.Length
        Write-Host ("  " + $Script:Box.V + " " + $chunk + (' ' * $pad) + " " + $Script:Box.V) -ForegroundColor $Script:Palette.Primary
    }
    $pad = $inner - $t.Length
    Write-Host ("  " + $Script:Box.V + " " + $t + (' ' * $pad) + " " + $Script:Box.V) -ForegroundColor $Script:Palette.Primary
}

function Write-BoxSeparator {
    <#.SYNOPSIS Renders an internal horizontal divider: ├──...──┤#>
    [CmdletBinding()] param()
    $width     = $Script:BoxWidth
    $innerSpan = $width - 2
    $line = $Script:Box.CrossL + ($Script:Box.H * $innerSpan) + $Script:Box.CrossR
    Write-Host ('  ' + $line) -ForegroundColor $Script:Palette.Muted
}

function Write-BoxSubtitle {
    <#.SYNOPSIS Renders a centered subtitle inside a box: ── Section ──#>
    [CmdletBinding()] param([Parameter(Mandatory)][string]$Title)
    $width = $Script:BoxWidth
    $inner = $width - 4
    $t = [string]$Title
    if ($t.Length -gt ($inner - 6)) { $t = $t.Substring(0, $inner - 6) }
    $decoLen  = $inner - $t.Length - 2
    $sideLen  = [int][Math]::Floor($decoLen / 2)
    $rightLen = $decoLen - $sideLen
    $content = ($Script:Box.H * $sideLen) + ' ' + $t + ' ' + ($Script:Box.H * $rightLen)
    $pad = $inner - $content.Length
    if ($pad -lt 0) { $content = $content.Substring(0, $inner); $pad = 0 }
    Write-Host ("  " + $Script:Box.V + " " + $content + (' ' * $pad) + " " + $Script:Box.V) -ForegroundColor $Script:Palette.Accent
}

function Write-BoxKeyValue {
    <#
    .SYNOPSIS
        Renders a key-value row with dotted leader between them:
        │  Key...........Value │
    #>
    [CmdletBinding()] param(
        [Parameter(Mandatory)][string]$Key,
        [Parameter(Mandatory)][string]$Value,
        [string]$KeyColor,
        [string]$ValueColor
    )
    $width = $Script:BoxWidth
    $inner = $width - 4
    $k = [string]$Key
    $v = [string]$Value
    $keyPart = "  " + $k
    $minDots = 3
    $maxKeyLen = $inner - $minDots - 1
    if ($keyPart.Length -gt $maxKeyLen) {
        $keyPart = $keyPart.Substring(0, $maxKeyLen)
    }
    $availForValue = $inner - $keyPart.Length - $minDots
    if ($availForValue -lt 1) { $availForValue = 1 }
    if ($v.Length -gt $availForValue) { $v = $v.Substring(0, $availForValue) }
    $dotsCount = $inner - $keyPart.Length - $v.Length
    if ($dotsCount -lt 1) { $dotsCount = 1 }

    $kColor = if ($KeyColor)   { $KeyColor }   else { $Script:Palette.Accent  }
    $vColor = if ($ValueColor) { $ValueColor } else { $Script:Palette.Primary }

    Write-Host -NoNewline ("  " + $Script:Box.V + " ") -ForegroundColor $Script:Palette.Muted
    Write-Host -NoNewline $keyPart -ForegroundColor $kColor
    Write-Host -NoNewline ('.' * $dotsCount) -ForegroundColor $Script:Palette.Muted
    Write-Host -NoNewline $v -ForegroundColor $vColor
    Write-Host -NoNewline (" " + $Script:Box.V) -ForegroundColor $Script:Palette.Muted
    Write-Host ''
}

function Write-BoxBottom {
    <#.SYNOPSIS Renders the bottom frame: ╰──────╯#>
    [CmdletBinding()] param()
    $width     = $Script:BoxWidth
    $innerSpan = $width - 2
    $line = $Script:Box.BotLeft + ($Script:Box.H * $innerSpan) + $Script:Box.BotRight
    Write-Host ('  ' + $line) -ForegroundColor $Script:Palette.Muted
}

function Write-Box {
    <#
    .SYNOPSIS
        Convenience wrapper: renders a full titled box from an array of
        content lines. Useful for static dialogs without interactivity.
    .EXAMPLE
        Write-Box -Title 'HELLO' -Lines @('Welcome to the template.','')
    #>
    [CmdletBinding()] param(
        [Parameter(Mandatory)][string]$Title,
        [Parameter()][string[]]$Lines = @()
    )
    Write-BoxTop -Title $Title
    foreach ($l in $Lines) { Write-BoxLine -Text $l }
    Write-BoxBottom
}

# ============================================================================
# 7. PROGRESS BAR
# ============================================================================
function Write-ProgressBar {
    <#
    .SYNOPSIS
        Renders a single-line progress bar.
    .DESCRIPTION
        Available styles:
          - Blocks  (default, L2): [████████████░░░░░░░░] 60%
          - Dots    (L2/L3):       [●●●●●●●●○○○○○○○○] 50%
          - Arrow   (L1, max compat): [=========>.....] 60%
          - Solid   (L2):           [▓▓▓▓▓▓▓▓        ] 60%
    #>
    [CmdletBinding()] param(
        [Parameter(Mandatory)][int]$Percent,
        [ValidateSet('Blocks','Dots','Arrow','Solid')][string]$Style = 'Blocks',
        [int]$Width = 30,
        [string]$Label
    )
    if ($Percent -lt 0)   { $Percent = 0 }
    if ($Percent -gt 100) { $Percent = 100 }
    $filled = [int][Math]::Floor(($Percent / 100) * $Width)
    $empty  = $Width - $filled

    $fillChar  = '='
    $emptyChar = ' '
    switch ($Style) {
        'Blocks' { $fillChar = [char]0x2588; $emptyChar = [char]0x2591 }
        'Dots'   { $fillChar = [char]0x25CF; $emptyChar = [char]0x25CB }
        'Arrow'  { $fillChar = '=';          $emptyChar = '.' }
        'Solid'  { $fillChar = [char]0x2593; $emptyChar = ' ' }
    }

    if ($Style -eq 'Arrow') {
        if ($filled -gt 0) {
            $bar = ('=' * ($filled - 1)) + '>' + ('.' * $empty)
        } else {
            $bar = '.' * $Width
        }
    } else {
        $bar = ([string]$fillChar * $filled) + ([string]$emptyChar * $empty)
    }
    $pctStr   = ('{0,3}%' -f $Percent)
    $labelStr = if ($Label) { "  $Label" } else { '' }
    Write-Host ("  [$bar] $pctStr$labelStr") -ForegroundColor $Script:Palette.Accent
}

# ============================================================================
# 8. SPINNER (synchronous, repaint-in-place)
# ============================================================================
# The spinner is synchronous on purpose: background timers in PS 5.1 cause
# cross-thread Console writes that interleave with main-thread output.
# Usage pattern:
#   $spin = New-Spinner -Label 'Loading'
#   for ($i=0; $i -lt 20; $i++) { Update-Spinner $spin; Start-Sleep -Ms 80 }
#   Complete-Spinner $spin -FinalMessage 'Done' -Success
function New-Spinner {
    <#
    .SYNOPSIS
        Creates a spinner state object to be updated in a loop.
    .PARAMETER Style
        Frame set: Braille, Block, Classic, Geometric.
    #>
    [CmdletBinding()] param(
        [string]$Label = 'Working',
        [ValidateSet('Braille','Block','Classic','Geometric')][string]$Style = 'Braille'
    )
    $frames = switch ($Style) {
        'Braille'   { @(([char]0x280B),([char]0x2819),([char]0x2839),([char]0x2838),([char]0x283C),([char]0x2834)) }
        'Block'     { @(([char]0x2596),([char]0x2598),([char]0x259D),([char]0x2592)) }
        'Classic'   { @('|','/','-','\') }
        'Geometric' { @(([char]0x25E4),([char]0x25E5),([char]0x25E2),([char]0x25E3)) }
    }
    return [PSCustomObject]@{
        Frames = $frames
        Index  = 0
        Label  = $Label
        Top    = [Console]::CursorTop
    }
}

function Update-Spinner {
    <#.SYNOPSIS Paints the next spinner frame in place.#>
    [CmdletBinding()] param([Parameter(Mandatory)]$Spinner)
    $frame = $Spinner.Frames[$Spinner.Index]
    $Spinner.Index = ($Spinner.Index + 1) % $Spinner.Frames.Count
    try { [Console]::SetCursorPosition(0, $Spinner.Top) } catch {}
    $line = "  $frame $($Spinner.Label)...   "
    Write-Host -NoNewline $line -ForegroundColor $Script:Palette.Accent
}

function Complete-Spinner {
    <#.SYNOPSIS Clears the spinner line and prints a final status message.#>
    [CmdletBinding()] param(
        [Parameter(Mandatory)]$Spinner,
        [string]$FinalMessage,
        [switch]$Success
    )
    try { [Console]::SetCursorPosition(0, $Spinner.Top) } catch {}
    Write-Host -NoNewline (' ' * 80)
    try { [Console]::SetCursorPosition(0, $Spinner.Top) } catch {}
    if ($FinalMessage) {
        if ($Success) {
            Write-Host ("  [+] $FinalMessage") -ForegroundColor $Script:Palette.Success
        } else {
            Write-Host ("  [-] $FinalMessage") -ForegroundColor $Script:Palette.Danger
        }
    } else {
        Write-Host ''
    }
}

# ============================================================================
# 9. INPUT HELPERS
# ============================================================================
function Read-YesNo {
    <#.SYNOPSIS Loops until the user answers y/n.#>
    [CmdletBinding()] param([Parameter(Mandatory)][string]$Prompt)
    while ($true) {
        Write-Host -NoNewline "  $Prompt [y/n] " -ForegroundColor $Script:Palette.Prompt
        $ans = (Read-Host).Trim().ToLower()
        if ($ans -eq 'y' -or $ans -eq 'yes') { return $true }
        if ($ans -eq 'n' -or $ans -eq 'no')  { return $false }
        Write-Warn 'Please answer y or n.'
    }
}

function Read-AnyKey {
    <#
    .SYNOPSIS
        Waits for any key press. Falls back to Read-Host when the console
        is non-interactive (piped stdin, ISE, CI runners).
    #>
    [CmdletBinding()] param([string]$Prompt = 'Press any key to continue...')
    Write-Host -NoNewline "  $Prompt " -ForegroundColor $Script:Palette.Muted
    try {
        $null = [Console]::ReadKey($true)
        Write-Host ''
    } catch {
        $null = Read-Host
    }
}

function Test-InteractiveConsole {
    <#.SYNOPSIS Returns $true if arrow-key input is available.#>
    try {
        $null = [Console]::KeyAvailable
        return $true
    } catch {
        return $false
    }
}

function Read-MenuSelection {
    <#
    .SYNOPSIS
        Renders an interactive menu with arrow-key navigation.
    .DESCRIPTION
        Returns the 0-based index of the selected option, or -1 if the user
        pressed ESC. Falls back to numbered input when the console is not
        interactive (piped stdin, ISE, CI runners).
    .PARAMETER Title
        Box title shown at the top.
    .PARAMETER Options
        Array of option strings.
    .PARAMETER DefaultIndex
        Pre-selected option (default 0).
    .PARAMETER Footer
        Optional footer line shown inside the box, after the options.
    #>
    [CmdletBinding()] param(
        [Parameter(Mandatory)][string]$Title,
        [Parameter(Mandatory)][string[]]$Options,
        [int]$DefaultIndex = 0,
        [string]$Footer
    )
    $selected = if ($DefaultIndex -ge 0 -and $DefaultIndex -lt $Options.Count) { $DefaultIndex } else { 0 }

    if (-not (Test-InteractiveConsole)) {
        # Fallback: numbered input
        Write-Banner
        Write-BoxTop -Title $Title
        for ($i = 0; $i -lt $Options.Count; $i++) {
            Write-BoxLine ("[{0}] {1}" -f ($i + 1), $Options[$i])
        }
        if ($Footer) { Write-BoxSeparator; Write-BoxLine $Footer }
        Write-BoxBottom
        while ($true) {
            Write-Host -NoNewline '  Select an option: ' -ForegroundColor $Script:Palette.Prompt
            $c = (Read-Host).Trim()
            if ($c -match '^\d+$') {
                $n = [int]$c
                if ($n -ge 1 -and $n -le $Options.Count) { return ($n - 1) }
            }
            Write-Warn 'Invalid option.'
        }
    }

    # Interactive: arrow-key navigation
    $redraw = $true
    while ($true) {
        if ($redraw) {
            Write-Banner
            Write-BoxTop -Title $Title
            for ($i = 0; $i -lt $Options.Count; $i++) {
                $marker = if ($i -eq $selected) { $Script:Box.Bullet } else { ' ' }
                $line = " $marker  $($Options[$i])"
                if ($i -eq $selected) {
                    $inner = $Script:BoxWidth - 4
                    if ($line.Length -gt $inner) { $line = $line.Substring(0, $inner) }
                    $pad = $inner - $line.Length
                    Write-Host -NoNewline ("  " + $Script:Box.V + " ") -ForegroundColor $Script:Palette.Muted
                    Write-Host -NoNewline $line -ForegroundColor $Script:Palette.Accent
                    Write-Host -NoNewline (' ' * $pad) -ForegroundColor $Script:Palette.Accent
                    Write-Host -NoNewline (" " + $Script:Box.V) -ForegroundColor $Script:Palette.Muted
                    Write-Host ''
                } else {
                    Write-BoxLine -Text $line
                }
            }
            if ($Footer) { Write-BoxSeparator; Write-BoxLine $Footer }
            Write-BoxBottom
            Write-Host "  Use up/down arrows to navigate, ENTER to select, ESC to cancel" -ForegroundColor $Script:Palette.Muted
            $redraw = $false
        }
        $key = [Console]::ReadKey($true)
        switch ($key.Key) {
            'UpArrow'   { $selected = ($selected - 1 + $Options.Count) % $Options.Count; $redraw = $true }
            'DownArrow' { $selected = ($selected + 1) % $Options.Count; $redraw = $true }
            'Home'      { $selected = 0; $redraw = $true }
            'End'       { $selected = $Options.Count - 1; $redraw = $true }
            'Enter'     { return $selected }
            'Escape'    { return -1 }
            default {
                $dk = $key.KeyChar
                if ($dk -match '^\d$') {
                    $n = [int]$dk.ToString()
                    if ($n -ge 1 -and $n -le $Options.Count) { return ($n - 1) }
                }
            }
        }
    }
}

# ============================================================================
# 10. BANNER
# ============================================================================
function Write-FadeIn {
    <#.SYNOPSIS Prints each line of an array with a small delay.#>
    [CmdletBinding()] param(
        [Parameter(Mandatory)][string[]]$Lines,
        [int]$DelayMs = 40,
        [string]$Color = 'Magenta'
    )
    foreach ($line in $Lines) {
        Write-Host $line -ForegroundColor $Color
        if ($DelayMs -gt 0) { Start-Sleep -Milliseconds $DelayMs }
    }
}

function Write-Banner {
    <#.SYNOPSIS Renders the welcome banner with ASCII art and current state flags.#>
    [CmdletBinding()] param()
    Clear-Host
    Write-Host ''
    $bar = '  ' + ([string]([char]0x2500) * 78)
    Write-Host $bar -ForegroundColor $Script:Palette.Muted
    Write-Host ''

    # 6-line ANSI shadow banner. Replace this array to rebrand the template.
    # Keep lines roughly the same width so the layout stays balanced.
    $bannerLines = @(
        '        ███████╗        ██╗   ███████╗   ███╗   ███╗   ██████╗  ██╗       ██████╗ ',
        '        ██╔════╝        ██║   ██╔════╝   ████╗ ████║   ██╔══██╗ ██║      ██╔═══██╗',
        '        █████╗          ██║   █████╗     ██╔████╔██║   ██████╔╝ ██║      ██║   ██║',
        '        ██╔══╝     ██   ██║   ██╔══╝     ██║╚██╔╝██║   ██╔═══╝  ██║      ██║   ██║',
        '        ███████╗   ╚█████╔╝   ███████╗   ██║ ╚═╝ ██║   ██║      ███████╗ ╚██████╔╝',
        '        ╚══════╝    ╚════╝    ╚══════╝   ╚═╝     ╚═╝   ╚═╝      ╚══════╝  ╚═════╝  '
    )
    Write-FadeIn -Lines $bannerLines -DelayMs 25 -Color $Script:Palette.Logo

    Write-Host ''
    Write-Host '                               CONSOLE TUI TEMPLATE' -ForegroundColor $Script:Palette.Primary
    Write-Host ("                                v$($Script:AppVersion)  by $($Script:AppAuthor)") -ForegroundColor $Script:Palette.Muted
    Write-Host ''
    Write-Host $bar -ForegroundColor $Script:Palette.Muted

    $prog  = if ($Script:Settings.ShowProgress) { 'ON' } else { 'OFF' }
    $debug = if ($Script:Settings.DebugMode)    { 'ON' } else { 'OFF' }
    $psVer = "PS $($Script:PSVersion.ToString())"

    Write-Host -NoNewline '  progress:' -ForegroundColor $Script:Palette.Muted
    $progColor = if ($prog -eq 'ON') { $Script:Palette.On } else { $Script:Palette.Off }
    Write-Host -NoNewline " $prog" -ForegroundColor $progColor

    Write-Host -NoNewline '   debug:' -ForegroundColor $Script:Palette.Muted
    $dbgColor = if ($debug -eq 'ON') { $Script:Palette.On } else { $Script:Palette.Off }
    Write-Host -NoNewline " $debug" -ForegroundColor $dbgColor

    Write-Host -NoNewline '   runtime:' -ForegroundColor $Script:Palette.Muted
    Write-Host -NoNewline " $psVer" -ForegroundColor $Script:Palette.Accent

    Write-Host ''
    Write-Host $bar -ForegroundColor $Script:Palette.Muted
    Write-Host ''
}

# ============================================================================
# 11. ENVIRONMENT CHECKS
# ============================================================================
function Test-RunningAsAdmin {
    <#.SYNOPSIS Returns $true if the current session is elevated.#>
    try {
        $id = [Security.Principal.WindowsIdentity]::GetCurrent()
        $pr = New-Object Security.Principal.WindowsPrincipal($id)
        return $pr.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    } catch { return $false }
}

function Test-PowerShellVersion {
    <#.SYNOPSIS Returns $true if PSVersion >= 5.1.#>
    try {
        return $Script:PSVersion -ge [version]'5.1'
    } catch { return $false }
}

# ============================================================================
# 12. SAMPLE TASK (demonstrates spinner + progress bar)
# ============================================================================
function Invoke-SampleTask {
    <#.SYNOPSIS Runs a fake multi-step task to showcase progress helpers.#>
    [CmdletBinding()] param()
    Write-Banner
    Write-Step 'Starting simulated process...'
    Write-Host ''

    $spin = New-Spinner -Label 'Loading configuration' -Style Braille
    for ($i = 0; $i -lt 15; $i++) { Update-Spinner $spin; Start-Sleep -Milliseconds 80 }
    Complete-Spinner $spin -FinalMessage 'Configuration loaded' -Success

    $spin = New-Spinner -Label 'Validating environment' -Style Braille
    for ($i = 0; $i -lt 15; $i++) { Update-Spinner $spin; Start-Sleep -Milliseconds 80 }
    Complete-Spinner $spin -FinalMessage 'Environment valid' -Success

    Write-ProgressBar -Percent 100 -Style Blocks -Label 'All steps complete'
    Write-Host ''
    Write-Ok 'Task completed successfully.'
    Read-AnyKey 'Press any key to return to the menu...'
}

# ============================================================================
# 13. STATUS DISPLAY
# ============================================================================
function Show-Status {
    <#.SYNOPSIS Renders a key-value info box with current system and session data.#>
    [CmdletBinding()] param()
    Write-Banner
    Write-BoxTop -Title 'SYSTEM INFORMATION'
    Write-BoxLine ''
    Write-BoxSubtitle -Title 'ENVIRONMENT'
    Write-BoxKeyValue -Key 'OS Version'   -Value ([Environment]::OSVersion.VersionString)
    Write-BoxKeyValue -Key 'User Domain'  -Value $env:USERDOMAIN
    Write-BoxKeyValue -Key 'User Name'    -Value $env:USERNAME
    Write-BoxKeyValue -Key 'Machine Name' -Value $env:COMPUTERNAME
    Write-BoxKeyValue -Key 'PowerShell'   -Value $Script:PSVersion.ToString()
    Write-BoxLine ''
    Write-BoxSeparator
    Write-BoxSubtitle -Title 'SESSION PARAMETERS'
    $progVal  = if ($Script:Settings.ShowProgress) { 'ON' } else { 'OFF' }
    $progCol  = if ($Script:Settings.ShowProgress) { $Script:Palette.On } else { $Script:Palette.Off }
    $debugVal = if ($Script:Settings.DebugMode)    { 'ON' } else { 'OFF' }
    $debugCol = if ($Script:Settings.DebugMode)    { $Script:Palette.On } else { $Script:Palette.Off }
    Write-BoxKeyValue -Key 'Show Progress' -Value $progVal  -ValueColor $progCol
    Write-BoxKeyValue -Key 'Debug Mode'    -Value $debugVal -ValueColor $debugCol
    $persistVal = if ($NoPersist) { 'DISABLED' } else { 'ENABLED' }
    Write-BoxKeyValue -Key 'Persist Flag'  -Value $persistVal
    $fileVal = if (Test-Path $Script:SettingsFile) { 'EXISTS' } else { 'NOT CREATED' }
    Write-BoxKeyValue -Key 'Settings File' -Value $fileVal
    Write-BoxLine ''
    Write-BoxBottom
    Write-Host ''
    Read-AnyKey 'Press any key to return to the menu...'
}

# ============================================================================
# 14. SETTINGS MENU (sub-menu)
# ============================================================================
function Show-SettingsMenu {
    <#.SYNOPSIS Interactive sub-menu for toggling runtime flags.#>
    [CmdletBinding()] param()
    while ($true) {
        $progState  = if ($Script:Settings.ShowProgress) { 'ON' } else { 'OFF' }
        $debugState = if ($Script:Settings.DebugMode)    { 'ON' } else { 'OFF' }
        $opts = @(
            "Toggle command progress (currently: $progState)",
            "Toggle debug mode (currently: $debugState)",
            'Save settings now',
            'Return to main menu'
        )
        $sel = Read-MenuSelection -Title 'SUBSYSTEM SETTINGS' -Options $opts -DefaultIndex 0
        switch ($sel) {
            0  { $Script:Settings.ShowProgress = -not $Script:Settings.ShowProgress; Export-Settings; Write-Ok 'Setting updated.'; Start-Sleep -Milliseconds 600 }
            1  { $Script:Settings.DebugMode    = -not $Script:Settings.DebugMode;    Export-Settings; Write-Ok 'Setting updated.'; Start-Sleep -Milliseconds 600 }
            2  { Export-Settings; Write-Ok 'Settings saved.'; Start-Sleep -Milliseconds 600 }
            3  { return }
            -1 { return }
            default { Write-Warn 'Invalid option.'; Start-Sleep -Milliseconds 400 }
        }
    }
}

# ============================================================================
# 15. MAIN MENU
# ============================================================================
function Show-MainMenu {
    <#.SYNOPSIS Top-level interactive loop with arrow-key navigation.#>
    [CmdletBinding()] param()
    while ($true) {
        $opts = @(
            'Run sample automated task',
            'View system status and variables',
            'Open subsystem settings',
            'Exit'
        )
        $footer = if ($Script:Settings.DebugMode) { 'DEBUG MODE IS ACTIVE' } else { $null }
        $sel = Read-MenuSelection -Title 'MAIN MENU' -Options $opts -DefaultIndex 0 -Footer $footer
        try {
            switch ($sel) {
                0  { Invoke-SampleTask }
                1  { Show-Status }
                2  { Show-SettingsMenu }
                3  {
                    Write-Host ''
                    Write-Ok 'Goodbye!'
                    Start-Sleep -Milliseconds 500
                    exit 0
                }
                -1 { return }
                default { Write-Warn 'Invalid option.'; Start-Sleep -Milliseconds 500 }
            }
        } catch {
            Write-Host ''
            Write-Err ('Execution exception: ' + $_.Exception.Message)
            Read-AnyKey 'Press any key to continue...'
        }
    }
}

# ============================================================================
# 16. ENTRY POINT
# ============================================================================
function Start-App {
    <#.SYNOPSIS Bootstrap entry point: validates environment, loads settings, runs main loop.#>
    [CmdletBinding()] param()

    # 1. Strict environment validation
    if (-not (Test-PowerShellVersion)) {
        Write-Err 'PowerShell 5.1 or later is required to run this script.'
        Read-AnyKey 'Press any key to exit...'
        exit 1
    }

    # 2. Optional admin restriction (uncomment if your tool must NOT run elevated).
    # if (Test-RunningAsAdmin) {
    #     Write-Err 'Do not run this script as Administrator.'
    #     Write-Warn 'Running under elevated credentials may break user paths.'
    #     Read-AnyKey 'Press any key to exit...'
    #     exit 1
    # }

    # 3. Load persisted settings, then let CLI params override them
    Import-Settings
    if ($ShowProgress -ge 0) { $Script:Settings.ShowProgress = [bool]$ShowProgress }
    if ($EnableDebug  -ge 0) { $Script:Settings.DebugMode    = [bool]$EnableDebug  }

    # 4. Main interactive loop
    Show-MainMenu
}

# ============================================================================
# SCRIPT ENTRY POINT (global try/catch)
# ============================================================================
try { Start-App }
catch {
    Write-Host ''
    Write-Err ("FATAL UNHANDLED ERROR: " + $_.Exception.Message)
    try { Write-Host $_.ScriptStackTrace -ForegroundColor DarkGray } catch {}
    Read-AnyKey 'Press any key to exit...'
    exit 1
}
