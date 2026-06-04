# Notas técnicas - decisiones, supuestos y siguientes pasos

## 1. Estado actual del trabajo

- Phase 1 (EDA y calidad de datos): completado.
- Phase 2 (staging `stg_*.sql`): completado para las 10 tablas raw.
- Tests de staging: definidos en `dbt_proyecto/models/staging/stg_core.yml`.
- Phase 2 marts: completado (modelos creados y ejecutando correctamente).
- Phase 3 dashboard: Completado.

Estas notas recogen el razonamiento de limpieza/modelado y los supuestos usados.

## 2. Decisiones de limpieza (staging) y justificación

A nivel general, para estandarización.

1. Conversión de IDs a tipo entero.
- Decisión: `cast(... as integer)` para PK/FK.
- Justificación: evita errores en joins por diferencias de tipo y asegura consistencia referencial.

2. Estandarización de textos categóricos y códigos.
- Decisión: uso de `trim()` y `upper()` en códigos y categorías.
- Justificación: elimina ruido por espacios/mayúsculas y evita duplicidad lógica de valores.
- Nota adicional: cuando los códigos de negocio resultan inconsistentes, duplicados o vacíos, se priorizó el uso de `id`/PK en los marts finales para asegurar relaciones robustas.

3. Conversión de strings vacíos a null.
- Decisión: `nullif(trim(campo), '')`.
- Justificación: cadena vacía no aporta información real; mejora perfilado de nulos y calidad analítica.

4. Normalización de fechas con formato mixto.
- Decisión: `coalesce(try_strptime(...'%Y-%m-%d'), try_strptime(...'%d/%m/%Y'))`.
- Justificación: en raw hay formatos mixtos; esta regla minimiza pérdida de datos.

5. Conversión explícita de booleanos.
- Decisión: cast de flags a boolean (`is_active`, `is_client_billable`, `main_employee`, etc.).
- Justificación: asegura filtros consistentes.

6. Desduplicación por clave de negocio con criterio de la fecha más reciente.
- Decisión: `row_number()` por PK y orden por `updated_at*` descendente; se conserva `row_num = 1`.
- Justificación: existen duplicados y se prioriza el estado más reciente.

7. Señales de calidad referencial.
- Decisión: crear flags `fk_*_valid` en modelos con relaciones críticas.
- Justificación: permite diagnosticar si la FK esta bien o mal, sin eliminar registros todavia, para observar calidad de dato.

8. Autocompletar columnas críticas con vacíos importantes.
- Decisión: rellenar valores faltantes solo cuando había una regla clara (ej. `project_code`, `route_code`, `client_code`), y dejar marcado el relleno como derivado.
- Justificación: sin esta imputación parcial, se perderían filas clave en los marts y se dañaría la calidad del análisis, aunque esto añade un nivel de incertidumbre que debe documentarse.

### 2.1 Decisiones por tabla

`stg_clients`
- Problema: en clientes hay códigos y países escritos de formas distintas (mayúsculas, espacios, etc.) y además algunos`client_id` están repetidos.
- Solución: se limpia `client_country`, se conserva `client_name`/`client_sector`, y `client_code` se recupera desde proyectos por `client_id` porque no viene en `raw_clients`. Tambien se deja un solo registro por `client_id` (el mas reciente por `updated_at_sys`).
- Justificación: se adapta la limpieza al esquema real del raw sin inventar columnas inexistentes, manteniendo una clave de cliente util para cruces.

`stg_projects`
- Problema: `project_code` ausente en algunos registros.
- Solución: cuando falta se completa siguiendo el formato `PRJ_UNK_<project_id>`.
- Justificación: evita perder este registro que podria afectar en analisis, y además se ve claramente que fue rellenado y no venia dato original.

`stg_campaigns`
- Problema: categorías nulas `campaign_state` y numéricos faltantes `visit_duration_minutes`.
- Solución: en `campaign_state` se transforman vacios a `null` con `nullif(trim(campaign_state), '')`; en `visit_duration_minutes` se convierten nulos a `0.0` con `coalesce(cast(visit_duration_minutes as float), 0.0)`.
- Observación adicional: la columna de trabajador en campañas aparece vacía en varios registros; debería normalizarse a un valor explicito como `No asignado` / `No especificado` para evitar ambigüedad en el análisis.
- Justificación: en los dashboards y marts es preferible distinguir un trabajador no asignado de un dato perdido, mejorando la interpretabilidad.

`stg_*` (tipado de fechas)
- Problema: varios campos que en origen eran solo fecha se estaban materializando como datetime/timestamp, mostrando `00:00:00` artificial en CSV/BI.
- Solución: se homogeneizo el tipado a `DATE` en campos de fecha de negocio y fechas de sistema de staging (`created_at`, `updated_at`, `updated_at_sys`, `deleted_at`, `visit_date`, `route_start_date`, `route_end_date`, `campaign_start_date`, `campaign_end_date`, `employee_hire_date`).
- Justificación: respeta mejor el grano temporal real del dato origen y evita ruido visual en Power BI.

`stg_questions`
- Problema: inconsistencias de formato en `question_type`/`question_code`.
- Solución: normalización de texto y nulos controlados.
- Justificación: asegura que los tipos y códigos de pregunta sean consistentes para filtrar, agrupar y analizar correctamente, sin mezclar categorías por diferencias de formato.

`stg_workers`
- Problema: inconsistencias en provincia/tipo contrato y nulos en contrato.
- Solución: se normaliza el texto dejandolos vacios como `null`.
- Justificación: así mantenemos consistencia de formato para analizar por provincia/tipo de contrato y, al mismo tiempo, conservamos como faltante real la información que no viene en origen.

`stg_pos`
- Problema: campos geográficos y postales con tipos no consistentes.
- Solución: casteo a tipos numéricos y normalización de localidad/provincia.
- Justificación: permite hacer analisis por zona sin errores de tipo.

`stg_routes`
- Problema: falta `route_code` en parte de los registros.
- Solución: se crea código `RUT_UNK_<route_id>` y se estandariza.
- Justificación: sí cada ruta se puede identificar bien y no da problemas al cruzar datos o agrupar en reportes.

`stg_visits`
- Problema: `route_id`  viene vacío o no coincide con una ruta existente.
- Solución: permitir null en `route_id`; y se valida la FK solo cuando ese campo viene informado.
- Justificación:  así no se pierden visitas reales por un dato faltante de ruta y se mantiene visible el problema de calidad para revisarlo después.

`stg_responses`
- Problema: si tocamos mucho los textos de respuesta, podemos cambiar su significado real.
- Solución: limpieza mínima en `answer`/`expected_answer` (trim/nullif), quitar espacios y pasar vacíos a null, sin modificar el contenido.
- Justificación: así mantenemos el dato tal como viene de origen, pero más limpio para analizarlo sin ruido.

## 3. Supuestos de modelado y negocio

1. En staging solo limpiamos y ordenamos datos; no aplicamos reglas de negocio finales.
2. Si hay duplicados, nos quedamos con el registro más reciente (`updated_at` / `updated_at_sys`).
3. Si una fecha no se puede convertir, se deja en `null`.
4. En visitas, `route_id` puede venir vacío y eso se acepta en staging.
5. Si el dato origen solo trae fecha (sin hora), el modelo expone `DATE`.

## 4. Documentación del Dashboard y justificación de KPIs

El dashboard de Power BI está diseñado en dos páginas separadas por rol de usuario, para que la dirección y la operación obtengan insights distintos pero alineados con el modelo de datos gestionado en dbt.

### Página 1: Visión de Portafolio (Management View)

- Objetivo: auditar la salud global de clientes y proyectos.
- KPIs principales:
  * `Visitas Totales` (1,747): mide el volumen absoluto de actividad comercial.
  * `Campañas Totales` (72): inventario de campañas activas y cerradas.
  * `Tasa de Finalización de Campañas` (88.09%): indicador clave de cumplimiento del compromiso de visitas.
- Notas de calidad de datos:
  * Se detectaron 13 campañas con `campaign_state` en blanco.
  * Se aplicó una regla de negocio en el modelo para inferir `Activa` o `Cerrada` desde `campaign_end_date`, evitando excluir registros y preservando el volumen total.
- Visualización destacada: barras horizontales de rendimiento de campañas activas.
  * Permite aislar campañas activas y detectar tendencias de rendimiento.
  * Insight clave: campañas iniciadas en febrero 2026 muestran una desaceleración crítica (≈75%), funcionando como alerta temprana.

### Página 2: Control de Rutas (Operations View)

- Objetivo: dar visibilidad diaria al equipo de supervisión de rutas y visitas.
- KPIs principales:
  * `Trabajadores Activos` (35): fuerza laboral disponible.
  * `Visitas Pendientes` (208): trabajo asignado sin completar.
  * Decisión soportada: permite actuar para reducir el número a cero antes del cierre del día.
- Visualización destacada: columnas apiladas de estado de ejecución por trabajador con filtro dropdown.
  * Facilita la búsqueda por trabajador y el análisis de estados de visita.
  * Insights clave:
    1. Bloque masivo de visitas sin empleado asociado (>1,100), indicando un fallo de calidad de datos en origen y una auditoría técnica necesaria.
    2. Saturación en Javier y Lucía: alta carga de trabajo con volumen importante de visitas “Completadas con incidencia”, indicando problemas de efectividad operativa.

### 4.1 Impacto para el documento acompañante

- Este archivo `notes.md` complementa el dashboard aportando el contexto de modelado y limpieza que sustenta los KPIs.
- Incluye los supuestos de calidad y el razonamiento para no eliminar registros con datos faltantes en staging.
- Sirve como referencia técnica para explicar por qué los KPI del Power BI se construyen sobre un dataset que preserva datos críticos de negocio y destaca problemas de calidad detectados.

## 5. Limitaciones identificadas

- Puede haber nulos en campos clave de negocio (por ejemplo, estado de campana o route_id en visitas) porque se preserva el dato origen.
- La calidad referencial se marca con `fk_*_valid`, pero no se excluyen filas invalidas en staging.

### 4.1 Warning conocido en tests (visitas vs rutas)

- Test afectado: `relationships_stg_visits_route_id__route_id__ref_stg_routes_`.
- Resultado observado: 70 filas de `stg_visits` con `route_id` informado que no existe en `stg_routes`.
- Detalle de calidad: son 70 `route_id` distintos y cada uno aparece 1 vez.
- Estado actual: este test esta configurado con `severity: warn` en `dbt_proyecto/models/staging/stg_core.yml`, por lo que no bloquea `dbt build`.
- Interpretacion: no es error tecnico de dbt ni de SQL; es inconsistencia en datos de origen (FK huerfana).
- Impacto analitico: esas visitas no hacen match al analizar por ruta, pero siguen disponibles para analisis general de visitas/campanas.

### 4.2 Ajustes recientes en marts para BI

- `mart_campaign_performance` ahora incluye `project_id` y `client_id` (ademas de los codigos) para facilitar relaciones robustas en Power BI.
- Se mejoro el relleno de `client_name` con prioridad por `client_id` y fallback por `client_code`.
- Se detecto un caso de campañas sin `project_code` (por ejemplo, campañas asociadas a proyectos 15 y 22) que dejaba `project_id` nulo en el mart.
- Solución aplicada: fallback de `project_id` derivado desde `campaign_name` cuando falta `project_code`, y posterior enlace a cliente.
- Resultado validado en el mart: `project_id`, `client_id` y `client_name` sin nulos en el estado actual del dataset.
- Observación clave: la columna `campaign_active`/`campaign_state` no sigue una regla clara en el raw y no tiene sentido lógico consistente. Por seguridad, se prefirió mantener ambos campos con limpieza mínima y no basar KPI críticos únicamente en ellos.

## 5. Qué haría con más tiempo

- Agregar tests `accepted_values` para estados (`visit_status`, `campaign_state`, `question_type`).
- Definir umbrales de calidad (porcentaje maximo de FKs invalidas) y alertas.
- Documentar metricas de negocio del dashboard con definiciones formales.
- Revisar en profundidad el origen de las incidencias de `code` y `state` para evitar reglas ad-hoc en el futuro.
- Mejorar algunas tablas con más tiempo para auditar de dónde vienen los valores inconsistentes y definir reglas de imputación más robustas.
- Hacer un dashboard más visual y de mayor calidad; el actual es funcional pero muy simple y limitado por el tiempo disponible.


