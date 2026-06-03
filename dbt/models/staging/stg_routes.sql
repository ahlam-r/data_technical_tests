with source as (
    select * from read_csv_auto('../data/raw/raw_routes.csv')
),
campaigns_ref as (
    select distinct cast(campaign_id as integer) as campaign_id
    from read_csv_auto('../data/raw/raw_campaigns.csv')
),
cleaned as (
    select
        cast(s.route_id as integer) as route_id,
        coalesce(nullif(upper(trim(cast(s.route_code as varchar))), ''), 'RUT_UNK_' || cast(s.route_id as varchar)) as route_code,
        nullif(trim(cast(s.route_name as varchar)), '') as route_name,
        cast(s.campaign_id as integer) as campaign_id,
        upper(trim(cast(s.campaign_code as varchar))) as campaign_code,

        coalesce(
            try_cast(s.route_start_date as date),
            cast(try_strptime(cast(s.route_start_date as varchar), '%Y-%m-%d') as date),
            cast(try_strptime(cast(s.route_start_date as varchar), '%d/%m/%Y') as date)
        ) as route_start_date,

        coalesce(
            try_cast(s.route_end_date as date),
            cast(try_strptime(cast(s.route_end_date as varchar), '%Y-%m-%d') as date),
            cast(try_strptime(cast(s.route_end_date as varchar), '%d/%m/%Y') as date)
        ) as route_end_date,

        nullif(trim(cast(s.route_status as varchar)), '') as route_status,
        nullif(upper(trim(cast(s.delegation_code as varchar))), '') as delegation_code,
        cast(s.recall_mail_sent as boolean) as recall_mail_sent,

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

        -- Validacion FK rutas -> campanas
        case when c.campaign_id is not null then true else false end as fk_campaign_id_valid,

        row_number() over (
            partition by cast(s.route_id as integer)
            order by coalesce(
                try_cast(s.updated_at_sys as timestamp),
                try_strptime(cast(s.updated_at_sys as varchar), '%Y-%m-%d'),
                try_strptime(cast(s.updated_at_sys as varchar), '%d/%m/%Y')
            ) desc
        ) as row_num
    from source s
    left join campaigns_ref c
        on cast(s.campaign_id as integer) = c.campaign_id
)
select
    route_id,
    route_code,
    route_name,
    campaign_id,
    campaign_code,
    route_start_date,
    route_end_date,
    route_status,
    delegation_code,
    recall_mail_sent,
    fk_campaign_id_valid,
    created_at,
    updated_at_sys
from cleaned
where row_num = 1
