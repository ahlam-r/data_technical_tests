# dbt_proyecto

Este proyecto sigue una estructura simple de dbt con dos capas:

- `models/staging`: limpieza y estandarizacion de los CSV raw.
- `models/marts`: modelos listos para negocio/BI.

## Modelos creados

### Staging

- `stg_clients`
- `stg_projects`
- `stg_campaigns`
- `stg_questions`
- `stg_workers`
- `stg_pos`
- `stg_routes`
- `stg_route_employee`
- `stg_visits`
- `stg_responses`

### Marts

- `mart_campaign_performance`: KPIs de visitas por campaign.
- `mart_visit_responses`: tabla plana visita + respuesta para BI.

## Tests

Se usan tests de dbt de tipo:

- `not_null`
- `unique`
- `relationships`

Aplicados en staging y marts sobre claves primarias y foraneas.

## Como ejecutar en local

Desde la carpeta `dbt_proyecto`:

```bash
dbt debug
```

Ejecutar staging:

```bash
dbt run --select path:models/staging
dbt test --select path:models/staging
```

Ejecutar marts:

```bash
dbt run --select path:models/marts
dbt test --select path:models/marts
```

Ejecutar todo:

```bash
dbt build
```

## Que agregaria con mas tiempo

- Mas tests de dominio (`accepted_values`) para estados y tipos de pregunta.
- Tests de calidad extra para detectar outliers y reglas de negocio.
- Documentacion mas detallada de metricas para dashboard.
