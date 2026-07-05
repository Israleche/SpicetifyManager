# TUI Visual Encyclopedia

> **Version 4.1** — Universal reference for building Text User Interfaces in
> PowerShell (and other CLI languages). Designed for both human developers and
> AI agents: every glyph is tagged with a compatibility level so you can
> reason about portability without running the script.

This document is the companion reference for `Ejemplo_De_Formato.ps1`. The
template implements a subset of what is described here; this document is the
canonical visual vocabulary you should consult when extending or rebranding
the template, or when authoring a brand-new tool that should match the house
style.

---

## How to read this document

Each section opens with a short intent statement, followed by glyph tables.
Every glyph is annotated with a **compatibility level**:

| Level | Tag              | Meaning                                                                |
| ----- | ---------------- | ---------------------------------------------------------------------- |
| L1    | `UNIVERSAL-ASCII` | 100% safe. Works in legacy `cmd.exe`, MS-DOS, PS 5.1 conhost, any UNIX terminal. No encoding setup required. |
| L2    | `UTF8-STANDARD`   | Requires `chcp 65001` or `[Console]::OutputEncoding = UTF8` on Windows. Native on Linux/macOS. |
| L3    | `MODERN-EMOJI`    | Works in Windows Terminal, VS Code Terminal, PS 7+, modern Linux/macOS terminals. Fails on old `cmd.exe`. |
| L4    | `NERD-FONTS`      | Requires a patched dev font (FiraCode NF, Meslo, Cascadia NF).          |

### Master column-width rule (for AI agents computing padding)

- **L1 / L2 / L3 box-drawing characters** occupy exactly **1 column** in any
  monospaced font.
- **L3 emojis and L4 nerd-font icons** occupy **2 columns** in most modern
  terminals (Windows Terminal, Alacritty, iTerm2).
- When computing `padding = inner_width - text_length`, subtract **2** for
  every emoji and **1** for every box-drawing character.

### AI parsing hints

When an AI agent reads this file and needs to render a panel, it should:
1. Pick a compatibility level based on the target terminal (default L2).
2. Select glyphs only from that level or below.
3. Compute padding using the master column-width rule above.
4. Use the box-drawing helpers from `Ejemplo_De_Formato.ps1`
   (`Write-BoxTop`, `Write-BoxLine`, `Write-BoxSeparator`, `Write-BoxSubtitle`,
   `Write-BoxKeyValue`, `Write-BoxBottom`) — they already implement these
   rules.

---

## Section 1 — Platform / Shell / Subsystem compatibility matrix

| Level | Tag                | cmd.exe (legacy) | cmd.exe (Win11) | PS 5.1 conhost | PS 7+ Windows | Linux Bash/Zsh | macOS Terminal/iTerm2 |
| ----- | ------------------ | :--------------: | :-------------: | :------------: | :-----------: | :------------: | :-------------------: |
| L1    | UNIVERSAL-ASCII    |        ✅        |       ✅        |       ✅       |      ✅       |       ✅       |          ✅           |
| L2    | UTF8-STANDARD      |        ⚠️ a       |       ✅        |       ⚠️ a      |      ✅       |       ✅       |          ✅           |
| L3    | MODERN-EMOJI       |        ❌        |       ✅        |       ❌       |      ✅       |       ✅       |          ✅           |
| L4    | NERD-FONTS         |        ❌        |       ⚠️ b       |       ❌       |      ⚠️ b      |       ⚠️ b      |          ⚠️ b           |

> _a_ Requires `chcp 65001` or `[Console]::OutputEncoding = [System.Text.Encoding]::UTF8`.
> _b_ Depends on the configured terminal font, not the shell.

---

## Section 2 — Block characters & progress-bar systems

### 2.1 Vertical block fractions (L2/L3)

Useful for vertical progress bars and equalizers. Each character is 1 column wide.

```
█ ▉ ▊ ▋ ▌ ▍ ▎ ▏ ▐ ░ ▒ ▓ ▔ ▕ ▖ ▗ ▘ ▙ ▚ ▛ ▜ ▝ ▞ ▟
```

### 2.2 Horizontal fractional sparklines (L3)

Ideal for single-line CPU/RAM micro-graphs.

```
▂ ▃ ▄ ▅ ▆ ▇ █
```

### 2.3 Braille matrix (L3)

High-density dots for micro-graphs or high-fidelity spinners.

```
⠋ ⠙ ⠹ ⠸ ⠼ ⠴ ⠦ ⠧ ⠇ ⠏ ⠁ ⠂ ⠄ ⠆ ⠝ ⠟ ⠽ ⠫ ⠻ ⠉ ⠚ ⠒
```

### 2.4 Preconfigured progress-bar styles

The template ships with `Write-ProgressBar -Style <name>` implementing these
four styles. Use the one that best fits the terminal's compatibility level.

#### Style A — Industrial Density Blocks (L2) — default

Best for global installers. Solid `█` for 100%, `▓` 75%, `▒` 50%, `░` 25%.

```
[████████████████████████▓▓▓▒▒▒░░░░░░] 75%
[████████████████████████████████████] 100%
```

#### Style B — Fractional Fluid (L3)

Ultra-smooth transitions for high-end terminals.

```
[██████████████████████████▍          ] 68%
```

#### Style C — Continuous Flow Arrow (L1)

Maximum legacy compatibility — safe in any terminal.

```
[=========================>          ] 70%
[>>>>>>>>>>>>>>>>>>>>>>>>>>          ] 72%
```

#### Style D — Geometric Minimalist (L2/L3)

For dashboards and KPI panels.

```
[●●●●●●●●●●●●●●●●●●●●○○○○○○○○○○○○○○] 55%
[■■■■■■■■■■■■■■■■■■■■▢▢▢▢▢▢▢▢▢▢▢▢▢▢] 55%
[◆◆◆◆◆◆◆◆◆◆◆◆◆◆◆◆◆◆◆◆◇◇◇◇◇◇◇◇◇◇◇◇◇◇] 55%
```

#### Style E — Single-Thread Minimalist (L2)

```
▕████████████████████████░░░░░░░░░░▏
```

### 2.5 Rotating spinners for async loops

The template ships with `New-Spinner -Style <name>` implementing these frame
sets. The spinner is **synchronous** — call `Update-Spinner` inside your loop
and `Complete-Spinner` when done.

| Style      | Level | Frames                                          |
| ---------- | :---: | ----------------------------------------------- |
| Classic    | L1    | `\| / - \`                                       |
| Dots       | L1    | `. .. ... ` (4 frames, last is blank)           |
| Geometric  | L2    | `◤ ◥ ◢ ◣`                                       |
| Block      | L3    | `▖ ▘ ▝ ▗`                                       |
| Braille    | L3    | `⠋ ⠙ ⠹ ⠸ ⠼ ⠴`                                    |
| Lunar      | L3    | `🌑 🌒 🌓 🌔 🌕 🌖 🌗 🌘`                          |

---

## Section 3 — Frames, borders, and intersection matrices

The template uses **modern curved corners** by default. Other styles are
documented here so you can swap them in by editing the `$Script:Box` table.

### 3.1 Thin single line (L2) — 1 column

```
Esquinas: ┌ ┐ └ ┘
Líneas:   ─ │
Cruces:   ├ ┤ ┬ ┴ ┼
```

### 3.2 Thick single line (L3) — 1 column

```
Esquinas: ┏ ┓ ┗ ┛
Líneas:   ━ ┃
Cruces:   ┣ ┫ ┳ ┻ ╋
```

### 3.3 Industrial double line (L2) — 1 column

```
Esquinas: ╔ ╗ ╚ ╝
Líneas:   ═ ║
Cruces:   ╠ ╣ ╦ ╩ ╬
```

### 3.4 Curved elegant line (L3) — **default in this template**

```
Esquinas: ╭ ╮ ╰ ╯
Líneas:   ─ │
Cruces:   ├ ┤ ┬ ┴ ┼
```

### 3.5 Dashed lines (L3)

```
2-point:  ╌ ╎
3-point:  ╍ ╏
4-point:  ┄ ┆
Alternate: ┈ ┊
```

### 3.6 Hybrid matrices (L3)

Useful when crossing single and double lines in the same panel.

```
╒ ╕ ╘ ╛ ╞ ╡ ╤ ╧ ╪ ╓ ╖ ╙ ╜ ╟ ╢ ╥ ╨ ╫
```

---

## Section 4 — Hierarchical connectors (trees & pipelines)

### 4.1 Standard tree structure (L2)

```
├──  intermediate node
└──  terminal node
│    vertical continuity conductor
├─── extended intermediate node
└─── extended terminal node
```

### 4.2 Procedural flow indicators (L2/L3)

```
──►   ├──►   └──►   ═►   ╘══►   ╘══>
➔     ➔     🡪     🡫     🡨     🡩
↳     ↴     ↱     ↲
```

---

## Section 5 — Micro-contextual state glyphs

Each state has three levels: L1 (text), L2 (Unicode), L3 (emoji). Pick the
level that matches your terminal.

### 5.1 Success / completed

| Level | Glyphs                                            |
| ----- | ------------------------------------------------- |
| L1    | `[+]` `[OK]` `[DONE]` `(Y)` `V`                   |
| L2    | `✔` `✓` `[✔]` `(✓)` `►` `▶` `▲`                   |
| L3    | 🟢 🟩 ✅ ✔️ 🗲                                       |

### 5.2 Warning / action required / pause

| Level | Glyphs                                            |
| ----- | ------------------------------------------------- |
| L1    | `[!]` `[?]` `[WARN]` `[WAIT]`                     |
| L2    | `⚠` `[⚠]` `⚡` `[⚡]` `♦` `❖`                       |
| L3    | 🟡 🟨 ⚠️ 🔸 🔶 ⏳                                       |

### 5.3 Error / critical / exception

| Level | Glyphs                                            |
| ----- | ------------------------------------------------- |
| L1    | `[x]` `[-]` `[ERR]` `[FAIL]` `(N)`                |
| L2    | `✖` `✗` `[✖]` `(x)` `■` `◄` `◀` `▼`                |
| L3    | 🔴 🟥 ❌ 🛑 ⛔ 💥                                       |

### 5.4 Information / audit / log

| Level | Glyphs                                            |
| ----- | ------------------------------------------------- |
| L1    | `[i]` `[*]` `[INFO]` `[LOG]`                      |
| L2    | `ⓘ` `ℹ` `[ⓘ]` `(i)` `▫` `▪`                        |
| L3    | 🔵 🟦 ℹ️ 🔹 🔷 📋                                       |

> **Template convention:** the inline status helpers (`Write-Ok`, `Write-Warn`,
> `Write-Err`, `Write-Info`, `Write-Step`) use the **L1** bracket form so they
> render correctly in every terminal. Swap them for L2/L3 in the
> `$Script:Palette` table only if you control the target terminal.

---

## Section 6 — Massive horizontal separators

Copy a full line to visually isolate blocks of output.

### L1 — Pure ASCII

```
--------------------------------------------------------------------------------
================================================================================
________________________________________________________________________________
################################################################################
********************************************************************************
```

### L2 — Solid Unicode

```
────────────────────────────────────────────────────────────────────────────────
════════════════════════════════════════════════════════════════════════════════
▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒
```

### L3 — Heavy modern

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌
❖❖❖❖❖❖❖❖❖❖❖❖❖❖❖❖❖❖❖❖❖❖❖❖❖❖❖❖❖❖❖❖❖❖❖❖❖❖❖❖❖❖❖❖❖❖❖❖❖❖❖❖❖❖❖❖❖❖❖❖❖❖❖❖❖❖❖❖❖❖❖❖❖❖❖❖❖❖❖❖
```

---

## Section 7 — Thematic icon metadata (L3)

Easy to interpret by humans and LLMs as visual flags/tags. Each emoji occupies
**2 columns** in most modern terminals — subtract 2 from the inner width when
computing padding.

| Icon | Meaning                  | Icon | Meaning                | Icon | Meaning                |
 ---- | ------------------------ | ---- | ---------------------- | ---- | ----------------------
| ⚙️    | Settings / SysConfig     | 🛠️   | Maintenance / Build    | 📦   | Modules / Extensions   |
| 🚀   | Deploy / Launch          | 📂   | Directories / Paths    | 📄   | Files / Scripts        |
| 💻   | Terminal / Processes     | 🔒   | Security / Encryption  | 🔑   | Keys / Credentials     |
| 🌐   | Internet / Network       | 📡   | Connection / Sockets   | 📊   | Statistics / Telemetry |
| 💾   | Save / Backup            | 🔍   | Search / Scan          | ⏱️   | Timeouts / Cron        |
| 🗑️   | Delete / Flush           | 🔔   | Alerts / Events        | 📥   | Download / Update      |

---

## Section 8 — Single-line Unicode typefaces (mock fonts)

For injecting stylized words without breaking the console grid with a giant
ASCII banner.

### 8.1 Monospaced typewriter

```
𝙰 𝙱 𝙲 𝙳 𝙴 𝙵 𝙶 𝙷 𝙸 𝙹 𝙺 𝙻 𝙼 𝙽 𝙾 𝙿 𝚀 𝚁 𝚂 𝚃 𝚄 𝚅 𝚆 𝚇 𝚈 𝚉
𝚊 𝚋 𝚌 𝚍 𝚎 𝚏 𝚐 𝚑 𝚒 𝚓 𝚔 𝚕 𝚖 𝚗 𝚘 𝚙 𝚚 𝚛 𝚜 𝚝 𝚞 𝚟 𝚠 𝚡 𝚢 𝚣
𝟶 𝟷 𝟸 𝟹 𝟺 𝟻 𝟼 𝟽 𝟾 𝟿
```

### 8.2 Bold sans-serif (mathematical)

```
𝐀 𝐁 𝐂 𝐃 𝐄 𝐅 𝐆 𝐇 𝐈 𝐉 𝐊 𝐋 𝐌 𝐍 𝐎 𝐏 𝐐 𝐑 𝐒 𝐓 𝐔 𝐕 𝐖 𝐗 𝐘 𝐙
𝐚 𝐛 𝐜 𝐝 𝐞 𝐟 𝐠 𝐡 𝐢 𝐣 𝐤 𝐥 𝐦 𝐧 𝐨 𝐩 𝐪 𝐫 𝐬 𝐭 𝐮 𝐯 𝐰 𝐱 𝐲 𝐳
𝟎 𝟏 𝟐 𝟑 𝟒 𝟓 𝟔 𝟕 𝟖 𝟗
```

### 8.3 Reverse-circled block digits

```
❶ ❷ ❸ ❹ ❺ ❻ ❼ ❽ ❾ ⓿
🅛 🅞 🅖 🅘 🅝  🅢 🅣 🅤 🅢
```

---

## Section 9 — Full maquetted examples (copy & paste)

### Example 1 — Advanced control panel with double line and hybrid indicators (L2)

```
╔══════════════════════════════════════════════════════════════════════════╗
║                    SPICETIFY MANAGER - CONTROL PANEL                    ║
╠══════════════════════════════════════════════════════════════════════════╣
║                                                                          ║
║  ⚙️ Entorno del Sistema:                                                 ║
║  ├── Directorio de Spicetify ....... [ C:\Users\Appdata\spicetify ]      ║
║  ├── Estado de Spotify Desktop ...... [ ✔ ONLINE ]                       ║
║  └── Aplicación Automática (Hook) .. [ ⚡ ENABLED ]                      ║
║                                                                          ║
║  📊 Estado de la Instalación Actual:                                     ║
║  ├─ Descargando Componentes Core [████████████████████░░░░░░░░░░] 66%   ║
║  └─ Verificando Integridad ...... [ ⓘ PENDING ]                         ║
║                                                                          ║
╠══════════════════════════════════════════════════════════════════════════╣
║ [1] Aplicar Cambios  [2] Reparar Rutas  [3] Copia de Seguridad  [4] Salir ║
╚══════════════════════════════════════════════════════════════════════════╝
```

### Example 2 — Minimalist log panel with curved corners (L3, default in template)

```
╭──────────────────────────────────────────────────────────────────────────╮
│ 📋 LOG DE SUBSISTEMAS Y DEPURACIÓN                                       │
├──────────────────────────────────────────────────────────────────────────┤
│  🟢 10:04:12 [INFO] Inicializando codificación UTF-8 en host local...    │
│  🟡 10:04:13 [WARN] Detectada versión antigua del reproductor cliente.   │
│  🔴 10:04:15 [FAIL] Error crítico al enlazar socket del Marketplace.     │
│  ──► Reintentando conexión de respaldo en 5 segundos...                  │
╰──────────────────────────────────────────────────────────────────────────╯
```

### Example 3 — Structured tree menu (L2)

```
┌─[ MÓDULOS DEL REPOSITORIO ]
│
├── 📦 Temas Disponibles
│   ├── ──► Dribbblish (Configurado)
│   ├── ──► Sleek
│   └── ──► Ziro
│
├── 🛠️ Extensiones Activas
│   ├── [✔] Adblock_Native.js
│   └── [✖] Shuffle_Plus.js (Desactivado)
│
└─ Código de Salida del Proceso: 0x000 (Exitoso)
```

---

## Section 10 — How to extend the template

### 10.1 Rebrand the banner

Edit the `$bannerLines` array inside `Write-Banner` (function #10 in
`Ejemplo_De_Formato.ps1`). Keep each line roughly the same width so the
layout stays balanced. Use the glyphs from `ABECEDARIO_ASCII.txt` to draw
your title.

### 10.2 Re-skin the box style

Edit the `$Script:Box` table at the top of section 4 in the template. Swap
the curved-corner glyphs for any of the alternatives in Section 3 of this
document. All rendering functions read from this table, so the change
propagates everywhere automatically.

### 10.3 Re-palette the colors

Edit the `$Script:Palette` table. Every helper reads from this table, so
changing one entry (e.g. `Muted = 'DarkCyan'`) updates the entire UI.

### 10.4 Add a new status helper

Follow the convention: indent 2 spaces, use a 3-char bracket marker, and
read the color from `$Script:Palette`. Example:

```powershell
function Write-Question {
    [CmdletBinding()] param([Parameter(Mandatory)][string]$Text)
    Write-Host ("  [?] $Text") -ForegroundColor $Script:Palette.Warning
}
```

### 10.5 Add a new progress-bar style

Extend the `switch ($Style)` block inside `Write-ProgressBar`. Pick glyphs
from Section 2 of this document, respecting the compatibility level of your
target terminal.

### 10.6 Add a new spinner style

Extend the `switch ($Style)` block inside `New-Spinner`. Use frame arrays
from Section 2.5. Keep frame counts between 4 and 12 for smooth animation
at 80–120 ms per frame.

---

## Section 11 — AI agent quick-start checklist

When an AI agent is asked to build or extend a TUI script in this house style,
it should:

1. **Read** this document and `ABECEDARIO_ASCII.txt` to learn the vocabulary.
2. **Import** `Ejemplo_De_Formato.ps1` (dot-source it) to inherit all helpers.
3. **Pick** a compatibility level (default L2) and stay within it.
4. **Compute** padding using the master column-width rule from the
   "How to read this document" section.
5. **Use** the existing helpers (`Write-BoxTop`, `Write-BoxLine`,
   `Write-BoxSeparator`, `Write-BoxSubtitle`, `Write-BoxKeyValue`,
   `Write-BoxBottom`, `Write-ProgressBar`, `New-Spinner`, `Read-MenuSelection`)
   instead of inventing new ones whenever possible.
6. **Rebrand** by editing the three tables (`$Script:Palette`, `$Script:Box`,
   `$bannerLines`), not by patching rendering functions.
7. **Persist** user-tunable state via `Import-Settings` / `Export-Settings`
   rather than inventing a new config format.
8. **Validate** every new glyph against the compatibility matrix in Section 1
   before shipping.

---

_End of encyclopedia._
