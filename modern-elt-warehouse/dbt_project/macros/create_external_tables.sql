-- Macro to create external tables from GCS data
-- This ensures external tables exist before tests run

{% macro create_external_tables() %}
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
              uris = ['gs://{{ var('gcs_raw_bucket') }}/olist/{{ table_name }}/*.csv'],
              skip_leading_rows = 1,
              allow_jagged_rows = true,
              allow_quoted_newlines = true
            );
        {% endset %}
        
        {% do run_query(sql) %}
        {% do log("Created external table: " ~ table_name, info=true) %}
    {% endfor %}
{% endmacro %}
