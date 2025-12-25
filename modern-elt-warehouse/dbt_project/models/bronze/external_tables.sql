-- Create external tables from GCS CSV files
-- This approach allows dbt to read directly from GCS without manual loading

{% set tables = [
    'orders',
    'order_items', 
    'customers',
    'sellers',
    'products',
    'order_payments',
    'order_reviews',
    'geolocation',
    'product_category_translation'
] %}

{% for table in tables %}

create or replace external table `{{ target.project }}.olist_bronze.{{ table }}`
options (
  format = 'CSV',
  uris = ['gs://modern-elt-warehouse-raw-zone/olist/olist_{{ table }}_dataset/year=*/month=*/day=*/*.csv'],
  skip_leading_rows = 1
);

{% endfor %}
