with responses as (
    select
        answer_id,
        visit_id,
        question_id,
        question_type,
        answer,
        expected_answer,
        fk_visit_id_valid,
        fk_question_id_valid,
        created_at,
        updated_at_sys
    from {{ ref('stg_responses') }}
),

visits as (
    select
        visit_id,
        campaign_id,
        campaign_code as visit_campaign_code,
        project_code,
        intervention_point_id,
        route_id,
        visit_date,
        visit_time,
        visit_status,
        visit_type,
        is_client_billable
    from {{ ref('stg_visits') }}
),

questions as (
    select
        question_id,
        campaign_id as question_campaign_id,
        question_name,
        question_type as question_type_master,
        question_category,
        question_order,
        question_is_highlighted,
        image_associated
    from {{ ref('stg_questions') }}
),

campaigns as (
    select
        campaign_id,
        campaign_name,
        project_id,
        project_code,
        client_code
    from {{ ref('stg_campaigns') }}
),

projects as (
    select
        project_id,
        project_code,
        project_name,
        client_id
    from {{ ref('stg_projects') }}
),

clients as (
    select
        client_id,
        client_code,
        client_name
    from {{ ref('stg_clients') }}
),

route_assignments as (
    select
        route_id,
        employee_id,
        main_employee,
        row_number() over (
            partition by route_id
            order by case when main_employee then 0 else 1 end, employee_id
        ) as route_assignment_rank,
        count(*) over (partition by route_id) as workers_assigned_count
    from {{ ref('stg_route_employee') }}
),

main_route_worker as (
    select
        route_id,
        employee_id as main_employee_id,
        main_employee,
        workers_assigned_count
    from route_assignments
    where route_assignment_rank = 1
),

workers as (
    select
        employee_id,
        employee_first_name,
        employee_active_status,
        employee_contract_type,
        employee_address_province
    from {{ ref('stg_workers') }}
)

select
    r.answer_id,
    r.visit_id,
    r.question_id,
    v.campaign_id,
    coalesce(c.project_id, p_by_code.project_id) as project_id,
    coalesce(p_by_id.project_name, p_by_code.project_name) as project_name,
    coalesce(p_by_id.client_id, p_by_code.client_id, cl_by_code.client_id) as client_id,
    coalesce(cl_by_id.client_name, cl_by_code.client_name) as client_name,
    c.campaign_name,
    v.intervention_point_id,
    v.route_id,
    mrw.main_employee_id as employee_id,
    w.employee_first_name as employee_name,
    mrw.main_employee as is_main_employee,
    coalesce(mrw.workers_assigned_count, 0) as workers_assigned_count,
    w.employee_active_status,
    w.employee_contract_type,
    w.employee_address_province,
    v.visit_date,
    v.visit_time,
    v.visit_status,
    v.visit_type,
    v.is_client_billable,
    q.question_name,
    q.question_category,
    q.question_order,
    q.question_is_highlighted,
    q.image_associated,
    coalesce(r.question_type, q.question_type_master) as question_type,
    r.answer,
    r.expected_answer,
    r.fk_visit_id_valid,
    r.fk_question_id_valid,
    r.created_at,
    r.updated_at_sys
from responses r
left join visits v
    on r.visit_id = v.visit_id
left join questions q
    on r.question_id = q.question_id
left join campaigns c
    on v.campaign_id = c.campaign_id
left join projects p_by_id
    on c.project_id = p_by_id.project_id
left join projects p_by_code
    on coalesce(c.project_code, v.project_code) = p_by_code.project_code
left join clients cl_by_id
    on coalesce(p_by_id.client_id, p_by_code.client_id) = cl_by_id.client_id
left join clients cl_by_code
    on c.client_code = cl_by_code.client_code
left join main_route_worker mrw
    on v.route_id = mrw.route_id
left join workers w
    on mrw.main_employee_id = w.employee_id
