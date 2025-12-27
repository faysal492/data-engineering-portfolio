-- External Tables from GCS
-- ========================
-- Create external tables pointing to GCS data for all Olist datasets
-- These tables serve as the bronze layer data source

{% if execute %}
    {% set external_tables = [
        'olist_customers_dataset',
        'olist_geolocation_dataset',
        'olist_order_items_dataset',
        'olist_order_payments_dataset',
        'olist_order_reviews_dataset',
        'olist_orders_dataset',
        'olist_products_dataset',
        'olist_sellers_dataset',
        'product_category_name_translation'
    ] %}
    
    {% for table_name in external_tables %}
        {% set sql %}
            CREATE OR REPLACE EXTERNAL TABLE `{{ target.project }}.olist_bronze.{{ table_name }}`
            OPTIONS (
              format = 'CSV',
              uris = ['gs://{{ var('gcs_raw_bucket') }}/olist/{{ table_name }}/year=*/month=*/day=*/*.csv'],
              skip_leading_rows = 1,
              allow_jagged_rows = true,
              allow_quoted_newlines = true
            );
        {% endset %}
        
        {% if execute %}
            {% do run_query(sql) %}
            {% do log("Created external table: " ~ table_name, info=true) %}
        {% endif %}
    {% endfor %}
{% endif %}

-- This model doesn't materialize anything itself
{{ config(
    materialized='ephemeral'
) }}

SELECT 1 as id
