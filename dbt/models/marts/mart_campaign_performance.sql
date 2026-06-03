with campaigns as (
    select
        campaign_id,
        campaign_code,
        campaign_name,
        project_id,
        project_code,
        client_code,
        campaign_start_date,
        campaign_end_date,
        campaign_state,
        campaign_status,
        campaign_is_active_by_date,
        is_active
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

workers as (
    select
        employee_id,
        employee_first_name
    from {{ ref('stg_workers') }}
),

visits as (
    select
        campaign_id,
        visit_id,
        route_id,
        visit_status
    from {{ ref('stg_visits') }}
),

routes as (
    select
        campaign_id,
        route_id
    from {{ ref('stg_routes') }}
),

route_workers as (
    select
        r.campaign_id,
        re.route_id,
        re.employee_id,
        re.main_employee,
        w.employee_first_name
    from {{ ref('stg_route_employee') }} re
    inner join routes r
        on re.route_id = r.route_id
    left join workers w
        on re.employee_id = w.employee_id
),

visits_agg as (
    select
        campaign_id,
        count(distinct visit_id) as total_visits,
        count(distinct case when visit_status in ('OK', 'INCID', 'INFO') then visit_id end) as completed_visits,
        count(distinct case when visit_status = 'NOVIS' then visit_id end) as not_visited_visits,
        count(distinct case when visit_status = 'INCID' then visit_id end) as incid_visits
    from visits
    group by campaign_id
),

route_worker_agg as (
    select
        r.campaign_id,
        count(distinct r.route_id) as routes_total,
        count(distinct case when v.route_id is not null then r.route_id end) as routes_with_visits,
        count(distinct rw.employee_id) as workers_assigned,
        count(distinct case when rw.main_employee then rw.employee_id end) as main_workers_assigned,
        string_agg(distinct cast(rw.employee_id as varchar), ', ' order by cast(rw.employee_id as varchar)) as worker_ids,
        string_agg(distinct rw.employee_first_name, ', ' order by rw.employee_first_name) as worker_names
    from routes r
    left join visits v
        on r.route_id = v.route_id
    left join route_workers rw
        on r.route_id = rw.route_id
    group by r.campaign_id
)

select
    c.campaign_id,
    c.campaign_name,
    coalesce(p_by_id.project_id, p_by_code.project_id, c.project_id) as project_id,
    coalesce(p_by_id.project_name, p_by_code.project_name) as project_name,
    coalesce(p_by_id.client_id, p_by_code.client_id, cl_by_code.client_id) as client_id,
    coalesce(cl_by_id.client_name, cl_by_code.client_name) as client_name,
    c.campaign_start_date,
    c.campaign_end_date,
    c.campaign_state,
    c.is_active,
    c.campaign_status,
    c.campaign_is_active_by_date,
    coalesce(v.total_visits, 0) as total_visits,
    coalesce(v.completed_visits, 0) as completed_visits,
    coalesce(v.not_visited_visits, 0) as not_visited_visits,
    coalesce(v.incid_visits, 0) as incid_visits,
    coalesce(rw.routes_total, 0) as routes_total,
    coalesce(rw.routes_with_visits, 0) as routes_with_visits,
    coalesce(rw.workers_assigned, 0) as workers_assigned,
    coalesce(rw.main_workers_assigned, 0) as main_workers_assigned,
    coalesce(rw.worker_ids, '') as worker_ids,
    coalesce(rw.worker_names, '') as worker_names,
    case
        when coalesce(v.total_visits, 0) = 0 then 0.0
        else round((coalesce(v.completed_visits, 0) * 1.0) / v.total_visits, 4)
    end as completion_rate,
    case
        when coalesce(rw.routes_total, 0) = 0 then 0.0
        else round((coalesce(rw.routes_with_visits, 0) * 1.0) / rw.routes_total, 4)
    end as route_execution_rate,
    case
        when coalesce(v.total_visits, 0) = 0 then 0.0
        else round((coalesce(v.incid_visits, 0) * 1.0) / v.total_visits, 4)
    end as incidence_rate
from campaigns c
left join projects p_by_id
    on c.project_id = p_by_id.project_id
left join projects p_by_code
    on c.project_code = p_by_code.project_code
left join clients cl_by_id
    on coalesce(p_by_id.client_id, p_by_code.client_id) = cl_by_id.client_id
left join clients cl_by_code
    on c.client_code = cl_by_code.client_code
left join visits_agg v
    on c.campaign_id = v.campaign_id
left join route_worker_agg rw
    on c.campaign_id = rw.campaign_id
