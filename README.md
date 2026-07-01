<p align="center">
  <img src="https://readme-typing-svg.demolab.com?font=Fira+Code&weight=600&size=28&duration=3000&pause=1000&color=FF0000&center=true&vCenter=true&width=500&lines=SPICETIFY+MANAGER" alt="Spicetify Manager" />
</p>

<p align="center">
  <strong>A PowerShell control panel for Spicetify + Spotify Desktop.</strong>
</p>

---

## Features

| Feature | Description |
|---|---|
| **Auto Apply** | One-command `spicetify auto` — backup, apply, and launch Spotify |
| **Full Restore** | Restore, backup, and re-apply in a single guided flow |
| **Quick Repair** | Fast `backup apply` when things break after a Spotify update |
| **Theme Manager** | List, apply, and switch themes by name |
| **Extensions** | Enable and manage Spicetify extensions |
| **Marketplace** | Install or repair the Spicetify Marketplace |
| **Spotify Desktop** | Detect Store vs Desktop, auto-install the correct version |
| **Path Repair** | Automatically fix `spotify_path` and `prefs_path` in spicetify config |
| **Upgrade** | One-click Spicetify CLI upgrade |

---

## Quick Start

### Prerequisites

- **Windows 10/11**
- **PowerShell 5.1+** (included with Windows)
- **Spotify Desktop** (not the Microsoft Store version — the manager will help you switch)
- **Do NOT run as Administrator** — Spicetify refuses admin and Spotify shows a black window

### Install & Run

1. Download the latest release or clone this repository:
   ```bash
   git clone https://github.com/YOUR_USERNAME/Spicetify-Manager.git
   cd Spicetify-Manager
   ```

2. Double-click **`Spicetify-Manager.bat`**

   That's it. The batch file handles execution policy and encoding automatically.

### Alternative: Run directly in PowerShell

```powershell
powershell -ExecutionPolicy Bypass -File .\Spicetify_Manager.ps1
```

---

## Usage

When you launch the manager, you'll see the main menu:

```
  ==================================================================

   ███████╗██████╗ ██╗ ██████╗███████╗████████╗██╗███████╗██╗   ██╗
   ██╔════╝██╔══██╗██║██╔════╝██╔════╝╚══██╔══╝██║██╔════╝╚██╗ ██╔╝
   ███████╗██████╔╝██║██║     █████╗     ██║   ██║█████╗   ╚████╔╝
   ╚════██║██╔═══╝ ██║██║     ██╔══╝     ██║   ██║██╔══╝    ╚██╔╝
   ███████║██║     ██║╚██████╗███████╗   ██║   ██║██║        ██║
   ╚══════╝╚═╝     ╚═╝ ╚═════╝╚══════╝   ╚═╝   ╚═╝╚═╝        ╚═╝

                               MANAGER

  ==================================================================
  progress:ON  autofix:ON  autoopen:ON
  ==================================================================

  +--------------------------------------------------------------+
  |                         MAIN MENU                             |
  +--------------------------------------------------------------+
  | [1] Auto (spicetify auto: backup/apply/launch)               |
  | [2] Full restore & repair (restore + backup + apply)         |
  | [3] Quick repair (backup apply)                              |
  | [4] Manage themes / extensions / apps                        |
  | [5] Install / repair Marketplace                             |
  | [6] Upgrade Spicetify CLI                                    |
  | [7] Open Spicetify config folder                             |
  | [8] View status & info                                       |
  | [9] Install / fix desktop Spotify                            |
  | [S] Settings                                                 |
  | [A] Advanced options                                         |
  | [H] Help & documentation                                     |
  | [0] Exit                                                     |
  +--------------------------------------------------------------+
```

### Menu Options

| Key | Action |
|-----|--------|
| `1` | **Auto** — Runs `spicetify auto` (backup + apply + open Spotify) |
| `2` | **Full Restore** — `restore backup` → `backup` → `apply` (fixes broken patches) |
| `3` | **Quick Repair** — `backup apply` (fast fix after Spotify update) |
| `4` | **Themes/Extensions/Apps** — Sub-menu for themes, extensions, custom apps, Marketplace |
| `5` | **Marketplace** — Install or repair Spicetify Marketplace |
| `6` | **Upgrade** — Update Spicetify CLI to the latest version |
| `7` | **Config Folder** — Open Spicetify's config directory in Explorer |
| `8` | **Status** — Show Spicetify version, Spotify state, and detected paths |
| `9` | **Spotify Desktop** — Remove Store version, install Desktop version |
| `S` | **Settings** — Toggle progress output, auto-fix, auto-open |
| `A` | **Advanced** — Direct spicetify commands, path repair |
| `H` | **Help** — Documentation, troubleshooting, first-time guide |
| `0` | **Exit** |

---

## Settings

Settings are **per-session** — they reset when you close the manager. This keeps things simple and stateless.

| Setting | Default | Description |
|---------|---------|-------------|
| `ShowCommandProgress` | ON | Display spicetify CLI output as commands run |
| `AutoFixSpotify` | ON | Automatically detect and fix Spotify issues at startup |
| `AutoOpenSpotify` | ON | Open Spotify after apply/restore operations |

### Override via command line

```powershell
.\Spicetify_Manager.ps1 -ShowProgress 0 -AutoFix 0 -AutoOpen 1
```

| Parameter | Values | Effect |
|-----------|--------|--------|
| `-ShowProgress` | `0` or `1` | Hide/show CLI output |
| `-AutoFix` | `0` or `1` | Disable/enable Spotify auto-fix |
| `-AutoOpen` | `0` or `1` | Disable/enable auto-open Spotify |

---

## Troubleshooting

See [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md) for common issues and fixes.

**Quick fixes:**

| Problem | Fix |
|---------|-----|
| Black Spotify window | You ran as Administrator. Re-run as normal user. |
| "No backup available" | Open Spotify once, log in, close it, then run option 2. |
| Store Spotify detected | Use option 9 to switch to Desktop version. |
| Spicetify not found | The manager will offer to install it automatically. |
| Spotify update broke themes | Run option 3 (Quick Repair) or option 2 (Full Restore). |

---

## How It Works

Spicetify Manager is a PowerShell wrapper around the [Spicetify CLI](https://github.com/spicetify/cli). It:

1. Detects your Spotify installation type (Desktop vs Microsoft Store)
2. Verifies Spicetify is installed (offers to install if missing)
3. Presents a menu-driven interface for common Spicetify operations
4. Handles the Spotify process (close before patching, reopen after)
5. Auto-repairs config paths when Spotify's location changes

The script is **stateless** — no config files are written to disk. Every session starts fresh with sensible defaults.

---

## Project Structure

```
Spicetify-Manager/
├── .github/
│   └── FUNDING.yml           # Sponsorship info
├── docs/
│   └── TROUBLESHOOTING.md    # Detailed troubleshooting guide
├── .gitignore                # Git ignore rules
├── README.md                 # This file
├── Spicify_Manager.ps1       # Main PowerShell script
└── Spicetify-Manager.bat     # Double-click launcher
```

---

## Requirements

- Windows 10 or later
- PowerShell 5.1+ (pre-installed on Windows 10/11)
- [Spotify Desktop](https://www.spotify.com/download/windows/) (not the Microsoft Store version)
- Internet connection (for installing Spicetify, Marketplace, or Spotify)

---

## Acknowledgments

- [Spicetify CLI](https://github.com/spicetify/cli) — The core tool this manager wraps
- [Spicetify Marketplace](https://github.com/spicetify/marketplace) — Theme and extension browser
- [Spotify](https://www.spotify.com/) — Music streaming platform

---
