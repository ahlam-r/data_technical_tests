with source as (
    select * from read_csv_auto('../data/raw/raw_workers.csv')
),
cleaned as (
    select
        cast(s.employee_id as integer) as employee_id,
        nullif(trim(cast(s.employee_first_name as varchar)), '') as employee_first_name,
        cast(s.employee_active_status as boolean) as employee_active_status,

        coalesce(
            try_cast(s.employee_hire_date as date),
            cast(try_strptime(cast(s.employee_hire_date as varchar), '%Y-%m-%d') as date),
            cast(try_strptime(cast(s.employee_hire_date as varchar), '%d/%m/%Y') as date)
        ) as employee_hire_date,

        nullif(upper(trim(cast(s.employee_address_province as varchar))), '') as employee_address_province,
        nullif(upper(trim(cast(s.employee_contract_type as varchar))), '') as employee_contract_type,
        cast(s.company_id as integer) as company_id,

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

        row_number() over (
            partition by cast(s.employee_id as integer)
            order by coalesce(
                try_cast(s.updated_at_sys as timestamp),
                try_strptime(cast(s.updated_at_sys as varchar), '%Y-%m-%d'),
                try_strptime(cast(s.updated_at_sys as varchar), '%d/%m/%Y')
            ) desc
        ) as row_num
    from source s
)
select
    employee_id,
    employee_first_name,
    employee_active_status,
    employee_hire_date,
    employee_address_province,
    employee_contract_type,
    company_id,
    created_at,
    updated_at_sys
from cleaned
where row_num = 1
