with source as (
    select *
    from read_csv_auto('../data/raw/raw_pos.csv')
),

cleaned as (
    select -- Castings y estandarizaciones básicas
        cast(s.intervention_point_id as integer) as intervention_point_id,
        upper(trim(cast(s.intervention_point_code as varchar))) as intervention_point_code,
        trim(cast(s.intervention_point_name as varchar)) as intervention_point_name, -- Dejamos el nombre con mayúscula inicial y respetando espacios para mejor legibilidad
        nullif(trim(cast(s.intervention_point_address as varchar)), '') as intervention_point_address,
        nullif(upper(trim(cast(s.intervention_point_province as varchar))), '') as intervention_point_province, 
        nullif(trim(cast(s.intervention_point_locality as varchar)), '') as intervention_point_locality,

        cast(s.intervention_point_postal_code as integer) as intervention_point_postal_code,
        cast(s.intervention_point_latitude as double) as intervention_point_latitude,
        cast(s.intervention_point_longitude as double) as intervention_point_longitude,

        cast(s.intervention_point_is_active as boolean) as intervention_point_is_active,

        coalesce(
            try_cast(s.created_at as date),
            cast(try_strptime(cast(s.created_at as varchar), '%Y-%m-%d') as date),
            cast(try_strptime(cast(s.created_at as varchar), '%d/%m/%Y') as date)
        ) as created_at,

        coalesce(
            try_cast(s.updated_at as date),
            cast(try_strptime(cast(s.updated_at as varchar), '%Y-%m-%d') as date),
            cast(try_strptime(cast(s.updated_at as varchar), '%d/%m/%Y') as date)
        ) as updated_at,
        
        -- Ventana de desduplicación para proteger la Primary Key ante los tests de dbt
        row_number() over (
            partition by cast(s.intervention_point_id as integer) 
            order by coalesce(
                try_cast(s.updated_at as timestamp),
                try_strptime(cast(s.updated_at as varchar), '%Y-%m-%d'),
                try_strptime(cast(s.updated_at as varchar), '%d/%m/%Y')
            ) desc
        ) as row_num

    from source s
)

select 
    intervention_point_id, 
    intervention_point_code, 
    intervention_point_name,
    intervention_point_address, 
    intervention_point_province, 
    intervention_point_locality,
    intervention_point_postal_code, 
    intervention_point_latitude, 
    intervention_point_longitude,
    intervention_point_is_active, 
    created_at, 
    updated_at
from cleaned
where row_num = 1