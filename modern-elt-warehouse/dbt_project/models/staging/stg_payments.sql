{{
    config(
        materialized='table',
        schema='olist_silver',
        tags=['staging'],
        description='Cleaned payment data with aggregate calculations'
    )
}}

with source_data as (
    select
        order_id,
        payment_sequential,
        payment_type,
        payment_installments,
        payment_value,
        current_timestamp() as dbt_loaded_at
    from {{ source('olist', 'order_payments') }}
),

cleaned as (
    select
        order_id,
        payment_sequential,
        lower(payment_type) as payment_type,
        payment_installments,
        payment_value,
        dbt_loaded_at,
        -- Calculate payment characteristics
        case
            when payment_installments = 1 then 'Immediate'
            when payment_installments between 2 and 3 then 'Short-term'
            when payment_installments between 4 and 6 then 'Medium-term'
            else 'Long-term'
        end as payment_term_category
    from source_data
    where order_id is not null
        and payment_value > 0
)

select * from cleaned
