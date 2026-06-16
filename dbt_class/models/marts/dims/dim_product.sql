{{ config(
    materialized = 'table',
    schema = 'gold'
) }}

WITH src AS (

    SELECT
        *
    FROM
        {{ ref('stg_product') }}
)
SELECT
    product_id,
    schm_type,
    schm_code,
    product_desc,
    created_date,
    modified_date
FROM
    src