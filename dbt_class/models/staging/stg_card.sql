{{ config(
    materialized = 'table'
) }}

WITH src AS (

    SELECT
        *
    FROM
        {{ source(
            'localsource',
            'card'
        ) }}
)
SELECT
    card_number,
    account_id,
    balance,
    card_type,
    closing_balance,
    card_expiry_date,
    created_date,
    modified_date
FROM
    src
