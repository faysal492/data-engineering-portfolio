{{
    config(
        materialized='table',
        schema='olist_silver',
        tags=['staging'],
        description='Cleaned order items with price and freight validation'
    )
}}

with source_data as (
    select
        order_id,
        order_item_id,
        product_id,
        seller_id,
        shipping_limit_date,
        price,
        freight_value,
        current_timestamp() as dbt_loaded_at
    from {{ source('olist', 'order_items') }}
),

cleaned as (
    select
        order_id,
        order_item_id,
        product_id,
        seller_id,
        shipping_limit_date,
        price,
        freight_value,
        dbt_loaded_at,
        -- Total item cost
        price + coalesce(freight_value, 0) as total_item_cost,
        -- Flag invalid records
        case
            when price < 0 or freight_value < 0 then true
            else false
        end as has_invalid_values
    from source_data
    where order_id is not null
        and product_id is not null
        and seller_id is not null
)

select * from cleaned
