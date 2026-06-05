{{ config(
    materialized = 'incremental'
) }}

WITH src AS (

    SELECT
        *
    FROM
        {{ source(
            'railway',
            'customer'
        ) }}

{% if is_incremental() %}
WHERE
    modified_date > (
        SELECT
            MAX(modified_date)
        FROM
            {{ this }}
    )
{% endif %}
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
    nationality
FROM
    src
