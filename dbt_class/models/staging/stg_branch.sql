{{ config(
    materialized = 'table'
) }}

WITH src AS (

    SELECT
        *
    FROM
        {{ source(
            'localsource',
            'branch'
        ) }}
)
SELECT
    branch_id,
    province,
    cluster_name,
    city_name,
    branch_name,
    created_date,
    modified_date       
FROM    src
