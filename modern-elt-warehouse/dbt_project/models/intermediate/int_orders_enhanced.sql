{{
    config(
        materialized='table',
        schema='olist_silver',
        tags=['intermediate'],
        description='Orders with customer and payment information joined'
    )
}}

with orders as (
    select * from {{ ref('stg_orders') }}
),

customers as (
    select 
        customer_id,
        customer_unique_id,
        customer_city,
        customer_state,
        region
    from {{ ref('stg_customers') }}
),

payments as (
    select 
        order_id,
        sum(payment_value) as total_payment,
        count(distinct payment_type) as payment_method_count,
        max(case when payment_installments > 1 then payment_installments else null end) as max_installments
    from {{ ref('stg_payments') }}
    group by order_id
)

select
    o.order_id,
    o.customer_id,
    c.customer_unique_id,
    c.customer_city,
    c.customer_state,
    c.region,
    o.order_status,
    o.order_purchase_timestamp,
    o.order_approved_at,
    o.order_delivered_carrier_date,
    o.order_delivered_customer_date,
    o.order_estimated_delivery_date,
    o.days_late,
    o.delivered_on_time,
    p.total_payment,
    p.payment_method_count,
    p.max_installments,
    -- Calculate order days to delivery
    case
        when o.order_delivered_customer_date is not null
        then date_diff(
            date(o.order_delivered_customer_date),
            date(o.order_purchase_timestamp),
            day
        )
        else null
    end as days_to_delivery,
    o.dbt_loaded_at
from orders o
left join customers c on o.customer_id = c.customer_id
left join payments p on o.order_id = p.order_id
