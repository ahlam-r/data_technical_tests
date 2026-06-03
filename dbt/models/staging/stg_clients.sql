with source as (
    select * from read_csv_auto('../data/raw/raw_clients.csv')
),
project_codes as (
    select
        cast(client_id as integer) as client_id,
        max(nullif(upper(trim(cast(client_code as varchar))), '')) as client_code
    from read_csv_auto('../data/raw/raw_projects.csv')
    group by 1
),
cleaned as (
    select
        cast(s.client_id as integer) as client_id,
        pc.client_code as client_code,
        nullif(trim(cast(s.client_name as varchar)), '') as client_name,
        
        -- Estandarización del País a Mayúsculas y control de nulos
        nullif(upper(trim(cast(s.country as varchar))), '') as client_country,
        nullif(trim(cast(s.sector as varchar)), '') as client_sector,
        
        -- Booleanos puros
        false as is_client_billable,
        false as is_active,
        
        -- Fechas forzadas a DATE
        coalesce(
            try_cast(s.created_at as date),
            cast(try_strptime(cast(s.created_at as varchar), '%Y-%m-%d') as date),
            cast(try_strptime(cast(s.created_at as varchar), '%d/%m/%Y') as date)
        ) as created_at,
        
        coalesce(
            try_cast(s.updated_at_sys as date),
            cast(try_strptime(cast(s.updated_at_sys as varchar), '%Y-%m-%d') as date),
            cast(try_strptime(cast(s.updated_at_sys as varchar), '%d/%m/%Y') as date)
        ) as updated_at_sys,
        
        -- Desduplicación por PK
        row_number() over (
            partition by cast(s.client_id as integer) 
            order by coalesce(
                try_cast(s.updated_at_sys as timestamp),
                try_strptime(cast(s.updated_at_sys as varchar), '%Y-%m-%d'),
                try_strptime(cast(s.updated_at_sys as varchar), '%d/%m/%Y')
            ) desc
        ) as row_num
    from source s
    left join project_codes pc
        on cast(s.client_id as integer) = pc.client_id
)
select 
    client_id, client_code, client_name, client_country, client_sector,
    is_client_billable, is_active, created_at, updated_at_sys
from cleaned
where row_num = 1