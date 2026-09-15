{{
    config(
        materialized = 'table'
    )
}}

select
    vendor_id,
    case
        when vendor_id = '1' then 'Creative Mobile Technologies, LLC'
        when vendor_id = '2' then 'VeriFone Inc.'
        else 'Unknown / Not documented'
    end as vendor_name
from (
    select distinct vendor_id
    from {{ ref('int_taxi__trips') }}
)