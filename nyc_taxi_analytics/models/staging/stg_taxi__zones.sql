with source AS (
    SELECT * FROM {{ source('nyc_taxi_public', 'taxi_zone_geom')}}
),
renamed AS (
    SELECT 
    zone_id,
    zone_name,
    borough

    --Mantido zonas_id 264,265,57,105 e 104 para análise no output final

    FROM source
)
SELECT * from renamed