{{
    config(
        materialized='table',
        schema='olist_silver',
        tags=['staging'],
        description='Cleaned product data with category information'
    )
}}

with source_data as (
    select
        product_id,
        product_category_name,
        product_name_lenght,
        product_description_lenght,
        product_photos_qty,
        product_weight_g,
        product_length_cm,
        product_height_cm,
        product_width_cm,
        current_timestamp() as dbt_loaded_at
    from {{ source('olist', 'products') }}
),

cleaned as (
    select
        product_id,
        product_category_name,
        product_name_lenght,
        product_description_lenght,
        product_photos_qty,
        product_weight_g,
        product_length_cm,
        product_height_cm,
        product_width_cm,
        dbt_loaded_at,
        -- Calculate product volume
        case
            when product_length_cm is not null 
                and product_height_cm is not null 
                and product_width_cm is not null
            then (product_length_cm * product_height_cm * product_width_cm) / 1000.0
            else null
        end as product_volume_liters,
        -- Flag incomplete product info
        case
            when product_category_name is null
                or product_weight_g is null
                or product_length_cm is null
            then true
            else false
        end as incomplete_info
    from source_data
    where product_id is not null
)

select * from cleaned
