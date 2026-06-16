{{ config(
    materialized = 'table',
    on_schema_change = 'sync_all_columns',
        post_hook = [
        "CREATE INDEX IF NOT EXISTS idx_slv_customer_nationality ON {{ this }} (nationality)",
        "CLUSTER {{ this }} USING idx_slv_customer_nationality"
    ],
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
    modified_date,
    temporary_address
FROM
    src
