{{
    config(
        materialized='table',
        schema='olist_silver',
        tags=['intermediate'],
        description='Order items with product information and seller details'
    )
}}

with items as (
    select * from {{ ref('stg_order_items') }}
),

products as (
    select
        product_id,
        product_category_name,
        product_weight_g,
        product_volume_liters
    from {{ ref('stg_products') }}
),

sellers as (
    select
        seller_id,
        seller_city,
        seller_state,
        region as seller_region
    from {{ ref('stg_sellers') }}
)

select
    i.order_id,
    i.order_item_id,
    i.product_id,
    p.product_category_name,
    i.seller_id,
    s.seller_city,
    s.seller_state,
    s.seller_region,
    i.price,
    i.freight_value,
    i.total_item_cost,
    p.product_weight_g,
    p.product_volume_liters,
    i.has_invalid_values,
    i.shipping_limit_date,
    i.dbt_loaded_at
from items i
left join products p on i.product_id = p.product_id
left join sellers s on i.seller_id = s.seller_id
