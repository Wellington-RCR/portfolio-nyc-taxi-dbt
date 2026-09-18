{{
    config(
        materialized = 'table'
    )
}}

select
    -- Chaves/FKs
    trips.vendor_id,
    trips.payment_type,
    trips.pickup_location_id,
    trips.dropoff_location_id,
    date(trips.pickup_datetime) as date_day,

    -- Métricas
    trips.trip_distance,
    trips.fare_amount,
    trips.tip_amount,
    trips.tolls_amount,
    trips.mta_tax,
    trips.extra,
    trips.total_amount,
    trips.passenger_count,
    trips.is_valid_fare,

    -- Flag de qualidade: identificamos 1.442 corridas (0,0017%) com pickup_datetime
    -- fora de 2019 (range 2001-2090), provavelmente erro de digitação/relógio do
    -- equipamento de bordo. Preservadas na fato, sinalizadas para filtro na ponta.
    case
        when extract(year from trips.pickup_datetime) = 2019 then true
        else false
    end as is_valid_date

from {{ ref('int_taxi__trips') }} as trips