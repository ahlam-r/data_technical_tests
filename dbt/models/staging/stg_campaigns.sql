
with source as (
    select * from read_csv_auto('../data/raw/raw_campaigns.csv')
),
cleaned as (
    select -- Conversión de IDs a enteros,
        cast(s.campaign_id as integer) as campaign_id,
        coalesce(
            nullif(upper(trim(cast(s.campaign_code as varchar))), ''),
            'CPG_UNK_' || cast(cast(s.campaign_id as integer) as varchar)
        ) as campaign_code,
        trim(cast(s.campaign_name as varchar)) as campaign_name, --trim para eliminar espacios en blanco al inicio y al final
        cast(s.project_id as integer) as project_id,
        
        -- Fechas operativas de la campaña
        coalesce(
            try_cast(s.campaign_start_date as date),
            cast(try_strptime(cast(s.campaign_start_date as varchar), '%Y-%m-%d') as date),
            cast(try_strptime(cast(s.campaign_start_date as varchar), '%d/%m/%Y') as date)
        ) as campaign_start_date,
        
        coalesce(
            try_cast(s.campaign_end_date as date),
            cast(try_strptime(cast(s.campaign_end_date as varchar), '%Y-%m-%d') as date),
            cast(try_strptime(cast(s.campaign_end_date as varchar), '%d/%m/%Y') as date)
        ) as campaign_end_date,
        
        -- Imputación de nulos strings y números, valores vacios a null, y numeros a 0
        nullif(trim(cast(s.campaign_state as varchar)), '') as campaign_state,
        coalesce(cast(s.visit_duration_minutes as float), 0.0) as visit_duration_minutes,
        
        -- Inferir si la campaña está activa en función de las fechas
        case
            when coalesce(try_cast(s.campaign_start_date as date), cast(try_strptime(cast(s.campaign_start_date as varchar), '%Y-%m-%d') as date), cast(try_strptime(cast(s.campaign_start_date as varchar), '%d/%m/%Y') as date)) is null
              or coalesce(try_cast(s.campaign_end_date as date), cast(try_strptime(cast(s.campaign_end_date as varchar), '%Y-%m-%d') as date), cast(try_strptime(cast(s.campaign_end_date as varchar), '%d/%m/%Y') as date)) is null then null
            when coalesce(try_cast(s.campaign_start_date as date), cast(try_strptime(cast(s.campaign_start_date as varchar), '%Y-%m-%d') as date), cast(try_strptime(cast(s.campaign_start_date as varchar), '%d/%m/%Y') as date)) > current_date then 'PROGRAMADA'
            when coalesce(try_cast(s.campaign_end_date as date), cast(try_strptime(cast(s.campaign_end_date as varchar), '%Y-%m-%d') as date), cast(try_strptime(cast(s.campaign_end_date as varchar), '%d/%m/%Y') as date)) < current_date then 'CERRADA'
            else 'ACTIVA'
        end as campaign_status,
        cast(coalesce(try_cast(s.campaign_start_date as date), cast(try_strptime(cast(s.campaign_start_date as varchar), '%Y-%m-%d') as date), cast(try_strptime(cast(s.campaign_start_date as varchar), '%d/%m/%Y') as date)) <= current_date
            and coalesce(try_cast(s.campaign_end_date as date), cast(try_strptime(cast(s.campaign_end_date as varchar), '%Y-%m-%d') as date), cast(try_strptime(cast(s.campaign_end_date as varchar), '%d/%m/%Y') as date)) >= current_date as boolean) as campaign_is_active_by_date,
        
        -- Normalización de códigos, convertir a mayúsculas y eliminar espacios en blanco
        upper(trim(cast(s.client_code as varchar))) as client_code,
        coalesce(
            nullif(upper(trim(cast(s.project_code as varchar))), ''),
            'PRJ_UNK_' || cast(cast(s.project_id as integer) as varchar)
        ) as project_code,
        
        -- Fechas de sistema (DATE)
        coalesce(
            try_cast(s.created_at as date),
            cast(try_strptime(cast(s.created_at as varchar), '%Y-%m-%d') as date),
            cast(try_strptime(cast(s.created_at as varchar), '%d/%m/%Y') as date)
        ) as created_at,
        -- Dateetime para mantener trazabilidad de actualizaciones en el sistema
        coalesce(
            try_cast(s.updated_at_sys as date),
            cast(try_strptime(cast(s.updated_at_sys as varchar), '%Y-%m-%d') as date),
            cast(try_strptime(cast(s.updated_at_sys as varchar), '%d/%m/%Y') as date)
        ) as updated_at_sys,
        
        -- is_active la casteamos directamente a boolean (maneja 'true', 'false', 1, 0 automáticamente)
        cast(s.is_active as boolean) as is_active,
        --  Desduplicación por PK teniendo en cuenta la fecha de actualización del sistema para quedarnos con el registro más reciente
        row_number() over (
            partition by cast(s.campaign_id as integer) 
            order by coalesce(
                try_cast(s.updated_at_sys as timestamp),
                try_strptime(cast(s.updated_at_sys as varchar), '%Y-%m-%d'),
                try_strptime(cast(s.updated_at_sys as varchar), '%d/%m/%Y')
            ) desc
        ) as row_num
    from source s
)
select 
    campaign_id, campaign_code, campaign_name, project_id, campaign_start_date, 
    campaign_end_date, campaign_state, campaign_status, campaign_is_active_by_date, visit_duration_minutes, 
    client_code, project_code, is_active, created_at, updated_at_sys
from cleaned 
where row_num = 1