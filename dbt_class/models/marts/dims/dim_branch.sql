{{ config(
    materialized = 'table',
    schema = 'gold'
) }}

WITH src AS (

    SELECT
        *
    FROM
        {{ ref('stg_branch') }}
)
SELECT
    branch_id,
    province,
    cluster_name,
    city_name,
    branch_name,
    created_date,
    modified_date
FROM
    src
