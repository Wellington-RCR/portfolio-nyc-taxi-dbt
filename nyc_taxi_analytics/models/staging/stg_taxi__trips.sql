with source as (

    select * from {{ source('nyc_taxi_public', 'tlc_yellow_trips_2019') }}

),

renamed as (

    select
        vendor_id,
        pickup_datetime,
        dropoff_datetime,
        passenger_count,
        trip_distance,
        rate_code,
        store_and_fwd_flag,
        payment_type,
        pickup_location_id,
        dropoff_location_id,
        fare_amount,
        extra,
        mta_tax,
        tip_amount,
        tolls_amount,
        imp_surcharge,
        airport_fee,
        total_amount,

        -- Flag quality: identificamos que ~0.24% das corridas têm fare_amount <= 0
        -- (170k negativas + 35k zeradas), tratadas como estorno/erro de origem, não descartadas
        case
            when fare_amount > 0 then true
            else false
        end as is_valid_fare

    from source

)

select * from renamed