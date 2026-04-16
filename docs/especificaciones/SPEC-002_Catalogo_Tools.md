# SPEC-002: Catálogo Completo de Tools MCP-InfoStat
> Definición de todas las tools necesarias para análisis cuantitativo completo

---

## Principios de Diseño

1. **Una tool por intención, no por menú.** El agente debe poder decir "ejecuta un ANAVA de un factor" y la tool se encarga de toda la navegación interna.
2. **Parámetros semánticos, no coordenadas de pantalla.** Los parámetros deben ser nombres de variables, opciones estadísticas, etc. — nunca coordenadas pixel.
3. **Siempre retornar datos estructurados.** No texto plano: tablas parseadas, p-valores como números, estadísticos como floats.
4. **Tools atómicas y componibles.** El agente debe poder encadenar tools en workflows multi-paso.

---

## DOMINIO 1: Control del Software (5 tools)

### `infostat_launch`
Lanza InfoStat y espera a que esté listo.

```json
{
  "name": "infostat_launch",
  "description": "Lanza InfoStat y establece una sesión activa. Debe llamarse antes que cualquier otra tool.",
  "inputSchema": {
    "type": "object",
    "properties": {
      "infostat_path": {
        "type": "string",
        "description": "Path al ejecutable InfoStat.exe. Si no se provee, usa el configurado en config.toml."
      },
      "timeout_seconds": {
        "type": "number",
        "default": 30
      }
    }
  }
}
```

### `infostat_close`
Cierra InfoStat de forma limpia (con opción de guardar).

```json
{
  "name": "infostat_close",
  "inputSchema": {
    "type": "object",
    "properties": {
      "save_before_close": { "type": "boolean", "default": false }
    }
  }
}
```

### `infostat_status`
Retorna el estado actual de la sesión InfoStat.

```json
{
  "name": "infostat_status",
  "description": "Retorna si InfoStat está corriendo, qué dataset tiene cargado, y si está listo para recibir comandos.",
  "inputSchema": { "type": "object", "properties": {} }
}
```

### `infostat_screenshot`
Captura una imagen de la ventana actual de InfoStat (para diagnóstico).

### `infostat_reset`
Cierra y relanza InfoStat en caso de estado inconsistente.

---

## DOMINIO 2: Carga y Gestión de Datos (10 tools)

### `data_load`
Carga un archivo de datos en InfoStat.

```json
{
  "name": "data_load",
  "description": "Carga un archivo de datos en InfoStat. Soporta .dbf, .xls, .xlsx, .csv, .txt.",
  "inputSchema": {
    "type": "object",
    "required": ["file_path"],
    "properties": {
      "file_path": { "type": "string" },
      "sheet_name": { "type": "string", "description": "Solo para Excel, nombre de la hoja." },
      "delimiter": { "type": "string", "description": "Solo para CSV/TXT." },
      "has_header": { "type": "boolean", "default": true }
    }
  }
}
```

### `data_save`
Guarda la tabla actual en InfoStat.

```json
{
  "name": "data_save",
  "inputSchema": {
    "type": "object",
    "properties": {
      "file_path": { "type": "string", "description": "Si no se provee, sobreescribe el archivo original." },
      "format": { "type": "string", "enum": ["dbf", "xls", "csv"], "default": "dbf" }
    }
  }
}
```

### `data_get_info`
Retorna información de la tabla cargada: nombres de columnas, tipos, cantidad de filas/columnas, valores faltantes.

### `data_set_variable_type`
Cambia el tipo de una variable (numérica, alfanumérica, fecha).

```json
{
  "name": "data_set_variable_type",
  "inputSchema": {
    "type": "object",
    "required": ["variable", "type"],
    "properties": {
      "variable": { "type": "string" },
      "type": { "type": "string", "enum": ["numeric", "text", "date"] }
    }
  }
}
```

### `data_transform`
Aplica transformaciones matemáticas a una variable.

```json
{
  "name": "data_transform",
  "description": "Crea una nueva columna como transformación de una variable existente.",
  "inputSchema": {
    "type": "object",
    "required": ["source_variable", "transformation", "new_variable_name"],
    "properties": {
      "source_variable": { "type": "string" },
      "transformation": {
        "type": "string",
        "enum": ["log", "sqrt", "square", "reciprocal", "rank", "logit", "probit", "uniform", "power"],
        "description": "Tipo de transformación según InfoStat."
      },
      "power_value": { "type": "number", "description": "Solo para transformation='power'." },
      "new_variable_name": { "type": "string" }
    }
  }
}
```

### `data_categorize`
Categoriza una variable numérica en grupos (usando la función Categorizar de InfoStat).

### `data_filter_cases`
Activa/desactiva casos según una condición (equivalente a "Seleccionar caso" en InfoStat).

```json
{
  "name": "data_filter_cases",
  "inputSchema": {
    "type": "object",
    "required": ["condition"],
    "properties": {
      "condition": {
        "type": "string",
        "description": "Expresión de filtro. Ej: 'Tratamiento = A AND Peso > 10'"
      },
      "mode": {
        "type": "string",
        "enum": ["activate_matching", "deactivate_matching", "activate_all"],
        "default": "activate_matching"
      }
    }
  }
}
```

### `data_create_variable`
Crea una nueva variable con fórmula (equivalente a "Fórmulas" en InfoStat).

### `data_create_dummies`
Crea variables auxiliares (dummy) desde una variable categórica.

### `data_merge`
Une dos tablas (por columnas o por filas).

---

## DOMINIO 3: Análisis Estadísticos (30+ tools)

### Estadística Descriptiva

#### `stats_descriptive_summary`
Ejecuta medidas resumen para una o más variables.

```json
{
  "name": "stats_descriptive_summary",
  "description": "Calcula medidas resumen (media, mediana, desvío, mín, máx, CV, asimetría, curtosis) para las variables seleccionadas.",
  "inputSchema": {
    "type": "object",
    "required": ["variables"],
    "properties": {
      "variables": {
        "type": "array",
        "items": { "type": "string" },
        "description": "Lista de variables cuantitativas."
      },
      "grouping_variable": {
        "type": "string",
        "description": "Variable categórica para calcular descriptivos por grupo."
      },
      "statistics": {
        "type": "array",
        "items": { "type": "string", "enum": ["mean", "median", "sd", "cv", "min", "max", "q1", "q3", "skewness", "kurtosis", "n", "na_count"] },
        "default": ["n", "mean", "sd", "cv", "min", "max"]
      }
    }
  }
}
```

**Respuesta esperada:**
```json
{
  "success": true,
  "operation": "stats_descriptive_summary",
  "result": {
    "table": [
      { "variable": "Peso", "group": "A", "n": 15, "mean": 23.4, "sd": 2.1, "cv": 8.97, "min": 19.2, "max": 27.8 }
    ]
  }
}
```

#### `stats_frequency_table`
Tablas de frecuencias para variables categóricas.

#### `stats_normality_test`
Prueba de normalidad (Shapiro-Wilks, Kolmogorov-Smirnov).

```json
{
  "name": "stats_normality_test",
  "inputSchema": {
    "type": "object",
    "required": ["variable"],
    "properties": {
      "variable": { "type": "string" },
      "test": { "type": "string", "enum": ["shapiro_wilks", "kolmogorov_smirnov"], "default": "shapiro_wilks" },
      "grouping_variable": { "type": "string" }
    }
  }
}
```

---

### Inferencia

#### `stats_t_test_one_sample`
Prueba T para una muestra.

```json
{
  "name": "stats_t_test_one_sample",
  "inputSchema": {
    "type": "object",
    "required": ["variable", "null_mean"],
    "properties": {
      "variable": { "type": "string" },
      "null_mean": { "type": "number" },
      "alpha": { "type": "number", "default": 0.05 },
      "alternative": { "type": "string", "enum": ["two_sided", "less", "greater"], "default": "two_sided" }
    }
  }
}
```

#### `stats_t_test_two_samples`
Prueba T para dos muestras independientes (con prueba de Levene de homogeneidad de varianzas).

#### `stats_t_test_paired`
Prueba T para observaciones apareadas (y Wilcoxon apareado).

#### `stats_nonparametric_one_sample`
Pruebas no paramétricas para una muestra (rachas, signos, Wilcoxon).

#### `stats_nonparametric_two_samples`
Pruebas para dos muestras independientes (Mann-Whitney, Kolmogorov-Smirnov, Van Der Waerden, Wald-Wolfowitz).

#### `stats_proportion_test`
Prueba de proporciones (una y dos muestras).

---

### Análisis de la Varianza

#### `stats_anova`
Análisis de la varianza. Tool central y más compleja.

```json
{
  "name": "stats_anova",
  "description": "Ejecuta un ANAVA en InfoStat. Soporta los principales diseños experimentales.",
  "inputSchema": {
    "type": "object",
    "required": ["response_variable", "design"],
    "properties": {
      "response_variable": { "type": "string" },
      "design": {
        "type": "string",
        "enum": [
          "completely_randomized",
          "randomized_blocks",
          "latin_square",
          "factorial",
          "nested",
          "split_plot",
          "split_split_plot"
        ]
      },
      "treatment_factors": {
        "type": "array",
        "items": { "type": "string" },
        "description": "Variables de tratamiento (factores)."
      },
      "block_variable": { "type": "string", "description": "Variable de bloque (si aplica)." },
      "row_variable": { "type": "string", "description": "Variable de fila (para cuadrado latino)." },
      "col_variable": { "type": "string", "description": "Variable de columna (para cuadrado latino)." },
      "whole_plot_factor": { "type": "string", "description": "Factor de parcela principal (split plot)." },
      "sub_plot_factor": { "type": "string", "description": "Factor de sub-parcela (split plot)." },
      "multiple_comparison": {
        "type": "string",
        "enum": ["none", "lsd", "tukey", "duncan", "snk", "bonferroni", "scheffe", "scott_knott", "joliffe"],
        "default": "lsd"
      },
      "alpha": { "type": "number", "default": 0.05 },
      "check_assumptions": { "type": "boolean", "default": true }
    }
  }
}
```

**Respuesta esperada:**
```json
{
  "result": {
    "anova_table": [
      { "source": "Tratamiento", "df": 3, "ss": 145.2, "ms": 48.4, "f_value": 12.3, "p_value": 0.0002 },
      { "source": "Error", "df": 20, "ss": 78.5, "ms": 3.925, "f_value": null, "p_value": null },
      { "source": "Total", "df": 23, "ss": 223.7, "ms": null, "f_value": null, "p_value": null }
    ],
    "r_squared": 0.649,
    "cv_percent": 8.43,
    "means_table": [
      { "group": "A", "mean": 23.4, "n": 6, "letter": "a" },
      { "group": "B", "mean": 19.1, "n": 6, "letter": "b" }
    ],
    "multiple_comparison_method": "lsd",
    "normality_test": { "test": "shapiro_wilks", "statistic": 0.962, "p_value": 0.412 },
    "homogeneity_test": { "test": "levene", "statistic": 1.24, "p_value": 0.318 }
  }
}
```

#### `stats_ancova`
Análisis de covarianza.

#### `stats_kruskal_wallis`
Prueba de Kruskal-Wallis (ANAVA no paramétrico).

#### `stats_friedman`
Prueba de Friedman.

---

### Regresión

#### `stats_regression_linear`
Regresión lineal simple y múltiple.

```json
{
  "name": "stats_regression_linear",
  "inputSchema": {
    "type": "object",
    "required": ["response_variable", "predictor_variables"],
    "properties": {
      "response_variable": { "type": "string" },
      "predictor_variables": { "type": "array", "items": { "type": "string" } },
      "include_intercept": { "type": "boolean", "default": true },
      "stepwise": { "type": "string", "enum": ["none", "forward", "backward", "both"], "default": "none" },
      "alpha_in": { "type": "number", "default": 0.05 },
      "alpha_out": { "type": "number", "default": 0.10 },
      "check_assumptions": { "type": "boolean", "default": true }
    }
  }
}
```

#### `stats_regression_nonlinear`
Regresión no lineal (modelos predeterminados de InfoStat: Gompertz, logístico, monomolecular, Richards, von Bertalanffy, etc.).

```json
{
  "name": "stats_regression_nonlinear",
  "inputSchema": {
    "type": "object",
    "required": ["response_variable", "predictor_variable", "model"],
    "properties": {
      "response_variable": { "type": "string" },
      "predictor_variable": { "type": "string" },
      "model": {
        "type": "string",
        "enum": ["logistic", "gompertz", "monomolecular", "richards", "von_bertalanffy", "exponential", "power", "custom"]
      },
      "initial_params": { "type": "object", "description": "Valores iniciales de parámetros para el ajuste." },
      "custom_formula": { "type": "string", "description": "Solo para model='custom'." }
    }
  }
}
```

#### `stats_regression_logistic`
Regresión logística (variable respuesta binaria o politómica).

#### `stats_regression_pls`
Regresión por Mínimos Cuadrados Parciales (PLS).

#### `stats_correlation`
Coeficientes de correlación (Pearson, Spearman, Kendall), correlaciones parciales y path analysis.

---

### Datos Categorizados

#### `stats_contingency_table`
Tablas de contingencia con Chi-cuadrado, Fisher, riesgo relativo, odds ratio.

#### `stats_kaplan_meier`
Análisis de sobrevida de Kaplan-Meier.

---

### Análisis Multivariado

#### `stats_pca`
Análisis de componentes principales.

```json
{
  "name": "stats_pca",
  "inputSchema": {
    "type": "object",
    "required": ["variables"],
    "properties": {
      "variables": { "type": "array", "items": { "type": "string" } },
      "use_correlation_matrix": { "type": "boolean", "default": true },
      "n_components": { "type": "integer", "description": "Número de componentes a retener. Null = criterio Kaiser." },
      "grouping_variable": { "type": "string" }
    }
  }
}
```

#### `stats_cluster_hierarchical`
Análisis de conglomerados jerárquico.

```json
{
  "name": "stats_cluster_hierarchical",
  "inputSchema": {
    "type": "object",
    "required": ["variables"],
    "properties": {
      "variables": { "type": "array", "items": { "type": "string" } },
      "distance_metric": {
        "type": "string",
        "enum": ["euclidean", "manhattan", "gower", "jaccard", "simple_matching", "pearson", "spearman"],
        "default": "euclidean"
      },
      "linkage_method": {
        "type": "string",
        "enum": ["ward", "complete", "average", "single", "centroid"],
        "default": "ward"
      },
      "standardize": { "type": "boolean", "default": false }
    }
  }
}
```

#### `stats_cluster_kmeans`
Conglomerados no jerárquicos (K-means).

#### `stats_discriminant`
Análisis discriminante.

#### `stats_canonical_correlation`
Correlaciones canónicas.

#### `stats_correspondence`
Análisis de correspondencias.

#### `stats_principal_coordinates`
Análisis de coordenadas principales.

#### `stats_manova`
Análisis de la varianza multivariado (MANOVA).

#### `stats_procrustes`
Procrustes generalizado.

#### `stats_classification_tree`
Árbol de clasificación.

#### `stats_regression_tree`
Árbol de regresión.

---

### Series de Tiempo

#### `stats_arima`
Modelado ARIMA (Box-Jenkins completo).

```json
{
  "name": "stats_arima",
  "inputSchema": {
    "type": "object",
    "required": ["time_variable", "series_variable"],
    "properties": {
      "time_variable": { "type": "string" },
      "series_variable": { "type": "string" },
      "p": { "type": "integer", "description": "Orden AR." },
      "d": { "type": "integer", "description": "Orden de diferenciación." },
      "q": { "type": "integer", "description": "Orden MA." },
      "seasonal_p": { "type": "integer" },
      "seasonal_d": { "type": "integer" },
      "seasonal_q": { "type": "integer" },
      "seasonal_period": { "type": "integer" },
      "auto_identify": { "type": "boolean", "default": false, "description": "Si true, InfoStat intenta identificar el modelo automáticamente." }
    }
  }
}
```

#### `stats_unit_root_test`
Prueba de raíz unitaria (Dickey-Fuller, Phillips-Perron).

#### `stats_cross_correlation`
Correlaciones cruzadas.

#### `stats_power_spectrum`
Espectro de potencia.

#### `stats_smoothing`
Suavizados (media móvil, exponencial simple/doble, Holt-Winters).

---

### Control de Calidad

#### `stats_qc_control_chart`
Diagramas de control (Shewhart para variables y atributos).

```json
{
  "name": "stats_qc_control_chart",
  "inputSchema": {
    "type": "object",
    "required": ["variable", "chart_type"],
    "properties": {
      "variable": { "type": "string" },
      "subgroup_variable": { "type": "string" },
      "chart_type": {
        "type": "string",
        "enum": ["xbar_r", "xbar_s", "i_mr", "p", "np", "c", "u"]
      }
    }
  }
}
```

#### `stats_qc_process_capability`
Capacidad de proceso (Cp, Cpk, Pp, Ppk).

#### `stats_pareto`
Diagrama de Pareto.

---

## DOMINIO 4: Lectura de Resultados (3 tools)

### `results_get_last`
Retorna los últimos resultados generados por InfoStat, parseados.

```json
{
  "name": "results_get_last",
  "description": "Retorna el contenido parseado de la ventana de resultados de InfoStat.",
  "inputSchema": {
    "type": "object",
    "properties": {
      "format": { "type": "string", "enum": ["structured", "raw_text"], "default": "structured" }
    }
  }
}
```

### `results_save`
Guarda los resultados actuales a un archivo.

### `results_clear`
Limpia la ventana de resultados.

---

## DOMINIO 5: Gráficos (4 tools)

### `graph_create`
Crea un gráfico en InfoStat.

```json
{
  "name": "graph_create",
  "inputSchema": {
    "type": "object",
    "required": ["chart_type"],
    "properties": {
      "chart_type": {
        "type": "string",
        "enum": ["scatter", "dots", "bar", "boxplot", "density", "qqplot", "ecdf", "histogram", "profile", "stars", "pie", "stacked_bar", "scatter_matrix"]
      },
      "x_variable": { "type": "string" },
      "y_variable": { "type": "string" },
      "grouping_variable": { "type": "string" },
      "title": { "type": "string" },
      "x_label": { "type": "string" },
      "y_label": { "type": "string" }
    }
  }
}
```

### `graph_export`
Exporta el gráfico actual a un archivo de imagen.

```json
{
  "name": "graph_export",
  "inputSchema": {
    "type": "object",
    "required": ["output_path"],
    "properties": {
      "output_path": { "type": "string" },
      "format": { "type": "string", "enum": ["png", "jpg", "bmp", "emf"], "default": "png" },
      "width_px": { "type": "integer", "default": 800 },
      "height_px": { "type": "integer", "default": 600 }
    }
  }
}
```

### `graph_list_open`
Lista los gráficos actualmente abiertos en InfoStat.

### `graph_close_all`
Cierra todos los gráficos abiertos.

---

## Resumen: Conteo de Tools

| Dominio | Tools | Estado actual |
|---|---|---|
| Control del software | 5 | 0 implementadas |
| Carga y gestión de datos | 10 | 0 implementadas |
| Estadística descriptiva | 3 | 0 implementadas |
| Inferencia | 6 | 0 implementadas |
| ANAVA | 4 | 0 implementadas |
| Regresión | 5 | 0 implementadas |
| Datos categorizados | 2 | 0 implementadas |
| Multivariado | 10 | 0 implementadas |
| Series de tiempo | 5 | 0 implementadas |
| Control de calidad | 3 | 0 implementadas |
| Lectura de resultados | 3 | 0 implementadas |
| Gráficos | 4 | 0 implementadas |
| Pre-procesamiento (existentes) | 4 | 4 implementadas (mejorar) |
| **TOTAL** | **64** | **4 (6%)** |
