with source as (
    select * from read_csv_auto('../data/raw/raw_projects.csv')
),
clients_ref as (
    select distinct cast(client_id as integer) as client_id
    from read_csv_auto('../data/raw/raw_clients.csv')
),
cleaned as (
    select
        cast(s.project_id as integer) as project_id,
        nullif(trim(cast(s.project_name as varchar)), '') as project_name,

        -- Imputacion de project_code faltante siguiendo una regla trazable,
        -- Si el project_code es nulo o vacío, se asigna 'PRJ_UNK_' seguido del project_id 
        -- Esto nos permite identificar fácilmente los proyectos con código faltante y
        -- saber que lo hemos modificado nosotros en el proceso de limpieza.
        coalesce(
            nullif(upper(trim(cast(s.project_code as varchar))), ''),
            'PRJ_UNK_' || cast(s.project_id as varchar)
        ) as project_code,

        cast(s.client_id as integer) as client_id,
        upper(trim(cast(s.client_code as varchar))) as client_code,

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

        cast(s.project_exportable as boolean) as project_exportable,

        -- Validacion FK proyectos -> clientes para calidad de datos 
        case when c.client_id is not null then true else false end as fk_client_id_valid,

        row_number() over ( -- Desduplicación por PK teniendo en cuenta la fecha de actualización del sistema para quedarnos con el registro más reciente
            partition by cast(s.project_id as integer)
            order by coalesce(
                try_cast(s.updated_at_sys as timestamp),
                try_strptime(cast(s.updated_at_sys as varchar), '%Y-%m-%d'),
                try_strptime(cast(s.updated_at_sys as varchar), '%d/%m/%Y')
            ) desc
        ) as row_num
    from source s
    left join clients_ref c
        on cast(s.client_id as integer) = c.client_id
)
select
    project_id,
    project_name,
    project_code,
    client_id,
    client_code,
    project_exportable,
    fk_client_id_valid,
    created_at,
    updated_at_sys
from cleaned
where row_num = 1
