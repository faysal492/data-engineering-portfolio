-- Macro to create external tables from GCS data
-- This ensures external tables exist before tests run

{% macro create_external_tables() %}
    {% set external_tables = [
        ('olist_customers_dataset', 'customer_id STRING, customer_unique_id STRING, customer_zip_code_prefix STRING, customer_city STRING, customer_state STRING'),
        ('olist_geolocation_dataset', 'geolocation_zip_code_prefix STRING, geolocation_lat FLOAT64, geolocation_lng FLOAT64, geolocation_city STRING, geolocation_state STRING'),
        ('olist_order_items_dataset', 'order_id STRING, order_item_id INT64, product_id STRING, seller_id STRING, shipping_limit_date STRING, price FLOAT64, freight_value FLOAT64'),
        ('olist_order_payments_dataset', 'order_id STRING, payment_sequential INT64, payment_type STRING, payment_installments INT64, payment_value FLOAT64'),
        ('olist_order_reviews_dataset', 'review_id STRING, order_id STRING, review_score INT64, review_comment_title STRING, review_comment_message STRING, review_creation_date STRING, review_answer_timestamp STRING'),
        ('olist_orders_dataset', 'order_id STRING, customer_id STRING, order_status STRING, order_purchase_timestamp STRING, order_approved_at STRING, order_delivered_carrier_date STRING, order_delivered_customer_date STRING, order_estimated_delivery_date STRING'),
        ('olist_products_dataset', 'product_id STRING, product_category_name STRING, product_name_lenght INT64, product_description_lenght INT64, product_photos_qty INT64, product_weight_g INT64, product_length_cm INT64, product_height_cm INT64, product_width_cm INT64'),
        ('olist_sellers_dataset', 'seller_id STRING, seller_zip_code_prefix STRING, seller_city STRING, seller_state STRING'),
        ('product_category_name_translation', 'product_category_name STRING, product_category_name_english STRING')
    ] %}
    
    {% for table_name, schema in external_tables %}
        {% set sql %}
            CREATE OR REPLACE EXTERNAL TABLE `{{ target.project }}.olist_bronze.{{ table_name }}`
            (
              {{ schema }}
            )
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
