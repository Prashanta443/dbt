{{ config(materialized = 'table') }}


SELECT
    date_key,
    display_date,
    year,
    month,
    day,
    week_of_month
FROM {{ ref('date') }}