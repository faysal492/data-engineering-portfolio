{{
    config(
        materialized='table',
        schema='olist_silver',
        tags=['staging'],
        description='Cleaned customer data with geographic information'
    )
}}

with source_data as (
    select
        customer_id,
        customer_unique_id,
        customer_zip_code_prefix,
        customer_city,
        customer_state,
        current_timestamp() as dbt_loaded_at
    from {{ source('olist', 'customers') }}
),

cleaned as (
    select
        customer_id,
        customer_unique_id,
        customer_zip_code_prefix,
        upper(customer_city) as customer_city,
        upper(customer_state) as customer_state,
        dbt_loaded_at,
        -- Add region logic
        case
            when customer_state in ('SP', 'RJ', 'MG', 'ES') then 'Southeast'
            when customer_state in ('BA', 'PE', 'CE', 'RN', 'PB', 'AL', 'SE', 'PI', 'MA') then 'Northeast'
            when customer_state in ('SC', 'RS', 'PR') then 'South'
            when customer_state in ('DF', 'GO', 'MT', 'MS') then 'Center-West'
            when customer_state in ('AM', 'RR', 'AP', 'PA', 'TO', 'AC', 'RO') then 'North'
            else 'Unknown'
        end as region
    from source_data
    where customer_id is not null
)

select * from cleaned
