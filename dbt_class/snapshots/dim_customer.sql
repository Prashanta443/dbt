{% snapshot dim_customer %}

{{
    config(
        target_schema = 'gold',
        unique_key ='cust_id',
        strategy = 'timestamp',
        updated_at = 'modified_date'
    )
}}
with src as (
    SELECT * FROM {{ref('stg_customer') }}
)

SELECT 
    cust_id,
    name,
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
FROM src

{% endsnapshot %}
