{{
    config(
        materialized='table',
        schema='olist_gold',
        tags=['marts'],
        unique_key='seller_id',
        description='Seller dimension with performance metrics'
    )
}}

with sellers as (
    select
        s.seller_id,
        s.seller_city,
        s.seller_state,
        s.region,
        s.dbt_loaded_at
    from {{ ref('stg_sellers') }} s
),

seller_products as (
    select
        oi.seller_id,
        count(distinct oi.product_id) as product_count,
        count(distinct p.product_category_name) as category_count,
        round(avg(p.product_photos_qty), 2) as avg_photos_per_product
    from {{ ref('int_order_items_enriched') }} oi
    left join {{ ref('stg_products') }} p on oi.product_id = p.product_id
    group by oi.seller_id
),

seller_sales as (
    select
        seller_id,
        count(distinct order_id) as total_orders,
        count(*) as total_items_sold,
        sum(price) as total_revenue,
        round(avg(price), 2) as avg_item_price,
        sum(total_item_cost) as total_gross_cost
    from {{ ref('int_order_items_enriched') }}
    group by seller_id
),

seller_performance as (
    select
        o.order_id,
        oi.seller_id,
        o.delivered_on_time,
        o.days_late,
        r.review_score
    from {{ ref('int_orders_enhanced') }} o
    left join {{ ref('int_order_items_enriched') }} oi on o.order_id = oi.order_id
    left join {{ ref('stg_reviews') }} r on o.order_id = r.order_id
),

seller_metrics as (
    select
        seller_id,
        count(*) as total_items_reviewed,
        sum(case when delivered_on_time then 1 else 0 end) as on_time_items,
        round(100.0 * sum(case when delivered_on_time then 1 else 0 end) / count(*), 2) as on_time_pct,
        round(avg(days_late), 2) as avg_days_late,
        round(avg(review_score), 2) as avg_seller_rating,
        sum(case when review_score >= 4 then 1 else 0 end) as positive_reviews
    from seller_performance
    group by seller_id
)

select
    s.seller_id,
    s.seller_city,
    s.seller_state,
    s.region,
    sp.product_count,
    sp.category_count,
    sp.avg_photos_per_product,
    ss.total_orders,
    ss.total_items_sold,
    ss.total_revenue,
    ss.avg_item_price,
    ss.total_gross_cost,
    sm.total_items_reviewed,
    sm.on_time_items,
    sm.on_time_pct,
    sm.avg_days_late,
    sm.avg_seller_rating,
    sm.positive_reviews,
    -- Seller classification
    case
        when ss.total_revenue >= 50000 then 'Top Tier'
        when ss.total_revenue >= 20000 then 'High Volume'
        when ss.total_revenue >= 5000 then 'Medium Volume'
        else 'Emerging'
    end as seller_tier,
    case
        when sm.on_time_pct >= 95 then 'Excellent'
        when sm.on_time_pct >= 85 then 'Good'
        when sm.on_time_pct >= 70 then 'Fair'
        else 'Needs Improvement'
    end as delivery_performance,
    s.dbt_loaded_at,
    current_timestamp() as dbt_updated_at
from sellers s
left join seller_products sp on s.seller_id = sp.seller_id
left join seller_sales ss on s.seller_id = ss.seller_id
left join seller_metrics sm on s.seller_id = sm.seller_id
