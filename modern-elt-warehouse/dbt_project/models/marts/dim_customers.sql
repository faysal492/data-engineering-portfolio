{{
    config(
        materialized='table',
        schema='olist_gold',
        tags=['marts'],
        unique_key='customer_id',
        description='Customer dimension with aggregated metrics'
    )
}}

with customers as (
    select
        c.customer_id,
        c.customer_unique_id,
        c.customer_city,
        c.customer_state,
        c.region,
        c.dbt_loaded_at
    from {{ ref('stg_customers') }} c
),

customer_orders as (
    select
        customer_id,
        count(*) as total_orders,
        sum(case when delivered_on_time then 1 else 0 end) as on_time_orders,
        round(100.0 * sum(case when delivered_on_time then 1 else 0 end) / count(*), 2) as on_time_pct,
        sum(case when order_status = 'delivered' then 1 else 0 end) as completed_orders,
        sum(case when order_status in ('canceled', 'unavailable') then 1 else 0 end) as canceled_orders
    from {{ ref('int_orders_enhanced') }}
    group by customer_id
),

customer_value as (
    select
        o.customer_id,
        sum(oi.total_item_cost) as total_lifetime_value,
        avg(oi.total_item_cost) as avg_order_value,
        max(o.order_purchase_timestamp) as last_order_date,
        min(o.order_purchase_timestamp) as first_order_date
    from {{ ref('int_orders_enhanced') }} o
    left join {{ ref('int_order_items_enriched') }} oi on o.order_id = oi.order_id
    group by o.customer_id
),

customer_satisfaction as (
    select
        o.customer_id,
        round(avg(r.review_score), 2) as avg_customer_rating,
        count(r.review_id) as total_reviews,
        sum(case when r.review_score >= 4 then 1 else 0 end) as positive_reviews
    from {{ ref('int_orders_enhanced') }} o
    left join {{ ref('stg_reviews') }} r on o.order_id = r.order_id
    group by o.customer_id
)

select
    c.customer_id,
    c.customer_unique_id,
    c.customer_city,
    c.customer_state,
    c.region,
    co.total_orders,
    co.on_time_orders,
    co.on_time_pct,
    co.completed_orders,
    co.canceled_orders,
    cv.total_lifetime_value,
    cv.avg_order_value,
    cv.last_order_date,
    cv.first_order_date,
    cs.avg_customer_rating,
    cs.total_reviews,
    cs.positive_reviews,
    -- Customer segment classification
    case
        when cv.total_lifetime_value >= 1000 then 'High Value'
        when cv.total_lifetime_value >= 500 then 'Medium Value'
        else 'Low Value'
    end as customer_segment,
    c.dbt_loaded_at,
    current_timestamp() as dbt_updated_at
from customers c
left join customer_orders co on c.customer_id = co.customer_id
left join customer_value cv on c.customer_id = cv.customer_id
left join customer_satisfaction cs on c.customer_id = cs.customer_id
