# SPEC-003: Implementación Técnica — UI Automation y Flujos Agénticos
> Guía de implementación concreta para cada dominio del servidor MCP

---

## Parte 1: Capa de UI Automation con pywinauto

### Setup básico

```python
# infostat/ui/launcher.py
import subprocess
import time
from pathlib import Path
import pywinauto
from pywinauto import Application
from pywinauto.timings import wait_until_passes

INFOSTAT_WINDOW_TITLE = "InfoStat"
INFOSTAT_RESULTS_WINDOW = "Resultados"

class InfoStatLauncher:
    def __init__(self, exe_path: str):
        self.exe_path = Path(exe_path)
        self.app: Application | None = None

    def launch(self, timeout: float = 30) -> Application:
        """Lanza InfoStat y retorna el handle de la aplicación."""
        if not self.exe_path.exists():
            raise FileNotFoundError(f"InfoStat no encontrado en: {self.exe_path}")

        process = subprocess.Popen([str(self.exe_path)])
        
        # Esperar a que la ventana principal esté lista
        self.app = Application(backend="win32")
        wait_until_passes(
            timeout=timeout,
            retry_interval=0.5,
            func=lambda: self.app.connect(title_re=INFOSTAT_WINDOW_TITLE + ".*")
        )
        
        return self.app

    def get_main_window(self):
        return self.app.window(title_re=INFOSTAT_WINDOW_TITLE + ".*")

    def is_ready(self) -> bool:
        """Verifica si InfoStat está listo para recibir comandos."""
        try:
            win = self.get_main_window()
            return win.is_enabled() and not self._has_blocking_dialog()
        except Exception:
            return False

    def _has_blocking_dialog(self) -> bool:
        """Detecta si hay un diálogo modal bloqueante."""
        try:
            dialogs = self.app.windows(class_name="#32770")  # Clase de diálogos Win32
            return len(dialogs) > 0
        except Exception:
            return False
```

### Navegación de menús

```python
# infostat/ui/menu_navigator.py
from pywinauto import Application
import pywinauto.keyboard as kb

class InfoStatMenuNavigator:
    def __init__(self, app: Application):
        self.app = app

    def navigate(self, *menu_path: str):
        """
        Navega una ruta de menú en InfoStat.
        Ej: navigate("Estadísticas", "Análisis de la varianza", "Diseño CRD")
        """
        win = self.app.window(title_re="InfoStat.*")
        menu = win.menu()
        
        item = menu
        for step in menu_path:
            item = item.item(step)
            item.click()
            time.sleep(0.3)  # Esperar a que el submenú se despliegue

    def click_menu_item(self, menu_path: list[str]):
        """Alternativa usando keyboard navigation para mayor robustez."""
        win = self.app.window(title_re="InfoStat.*")
        win.set_focus()
        
        # Usar el menú de la ventana principal
        menu_bar = win.child_window(control_type="MenuBar")
        # Navegar jerárquicamente
        current = menu_bar
        for item_name in menu_path:
            current = current.child_window(title=item_name, control_type="MenuItem")
            current.click_input()
            time.sleep(0.2)
```

### Completado de diálogos

```python
# infostat/ui/dialog_handler.py
"""
Cada procedimiento de InfoStat tiene su propio diálogo con controles específicos.
Este módulo contiene handlers para cada tipo de diálogo.
"""
import pywinauto
from pywinauto import Application
import time

class ANOVADialogHandler:
    """Handler para el diálogo de ANAVA de InfoStat."""
    
    def __init__(self, app: Application):
        self.app = app

    def configure_one_way(self, response_var: str, treatment_var: str,
                           multiple_comparison: str = "lsd", alpha: float = 0.05):
        """Configura el diálogo de ANAVA completamente aleatorizado."""
        
        # Esperar a que el diálogo aparezca
        dialog = self._wait_for_dialog("ANAVA", timeout=10)
        
        # Seleccionar variable respuesta
        self._select_variable(dialog, "Variable respuesta", response_var)
        
        # Seleccionar factor de tratamiento
        self._select_variable(dialog, "Factor", treatment_var)
        
        # Configurar comparaciones múltiples
        self._set_multiple_comparison(dialog, multiple_comparison)
        
        # Configurar alpha
        alpha_field = dialog.child_window(title="Alfa", control_type="Edit")
        alpha_field.set_text(str(alpha))
        
        # Hacer clic en Aceptar
        ok_button = dialog.child_window(title="Aceptar", control_type="Button")
        ok_button.click()
        
        # Esperar a que el diálogo se cierre y los resultados aparezcan
        self._wait_for_results(timeout=30)

    def _wait_for_dialog(self, title_contains: str, timeout: float = 10):
        """Espera a que aparezca un diálogo con el título indicado."""
        from pywinauto.timings import wait_until_passes
        
        dialog = None
        def find_dialog():
            nonlocal dialog
            dialog = self.app.window(title_re=f".*{title_contains}.*", control_type="Dialog")
            assert dialog.exists()
        
        wait_until_passes(timeout=timeout, retry_interval=0.3, func=find_dialog)
        return dialog

    def _select_variable(self, dialog, listbox_label: str, variable_name: str):
        """Selecciona una variable en un listbox del diálogo."""
        # InfoStat usa ListBox para selección de variables
        # La lógica exacta depende del layout del diálogo específico
        listbox = dialog.child_window(title=listbox_label).next_sibling(control_type="ListBox")
        listbox.select(variable_name)

    def _set_multiple_comparison(self, dialog, method: str):
        """Selecciona el método de comparación múltiple."""
        method_map = {
            "lsd": "DMS de Fisher",
            "tukey": "Tukey",
            "duncan": "Duncan",
            "snk": "SNK",
            "bonferroni": "Bonferroni",
            "scheffe": "Scheffé",
            "scott_knott": "Scott y Knott"
        }
        
        display_name = method_map.get(method, "DMS de Fisher")
        combo = dialog.child_window(control_type="ComboBox")  # ComboBox de comparaciones
        combo.select(display_name)

    def _wait_for_results(self, timeout: float = 30):
        """Espera a que InfoStat termine el análisis."""
        # Monitorear si hay cambios en la ventana de resultados
        results_win = self.app.window(title=INFOSTAT_RESULTS_WINDOW)
        initial_text = results_win.window_text() if results_win.exists() else ""
        
        from pywinauto.timings import wait_until_passes
        
        def results_updated():
            current_text = results_win.window_text()
            assert current_text != initial_text
        
        wait_until_passes(timeout=timeout, retry_interval=0.5, func=results_updated)
```

---

## Parte 2: Parser de Resultados

InfoStat produce resultados como texto tabulado en su ventana de Resultados. El parser debe extraer tablas estructuradas.

```python
# infostat/results/capture.py
import re
from dataclasses import dataclass

@dataclass
class ANOVATable:
    source: str
    df: int
    ss: float
    ms: float | None
    f_value: float | None
    p_value: float | None

@dataclass
class ANOVAResult:
    anova_table: list[ANOVATable]
    r_squared: float | None
    cv_percent: float | None
    means_table: list[dict]
    multiple_comparison_method: str | None

class InfoStatResultsCapture:
    def __init__(self, app):
        self.app = app

    def get_results_text(self) -> str:
        """Extrae el texto completo de la ventana de resultados."""
        results_win = self.app.window(title="Resultados")
        if not results_win.exists():
            return ""
        
        # Usar Ctrl+A + Ctrl+C para copiar todo el texto
        results_win.set_focus()
        import pywinauto.keyboard as kb
        kb.send_keys("^a^c")
        
        import win32clipboard
        win32clipboard.OpenClipboard()
        text = win32clipboard.GetClipboardData(win32clipboard.CF_TEXT)
        win32clipboard.CloseClipboard()
        
        return text.decode("latin-1") if isinstance(text, bytes) else text

    def parse_anova_table(self, text: str) -> ANOVAResult:
        """Parsea la tabla de ANAVA del texto de resultados."""
        
        # Patrón para la tabla ANAVA de InfoStat
        # Formato típico:
        # Fuente de variación  GL    SC      CM      F-valor   Pr>F
        # Tratamiento           3    145.2   48.4    12.3      0.0002
        # Error                20     78.5    3.93
        # Total                23    223.7
        
        anova_pattern = re.compile(
            r"(\w[\w\s]+?)\s+(\d+)\s+([\d.]+)\s+([\d.]+)\s+([\d.]+)\s+([\d.<>]+)",
            re.MULTILINE
        )
        
        rows = []
        for match in anova_pattern.finditer(text):
            source, df, ss, ms, f_val, p_val = match.groups()
            rows.append(ANOVATable(
                source=source.strip(),
                df=int(df),
                ss=float(ss),
                ms=float(ms),
                f_value=float(f_val),
                p_value=self._parse_pvalue(p_val)
            ))
        
        # Parsear CV y R²
        cv_match = re.search(r"CV\s*=\s*([\d.]+)\s*%", text)
        r2_match = re.search(r"R²\s*=\s*([\d.]+)", text)
        
        return ANOVAResult(
            anova_table=rows,
            r_squared=float(r2_match.group(1)) if r2_match else None,
            cv_percent=float(cv_match.group(1)) if cv_match else None,
            means_table=self._parse_means_table(text),
            multiple_comparison_method=self._detect_comparison_method(text)
        )

    def _parse_pvalue(self, p_str: str) -> float | None:
        p_str = p_str.strip()
        if p_str.startswith("<"):
            return float(p_str[1:])
        try:
            return float(p_str)
        except ValueError:
            return None

    def _parse_means_table(self, text: str) -> list[dict]:
        """Parsea la tabla de medias con letras de comparación múltiple."""
        # Formato InfoStat: Grupo | Media | n | Letras
        means = []
        # Implementación específica según el formato de InfoStat
        pattern = re.compile(r"(\S+)\s+([\d.]+)\s+(\d+)\s+([A-Za-z]+)", re.MULTILINE)
        for match in pattern.finditer(text):
            group, mean, n, letter = match.groups()
            means.append({"group": group, "mean": float(mean), "n": int(n), "letter": letter})
        return means

    def _detect_comparison_method(self, text: str) -> str | None:
        methods = {
            "DMS de Fisher": "lsd",
            "Tukey": "tukey",
            "Duncan": "duncan",
            "Scott y Knott": "scott_knott"
        }
        for name, code in methods.items():
            if name in text:
                return code
        return None
```

---

## Parte 3: Tool Implementation (FastMCP)

```python
# server.py
from mcp.server.fastmcp import FastMCP
from infostat.session import InfoStatSessionManager
from infostat.analysis.anova import run_anova
from infostat.validation.metadata import run_survey_metadata

mcp = FastMCP("InfoStat MCP Server")
session = InfoStatSessionManager()

@mcp.tool()
def infostat_launch(infostat_path: str | None = None, timeout_seconds: float = 30) -> dict:
    """Lanza InfoStat y establece una sesión activa."""
    try:
        session.launch(exe_path=infostat_path, timeout=timeout_seconds)
        return {"success": True, "message": "InfoStat lanzado correctamente.", "pid": session.pid}
    except Exception as e:
        return {"success": False, "error": str(e)}

@mcp.tool()
def stats_anova(
    response_variable: str,
    design: str,
    treatment_factors: list[str],
    block_variable: str | None = None,
    multiple_comparison: str = "lsd",
    alpha: float = 0.05,
    check_assumptions: bool = True
) -> dict:
    """
    Ejecuta un Análisis de la Varianza (ANAVA) en InfoStat.
    
    Diseños soportados: completely_randomized, randomized_blocks, latin_square,
    factorial, nested, split_plot, split_split_plot.
    """
    if not session.is_ready():
        return {"success": False, "error": "InfoStat no está activo. Llame primero a infostat_launch."}
    
    try:
        result = run_anova(
            session=session,
            response_variable=response_variable,
            design=design,
            treatment_factors=treatment_factors,
            block_variable=block_variable,
            multiple_comparison=multiple_comparison,
            alpha=alpha,
            check_assumptions=check_assumptions
        )
        return {"success": True, "operation": "stats_anova", "result": result}
    except Exception as e:
        return {"success": False, "error": str(e), "operation": "stats_anova"}

if __name__ == "__main__":
    mcp.run()
```

---

## Parte 4: Flujos Agénticos de Ejemplo

### Flujo 1: ANAVA completo con comparaciones múltiples

El agente debería poder ejecutar este flujo de forma autónoma:

```
1. infostat_launch()
2. data_load(file_path="experimento_trigo.csv")
3. data_get_info()  → verificar variables disponibles
4. stats_normality_test(variable="Rendimiento", grouping_variable="Variedad")
5. stats_anova(
     response_variable="Rendimiento",
     design="completely_randomized",
     treatment_factors=["Variedad"],
     multiple_comparison="tukey",
     alpha=0.05
   )
6. graph_create(chart_type="boxplot", x_variable="Variedad", y_variable="Rendimiento")
7. graph_export(output_path="boxplot_variedades.png")
8. results_get_last()  → leer tabla ANAVA y medias
9. infostat_close()
```

### Flujo 2: Análisis de regresión no lineal

```
1. infostat_launch()
2. data_load(file_path="crecimiento_bovino.xlsx")
3. stats_descriptive_summary(variables=["Peso"], grouping_variable="Semana")
4. graph_create(chart_type="scatter", x_variable="Semana", y_variable="Peso")
5. stats_regression_nonlinear(
     response_variable="Peso",
     predictor_variable="Semana",
     model="gompertz"
   )
6. graph_export(output_path="ajuste_gompertz.png")
7. results_get_last()
```

### Flujo 3: Análisis multivariado completo

```
1. infostat_launch()
2. data_load(file_path="germoplasma_soja.csv")
3. stats_descriptive_summary(variables=["Altura", "Rendimiento", "ProtPct", "AceitePct"])
4. stats_pca(variables=["Altura", "Rendimiento", "ProtPct", "AceitePct"], grouping_variable="Origen")
5. graph_export(output_path="biplot_pca.png")
6. stats_cluster_hierarchical(
     variables=["Altura", "Rendimiento", "ProtPct", "AceitePct"],
     distance_metric="gower",
     linkage_method="ward"
   )
7. graph_export(output_path="dendrograma.png")
8. results_get_last()
```

---

## Parte 5: Estrategia de Testing

### Tests de integración (requieren InfoStat instalado)

```python
# tests/test_anova.py
import pytest
from infostat.session import InfoStatSessionManager

@pytest.fixture(scope="session")
def infostat_session():
    session = InfoStatSessionManager()
    session.launch(exe_path="C:/Program Files/InfoStat/InfoStat.exe")
    yield session
    session.close()

def test_anova_completely_randomized(infostat_session, tmp_path):
    # Crear dataset de prueba
    test_data = tmp_path / "test_anova.csv"
    test_data.write_text("Tratamiento,Rendimiento\nA,23.4\nA,25.1\nA,22.8\nB,18.2\nB,19.5\nB,17.9\n")
    
    infostat_session.data_load(str(test_data))
    result = infostat_session.run_anova(
        response_variable="Rendimiento",
        design="completely_randomized",
        treatment_factors=["Tratamiento"]
    )
    
    assert result["success"] is True
    assert "anova_table" in result["result"]
    assert result["result"]["anova_table"][0]["p_value"] < 0.05

def test_anova_returns_means_with_letters(infostat_session, tmp_path):
    # ... similar setup ...
    result = infostat_session.run_anova(
        response_variable="Rendimiento",
        design="completely_randomized",
        treatment_factors=["Tratamiento"],
        multiple_comparison="tukey"
    )
    means = result["result"]["means_table"]
    assert all("letter" in m for m in means)
```

### Tests de parsers (sin InfoStat, usando texto de ejemplo)

```python
# tests/test_result_parsers.py
from infostat.results.capture import InfoStatResultsCapture

SAMPLE_ANOVA_OUTPUT = """
Análisis de la Varianza
Variable: Rendimiento

Fuente de variación  GL    SC        CM       F-valor   Pr>F
Tratamiento           3   145.234    48.411   12.301    0.0002
Error                20    78.547     3.927
Total                23   223.781

CV = 8.43 %   R² = 0.649

Test DMS de Fisher Alfa=0.05 DMS=3.512
Medias con una letra común no son significativamente diferentes

Tratamiento  Media    n    E.E.
A            23.40    6    0.809  a
B            19.10    6    0.809   b
C            21.50    6    0.809  ab
D            18.20    6    0.809   b
"""

def test_parse_anova_table():
    capture = InfoStatResultsCapture(app=None)
    result = capture.parse_anova_table(SAMPLE_ANOVA_OUTPUT)
    
    assert result.r_squared == 0.649
    assert result.cv_percent == 8.43
    assert len(result.anova_table) == 3
    assert result.anova_table[0].f_value == 12.301
    assert result.anova_table[0].p_value == 0.0002
    assert result.multiple_comparison_method == "lsd"
    assert len(result.means_table) == 4
```

---

## Parte 6: Configuración del Servidor

```toml
# config.toml
[infostat]
exe_path = "C:/Program Files/InfoStat/InfoStat.exe"
data_base_dir = "C:/Users/usuario/Documentos/InfoStat/datos"
results_base_dir = "C:/Users/usuario/Documentos/InfoStat/resultados"

[timeouts]
launch_seconds = 30
dialog_appear_seconds = 10
analysis_complete_seconds = 120
menu_navigate_seconds = 5

[mcp]
host = "127.0.0.1"
port = 8765
transport = "stdio"  # o "http" para uso remoto local

[security]
allowed_extensions = [".csv", ".xls", ".xlsx", ".dbf", ".txt"]
max_file_size_mb = 100
```
