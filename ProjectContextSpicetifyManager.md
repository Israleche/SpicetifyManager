# ProjectContextSpicetifyManager.md

> **Contexto completo del proyecto Spicetify Manager** — Documento de referencia para entender la estructura, tecnologías, funcionamiento interno y uso del proyecto.

---

## 📋 Descripción del Proyecto

**Spicetify Manager** es un panel de control en **PowerShell** para gestionar **Spicetify CLI** y **Spotify Desktop** en Windows. Es un wrapper interactivo que simplifica las operaciones comunes de Spicetify (temas, extensiones, Marketplace, reparaciones, actualizaciones) mediante un menú visual en consola.

**Propósito:** Eliminar la complejidad de línea de comandos de Spicetify CLI y automatizar flujos comunes (backup, apply, restore, reparación de paths, instalación de Spotify Desktop vs Store).

**Público objetivo:** Usuarios de Windows que quieren personalizar Spotify Desktop con temas/extensiones sin lidiar con la CLI directamente.

---

## ✨ Características Principales

| Categoría | Funcionalidad |
|-----------|---------------|
| **Operaciones Core** | `spicetify auto` (backup + apply + launch), Full Restore (restore backup → backup → apply), Quick Repair (backup apply) |
| **Temas/Extensiones** | Listar temas instalados, aplicar tema por nombre, listar/habilitar extensiones, listar custom apps |
| **Marketplace** | Instalar/reparar Spicetify Marketplace (navegador visual de temas/extensiones dentro de Spotify) |
| **Spotify Desktop** | Detectar Store vs Desktop, desinstalar Store, instalar Desktop oficial, inicializar prefs |
| **Mantenimiento** | Upgrade Spicetify CLI, reparar paths (`spotify_path`, `prefs_path`), abrir carpeta de config |
| **Diagnóstico** | Status completo (versión Spicetify, estado Spotify, paths detectados, prefs) |
| **Configuración** | Toggle por sesión: mostrar progreso CLI, auto-fix Spotify, auto-open Spotify |
| **Ayuda integrada** | Menú contextual: qué es Spicetify, cómo funciona el manager, guía primer uso, problemas comunes, explicación menús |

---

## 🛠 Stack Tecnológico

| Componente | Tecnología | Versión/Detalles |
|------------|------------|------------------|
| **Lenguaje principal** | PowerShell | 5.1+ (incluido en Windows 10/11) |
| **Launcher** | Batch (`.bat`) | Wrapper para `-ExecutionPolicy Bypass` y `chcp 65001` |
| **Core CLI wrappado** | [Spicetify CLI](https://github.com/spicetify/cli) | Go binary, instalado via `install.ps1` oficial |
| **Marketplace** | [Spicetify Marketplace](https://github.com/spicetify/marketplace) | Instalador oficial PS1 |
| **Spotify Desktop** | Instalador oficial | `https://download.scdn.co/SpotifySetup.exe` |
| **Detección Store** | `Get-AppxPackage` | Paquete `SpotifyAB.SpotifyMusic` |
| **Encoding** | UTF-8 (codepage 65001) | Forzado en `.bat` y script PS1 |
| **Persistencia** | **Ninguna** (stateless) | Settings solo en memoria, se resetean al cerrar |

### Dependencias Externas (se instalan automáticamente)
- **Spicetify CLI** → `https://raw.githubusercontent.com/spicetify/cli/main/install.ps1`
- **Spicetify Marketplace** → `https://raw.githubusercontent.com/spicetify/marketplace/main/resources/install.ps1`
- **Spotify Desktop** → `https://download.scdn.co/SpotifySetup.exe`

---

## 📦 Guía de Instalación Paso a Paso

### Prerrequisitos
- **Windows 10/11**
- **PowerShell 5.1+** (incluido en Windows)
- **Spotify Desktop** (NO Microsoft Store — el manager ayuda a cambiar)
- **NO ejecutar como Administrador** (Spicetify lo rechaza y Spotify muestra ventana negra)

### Instalación Rápida
```bash
git clone https://github.com/Isralechee/SpicetifyManager.git
cd SpicetifyManager
```

### Ejecución
**Opción A — Doble clic (recomendado):**
```
Spicetify-Manager.bat
```
> El `.bat` configura `chcp 65001` (UTF-8) y ejecuta con `-ExecutionPolicy Bypass`.

**Opción B — PowerShell directo:**
```powershell
powershell -ExecutionPolicy Bypass -File .\Spicetify_Manager.ps1
```

**Opción C — Con parámetros de arranque:**
```powershell
.\Spicetify_Manager.ps1 -ShowProgress 0 -AutoFix 0 -AutoOpen 1
```

| Parámetro | Valores | Efecto |
|-----------|---------|--------|
| `-ShowProgress` | `0` / `1` | Ocultar/mostrar output de comandos Spicetify |
| `-AutoFix` | `0` / `1` | Desactivar/activar auto-reparación de Spotify al inicio |
| `-AutoOpen` | `0` / `1` | Desactivar/activar auto-abrir Spotify tras apply/restore |

---

## 📁 Estructura de Carpetas Explicada

```
SpicetifyManager/
├── .github/
│   ├── FUNDING.yml              # Configuración de patrocinio (GitHub Sponsors)
│   └── ISSUE_TEMPLATE/
│       ├── bug_report.md        # Plantilla reporte de bugs
│       ├── feature_request.md   # Plantilla solicitud features
│       └── custom.md            # Plantilla personalizada
├── docs/
│   └── TROUBLESHOOTING.md       # Guía detallada de problemas comunes y soluciones
├── .gitignore                   # Ignora: Thumbs.db, .vscode/, *.ps1.bak, *.zip, etc.
├── README.md                    # Documentación principal (features, usage, troubleshooting)
├── Spicetify_Manager.ps1        # Script principal PowerShell (~600 líneas)
├── Spicetify-Manager.bat        # Launcher batch (UTF-8, bypass execution policy)
└── ProjectContextSpicetifyManager.md  # ← ESTE ARCHIVO
```

### Archivos Clave

| Archivo | Rol | Líneas aprox. |
|---------|-----|---------------|
| `Spicetify_Manager.ps1` | Lógica completa: menús, detección, invocación Spicetify, reparaciones, instalación | ~600 |
| `Spicetify-Manager.bat` | Entry point amigable: encoding UTF-8, execution policy bypass, error handling | ~30 |
| `README.md` | Documentación usuario final: features, quick start, menu reference, troubleshooting | ~200 |
| `docs/TROUBLESHOOTING.md` | Guía profunda: ventana negra, no backup, Store detectado, Unicode, pasos generales | ~150 |

---

## ⚙️ Variables de Entorno / Configuración

### Variables de Entorno Usadas (Lectura)
| Variable | Uso |
|----------|-----|
| `$env:APPDATA` | Ruta base config Spicetify (`%APPDATA%\spicetify`), Spotify (`%APPDATA%\Spotify`) |
| `$env:LOCALAPPDATA` | Spotify alternativo (`%LOCALAPPDATA%\Spotify`, `%LOCALAPPDATA%\Programs\Spotify`) |
| `$env:ProgramFiles` / `${env:ProgramFiles(x86)}` | Spotify instalado system-wide |
| `$env:TEMP` | Descarga temporal `SpotifySetup.exe` |
| `$env:PATH` | Actualizado dinámicamente tras instalar Spicetify |

### Configuración Interna (Script-scoped, **NO persistente**)
```powershell
$Script:ShowCommandProgress = $true   # Mostrar output CLI spicetify
$Script:AutoFixSpotify      = $true   # Auto-reparar Spotify al inicio
$Script:AutoOpenSpotify     = $true   # Abrir Spotify tras apply/restore
```
> **Importante:** Son *session-only*. Se reinician a defaults al cerrar el manager. Sobrescribibles vía parámetros de línea de comandos.

### URLs de Instalación (Constantes)
```powershell
$Script:SpicetifyInstallUrl   = 'https://raw.githubusercontent.com/spicetify/cli/main/install.ps1'
$Script:MarketplaceInstallUrl = 'https://raw.githubusercontent.com/spicetify/marketplace/main/resources/install.ps1'
$Script:SpotifyInstallerUrl   = 'https://download.scdn.co/SpotifySetup.exe'
```

---

## 🎮 Comandos de Uso / Flujo de Trabajo

### Menú Principal
```
[1] Auto (spicetify auto: backup/apply/launch)
[2] Full restore & repair (restore backup → backup → apply)
[3] Quick repair (backup apply)
[4] Manage themes / extensions / apps
[5] Install / repair Marketplace
[6] Upgrade Spicetify CLI
[7] Open Spicetify config folder
[8] View status & info
[9] Install / fix desktop Spotify
[S] Settings
[A] Advanced options
[H] Help & documentation
[0] Exit
```

### Submenús Principales

#### [4] Themes / Extensions / Apps
```
[1] List installed themes          → spicetify config current_theme
[2] Apply theme by name            → spicetify config current_theme <name>
[3] List extensions                → spicetify config extensions
[4] Enable extension               → spicetify extension <name>
[5] List custom apps               → spicetify config custom_apps
[6] Install Marketplace            → (instalador oficial)
[0] Back
```

#### [A] Advanced Options
```
[1] spicetify restore backup
[2] spicetify backup
[3] spicetify apply
[4] Open Spicetify config folder   → Invoke-Item en carpeta config
[5] Repair Spicetify paths         → Fix spotify_path + prefs_path
[0] Back
```

#### [S] Settings (Toggle por sesión)
```
[1] Toggle command output    (ShowCommandProgress)
[2] Toggle auto-fix Spotify  (AutoFixSpotify)
[3] Toggle auto-open Spotify (AutoOpenSpotify)
[0] Back
```

#### [H] Help Topics
```
[1] What is Spicetify?
[2] How this manager works
[3] First-time install guide
[4] Common problems & fixes
[5] Menu options explained
```

---

## 🔧 Funcionamiento Interno (Arquitectura)

### 1. Detección de Entorno (Startup)
```powershell
# Orden de prioridad para Spotify.exe
$candidates = @(
  "$env:APPDATA\Spotify\Spotify.exe",
  "$env:LOCALAPPDATA\Spotify\Spotify.exe",
  "$env:LOCALAPPDATA\Programs\Spotify\Spotify.exe",
  "$env:ProgramFiles\Spotify\Spotify.exe",
  "${env:ProgramFiles(x86)}\Spotify\Spotify.exe"
)

# Detección Store vs Desktop
Test-SpotifyDesktopInstalled  → Get-SpotifyExeCandidates | Select -First 1
Test-SpotifyStoreInstalled    → Get-AppxPackage 'SpotifyAB.SpotifyMusic' + alias WindowsApps
```

### 2. Auto-Fix al Inicio (si `$Script:AutoFixSpotify`)
- Si **Store detectado** + **NO Desktop** → Ofrece opción [9] para cambiar
- Si **Desktop detectado** → `Repair-SpicetifyPaths()` (fixea `spotify_path` y `prefs_path` en config Spicetify)
- Si **NO prefs** → Avisa: "Open Spotify once, log in, close, then re-run"

### 3. Invocación Spicetify (`Invoke-Spicetify`)
```powershell
function Invoke-Spicetify {
  param([string[]]$Args, [switch]$AllowFailure, [switch]$Quiet)
  $cmd = "spicetify $($Args -join ' ')"
  if ($ShowCommandProgress -and -not $Quiet) { Write-Host "  > $cmd" -Fore DarkGray }
  try {
    $out = & spicetify @Args 2>&1 | Out-String
    if ($ShowCommandProgress -and -not $Quiet -and $out.Trim()) { Write-Host $out -Fore DarkGray }
    return @{ Success = $true; Output = $out }
  } catch {
    if ($AllowFailure) { return @{ Success = $false; Output = $_.Exception.Message } }
    throw
  }
}
```

### 4. Operaciones Core
| Operación | Secuencia Spicetify | Manejo Spotify |
|-----------|---------------------|----------------|
| **Auto** | `spicetify auto` | Stop → Auto → Start |
| **Quick Repair** | `spicetify backup apply` | Stop → Backup Apply → Start |
| **Full Restore** | `restore backup` → `backup` → `apply` | Stop → 3 pasos → Start |
| **Upgrade** | Re-ejecutar `install.ps1` oficial | Refresh PATH |

### 5. Reparación de Paths (`Repair-SpicetifyPaths`)
```powershell
$exe   = Get-SpotifyExeCandidates | Select -First 1
$prefs = Get-SpotifyPrefsCandidates | Select -First 1
spicetify config spotify_path $exe
spicetify config prefs_path $prefs
```

### 6. Instalación Spotify Desktop (`Install-SpotifyDesktop`)
1. Elimina alias Store (`%LOCALAPPDATA%\Microsoft\WindowsApps\Spotify.exe`)
2. Desinstala paquete AppX `SpotifyAB.SpotifyMusic`
3. Descarga `SpotifySetup.exe` a `$env:TEMP`
4. Ejecuta instalador con `-Wait`
5. Espera hasta detectar `Spotify.exe` (max 60s)
6. Si no hay `prefs` → abre Spotify una vez para generarlos

---

## 🐛 Troubleshooting Rápido (Referencia)

| Problema | Causa | Solución Rápida |
|----------|-------|-----------------|
| Ventana negra Spotify | Ejecutado como Admin | Re-ejecutar **SIN** Admin |
| "No backup available" | Spotify nunca abierto/cerrado | Abrir Spotify → Log in → Cerrar → Opción [2] |
| Detecta Store Spotify | Instalado desde Microsoft Store | Opción [9] Install/fix Desktop |
| Spicetify no encontrado | No instalado o PATH no actualizado | Opción [6] Upgrade / reiniciar terminal |
| Spotify update rompió temas | Spotify actualizado, patches inválidos | Opción [3] Quick Repair o [2] Full Restore |
| Caracteres raros en banner | Terminal sin UTF-8 / fuente sin Unicode | Usar **Windows Terminal** + Cascadia Code |

> Ver `docs/TROUBLESHOOTING.md` para guía completa con Unicode, ejecución policy, etc.

---

## 🔗 Referencias Externas Clave

| Recurso | URL |
|---------|-----|
| Spicetify CLI (core) | https://github.com/spicetify/cli |
| Spicetify CLI Install Script | https://raw.githubusercontent.com/spicetify/cli/main/install.ps1 |
| Spicetify Marketplace | https://github.com/spicetify/marketplace |
| Marketplace Install Script | https://raw.githubusercontent.com/spicetify/marketplace/main/resources/install.ps1 |
| Spotify Desktop Installer | https://download.scdn.co/SpotifySetup.exe |
| Spicetify Docs | https://spicetify.app/docs |
| PowerShell 5.1 Docs | https://learn.microsoft.com/powershell/scripting/overview |

---

## 📝 Notas para Desarrollo Futuro

### Patrones del Código
- **Funciones prefijadas:** `Write-*`, `Test-*`, `Get-*`, `Invoke-*`, `Show-*`, `Install-*`, `Repair-*`, `Stop-*`, `Start-*`
- **Variables globales:** `$Script:` scope para settings y paleta de colores
- **Error handling:** `try/catch` + `Write-Err`/`Write-Warn` + `AllowFailure` switch en `Invoke-Spicetify`
- **UI:** Box-drawing chars (UTF-8), colores por paleta, `Write-Host` directo (no pipeline)
- **Stateless:** Cero archivos de config escritos; settings solo en memoria

### Puntos de Extensión Naturales
1. **Nuevo submenú** → Añadir `Show-NuevoMenu` + case en `MainMenu`
2. **Nueva operación Spicetify** → Wrapper en `Invoke-Spicetify` + función `Invoke-NuevaOperacion`
3. **Persistencia de settings** → Serializar `$Script:*` a JSON en `$env:APPDATA\SpicetifyManager\settings.json`
4. **Logging** → Añadir `-LogPath` param + `Add-Content` en `Invoke-Spicetify`
5. **Tests** → Pester tests para `Test-Spotify*`, `Get-*Candidates`, `Repair-SpicetifyPaths`

### Limitaciones Conocidas
- Solo Windows (PowerShell 5.1+, rutas Windows, `Get-AppxPackage`, `Start-Process -Wait`)
- No maneja múltiples usuarios simultáneos (usa `$env:APPDATA` del usuario actual)
- No valida firma digital de instaladores descargados (confía en URLs oficiales)
- Encoding UTF-8 forzado; puede fallar en `cmd.exe` legacy sin fuente Unicode

---

## 📄 Licencia
**MIT** — Ver cabecera de `Spicetify_Manager.ps1` (`.SYNOPSIS`, `.NOTES`).

---

## 👤 Autor
**Israleche** — [GitHub](https://github.com/Isralechee)

---

> **Última actualización:** 2026-07-01  
> **Versión del proyecto:** Basado en commit actual de `main`  
> **Para:** Contexto de trabajo futuro — este documento resume todo lo necesario para entender, mantener y extender Spicetify Manager.