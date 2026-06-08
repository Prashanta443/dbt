{{ config(
    materialized = 'table'
) }}

WITH src AS (

    SELECT
        *
    FROM
        {{ source(
            'localsource',
            'product'
        ) }}
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
