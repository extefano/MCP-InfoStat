# SPEC-001: Arquitectura del MCP-InfoStat Rediseñado
> Especificación técnica — Capa de automatización y diseño del servidor

---

## Objetivo

Diseñar un servidor MCP que permita a una IA agéntica ejecutar análisis estadísticos completos en InfoStat, incluyendo: apertura del software, carga de datos, ejecución de procedimientos, lectura de resultados y exportación de gráficos.

---

## Restricción Fundamental: InfoStat no tiene API

InfoStat es un software de escritorio Windows (`.exe`) sin API, sin CLI, sin COM automation documentada y sin interfaz de scripting nativa. La única forma de automatizarlo es mediante **automatización de interfaz gráfica (UI Automation)**.

### Opciones de automatización de UI

| Tecnología | Lenguaje | Pros | Contras |
|---|---|---|---|
| `pywinauto` | Python | Madura, bien documentada, soporta Win32 | Requiere que InfoStat esté corriendo en el mismo host |
| `win32api` + `win32gui` | Python | Control fino de ventanas | Frágil ante cambios de layout |
| AutoHotkey | AHK | Simple para interacciones básicas | No integrable como librería Python/Node |
| `uiautomation` (UIAutomation SDK) | Python/C# | Estándar Microsoft, más robusto | Mayor complejidad inicial |

**Recomendación:** `pywinauto` como capa primaria, con fallback a `win32api` para operaciones de bajo nivel.

---

## Arquitectura Propuesta

```
┌─────────────────────────────────────────────────────────────┐
│                     AGENTE IA (Claude)                       │
└───────────────────────┬─────────────────────────────────────┘
                        │ MCP Protocol (stdio / HTTP)
┌───────────────────────▼─────────────────────────────────────┐
│                   MCP-InfoStat Server                        │
│  ┌─────────────────────────────────────────────────────┐     │
│  │              Tool Router (FastMCP / Python)          │     │
│  └──────┬───────────┬──────────────┬──────────────┬────┘     │
│         │           │              │              │           │
│  ┌──────▼──┐ ┌──────▼──┐  ┌───────▼──┐  ┌───────▼──┐       │
│  │Session  │ │Data Mgr │  │Analysis  │  │Results   │       │
│  │Manager  │ │         │  │Executor  │  │Parser    │       │
│  └──────┬──┘ └──────┬──┘  └───────┬──┘  └───────┬──┘       │
│         └───────────┴──────────────┴──────────────┘         │
│                         │                                     │
│              ┌──────────▼──────────┐                         │
│              │   UI Automation     │                         │
│              │   Layer (pywinauto) │                         │
│              └──────────┬──────────┘                         │
└─────────────────────────┼───────────────────────────────────┘
                          │ Win32 API / UI Automation
┌─────────────────────────▼───────────────────────────────────┐
│              InfoStat (proceso Windows .exe)                 │
└─────────────────────────────────────────────────────────────┘
```

---

## Módulos del Servidor

### 1. Session Manager
Responsable del ciclo de vida de InfoStat como proceso.

**Estado que debe mantener:**
```python
class InfoStatSession:
    pid: int                    # PID del proceso InfoStat
    app: pywinauto.Application  # Handle de la aplicación
    main_window: WindowSpec     # Ventana principal
    active_dataset: str | None  # Path del dataset cargado
    is_ready: bool              # Si InfoStat está listo para recibir comandos
    results_buffer: list[str]   # Últimos resultados capturados
```

### 2. Data Manager
Maneja todas las operaciones sobre la tabla de datos de InfoStat.

### 3. Analysis Executor
Navega los menús de InfoStat y completa los diálogos de cada procedimiento estadístico.

### 4. Results Parser
Captura el contenido de la ventana de resultados y lo parsea en estructuras estructuradas.

---

## Estrategia de Captura de Resultados

InfoStat muestra los resultados en una ventana de texto (ventana "Resultados"). La estrategia de captura:

1. Antes de ejecutar un análisis, registrar el contenido actual de la ventana de resultados.
2. Ejecutar el análisis.
3. Esperar a que InfoStat termine (polling del estado de la ventana o de la barra de progreso).
4. Extraer el texto nuevo agregado a la ventana de resultados.
5. Parsear el texto usando parsers específicos por tipo de análisis (regex + heurísticas).

**Alternativa:** Usar la opción "Guardar resultados" de InfoStat para volcar el output a un archivo de texto y leerlo desde Python.

---

## Gestión de Errores y Timeouts

```python
class InfoStatError(Exception):
    pass

class InfoStatTimeoutError(InfoStatError):
    timeout_seconds: float
    operation: str

class InfoStatDialogError(InfoStatError):
    dialog_title: str
    message: str
```

Toda tool debe:
- Definir un `timeout` máximo por operación.
- Capturar diálogos de error de InfoStat antes de retornar.
- Retornar siempre un objeto estructurado con `success`, `result` y `error`.

---

## Esquema de Respuesta Estándar de Todas las Tools

```json
{
  "success": true,
  "operation": "anova_one_way",
  "duration_ms": 1240,
  "result": { ... },
  "warnings": [],
  "error": null
}
```

---

## Consideraciones de Seguridad

1. **El servidor DEBE correr en el mismo host Windows donde corre InfoStat.**
2. **No exponer el servidor en red pública** — solo comunicación local (stdio o localhost).
3. **Validar todos los paths de archivos** contra un directorio base configurable.
4. **Eliminar `r_routine` con `additionalProperties: true`** — reemplazar por tools específicas.
5. **No aceptar código arbitrario** de ningún tipo desde el cliente MCP.

---

## Stack Tecnológico Recomendado

```
Servidor MCP:    Python 3.11+ con FastMCP (mcp[cli])
UI Automation:   pywinauto >= 0.6.8
Win32:           pywin32 (win32api, win32gui, win32con)
Parser results:  regex + pyparsing para tablas de texto
Testing:         pytest + mock de ventanas pywinauto
Config:          TOML o JSON con schema validado por pydantic
```

---

## Estructura de Archivos del Proyecto

```
mcp-infostat/
├── server.py                  # Entry point FastMCP
├── config.toml                # Configuración (path a InfoStat.exe, timeouts, etc.)
├── pyproject.toml
├── infostat/
│   ├── session.py             # Session Manager
│   ├── ui/
│   │   ├── launcher.py        # Lanzar/cerrar InfoStat
│   │   ├── data_manager.py    # Gestión de datos
│   │   ├── menu_navigator.py  # Navegación de menús
│   │   └── dialog_handler.py  # Completar diálogos de análisis
│   ├── analysis/
│   │   ├── descriptive.py     # Estadística descriptiva
│   │   ├── inference.py       # Inferencia
│   │   ├── anova.py           # ANAVA
│   │   ├── regression.py      # Regresión
│   │   ├── multivariate.py    # Multivariado
│   │   └── time_series.py     # Series de tiempo
│   ├── results/
│   │   ├── capture.py         # Captura de ventana de resultados
│   │   └── parsers/           # Un parser por tipo de análisis
│   └── validation/
│       ├── metadata.py        # survey_metadata (existente, mejorado)
│       ├── limits.py          # quantitative_limits (existente)
│       └── consistency.py     # logical_consistency (existente)
├── tests/
└── docs/
```
