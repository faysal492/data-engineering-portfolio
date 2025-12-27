-- External Tables from GCS
-- ========================
-- External tables are created via the create_external_tables macro
-- in macros/create_external_tables.sql
-- This macro runs on dbt-run-start hook to ensure tables exist before models/tests

{{ config(
    materialized='ephemeral'
) }}

SELECT 1 as id
