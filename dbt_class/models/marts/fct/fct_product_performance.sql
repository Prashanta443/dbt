{{ config(
    materialized = 'table',
    schema = 'gold'
) }}

WITH accounts AS (

    SELECT
        *
    FROM
        {{ ref('stg_accounts') }}
)
SELECT
    product_id,
    COUNT(account_id)    AS total_accounts,
    SUM(account_balance) AS total_account_balance,
    AVG(account_balance) AS avg_account_balance,
    SUM(lien_amt)        AS total_lien_amount,
    SUM(
        CASE
            WHEN acct_cls_flg = 'Y' THEN 1
            ELSE 0
        END
    )                    AS closed_accounts,
    SUM(
        CASE
            WHEN acct_cls_flg = 'N' THEN 1
            ELSE 0
        END
    )                    AS active_accounts
FROM
    accounts
GROUP BY
    product_id
