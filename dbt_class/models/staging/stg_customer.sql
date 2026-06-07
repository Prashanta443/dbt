{{ config(
    materialized = 'incremental'
) }}

WITH src AS (

    SELECT
        *
    FROM
        {{ source(
            'localsource',
            'customer'
        ) }}
)
SELECT
    cust_id,
    NAME,
    address,
    phone_number,
    postal_code,
    country,
    email,
    father_name,
    mother_name,
    occupation,
    education,
    nationality,
    created_date,
    modified_date
FROM
    src
