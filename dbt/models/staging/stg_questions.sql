with source as (
    select * from read_csv_auto('../data/raw/raw_questions.csv')
),
campaigns_ref as ( -- comprueba que las campañas existen y hace cast con las tabla original para evitar problemas de formato
    select distinct cast(campaign_id as integer) as campaign_id
    from read_csv_auto('../data/raw/raw_campaigns.csv')
),
cleaned as (
    select -- Castings, estandarizaciones y validaciones básicas
        cast(s.question_id as integer) as question_id,
        cast(s.campaign_id as integer) as campaign_id,
        upper(trim(cast(s.campaign_code as varchar))) as campaign_code,
        nullif(upper(trim(cast(s.question_code as varchar))), '') as question_code,
        nullif(trim(cast(s.question_name as varchar)), '') as question_name,
        nullif(upper(trim(cast(s.question_type as varchar))), '') as question_type,
        nullif(trim(cast(s.question_category as varchar)), '') as question_category,
        cast(s.question_order as integer) as question_order,
        cast(s.question_is_highlighted as boolean) as question_is_highlighted,
        cast(s.image_associated as boolean) as image_associated,

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

        -- Validacion FK preguntas -> campaigns para calidad de datos
        case when c.campaign_id is not null then true else false end as fk_campaign_id_valid,

        row_number() over (
            partition by cast(s.question_id as integer)
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
    question_id,
    campaign_id,
    campaign_code,
    question_code,
    question_name,
    question_type,
    question_category,
    question_order,
    question_is_highlighted,
    image_associated,
    fk_campaign_id_valid,
    created_at,
    updated_at_sys
from cleaned
where row_num = 1
