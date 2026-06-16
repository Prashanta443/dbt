{{ config(
    materialized = 'table',
    schema = 'gold'
) }}

/*
    Aggregated fact. Grain: one row per branch.
    Combines account-level balances with transactional activity to describe
    how each branch is performing (accounts held, balances, transaction volume).
*/

WITH accounts AS (

    SELECT
        branch_id,
        COUNT(account_id)  AS total_accounts,
        SUM(account_balance) AS total_account_balance,
        AVG(account_balance) AS avg_account_balance,
        SUM(lien_amt)        AS total_lien_amount
    FROM
        {{ ref('stg_accounts') }}
    GROUP BY
        branch_id
),

transactions AS (

    SELECT
        branch_id,
        COUNT(tran_id)   AS total_transactions,
        SUM(tran_amount) AS total_tran_amount
    FROM
        {{ ref('stg_hist_transactional') }}
    GROUP BY
        branch_id
)
SELECT
    a.branch_id,
    a.total_accounts,
    a.total_account_balance,
    a.avg_account_balance,
    a.total_lien_amount,
    COALESCE(t.total_transactions, 0) AS total_transactions,
    COALESCE(t.total_tran_amount, 0)  AS total_tran_amount
FROM
    accounts a
    LEFT JOIN transactions t
        ON a.branch_id = t.branch_id
