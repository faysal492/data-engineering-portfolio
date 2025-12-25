{{
    config(
        materialized='table',
        schema='olist_gold',
        tags=['marts'],
        description='Fact table with order metrics and dimensions'
    )
}}

with orders as (
    select * from {{ ref('int_orders_enhanced') }}
),

order_items as (
    select
        order_id,
        count(*) as item_count,
        sum(price) as total_items_price,
        sum(freight_value) as total_freight,
        sum(total_item_cost) as total_order_value,
        avg(price) as avg_item_price
    from {{ ref('int_order_items_enriched') }}
    group by order_id
),

reviews as (
    select
        order_id,
        count(*) as review_count,
        avg(review_score) as avg_rating,
        max(review_score) as max_rating,
        min(review_score) as min_rating
    from {{ ref('stg_reviews') }}
    group by order_id
)

select
    o.order_id,
    o.customer_id,
    o.customer_unique_id,
    o.customer_city,
    o.customer_state,
    o.region as customer_region,
    o.order_status,
    o.order_purchase_timestamp,
    o.order_approved_at,
    o.order_delivered_customer_date,
    o.order_estimated_delivery_date,
    o.days_to_delivery,
    o.days_late,
    o.delivered_on_time,
    o.total_payment as payment_amount,
    o.payment_method_count,
    o.max_installments,
    oi.item_count,
    oi.total_items_price,
    oi.total_freight,
    oi.total_order_value,
    oi.avg_item_price,
    r.review_count,
    r.avg_rating,
    r.max_rating,
    r.min_rating,
    -- Business metrics
    case
        when r.avg_rating >= 4.5 then 'Excellent'
        when r.avg_rating >= 4.0 then 'Very Good'
        when r.avg_rating >= 3.0 then 'Good'
        when r.avg_rating >= 2.0 then 'Fair'
        when r.avg_rating >= 1.0 then 'Poor'
        else 'No Rating'
    end as rating_category,
    o.dbt_loaded_at,
    current_timestamp() as dbt_updated_at
from orders o
left join order_items oi on o.order_id = oi.order_id
left join reviews r on o.order_id = r.order_id
