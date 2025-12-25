{{
    config(
        materialized='table',
        schema='olist_silver',
        tags=['staging'],
        description='Cleaned and validated orders with business logic applied'
    )
}}

with source_data as (
    select
        order_id,
        customer_id,
        order_status,
        order_purchase_timestamp,
        order_approved_at,
        order_delivered_carrier_date,
        order_delivered_customer_date,
        order_estimated_delivery_date,
        current_timestamp() as dbt_loaded_at
    from {{ source('olist', 'orders') }}
),

cleaned as (
    select
        order_id,
        customer_id,
        upper(order_status) as order_status,
        order_purchase_timestamp,
        order_approved_at,
        order_delivered_carrier_date,
        order_delivered_customer_date,
        order_estimated_delivery_date,
        dbt_loaded_at,
        -- Calculate delivery performance
        case
            when order_delivered_customer_date is not null
                then date_diff(
                    date(order_delivered_customer_date),
                    date(order_estimated_delivery_date),
                    day
                )
            else null
        end as days_late,
        case
            when order_status = 'DELIVERED'
                and order_delivered_customer_date <= order_estimated_delivery_date
                then true
            else false
        end as delivered_on_time
    from source_data
    where order_id is not null
)

select * from cleaned
