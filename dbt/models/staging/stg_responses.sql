with source as (
    select * from read_csv_auto('../data/raw/raw_responses.csv')
),
visits_ref as (
    select distinct cast(visit_id as integer) as visit_id
    from read_csv_auto('../data/raw/raw_visits.csv')
),
questions_ref as (
    select distinct cast(question_id as integer) as question_id
    from read_csv_auto('../data/raw/raw_questions.csv')
),
cleaned as (
    select
        cast(s.answer_id as integer) as answer_id,
        cast(s.visit_id as integer) as visit_id,
        cast(nullif(trim(cast(s.question_id as varchar)), '') as integer) as question_id,
        upper(trim(cast(s.campaign_code as varchar))) as campaign_code,
        upper(trim(cast(s.intervention_point_code as varchar))) as intervention_point_code,
        nullif(upper(trim(cast(s.question_type as varchar))), '') as question_type,
        nullif(trim(cast(s.answer as varchar)), '') as answer,
        nullif(trim(cast(s.expected_answer as varchar)), '') as expected_answer,

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

        -- Validaciones FK respuestas -> visitas/preguntas
        case when v.visit_id is not null then true else false end as fk_visit_id_valid,
        case
            when cast(nullif(trim(cast(s.question_id as varchar)), '') as integer) is null then false
            when q.question_id is not null then true
            else false
        end as fk_question_id_valid,

        row_number() over (
            partition by cast(s.answer_id as integer)
            order by coalesce(
                try_cast(s.updated_at_sys as timestamp),
                try_strptime(cast(s.updated_at_sys as varchar), '%Y-%m-%d'),
                try_strptime(cast(s.updated_at_sys as varchar), '%d/%m/%Y')
            ) desc
        ) as row_num
    from source s
    left join visits_ref v
        on cast(s.visit_id as integer) = v.visit_id
    left join questions_ref q
        on cast(nullif(trim(cast(s.question_id as varchar)), '') as integer) = q.question_id
)
select
    answer_id,
    visit_id,
    question_id,
    campaign_code,
    intervention_point_code,
    question_type,
    answer,
    expected_answer,
    fk_visit_id_valid,
    fk_question_id_valid,
    created_at,
    updated_at_sys
from cleaned
where row_num = 1
