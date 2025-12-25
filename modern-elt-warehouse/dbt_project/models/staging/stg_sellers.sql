{{
    config(
        materialized='table',
        schema='olist_silver',
        tags=['staging'],
        description='Cleaned seller data with location information'
    )
}}

with source_data as (
    select
        seller_id,
        seller_zip_code_prefix,
        seller_city,
        seller_state,
        current_timestamp() as dbt_loaded_at
    from {{ source('olist', 'sellers') }}
),

cleaned as (
    select
        seller_id,
        seller_zip_code_prefix,
        upper(seller_city) as seller_city,
        upper(seller_state) as seller_state,
        dbt_loaded_at,
        -- Add region logic
        case
            when seller_state in ('SP', 'RJ', 'MG', 'ES') then 'Southeast'
            when seller_state in ('BA', 'PE', 'CE', 'RN', 'PB', 'AL', 'SE', 'PI', 'MA') then 'Northeast'
            when seller_state in ('SC', 'RS', 'PR') then 'South'
            when seller_state in ('DF', 'GO', 'MT', 'MS') then 'Center-West'
            when seller_state in ('AM', 'RR', 'AP', 'PA', 'TO', 'AC', 'RO') then 'North'
            else 'Unknown'
        end as region
    from source_data
    where seller_id is not null
)

select * from cleaned
