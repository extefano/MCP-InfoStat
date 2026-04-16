# Especificación de Diagnóstico Automático — MCP-InfoStat
## Documento para ejecución por agente autónomo (Sprint 2 — Pre-vuelo)

**Versión:** 1.0  
**Fecha:** 2026-04-16  
**Propósito:** Permitir que una instancia agentica de IA ejecute este diagnóstico sin intervención humana, lea los resultados y determine qué bloque de implementación es viable continuar.

---

## Instrucciones generales para el agente

Ejecutá cada sección **en orden**. Al final de cada sección registrá el resultado como `PASS`, `WARN` o `FAIL` en el archivo de reporte `diagnostico_resultado.json`. Al terminar todas las secciones, determiná la **decisión de bloque** según la tabla de la Sección 6.

Todos los comandos están escritos para **PowerShell en Windows**. Ejecutalos con:

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
```

---

## Sección 1 — Verificación de entorno Python

**Objetivo:** Confirmar que el entorno virtual del proyecto existe y que las dependencias están instaladas.

### 1.1 — Existencia del entorno virtual

```powershell
# Desde la raíz del repositorio MCP-Infostat
$venvPython = ".\.venv\Scripts\python.exe"
if (Test-Path $venvPython) {
    Write-Output "PASS: venv encontrado en $venvPython"
} else {
    Write-Output "FAIL: venv no encontrado. Ejecutar: python -m venv .venv"
}
```

**Criterio:** `PASS` si el archivo existe.

### 1.2 — Versión de Python

```powershell
& ".\.venv\Scripts\python.exe" --version
```

**Criterio:** `PASS` si retorna `Python 3.11.x` o superior. `FAIL` si es menor a 3.11.

### 1.3 — Dependencias del proyecto instaladas

```powershell
& ".\.venv\Scripts\python.exe" -c "import mcp; import tomli; import pytest; print('PASS: dependencias core ok')"
```

**Criterio:** `PASS` si no hay `ModuleNotFoundError`. Si falla, ejecutar:

```powershell
& ".\.venv\Scripts\pip.exe" install -e ".[dev]"
```

### 1.4 — Import del servidor MCP

```powershell
& ".\.venv\Scripts\python.exe" -c "import server; print('PASS: server.py importa sin errores')"
```

**Criterio:** `PASS` si no hay excepciones.

### 1.5 — Suite de tests existentes

```powershell
& ".\.venv\Scripts\pytest.exe" tests/ -v --tb=short 2>&1
```

**Criterio:** `PASS` si todos los tests pasan (7/7 esperados). `FAIL` si hay tests rotos. Registrar cantidad exacta de `passed` y `failed`.

---

## Sección 2 — Verificación de InfoStat instalado

**Objetivo:** Confirmar que InfoStat 2008 existe en el sistema y es ejecutable.

### 2.1 — Existencia del ejecutable principal

```powershell
$infostatExe = "C:\Program Files (x86)\InfoStat\InfoStat.exe"
if (Test-Path $infostatExe) {
    $fileInfo = Get-Item $infostatExe
    Write-Output "PASS: InfoStat.exe encontrado"
    Write-Output "  Tamaño: $($fileInfo.Length) bytes"
    Write-Output "  Fecha modificación: $($fileInfo.LastWriteTime)"
} else {
    Write-Output "FAIL: InfoStat.exe no encontrado en ruta por defecto"
    # Búsqueda alternativa
    $found = Get-ChildItem "C:\Program Files (x86)\" -Filter "InfoStat.exe" -Recurse -ErrorAction SilentlyContinue
    if ($found) {
        Write-Output "  Encontrado en ruta alternativa: $($found.FullName)"
    }
}
```

**Criterio:** `PASS` si el exe existe. `WARN` si se encontró en ruta alternativa (actualizar `config.toml`). `FAIL` si no se encuentra en ninguna ruta.

### 2.2 — Contenido de la carpeta de instalación

```powershell
Get-ChildItem "C:\Program Files (x86)\InfoStat\" | 
    Select-Object Name, Length, LastWriteTime | 
    Format-Table -AutoSize
```

**Criterio:** Registrar todos los archivos encontrados. Anotar extensiones presentes (`.exe`, `.dll`, `.ini`, `.dat`, etc.). Esto informa qué mecanismos de automatización son posibles.

### 2.3 — Verificación de archivos de configuración de InfoStat

```powershell
$configFiles = @(
    "C:\Program Files (x86)\InfoStat\InfoStat.ini",
    "C:\Program Files (x86)\InfoStat\InfoStat.cfg",
    "$env:APPDATA\InfoStat\InfoStat.ini",
    "$env:LOCALAPPDATA\InfoStat\InfoStat.ini"
)
foreach ($f in $configFiles) {
    if (Test-Path $f) {
        Write-Output "ENCONTRADO: $f"
        Get-Content $f | Select-Object -First 30
    }
}
```

**Criterio:** Registrar si existen archivos `.ini` o `.cfg`. Su presencia indica posibilidad de configuración por archivo.

### 2.4 — Verificación de archivos de resultados anteriores

```powershell
# Buscar archivos de resultados típicos de InfoStat
$resultExtensions = @("*.ist", "*.res", "*.out", "*.txt")
$searchPaths = @(
    "C:\Program Files (x86)\InfoStat\",
    "$env:USERPROFILE\Documents\",
    "$env:USERPROFILE\Desktop\"
)
foreach ($path in $searchPaths) {
    foreach ($ext in $resultExtensions) {
        $files = Get-ChildItem $path -Filter $ext -Recurse -ErrorAction SilentlyContinue | Select-Object -First 3
        if ($files) {
            Write-Output "Archivos $ext en ${path}:"
            $files | Select-Object FullName, Length, LastWriteTime | Format-Table
        }
    }
}
```

**Criterio:** Si existen archivos `.ist` o `.res` anteriores, registrar sus rutas — serán útiles para desarrollar el parser sin necesitar correr InfoStat.

---

## Sección 3 — Verificación de capacidad de automatización UI

**Objetivo:** Determinar si `pywinauto` puede controlar InfoStat.

### 3.1 — Instalación de pywinauto

```powershell
& ".\.venv\Scripts\python.exe" -c "import pywinauto; print('PASS: pywinauto disponible, versión:', pywinauto.__version__)"
```

Si falla:

```powershell
& ".\.venv\Scripts\pip.exe" install pywinauto
& ".\.venv\Scripts\python.exe" -c "import pywinauto; print('PASS: pywinauto instalado')"
```

**Criterio:** `PASS` si importa. `FAIL` si no se puede instalar (anotar error completo).

### 3.2 — Instalación de pywin32

```powershell
& ".\.venv\Scripts\python.exe" -c "import win32api; import win32gui; import win32con; print('PASS: pywin32 disponible')"
```

Si falla:

```powershell
& ".\.venv\Scripts\pip.exe" install pywin32
& ".\.venv\Scripts\python.exe" -c "import win32api; print('PASS: pywin32 instalado')"
```

**Criterio:** `PASS` si importa. `FAIL` si no se puede instalar.

### 3.3 — Prueba de lanzamiento de InfoStat

```powershell
# Script Python para lanzar InfoStat y verificar que la ventana aparece
$testScript = @"
import subprocess
import time
import sys

exe_path = r'C:\Program Files (x86)\InfoStat\InfoStat.exe'

print('Intentando lanzar InfoStat...')
try:
    proc = subprocess.Popen([exe_path])
    print(f'Proceso lanzado. PID: {proc.pid}')
    time.sleep(5)  # Esperar que cargue
    
    # Verificar si sigue corriendo
    if proc.poll() is None:
        print('PASS: InfoStat sigue corriendo despues de 5 segundos')
        proc.terminate()
        print('Proceso terminado.')
    else:
        print(f'FAIL: InfoStat termino con codigo: {proc.returncode}')
except FileNotFoundError:
    print('FAIL: Ejecutable no encontrado')
except Exception as e:
    print(f'FAIL: Error inesperado: {e}')
"@

$testScript | & ".\.venv\Scripts\python.exe" -
```

**Criterio:** `PASS` si el proceso sobrevive 5 segundos. `FAIL` si termina inmediatamente o no se encuentra.

### 3.4 — Prueba de detección de ventana con pywinauto

```powershell
$testScript = @"
import subprocess
import time
import sys

try:
    from pywinauto import Application, Desktop
    from pywinauto.findwindows import ElementNotFoundError
except ImportError:
    print('SKIP: pywinauto no disponible')
    sys.exit(0)

exe_path = r'C:\Program Files (x86)\InfoStat\InfoStat.exe'

print('Lanzando InfoStat para inspeccion de ventana...')
proc = subprocess.Popen([exe_path])
time.sleep(6)

try:
    # Intentar conectar con backend UIA primero
    app = Application(backend='uia').connect(process=proc.pid, timeout=10)
    print('PASS: Conexion UIA exitosa')
    
    # Listar ventanas disponibles
    windows = app.windows()
    for w in windows:
        print(f'  Ventana: titulo={repr(w.window_text())}, clase={repr(w.class_name())}')
    
except Exception as e1:
    print(f'WARN: UIA fallo ({e1}), intentando backend win32...')
    try:
        app = Application(backend='win32').connect(process=proc.pid, timeout=10)
        print('PASS: Conexion win32 exitosa')
        windows = app.windows()
        for w in windows:
            print(f'  Ventana: titulo={repr(w.window_text())}, clase={repr(w.class_name())}')
    except Exception as e2:
        print(f'FAIL: Ambos backends fallaron. UIA: {e1} | win32: {e2}')
finally:
    proc.terminate()
    print('InfoStat terminado.')
"@

$testScript | & ".\.venv\Scripts\python.exe" -
```

**Criterio:** `PASS (uia)` o `PASS (win32)` si al menos un backend conecta y lista ventanas. Registrar títulos y clases de ventanas encontradas — son críticos para Sprint 2. `FAIL` si ambos backends fallan.

### 3.5 — Inspección de estructura de menú (solo si 3.4 pasó)

```powershell
$testScript = @"
import subprocess
import time

try:
    from pywinauto import Application
except ImportError:
    print('SKIP: pywinauto no disponible')
    exit()

exe_path = r'C:\Program Files (x86)\InfoStat\InfoStat.exe'
proc = subprocess.Popen([exe_path])
time.sleep(6)

try:
    # Probar con el backend que funcionó en 3.4
    app = Application(backend='uia').connect(process=proc.pid, timeout=10)
    main_win = app.top_window()
    print(f'Ventana principal: {repr(main_win.window_text())}')
    
    # Intentar listar items del menu principal
    try:
        menu = main_win.menu()
        print('Estructura de menu principal:')
        for i, item in enumerate(menu.items()):
            print(f'  [{i}] {item.text()}')
    except Exception as me:
        print(f'WARN: No se pudo listar menu directamente: {me}')
        # Intentar via child_window
        children = main_win.children()
        print(f'Hijos de ventana principal ({len(children)}):')
        for c in children[:20]:  # primeros 20
            print(f'  tipo={c.friendly_class_name()}, texto={repr(c.window_text()[:50])}')
            
except Exception as e:
    print(f'FAIL: {e}')
finally:
    proc.terminate()
"@

$testScript | & ".\.venv\Scripts\python.exe" -
```

**Criterio:** Registrar la estructura de menú completa. Si el menú "Archivo" o "Datos" es accesible por nombre, el Bloque A es implementable directamente. Si no, se necesita estrategia alternativa (coordenadas, teclas).

---

## Sección 4 — Verificación de config.toml del proyecto

**Objetivo:** Confirmar que la configuración del proyecto apunta a rutas válidas.

```powershell
$testScript = @"
import tomllib
import os

with open('config.toml', 'rb') as f:
    config = tomllib.load(f)

checks = {
    'infostat.exe_path': config.get('infostat', {}).get('exe_path', 'NO CONFIGURADO'),
    'paths.data_base_dir': config.get('paths', {}).get('data_base_dir', 'NO CONFIGURADO'),
    'paths.results_base_dir': config.get('paths', {}).get('results_base_dir', 'NO CONFIGURADO'),
}

for key, value in checks.items():
    exists = os.path.exists(value) if value != 'NO CONFIGURADO' else False
    status = 'PASS' if exists else ('WARN' if value != 'NO CONFIGURADO' else 'FAIL')
    print(f'{status}: {key} = {value}')
"@

& ".\.venv\Scripts\python.exe" -c $testScript
```

**Criterio:** `PASS` si las rutas existen. `WARN` si la ruta está configurada pero no existe (crear directorio). `FAIL` si `exe_path` dice `NO CONFIGURADO` o no existe.

**Corrección automática si falla exe_path:**

```powershell
# Actualizar config.toml con la ruta real
$configContent = Get-Content "config.toml" -Raw
$configContent = $configContent -replace 'exe_path\s*=\s*".*?"', 'exe_path = "C:\\Program Files (x86)\\InfoStat\\InfoStat.exe"'
$configContent | Set-Content "config.toml"
Write-Output "config.toml actualizado con ruta de InfoStat"
```

---

## Sección 5 — Generación del reporte de diagnóstico

Al finalizar todas las secciones anteriores, generar el archivo de resultado:

```powershell
$testScript = @"
import json
import subprocess
import os
import sys
from datetime import datetime

# El agente debe completar este diccionario con los resultados reales
resultado = {
    'timestamp': datetime.now().isoformat(),
    'seccion_1_python': {
        'venv_existe': None,          # True/False
        'python_version': None,        # ej: '3.11.9'
        'dependencias_ok': None,       # True/False
        'server_importa': None,        # True/False
        'tests_passed': None,          # int
        'tests_failed': None,          # int
    },
    'seccion_2_infostat': {
        'exe_encontrado': None,        # True/False
        'ruta_real': None,             # str
        'archivos_ini': None,          # list of str
        'archivos_resultados_previos': None,  # list of str
        'extensiones_resultados': None,       # list ej: ['.ist', '.res']
    },
    'seccion_3_automatizacion': {
        'pywinauto_disponible': None,  # True/False
        'pywin32_disponible': None,    # True/False
        'infostat_lanza': None,        # True/False
        'backend_exitoso': None,       # 'uia' | 'win32' | None
        'titulos_ventanas': None,      # list of str
        'clases_ventanas': None,       # list of str
        'menu_accesible': None,        # True/False
        'items_menu_principal': None,  # list of str
    },
    'seccion_4_config': {
        'exe_path_configurado': None,  # True/False
        'exe_path_existe': None,       # True/False
        'data_dir_existe': None,       # True/False
        'results_dir_existe': None,    # True/False
    },
}

# Guardar
with open('diagnostico_resultado.json', 'w', encoding='utf-8') as f:
    json.dump(resultado, f, indent=2, ensure_ascii=False)

print('Archivo diagnostico_resultado.json generado.')
print('El agente debe completar los valores None con los resultados reales de cada sección.')
"@

& ".\.venv\Scripts\python.exe" -c $testScript
```

---

## Sección 6 — Tabla de decisión de bloque

Una vez completado `diagnostico_resultado.json`, el agente aplica esta tabla para determinar qué implementar:

```
╔══════════════════════════════════════════════════════════════════════════════╗
║ CONDICIÓN                                          → DECISIÓN               ║
╠══════════════════════════════════════════════════════════════════════════════╣
║ tests_failed > 0                                   → STOP: Reparar tests    ║
║                                                      antes de continuar     ║
╠══════════════════════════════════════════════════════════════════════════════╣
║ exe_encontrado=False                               → BLOQUE C únicamente:   ║
║                                                      parser estructurado    ║
║                                                      con resultados mock    ║
╠══════════════════════════════════════════════════════════════════════════════╣
║ exe_encontrado=True                                                          ║
║ AND infostat_lanza=False                           → BLOQUE C + investigar  ║
║                                                      por qué no lanza       ║
╠══════════════════════════════════════════════════════════════════════════════╣
║ exe_encontrado=True                                                          ║
║ AND infostat_lanza=True                                                      ║
║ AND backend_exitoso=None                           → BLOQUE A limitado:     ║
║                                                      data_load por archivo  ║
║                                                      (sin UI automation)    ║
╠══════════════════════════════════════════════════════════════════════════════╣
║ exe_encontrado=True                                                          ║
║ AND infostat_lanza=True                                                      ║
║ AND backend_exitoso IN ['uia','win32']                                       ║
║ AND menu_accesible=False                           → BLOQUE A con           ║
║                                                      estrategia teclado     ║
║                                                      (Alt+F, SendKeys)      ║
╠══════════════════════════════════════════════════════════════════════════════╣
║ exe_encontrado=True                                                          ║
║ AND infostat_lanza=True                                                      ║
║ AND backend_exitoso IN ['uia','win32']                                       ║
║ AND menu_accesible=True                            → BLOQUE A COMPLETO +    ║
║                                                      BLOQUE B habilitado    ║
╚══════════════════════════════════════════════════════════════════════════════╝
```

---

## Sección 7 — Script de ejecución unificado

Para ejecutar todo el diagnóstico de una sola vez:

```powershell
# diagnostico_completo.ps1
# Ejecutar desde la raíz del repositorio MCP-Infostat
# Uso: .\diagnostico_completo.ps1 > diagnostico_log.txt 2>&1

Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass

$ErrorActionPreference = "Continue"
$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

Write-Output "======================================"
Write-Output "MCP-InfoStat — Diagnóstico Automático"
Write-Output "Inicio: $timestamp"
Write-Output "======================================"
Write-Output ""

# --- SECCIÓN 1 ---
Write-Output "[SECCION 1] Entorno Python"
Write-Output "---"

$venvPython = ".\.venv\Scripts\python.exe"
if (Test-Path $venvPython) {
    Write-Output "S1.1 PASS: venv encontrado"
} else {
    Write-Output "S1.1 FAIL: venv no encontrado — ejecutar: python -m venv .venv && pip install -e .[dev]"
}

& $venvPython --version 2>&1 | ForEach-Object { Write-Output "S1.2 Python version: $_" }

$depCheck = & $venvPython -c "import mcp; import tomllib; print('ok')" 2>&1
if ($depCheck -match "ok") { Write-Output "S1.3 PASS: dependencias core ok" } 
else { Write-Output "S1.3 FAIL: $depCheck" }

$importCheck = & $venvPython -c "import server; print('ok')" 2>&1
if ($importCheck -match "ok") { Write-Output "S1.4 PASS: server.py importa ok" } 
else { Write-Output "S1.4 FAIL: $importCheck" }

Write-Output "S1.5 Ejecutando suite de tests..."
& ".\.venv\Scripts\pytest.exe" tests/ -v --tb=short 2>&1 | ForEach-Object { Write-Output "  $_" }

Write-Output ""

# --- SECCIÓN 2 ---
Write-Output "[SECCION 2] InfoStat instalado"
Write-Output "---"

$infostatExe = "C:\Program Files (x86)\InfoStat\InfoStat.exe"
if (Test-Path $infostatExe) {
    $fi = Get-Item $infostatExe
    Write-Output "S2.1 PASS: InfoStat.exe en ruta por defecto"
    Write-Output "  Tamaño: $($fi.Length) bytes | Modificado: $($fi.LastWriteTime)"
} else {
    Write-Output "S2.1 FAIL: InfoStat.exe no en ruta por defecto"
    $alt = Get-ChildItem "C:\Program Files (x86)\" -Filter "InfoStat.exe" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($alt) { Write-Output "  WARN: Encontrado en: $($alt.FullName)" }
}

Write-Output "S2.2 Contenido carpeta InfoStat:"
Get-ChildItem "C:\Program Files (x86)\InfoStat\" -ErrorAction SilentlyContinue | 
    Select-Object Name, Length | Format-Table -AutoSize | ForEach-Object { Write-Output "  $_" }

Write-Output "S2.3 Archivos INI/CFG:"
@("C:\Program Files (x86)\InfoStat\InfoStat.ini",
  "$env:APPDATA\InfoStat\InfoStat.ini") | ForEach-Object {
    if (Test-Path $_) { Write-Output "  ENCONTRADO: $_" } 
    else { Write-Output "  ausente: $_" }
}

Write-Output "S2.4 Archivos de resultados previos:"
@("$env:USERPROFILE\Documents", "$env:USERPROFILE\Desktop", "C:\Program Files (x86)\InfoStat") | ForEach-Object {
    $base = $_
    @("*.ist","*.res","*.out") | ForEach-Object {
        Get-ChildItem $base -Filter $_ -Recurse -ErrorAction SilentlyContinue | Select-Object -First 2 |
            ForEach-Object { Write-Output "  $($_.FullName)" }
    }
}

Write-Output ""

# --- SECCIÓN 3 ---
Write-Output "[SECCION 3] Automatización UI"
Write-Output "---"

$pwiCheck = & $venvPython -c "import pywinauto; print('ok:' + pywinauto.__version__)" 2>&1
if ($pwiCheck -match "ok") { Write-Output "S3.1 PASS: pywinauto $($pwiCheck -replace 'ok:','')" }
else {
    Write-Output "S3.1 WARN: pywinauto no instalado — instalando..."
    & ".\.venv\Scripts\pip.exe" install pywinauto 2>&1 | Select-Object -Last 3 | ForEach-Object { Write-Output "  $_" }
}

$win32Check = & $venvPython -c "import win32api; print('ok')" 2>&1
if ($win32Check -match "ok") { Write-Output "S3.2 PASS: pywin32 disponible" }
else {
    Write-Output "S3.2 WARN: pywin32 no instalado — instalando..."
    & ".\.venv\Scripts\pip.exe" install pywin32 2>&1 | Select-Object -Last 3 | ForEach-Object { Write-Output "  $_" }
}

Write-Output "S3.3 Probando lanzamiento de InfoStat (espera 5s)..."
$launchResult = & $venvPython -c @"
import subprocess, time, sys
exe = r'C:\Program Files (x86)\InfoStat\InfoStat.exe'
try:
    p = subprocess.Popen([exe])
    time.sleep(5)
    if p.poll() is None:
        print('PASS:' + str(p.pid))
        p.terminate()
    else:
        print('FAIL:returncode=' + str(p.returncode))
except Exception as e:
    print('FAIL:' + str(e))
"@ 2>&1
Write-Output "  Resultado: $launchResult"

Write-Output "S3.4 Probando detección de ventana con pywinauto (espera 8s)..."
$windowResult = & $venvPython -c @"
import subprocess, time, sys
try:
    from pywinauto import Application
except ImportError:
    print('SKIP:pywinauto no disponible')
    sys.exit()
exe = r'C:\Program Files (x86)\InfoStat\InfoStat.exe'
p = subprocess.Popen([exe])
time.sleep(6)
connected = False
backend_used = None
windows_info = []
for backend in ['uia', 'win32']:
    try:
        app = Application(backend=backend).connect(process=p.pid, timeout=8)
        connected = True
        backend_used = backend
        for w in app.windows():
            windows_info.append(f'{repr(w.window_text())}|{repr(w.class_name())}')
        break
    except Exception as e:
        print(f'WARN:{backend}:{e}')
if connected:
    print(f'PASS:backend={backend_used}')
    for wi in windows_info:
        print(f'  VENTANA:{wi}')
else:
    print('FAIL:ningun backend conecto')
p.terminate()
"@ 2>&1
$windowResult | ForEach-Object { Write-Output "  $_" }

Write-Output "S3.5 Inspeccionando menú principal..."
$menuResult = & $venvPython -c @"
import subprocess, time
try:
    from pywinauto import Application
except ImportError:
    print('SKIP:pywinauto no disponible')
    exit()
exe = r'C:\Program Files (x86)\InfoStat\InfoStat.exe'
p = subprocess.Popen([exe])
time.sleep(6)
for backend in ['uia', 'win32']:
    try:
        app = Application(backend=backend).connect(process=p.pid, timeout=8)
        main_win = app.top_window()
        try:
            menu = main_win.menu()
            items = [item.text() for item in menu.items()]
            print('PASS:menu_accesible')
            for item in items:
                print(f'  MENU_ITEM:{item}')
        except Exception as me:
            print(f'WARN:menu_directo_fallo:{me}')
            children = main_win.children()
            print(f'PASS:hijos_listados:{len(children)}')
            for c in children[:15]:
                print(f'  HIJO:{c.friendly_class_name()}|{repr(c.window_text()[:40])}')
        break
    except Exception as e:
        pass
p.terminate()
"@ 2>&1
$menuResult | ForEach-Object { Write-Output "  $_" }

Write-Output ""

# --- SECCIÓN 4 ---
Write-Output "[SECCION 4] Configuración config.toml"
Write-Output "---"

$configResult = & $venvPython -c @"
import tomllib, os
with open('config.toml', 'rb') as f:
    config = tomllib.load(f)
exe = config.get('infostat', {}).get('exe_path', 'NO_CONFIGURADO')
data = config.get('paths', {}).get('data_base_dir', 'NO_CONFIGURADO')
res  = config.get('paths', {}).get('results_base_dir', 'NO_CONFIGURADO')
for k, v in [('exe_path', exe), ('data_base_dir', data), ('results_base_dir', res)]:
    status = 'PASS' if os.path.exists(v) else ('WARN' if v != 'NO_CONFIGURADO' else 'FAIL')
    print(f'{status}:{k}={v}')
"@ 2>&1
$configResult | ForEach-Object { Write-Output "  $_" }

Write-Output ""
Write-Output "======================================"
Write-Output "Diagnóstico completado: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
Write-Output "Revisar resultados arriba y aplicar tabla de decisión (Sección 6)."
Write-Output "======================================"
```

**Uso:**

```powershell
# Desde la raíz del repositorio
.\diagnostico_completo.ps1 | Tee-Object -FilePath diagnostico_log.txt
```

Esto genera `diagnostico_log.txt` con todo el output para que el agente lo analice y aplique la tabla de decisión.

---

## Notas para el agente que ejecuta esto

1. **Si InfoStat tiene una pantalla de bienvenida/splash** que bloquea la ventana principal, aumentar los `time.sleep()` en las secciones 3.3 y 3.4 de 5s a 10s.
2. **Si pywinauto necesita permisos elevados** para conectar a InfoStat, ejecutar PowerShell como Administrador.
3. **Si el backend `uia` falla con TimeoutError** pero `win32` funciona, anotar `backend_exitoso = 'win32'` — el resto del Sprint 2 usará ese backend.
4. **El agente debe guardar `diagnostico_resultado.json` completado** al repositorio para que la próxima sesión arranque con contexto completo.
