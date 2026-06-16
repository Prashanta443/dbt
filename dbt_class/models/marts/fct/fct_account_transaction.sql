{{ config(
    materialized = 'table',
    schema = 'gold'
) }}

WITH txn AS (

    SELECT
        *
    FROM
        {{ ref('stg_hist_transactional') }}
)
SELECT
    account_id,
    COUNT(tran_id)            AS total_transactions,
    SUM(tran_amount)          AS total_tran_amount,
    AVG(tran_amount)          AS avg_tran_amount,
    MIN(tran_amount)          AS min_tran_amount,
    MAX(tran_amount)          AS max_tran_amount,
    MIN(tran_date)            AS first_tran_date,
    MAX(tran_date)            AS last_tran_date
FROM
    txn
GROUP BY
    account_id
