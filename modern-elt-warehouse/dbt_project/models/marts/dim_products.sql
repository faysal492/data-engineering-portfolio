{{
    config(
        materialized='table',
        schema='olist_gold',
        tags=['marts'],
        unique_key='product_id',
        description='Product dimension with category and performance metrics'
    )
}}

with products as (
    select
        p.product_id,
        p.product_category_name,
        p.product_name_lenght,
        p.product_description_lenght,
        p.product_photos_qty as photo_count,
        p.product_weight_g,
        p.product_length_cm,
        p.product_height_cm,
        p.product_width_cm,
        p.product_volume_liters,
        p.incomplete_info,
        p.dbt_loaded_at
    from {{ ref('stg_products') }} p
),

product_sales as (
    select
        product_id,
        count(distinct order_id) as total_orders,
        count(*) as total_items_sold,
        sum(price) as total_revenue,
        round(avg(price), 2) as avg_price,
        min(price) as min_price,
        max(price) as max_price,
        sum(total_item_cost) as total_cost_value
    from {{ ref('int_order_items_enriched') }}
    group by product_id
),

product_reviews as (
    select
        oi.product_id,
        count(r.review_id) as total_reviews,
        round(avg(r.review_score), 2) as avg_rating,
        sum(case when r.review_score >= 4 then 1 else 0 end) as positive_reviews,
        sum(case when r.review_score <= 2 then 1 else 0 end) as negative_reviews
    from {{ ref('int_order_items_enriched') }} oi
    left join {{ ref('stg_reviews') }} r on oi.order_id = r.order_id
    group by oi.product_id
)

select
    p.product_id,
    p.product_category_name,
    p.product_name_lenght,
    p.product_description_lenght,
    p.photo_count,
    p.product_weight_g,
    p.product_length_cm,
    p.product_height_cm,
    p.product_width_cm,
    p.product_volume_liters,
    p.incomplete_info,
    ps.total_orders,
    ps.total_items_sold,
    ps.total_revenue,
    ps.avg_price,
    ps.min_price,
    ps.max_price,
    ps.total_cost_value,
    pr.total_reviews,
    pr.avg_rating,
    pr.positive_reviews,
    pr.negative_reviews,
    -- Product classification
    case
        when ps.total_items_sold >= 100 then 'Best Seller'
        when ps.total_items_sold >= 50 then 'Popular'
        when ps.total_items_sold >= 10 then 'Moderate Sales'
        else 'Low Sales'
    end as sales_category,
    case
        when pr.avg_rating >= 4.5 then 'Excellent'
        when pr.avg_rating >= 4.0 then 'Very Good'
        when pr.avg_rating >= 3.0 then 'Good'
        when pr.avg_rating >= 2.0 then 'Fair'
        when pr.avg_rating >= 1.0 then 'Poor'
        else 'Not Rated'
    end as rating_category,
    p.dbt_loaded_at,
    current_timestamp() as dbt_updated_at
from products p
left join product_sales ps on p.product_id = ps.product_id
left join product_reviews pr on p.product_id = pr.product_id
