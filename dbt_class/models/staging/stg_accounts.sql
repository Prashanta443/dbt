{{ config(
    materialized = 'incremental',
    incremental_strategy = 'merge',
    unique_key ='account_id',
) }}

WITH src AS (

    SELECT
        *
    FROM {{ source('localsource','account') }}
        
{% if is_incremental() %}

where modified_date >= (select coalesce(max(modified_date),'1900-01-01') from {{ this }} )

{% endif %}
)
SELECT
    account_id,
    customer_id,
    branch_id,
    account_balance,
    lien_amt,
    acct_cls_flg,
    product_id,
    schm_type,
    schm_code,
    acct_crncy_code,
    acct_opn_date,
    created_date,
    modified_date
FROM src
