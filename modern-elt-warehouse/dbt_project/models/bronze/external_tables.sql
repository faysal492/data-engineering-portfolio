-- External tables are created via sources.yml
-- This file is a placeholder model and is not materialized

{{ config(
    materialized='ephemeral'
) }}

SELECT 1 as id
