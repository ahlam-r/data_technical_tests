with source as (
    select * from read_csv_auto('../data/raw/raw_route_employee.csv')
),
routes_ref as (
    select distinct cast(route_id as integer) as route_id
    from read_csv_auto('../data/raw/raw_routes.csv')
),
workers_ref as (
    select distinct cast(employee_id as integer) as employee_id
    from read_csv_auto('../data/raw/raw_workers.csv')
),
cleaned as (
    select
        cast(s.route_employee_id as integer) as route_employee_id,
        cast(s.route_id as integer) as route_id,
        cast(s.employee_id as integer) as employee_id,
        cast(s.main_employee as boolean) as main_employee,
        cast(s.ip_percentage as double) as ip_percentage,

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

        coalesce(
            try_cast(s.deleted_at as date),
            cast(try_strptime(cast(s.deleted_at as varchar), '%Y-%m-%d') as date),
            cast(try_strptime(cast(s.deleted_at as varchar), '%d/%m/%Y') as date)
        ) as deleted_at,

        -- Validaciones de integridad referencial
        case when r.route_id is not null then true else false end as fk_route_id_valid,
        case when w.employee_id is not null then true else false end as fk_employee_id_valid,

        row_number() over (
            partition by cast(s.route_employee_id as integer)
            order by coalesce(
                try_cast(s.updated_at as timestamp),
                try_strptime(cast(s.updated_at as varchar), '%Y-%m-%d'),
                try_strptime(cast(s.updated_at as varchar), '%d/%m/%Y')
            ) desc
        ) as row_num
    from source s
    left join routes_ref r
        on cast(s.route_id as integer) = r.route_id
    left join workers_ref w
        on cast(s.employee_id as integer) = w.employee_id
)
select
    route_employee_id,
    route_id,
    employee_id,
    main_employee,
    ip_percentage,
    fk_route_id_valid,
    fk_employee_id_valid,
    created_at,
    updated_at,
    deleted_at
from cleaned
where row_num = 1
