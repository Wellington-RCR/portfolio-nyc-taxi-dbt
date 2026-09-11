{{
    config(
        materialized = 'incremental',
        incremental_strategy = 'merge',
        unique_key = ['vendor_id', 'pickup_datetime', 'pickup_location_id', 'dropoff_location_id'],
        partition_by = {
            "field" : "pickup_datetime",
            "data_type" : "timestamp",
            "granularity" : "day"
        }
    )
}}

select *
from {{ ref('stg_taxi__trips') }}

{% if is_incremental() %}

where pickup_datetime > (select max(pickup_datetime) from {{ this }})

{% endif %}