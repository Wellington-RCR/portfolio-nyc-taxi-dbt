{{
    config(
        materialized = 'table'
    )
}}

select
    payment_type,
    case
        when payment_type = '0' then 'Flex Fare'
        when payment_type = '1' then 'Credit card'
        when payment_type = '2' then 'Cash'
        when payment_type = '3' then 'No charge'
        when payment_type = '4' then 'Dispute'
        when payment_type = '5' then 'Unknown'
        else 'Unknown'
    end as payment_type_name
from (
    select distinct payment_type
    from {{ ref('int_taxi__trips') }}
)