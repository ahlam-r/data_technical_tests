# Fase 3 — Documentación del Dashboard y Justificación de KPIs

Para resolver la necesidad de negocio, se diseñó un reporte de Power BI dividido estratégicamente en dos páginas independientes. Separa el análisis según el rol del usuario (Management vs. Operations).

---

## Página 1: Visión de Portafolio (Management View)
Diseñada para responder a la necesidad de la dirección de auditar la salud global de los clientes y proyectos.

### KPIs Seleccionados y Justificación de Negocio:
*   **Visitas Totales (1,747):** Mide el volumen absoluto de actividad comercial requerida por el portafolio actual.
    *   *Decisión que soporta:* Permite a la dirección dimensionar el tamaño de la operación y el esfuerzo requerido por el negocio.
*   **Campañas Totales (72):** Control de inventario de proyectos comerciales activos y cerrados.
    *   *Nota de Calidad de Datos:* Se detectaron 13 campañas con estado en blanco. Se aplicó una regla de negocio avanzada en el modelo basada en el campo `campaign_end_date` para imputar el estado real (`Activa` o `Cerrada`) en lugar de omitir los registros, salvaguardando la integridad del volumen total del negocio.

   **Tasa de Finalización de Campañas (88.09%):** Es el KPI estrella de rendimiento ($Campaign\ Completion\ Rate$). 
    *   *Decisión que soporta:* Identifica de inmediato si el portafolio global cumple con los visitas pactados con los clientes. 

### Visualización Principal: Rendimiento de Campañas Activas
*   **Por qué se eligió:** Un gráfico de barras horizontales enfocado *exclusivamente* en campañas activas. 
*   **Insight de Negocio:** Permite a Management aislar el histórico y detectar que las campañas que iniciaron en **Febrero 2026** sufren una desaceleración crítica (estancadas en el 75.00%), sirviendo como un sistema de alerta temprana para evitar penalizaciones contractuales.

---

## Página 2: Control de Rutas (Operations View)
Diseñada para el equipo de supervisión que necesita asegurar el cumplimiento diario de las rutas en la calle.

### KPIs Seleccionados y Justificación de Negocio:
*   **Trabajadores Activos (35):** Mide la fuerza laboral disponible ejecutando rutas.
*   **Visitas Pendientes (208):** El KPI operativo crítico de la página. Mide el trabajo asignado que aún no se ha completado.
    *   *Decisión que soporta:* Apoya al supervisor a presionar o reasignar recursos para bajar este número a cero antes del cierre de la jornada.

### Visualización Principal: Estado de Ejecución de Rutas por Trabajador
*   **Por qué se eligió:** Un gráfico de columnas apiladas cruzando trabajadores con el estado detallado de sus visitas, incluyendo un filtro de búsqueda tipo *Dropdown* para agilizar la navegación y buscar por trabajador.
*   **Insights de Negocio Clave:**
    1.  **Problema de Asignación (Barra Anónima):** Se identificó un bloque masivo de visitas (más de 1,100) sin nombre de empleado asociado, detectando un fallo de calidad de datos en el sistema origen que requiere una auditoría técnica inmediata.
    2.  **Saturación y Efectividad (Javier y Lucía):** Al analizar al personal, Javier y Lucía absorben la mayor carga de trabajo pero reflejan un preocupante volumen de visitas "Completadas con incidencia" (azul oscuro). Esto indica que la operación sufre un problema de efectividad (bloqueos en tienda, falta de stock, etc.) y no de falta de actividad, requiriendo un balanceo de rutas o intervención en el punto de venta.