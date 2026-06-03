with source as (
    select * from read_csv_auto('../data/raw/raw_visits.csv')
),
campaigns_ref as (
    select distinct cast(campaign_id as integer) as campaign_id
    from read_csv_auto('../data/raw/raw_campaigns.csv')
),
pos_ref as (
    select distinct cast(intervention_point_id as integer) as intervention_point_id
    from read_csv_auto('../data/raw/raw_pos.csv')
),
routes_ref as (
    select distinct cast(route_id as integer) as route_id
    from read_csv_auto('../data/raw/raw_routes.csv')
),
cleaned as (
    select
        cast(s.visit_id as integer) as visit_id,
        cast(s.campaign_id as integer) as campaign_id,
        upper(trim(cast(s.campaign_code as varchar))) as campaign_code,
        upper(trim(cast(s.project_code as varchar))) as project_code,
        cast(s.intervention_point_id as integer) as intervention_point_id,
        upper(trim(cast(s.intervention_point_code as varchar))) as intervention_point_code,
        cast(nullif(trim(cast(s.route_id as varchar)), '') as integer) as route_id,
        nullif(upper(trim(cast(s.route_code as varchar))), '') as route_code,

        coalesce(
            try_cast(s.visit_date as date),
            cast(try_strptime(cast(s.visit_date as varchar), '%Y-%m-%d') as date),
            cast(try_strptime(cast(s.visit_date as varchar), '%d/%m/%Y') as date)
        ) as visit_date,

        coalesce(
            try_cast(s.visit_time as time),
            cast(try_strptime(cast(s.visit_time as varchar), '%H:%M:%S') as time)
        ) as visit_time,
        nullif(upper(trim(cast(s.visit_status as varchar))), '') as visit_status,
        nullif(upper(trim(cast(s.visit_type as varchar))), '') as visit_type,
        cast(s.is_client_billable as boolean) as is_client_billable,

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

        -- Validaciones FK para trazabilidad de calidad
        case when c.campaign_id is not null then true else false end as fk_campaign_id_valid,
        case when p.intervention_point_id is not null then true else false end as fk_intervention_point_id_valid,
        case
            when cast(nullif(trim(cast(s.route_id as varchar)), '') as integer) is null then true
            when r.route_id is not null then true
            else false
        end as fk_route_id_valid,

        row_number() over (-- Desduplicación por PK teniendo en cuenta la fecha de actualización del sistema para quedarnos con el registro más reciente
            partition by cast(s.visit_id as integer)
            order by coalesce(
                try_cast(s.updated_at_sys as timestamp),
                try_strptime(cast(s.updated_at_sys as varchar), '%Y-%m-%d'),
                try_strptime(cast(s.updated_at_sys as varchar), '%d/%m/%Y')
            ) desc
        ) as row_num
    from source s
    left join campaigns_ref c
        on cast(s.campaign_id as integer) = c.campaign_id
    left join pos_ref p
        on cast(s.intervention_point_id as integer) = p.intervention_point_id
    left join routes_ref r
        on cast(nullif(trim(cast(s.route_id as varchar)), '') as integer) = r.route_id
)
select 
    visit_id,
    campaign_id,
    campaign_code,
    project_code,
    intervention_point_id,
    intervention_point_code,
    route_id,
    route_code,
    visit_date,
    visit_time,
    visit_status,
    visit_type,
    is_client_billable,
    fk_campaign_id_valid,
    fk_intervention_point_id_valid,
    fk_route_id_valid,
    created_at,
    updated_at_sys
from cleaned
where row_num = 1
