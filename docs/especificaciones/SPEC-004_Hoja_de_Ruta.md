# SPEC-004: Hoja de Ruta de Implementación
> Plan de desarrollo por fases para el MCP-InfoStat rediseñado

---

## Fase 0: Eliminaciones y correcciones inmediatas

**Plazo estimado: 1 semana**

Antes de agregar nada nuevo, corregir los problemas actuales:

### Eliminar o refactorizar
- [ ] **Eliminar `r_routine`** en su forma actual (acepta plantillas R arbitrarias con `additionalProperties: true`). Si se mantiene para análisis que InfoStat no cubre, debe tener un registro de plantillas aprobadas hardcodeado en el servidor, nunca aceptar código libre del cliente.
- [ ] **Renombrar las 3 tools de validación** para dejar claro que son pre-procesamiento, no análisis de InfoStat. Prefijo sugerido: `validate_` en lugar de implicar que ejecutan InfoStat.
- [ ] **Agregar al README** una advertencia clara: "Este servidor actualmente realiza validación de datos. No interactúa con InfoStat como software."

### Mejorar tools existentes
- [ ] `survey_metadata`: agregar detección de tipo de variable según la clasificación de InfoStat (numérica continua, numérica discreta, nominal, ordinal).
- [ ] `quantitative_limits`: retornar también estadísticas básicas (media, mediana) junto con los outliers detectados.
- [ ] `logical_consistency`: retornar los registros inconsistentes con sus índices para que el agente pueda actuar sobre ellos.

---

## Fase 1: Infraestructura de automatización

**Plazo estimado: 3-4 semanas**
**Prerrequisito:** InfoStat instalado en el host de desarrollo; pywinauto instalado.

### Entregables
- [ ] `infostat_launch` — lanzar InfoStat y retornar estado de sesión
- [ ] `infostat_close` — cerrar limpiamente
- [ ] `infostat_status` — estado de la sesión actual
- [ ] `data_load` — cargar CSV, XLS, DBF en InfoStat
- [ ] `data_get_info` — retornar estructura de la tabla cargada
- [ ] `results_get_last` (versión raw text) — capturar ventana de resultados como texto plano

### Criterio de éxito
El agente puede: lanzar InfoStat → cargar un CSV → verificar variables → cerrar InfoStat. Sin ningún click manual del usuario.

### Riesgo principal
pywinauto puede fallar con versiones específicas de InfoStat si los controles de Windows no son accesibles vía UI Automation. Verificar con `inspect.exe` (herramienta de Microsoft) que los controles de InfoStat son navegables antes de empezar.

---

## Fase 2: Análisis estadístico básico

**Plazo estimado: 4-6 semanas**

### Entregables por prioridad

**Alta prioridad (los más usados):**
- [ ] `stats_descriptive_summary` + parser
- [ ] `stats_normality_test` + parser
- [ ] `stats_anova` (diseño completamente aleatorizado) + parser completo (tabla ANAVA + medias + letras)
- [ ] `stats_t_test_two_samples` + parser
- [ ] `stats_regression_linear` + parser

**Media prioridad:**
- [ ] `stats_anova` (bloques, factorial)
- [ ] `stats_correlation`
- [ ] `stats_kruskal_wallis`
- [ ] `stats_frequency_table`
- [ ] `stats_contingency_table`

### Criterio de éxito
El agente puede ejecutar un ANAVA completo (DCA, factorial, bloques) y retornar: tabla de ANAVA, R², CV, tabla de medias con letras de comparación múltiple, y resultados de supuestos — todo como JSON estructurado, sin intervención manual.

---

## Fase 3: Gráficos y exportación

**Plazo estimado: 2-3 semanas**

### Entregables
- [ ] `graph_create` (scatter, boxplot, barras, histograma — los más usados)
- [ ] `graph_export` (PNG/JPG)
- [ ] `data_save` — guardar tabla modificada
- [ ] `results_save` — guardar resultados a archivo
- [ ] `results_get_last` — versión con parsers estructurados por tipo de análisis

### Criterio de éxito
El agente puede generar un informe completo: análisis + gráficos exportados a archivos, todo automatizado.

---

## Fase 4: Análisis avanzados

**Plazo estimado: 6-8 semanas**

### Entregables
- [ ] `stats_anova` (parcelas divididas, sub-divididas, cuadrado latino, anidado)
- [ ] `stats_regression_nonlinear`
- [ ] `stats_regression_logistic`
- [ ] `stats_pca`
- [ ] `stats_cluster_hierarchical` + `stats_cluster_kmeans`
- [ ] `stats_discriminant`
- [ ] `data_transform`, `data_categorize`, `data_filter_cases`
- [ ] `data_create_variable` (fórmulas)
- [ ] `stats_arima` (series de tiempo)

---

## Fase 5: Cobertura completa

**Plazo estimado: 4-6 semanas adicionales**

### Entregables
- [ ] Tools de multivariado restantes (correspondencias, PLS, Procrustes, canónicas)
- [ ] Tools de control de calidad (cartas de control, Cp/Cpk, Pareto)
- [ ] Series de tiempo completas (espectro, suavizados, raíz unitaria)
- [ ] Gráficos restantes (estrellas, perfiles, Q-Q, ECDF)
- [ ] `stats_ancova`, `stats_manova`
- [ ] `stats_kaplan_meier`

---

## Métricas de Calidad por Fase

| Fase | Tools nuevas | Tests requeridos | Cobertura mínima de InfoStat |
|---|---|---|---|
| 0 | 0 (refactor) | 10 tests | — |
| 1 | 6 | 20 tests | Control de sesión 100% |
| 2 | 10+ | 50 tests | Análisis básicos 80% |
| 3 | 5 | 20 tests | Gráficos principales 70% |
| 4 | 12+ | 80 tests | Análisis avanzados 60% |
| 5 | 10+ | 60 tests | Cobertura total ~85% |

---

## Decisión Clave Antes de Comenzar

**¿Qué versión de InfoStat se va a automatizar?**

El manual provisto corresponde a InfoStat 2008. Existe InfoStat versión Professional (más reciente). Los títulos de ventanas, los textos de menú y la disposición de diálogos pueden diferir entre versiones. Se debe decidir y documentar la versión objetivo antes de escribir cualquier código de UI automation, ya que los selectores de controles son version-specific.

**Acción requerida:** Documentar en `config.toml` y en el README la versión exacta de InfoStat soportada y el sistema operativo (Windows 10/11). Agregar tests de compatibilidad en CI que verifiquen la versión de InfoStat antes de ejecutar cualquier tool.

---

## Deuda Técnica a Evitar

1. **No hardcodear coordenadas de pantalla** — usar siempre selectores de control por nombre/clase.
2. **No usar `time.sleep()` fijo** — usar siempre `wait_until_passes` con timeout configurable.
3. **No ignorar los diálogos de error de InfoStat** — capturar y retornar como errores estructurados.
4. **No asumir una única resolución de pantalla** — los controles de InfoStat deben localizarse por nombre, no por posición.
5. **No acumular texto de resultados entre análisis** — limpiar o marcar posición antes de cada análisis para parsear solo el output del análisis actual.
