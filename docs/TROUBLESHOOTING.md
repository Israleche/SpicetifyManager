# Troubleshooting Guide

This guide covers the most common issues you may encounter when using Spicetify Manager, along with step-by-step fixes.

---

## Table of Contents

1. [Black Window When Opening Spotify](#black-window-when-opening-spotify)
2. [No Backup Available](#no-backup-available)
3. [Microsoft Store Spotify Detected](#microsoft-store-spotify-detected)
4. [Spicetify Not Found / Not on PATH](#spicetify-not-found--not-on-path)
5. [Spotify Update Broke My Theme](#spotify-update-broke-my-theme)
6. [Extensions Not Loading](#extensions-not-loading)
7. [Prefs File Not Found](#prefs-file-not-found)
8. [PowerShell Execution Policy Errors](#powershell-execution-policy-errors)
9. [Unicode / Character Display Issues](#unicode--character-display-issues)

---

## Black Window When Opening Spotify

**Symptoms:** Spotify opens to a completely black window with no UI. This is the most common issue new users encounter.

**Cause:** You ran the manager (or Spotify) as Administrator. Spicetify patches are designed for user-level processes. When Spotify runs elevated, it loads a different profile and the patches fail silently, resulting in a black window.

**Fix:**

1. Close Spotify completely (check the system tray).
2. Re-run `Spicetify-Manager.bat` **as a normal user** — do NOT right-click → "Run as administrator".
3. If you previously applied patches while running as admin, you need to do a full restore:
   - Open the manager normally
   - Choose option **2** (Full Restore & Repair)
   - Wait for the process to complete

**Prevention:** Never run the manager or Spotify as Administrator. The manager will warn you and refuse to continue if it detects admin privileges.

---

## No Backup Available

**Symptoms:** When running `spicetify backup` or `spicetify auto`, you see the error message: `no backup available` or `error: backup is not available`.

**Cause:** Spicetify needs to read Spotify's original files to create a backup. If Spotify has never been opened (or was never fully initialized), the required `prefs` file does not exist yet.

**Fix:**

1. Open Spotify Desktop manually.
2. Log in to your account and wait for the UI to fully load.
3. Play a song for a few seconds (this ensures the prefs file is written).
4. Close Spotify completely (check the system tray).
5. Re-run the manager and choose option **1** (Auto) or **3** (Quick Repair).

**Prevention:** Always open Spotify at least once after a fresh install before using Spicetify.

---

## Microsoft Store Spotify Detected

**Symptoms:** The manager shows a warning: `Microsoft Store Spotify detected! Use option 9.`

**Cause:** The Microsoft Store version of Spotify is sandboxed and cannot be patched by Spicetify. You need the standard Desktop version downloaded from Spotify's website.

**Fix:**

1. Choose option **9** in the main menu (Install / fix desktop Spotify).
2. The manager will:
   - Remove the Store version alias
   - Uninstall the Microsoft Store package
   - Download and install the Desktop version from Spotify's servers
   - Open it once to initialize the prefs file
3. After installation completes, run option **1** (Auto) to apply Spicetify.

**Prevention:** Always download Spotify from [spotify.com/download](https://www.spotify.com/download/windows/), not from the Microsoft Store.

---

## Spicetify Not Found / Not on PATH

**Symptoms:** The manager warns that Spicetify is not installed, even though you previously installed it.

**Cause:** Spicetify was installed for a different user account, or the PATH environment variable was not refreshed after installation.

**Fix:**

1. If the manager offers to install Spicetify, choose **Yes**.
2. If you just installed Spicetify in a different terminal, close and re-open the manager — the PATH is refreshed at startup.
3. To manually verify, open a new PowerShell window and run:
   ```powershell
   spicetify -v
   ```
   If this fails, Spicetify is not on your PATH.

**Manual install:**
```powershell
irm https://raw.githubusercontent.com/spicetify/cli/main/install.ps1 | iex
```

After installation, close and re-open the manager.

---

## Spotify Update Broke My Theme

**Symptoms:** After Spotify updates itself, themes disappear, the UI reverts to default, or things look broken.

**Cause:** Spotify updates overwrite the patched files. You need to re-apply Spicetify after every Spotify update.

**Fix:**

1. Open the manager.
2. Choose option **3** (Quick Repair) for a fast `backup apply`.
3. If that doesn't work, choose option **2** (Full Restore & Repair) which does a complete `restore backup` → `backup` → `apply` cycle.

**Tip:** Run option **3** every time Spotify updates. It only takes a few seconds.

---

## Extensions Not Loading

**Symptoms:** You enabled an extension but it doesn't appear in Spotify.

**Cause:** Extensions require a fresh apply to take effect. Simply enabling them doesn't activate them immediately.

**Fix:**

1. Enable the extension through option **4** (Themes/Extensions/Apps).
2. Run option **1** (Auto) to apply the changes.
3. If the extension still doesn't load, try a full restore with option **2**.

**Check installed extensions:**
- Go to option **4** → **3** (List extensions) to see what's currently configured.

---

## Prefs File Not Found

**Symptoms:** Spicetify can't find the Spotify prefs file. You may see errors about `prefs_path`.

**Cause:** Spotify hasn't been opened yet, or it's installed in a non-standard location.

**Fix:**

1. Open Spotify, log in, and close it.
2. If the issue persists, try option **A** (Advanced) → **5** (Repair Spicetify Paths).
3. The path repair function scans common install locations and updates Spicetify's config automatically.

**Manual check:**
- Look for the prefs file at: `%APPDATA%\Spotify\prefs` or `%LOCALAPPDATA%\Spotify\prefs`

---

## PowerShell Execution Policy Errors

**Symptoms:** You see an error like `execution of scripts is disabled on this system` when trying to run the .ps1 file directly.

**Cause:** Windows defaults to a restricted PowerShell execution policy that prevents running scripts.

**Fix:**

Always use the **`Spicetify-Manager.bat`** launcher — it automatically sets `-ExecutionPolicy Bypass` for the session.

If you prefer to run the .ps1 directly:
```powershell
powershell -ExecutionPolicy Bypass -File .\Spicetify_Manager.ps1
```

Do NOT change your system-wide execution policy unless you understand the security implications.

---

## Unicode / Character Display Issues

**Symptoms:** The ASCII art banner looks garbled, or box-drawing characters appear as question marks or squares.

**Cause:** The terminal is not using a UTF-8 code page or the font doesn't support Unicode block characters.

**Fix:**

1. Make sure you're using **Windows Terminal** (recommended) or **PowerShell 7+** — both have excellent Unicode support.
2. If using legacy cmd.exe, the .bat file sets `chcp 65001` automatically, but some fonts still won't render the block characters correctly.
3. In Windows Terminal, go to Settings → Appearance and ensure the font supports Unicode (Cascadia Code, Cascadia Mono, or Consolas are good choices).

---

## Still Having Issues?

If your problem isn't listed here, try these general steps:

1. **Full Restore** — Option **2** fixes most issues by doing a clean restore and re-apply.
2. **Repair Paths** — Option **A** → **5** fixes config path mismatches.
3. **Reinstall Spicetify** — Option **6** upgrades to the latest version.
4. **Check Status** — Option **8** shows your current Spicetify version, Spotify state, and detected paths.

For Spicetify-specific issues, consult the [Spicetify CLI documentation](https://github.com/spicetify/cli) and the [Spicetify Wiki](https://spicetify.app/docs).
