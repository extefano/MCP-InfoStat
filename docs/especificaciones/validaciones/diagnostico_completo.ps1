# diagnostico_completo.ps1
# MCP-InfoStat — Diagnóstico Automático de Entorno
# Uso: .\diagnostico_completo.ps1 | Tee-Object -FilePath diagnostico_log.txt
# Ejecutar desde la raiz del repositorio MCP-Infostat como Administrador si es posible.

Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
$ErrorActionPreference = "Continue"
$venvPython = ".\.venv\Scripts\python.exe"
$infostatExe = "C:\Program Files (x86)\InfoStat\InfoStat.exe"

Write-Output "============================================="
Write-Output "MCP-InfoStat -- Diagnostico Automatico"
Write-Output "Inicio: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
Write-Output "============================================="
Write-Output ""

# -------------------------------------------------------
# SECCION 1 — Entorno Python
# -------------------------------------------------------
Write-Output "[SECCION 1] Entorno Python"
Write-Output "---"

if (Test-Path $venvPython) {
    Write-Output "S1.1 PASS: venv encontrado en $venvPython"
} else {
    Write-Output "S1.1 FAIL: venv no encontrado"
    Write-Output "  ACCION: python -m venv .venv && .\.venv\Scripts\pip install -e .[dev]"
}

$pyVer = & $venvPython --version 2>&1
Write-Output "S1.2 $pyVer"

$depCheck = & $venvPython -c "import mcp; import tomllib; print('ok')" 2>&1
if ($depCheck -match "ok") { Write-Output "S1.3 PASS: dependencias core ok" }
else { Write-Output "S1.3 FAIL: $depCheck" }

$importCheck = & $venvPython -c "import server; print('ok')" 2>&1
if ($importCheck -match "ok") { Write-Output "S1.4 PASS: server.py importa sin errores" }
else { Write-Output "S1.4 FAIL: $importCheck" }

Write-Output "S1.5 Suite de tests:"
$testsResult = & ".\.venv\Scripts\pytest.exe" tests/ -v --tb=short 2>&1
$testsResult | ForEach-Object { Write-Output "  $_" }

Write-Output ""

# -------------------------------------------------------
# SECCION 2 — InfoStat instalado
# -------------------------------------------------------
Write-Output "[SECCION 2] InfoStat instalado"
Write-Output "---"

if (Test-Path $infostatExe) {
    $fi = Get-Item $infostatExe
    Write-Output "S2.1 PASS: InfoStat.exe encontrado"
    Write-Output "  Tamanio: $($fi.Length) bytes"
    Write-Output "  Modificado: $($fi.LastWriteTime)"
} else {
    Write-Output "S2.1 FAIL: InfoStat.exe no encontrado en ruta por defecto"
    $alt = Get-ChildItem "C:\Program Files (x86)\" -Filter "InfoStat.exe" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($alt) {
        Write-Output "  WARN: Encontrado en ruta alternativa: $($alt.FullName)"
        Write-Output "  ACCION: Actualizar exe_path en config.toml"
    } else {
        Write-Output "  InfoStat no encontrado en ninguna ruta. Solo Bloque C disponible."
    }
}

Write-Output "S2.2 Contenido carpeta InfoStat:"
Get-ChildItem "C:\Program Files (x86)\InfoStat\" -ErrorAction SilentlyContinue |
    Select-Object Name, Length, Extension |
    Format-Table -AutoSize |
    ForEach-Object { Write-Output "  $_" }

Write-Output "S2.3 Archivos INI/CFG de InfoStat:"
@(
    "C:\Program Files (x86)\InfoStat\InfoStat.ini",
    "C:\Program Files (x86)\InfoStat\InfoStat.cfg",
    "$env:APPDATA\InfoStat\InfoStat.ini",
    "$env:LOCALAPPDATA\InfoStat\InfoStat.ini"
) | ForEach-Object {
    if (Test-Path $_) {
        Write-Output "  ENCONTRADO: $_"
        Get-Content $_ -ErrorAction SilentlyContinue | Select-Object -First 20 |
            ForEach-Object { Write-Output "    $_" }
    } else {
        Write-Output "  ausente: $_"
    }
}

Write-Output "S2.4 Archivos de resultados previos de InfoStat:"
@("$env:USERPROFILE\Documents", "$env:USERPROFILE\Desktop", "C:\Program Files (x86)\InfoStat") |
    ForEach-Object {
        $base = $_
        @("*.ist", "*.res", "*.out") | ForEach-Object {
            Get-ChildItem $base -Filter $_ -Recurse -ErrorAction SilentlyContinue |
                Select-Object -First 3 |
                ForEach-Object { Write-Output "  RESULTADO_PREVIO: $($_.FullName) ($($_.Length) bytes)" }
        }
    }

Write-Output ""

# -------------------------------------------------------
# SECCION 3 — Automatizacion UI
# -------------------------------------------------------
Write-Output "[SECCION 3] Automatizacion UI"
Write-Output "---"

# 3.1 pywinauto
$pwiCheck = & $venvPython -c "import pywinauto; print('ok:' + pywinauto.__version__)" 2>&1
if ($pwiCheck -match "ok:") {
    Write-Output "S3.1 PASS: pywinauto disponible ($($pwiCheck -replace 'ok:',''))"
} else {
    Write-Output "S3.1 WARN: pywinauto no instalado. Instalando..."
    & ".\.venv\Scripts\pip.exe" install pywinauto 2>&1 | Select-Object -Last 2 | ForEach-Object { Write-Output "  $_" }
    $pwiCheck2 = & $venvPython -c "import pywinauto; print('ok')" 2>&1
    if ($pwiCheck2 -match "ok") { Write-Output "  PASS: pywinauto instalado correctamente" }
    else { Write-Output "  FAIL: No se pudo instalar pywinauto: $pwiCheck2" }
}

# 3.2 pywin32
$win32Check = & $venvPython -c "import win32api; import win32gui; print('ok')" 2>&1
if ($win32Check -match "ok") {
    Write-Output "S3.2 PASS: pywin32 disponible"
} else {
    Write-Output "S3.2 WARN: pywin32 no instalado. Instalando..."
    & ".\.venv\Scripts\pip.exe" install pywin32 2>&1 | Select-Object -Last 2 | ForEach-Object { Write-Output "  $_" }
}

# 3.3 Lanzamiento
Write-Output "S3.3 Prueba de lanzamiento (espera 5s)..."
$launchPy = @'
import subprocess, time, sys
exe = r'C:\Program Files (x86)\InfoStat\InfoStat.exe'
try:
    p = subprocess.Popen([exe])
    time.sleep(5)
    if p.poll() is None:
        print("PASS:pid=" + str(p.pid))
        p.terminate()
    else:
        print("FAIL:returncode=" + str(p.returncode))
except FileNotFoundError:
    print("FAIL:exe_no_encontrado")
except Exception as e:
    print("FAIL:" + str(e))
'@
$launchResult = $launchPy | & $venvPython - 2>&1
Write-Output "  $launchResult"

# 3.4 Deteccion de ventana
Write-Output "S3.4 Deteccion de ventana pywinauto (espera 8s)..."
$windowPy = @'
import subprocess, time, sys
try:
    from pywinauto import Application
except ImportError:
    print("SKIP:pywinauto_no_disponible")
    sys.exit()
exe = r'C:\Program Files (x86)\InfoStat\InfoStat.exe'
p = subprocess.Popen([exe])
time.sleep(7)
for backend in ["uia", "win32"]:
    try:
        app = Application(backend=backend).connect(process=p.pid, timeout=8)
        wins = app.windows()
        print("PASS:backend=" + backend + ":ventanas=" + str(len(wins)))
        for w in wins:
            print("  VENTANA:titulo=" + repr(w.window_text()) + "|clase=" + repr(w.class_name()))
        p.terminate()
        sys.exit()
    except Exception as e:
        print("WARN:" + backend + ":" + str(e)[:120])
print("FAIL:ningun_backend_conecto")
p.terminate()
'@
$windowResult = $windowPy | & $venvPython - 2>&1
$windowResult | ForEach-Object { Write-Output "  $_" }

# 3.5 Menu
Write-Output "S3.5 Inspeccion de menu principal (espera 8s)..."
$menuPy = @'
import subprocess, time, sys
try:
    from pywinauto import Application
except ImportError:
    print("SKIP:pywinauto_no_disponible")
    sys.exit()
exe = r'C:\Program Files (x86)\InfoStat\InfoStat.exe'
p = subprocess.Popen([exe])
time.sleep(7)
connected = False
for backend in ["uia", "win32"]:
    try:
        app = Application(backend=backend).connect(process=p.pid, timeout=8)
        main_win = app.top_window()
        connected = True
        print("INFO:backend_menu=" + backend)
        menu_hits = []
        descendants = main_win.descendants()
        for d in descendants:
            try:
                cls = d.friendly_class_name()
            except Exception:
                cls = ""
            try:
                txt = d.window_text()
            except Exception:
                txt = ""
            cls_l = cls.lower()
            if cls_l in ["menu", "menuitem"] or "menu" in cls_l:
                menu_hits.append((cls, txt))

        if len(menu_hits) > 0:
            print("PASS:menu_accesible:items=" + str(len(menu_hits)))
            for cls, txt in menu_hits[:30]:
                print("  MENU_ITEM:" + cls + "|" + repr(txt[:60]))
        else:
            print("WARN:menu_no_detectado_en_descendants")
            children = main_win.children()
            print("INFO:hijos_ventana=" + str(len(children)))
            for c in children[:20]:
                print("  HIJO:" + c.friendly_class_name() + "|" + repr(c.window_text()[:40]))
        break
    except Exception as e:
        print("WARN:" + backend + ":" + str(e)[:80])
if not connected:
    print("FAIL:no_se_pudo_conectar_para_menu")
p.terminate()
'@
$menuResult = $menuPy | & $venvPython - 2>&1
$menuResult | ForEach-Object { Write-Output "  $_" }

Write-Output ""

# -------------------------------------------------------
# SECCION 4 — config.toml
# -------------------------------------------------------
Write-Output "[SECCION 4] Configuracion config.toml"
Write-Output "---"

$configPy = @'
import tomllib, os, sys
if not os.path.exists("config.toml"):
    print("FAIL:config.toml_no_encontrado")
    sys.exit()
with open("config.toml", "rb") as f:
    config = tomllib.load(f)
exe  = config.get("infostat", {}).get("exe_path", "NO_CONFIGURADO")
data = config.get("paths", {}).get("data_base_dir", "NO_CONFIGURADO")
res  = config.get("paths", {}).get("results_base_dir", "NO_CONFIGURADO")
for k, v in [("exe_path", exe), ("data_base_dir", data), ("results_base_dir", res)]:
    if v == "NO_CONFIGURADO":
        status = "FAIL"
    elif os.path.exists(v):
        status = "PASS"
    else:
        status = "WARN"
    print(f"{status}:{k}={v}")
'@
$configResult = $configPy | & $venvPython - 2>&1
$configResult | ForEach-Object { Write-Output "  $_" }

# Auto-fix exe_path si está vacío o incorrecto
$exeConfigCheck = $configResult | Where-Object { $_ -match "FAIL:exe_path|WARN:exe_path" }
if ($exeConfigCheck -and (Test-Path $infostatExe)) {
    Write-Output "  AUTOFIX: Actualizando exe_path en config.toml..."
    $c = Get-Content "config.toml" -Raw
    $escapedPath = $infostatExe -replace '\\', '\\\\'
    $c = $c -replace '(?m)exe_path\s*=\s*"[^"]*"', "exe_path = `"$escapedPath`""
    $c | Set-Content "config.toml" -Encoding UTF8
    Write-Output "  DONE: config.toml actualizado con $infostatExe"
}

Write-Output ""

# -------------------------------------------------------
# SECCION 5 -- Compatibilidad instalacion InfoStat 2020
# -------------------------------------------------------
Write-Output "[SECCION 5] Compatibilidad instalacion InfoStat 2020"
Write-Output "---"

function Get-PEMachine {
    param([string]$Path)

    if (-not (Test-Path $Path)) {
        return "missing"
    }

    $fs = [System.IO.File]::OpenRead($Path)
    try {
        $br = New-Object System.IO.BinaryReader($fs)
        $fs.Seek(0x3C, [System.IO.SeekOrigin]::Begin) | Out-Null
        $peOffset = $br.ReadInt32()
        $fs.Seek($peOffset + 4, [System.IO.SeekOrigin]::Begin) | Out-Null
        $machine = $br.ReadUInt16()
        switch ($machine) {
            0x014c { return "x86" }
            0x8664 { return "x64" }
            default { return ("0x{0:X4}" -f $machine) }
        }
    }
    finally {
        $fs.Dispose()
    }
}

$compatArchOk = $true
$versionMismatchDocs = $false
$compatErrorsLast30d = 0
$installerVersionMismatch = $false

if (Test-Path $infostatExe) {
    $exeItem = Get-Item $infostatExe
    $vi = $exeItem.VersionInfo

    Write-Output "S5.1 PASS: product_version=$($vi.ProductVersion) | file_version=$($vi.FileVersion)"
    if ($exeItem.LastWriteTime.Date -eq (Get-Date "2020-09-29").Date) {
        Write-Output "S5.2 PASS: fecha de compilacion/localizacion coincide con 2020-09-29"
    }
    else {
        Write-Output "S5.2 WARN: fecha de archivo distinta a 2020-09-29 ($($exeItem.LastWriteTime))"
    }

    $infostatArch = Get-PEMachine -Path $infostatExe
    $pythonArch = Get-PEMachine -Path $venvPython
    if ($infostatArch -eq "x86" -and $pythonArch -eq "x64") {
        $compatArchOk = $false
        Write-Output "S5.3 WARN: InfoStat x86 con Python x64 (pywinauto puede ser inestable)"
    }
    else {
        Write-Output "S5.3 PASS: arquitectura compatible (InfoStat=$infostatArch, Python=$pythonArch)"
    }

    $sig = Get-AuthenticodeSignature $infostatExe
    if ($sig.Status -eq "Valid") {
        Write-Output "S5.4 PASS: ejecutable firmado digitalmente"
    }
    else {
        Write-Output "S5.4 WARN: ejecutable sin firma valida ($($sig.Status))"
    }

    $installRoot = Split-Path $infostatExe -Parent
    $requiredDirs = @("Data", "Datos", "Help", "recursos", "RScripts_esp", "RSources")
    $missingDirs = @()
    foreach ($d in $requiredDirs) {
        if (-not (Test-Path (Join-Path $installRoot $d))) {
            $missingDirs += $d
        }
    }
    if ($missingDirs.Count -eq 0) {
        Write-Output "S5.5 PASS: estructura de instalacion esperada presente"
    }
    else {
        Write-Output "S5.5 WARN: faltan directorios esperados: $($missingDirs -join ', ')"
    }

    $errors = Get-WinEvent -FilterHashtable @{
            LogName = "Application"
            StartTime = (Get-Date).AddDays(-30)
            ProviderName = @("Application Error", ".NET Runtime", "Windows Error Reporting")
        } -MaxEvents 4000 -ErrorAction SilentlyContinue |
        Where-Object { $_.Message -like "*InfoStat*" } |
        Select-Object -First 20
    $compatErrorsLast30d = @($errors).Count
    if ($compatErrorsLast30d -eq 0) {
        Write-Output "S5.6 PASS: sin errores de runtime de InfoStat en EventLog (30 dias)"
    }
    else {
        Write-Output "S5.6 WARN: se detectaron $compatErrorsLast30d errores de runtime en EventLog (30 dias)"
    }

    if ($vi.ProductVersion -notmatch "2008") {
        $versionMismatchDocs = $true
        Write-Output "S5.7 WARN: el manual base es InfoStat 2008, pero el binario reporta version $($vi.ProductVersion)"
    }
    else {
        Write-Output "S5.7 PASS: version del binario alineada con manual base 2008"
    }

    $uninstallKeys = @(
        "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*"
    )
    $displayVersions = @()
    foreach ($k in $uninstallKeys) {
        $displayVersions += Get-ItemProperty $k -ErrorAction SilentlyContinue |
            Where-Object { $_.DisplayName -like "*InfoStat*" } |
            Select-Object -ExpandProperty DisplayVersion -ErrorAction SilentlyContinue
    }
    $displayVersions = @($displayVersions | Where-Object { $_ } | Select-Object -Unique)
    if ($displayVersions.Count -gt 0) {
        Write-Output "S5.8 INFO: version MSI registrada=$($displayVersions -join ', ')"
        if ($displayVersions -contains $vi.ProductVersion) {
            Write-Output "S5.9 PASS: version MSI coincide con product_version del ejecutable"
        }
        else {
            $installerVersionMismatch = $true
            Write-Output "S5.9 WARN: version MSI y product_version del ejecutable no coinciden"
        }
    }
    else {
        Write-Output "S5.8 WARN: no se encontro entrada de desinstalacion para InfoStat"
    }
}
else {
    $compatArchOk = $false
    $installerVersionMismatch = $true
    Write-Output "S5.1 FAIL: no se puede evaluar compatibilidad (InfoStat.exe ausente)"
}

Write-Output ""

# -------------------------------------------------------
# RESUMEN Y TABLA DE DECISION
# -------------------------------------------------------
Write-Output "============================================="
Write-Output "RESUMEN PARA DECISION DE BLOQUE"
Write-Output "============================================="

$exeOk     = Test-Path $infostatExe
$testsText = ($testsResult | Out-String)
$testsOk   = ($testsText -match "\bpassed\b") -and ($testsText -notmatch "\bfailed\b")
$launchOk  = [bool]($launchResult -match "PASS:pid=")
$backendOk = [bool]($windowResult -match "PASS:backend=")
$menuOk    = [bool]($menuResult -match "PASS:menu_accesible")
$pwiOk     = $pwiCheck -match "ok:" -or ($pwiCheck2 -match "ok")

Write-Output "Tests suite ok   : $testsOk"
Write-Output "InfoStat exe ok  : $exeOk"
Write-Output "InfoStat lanza   : $launchOk"
Write-Output "Backend UI ok    : $backendOk"
Write-Output "Menu accesible   : $menuOk"
Write-Output "Compat arch ok   : $compatArchOk"
Write-Output "Version doc risk : $versionMismatchDocs"
Write-Output "Runtime errors30d: $compatErrorsLast30d"
Write-Output "Installer ver risk: $installerVersionMismatch"

Write-Output ""
Write-Output "DECISION:"

if (-not $testsOk) {
    Write-Output "  !! STOP: Hay tests rotos. Reparar antes de continuar."
} elseif (-not $exeOk) {
    Write-Output "  => BLOQUE C: Parser estructurado con resultados mock (InfoStat no encontrado)."
} elseif (-not $launchOk) {
    Write-Output "  => BLOQUE C + investigar por que InfoStat no lanza."
} elseif (-not $backendOk) {
    Write-Output "  => BLOQUE A limitado: data_load por archivo sin UI automation."
} elseif (-not $menuOk) {
    Write-Output "  => BLOQUE A con estrategia teclado (Alt+F, SendKeys)."
} else {
    Write-Output "  => BLOQUE A COMPLETO + BLOQUE B habilitado. Continuar con Sprint 2 full."
}

if (-not $compatArchOk -or $versionMismatchDocs -or $installerVersionMismatch) {
    Write-Output "  !! NOTA_COMPAT: revisar x86/x64, diferencias con manual 2008 y version MSI registrada."
}

Write-Output ""
Write-Output "Fin diagnostico: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
Write-Output "Log guardado en: diagnostico_log.txt (si usaste Tee-Object)"
