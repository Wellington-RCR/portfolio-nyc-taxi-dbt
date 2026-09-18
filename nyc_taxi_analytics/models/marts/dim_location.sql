{{
    config(
        materialized = 'table'
    )
}}

with zones as (

    select distinct
        zone_id,
        case
            when zone_id in ('57','105','104') then 'Unknown'
            else zone_name
        end as zone_name,
        case
            when zone_id in ('57','105','104') then 'Unknown'
            else borough
        end as borough
    from {{ ref('stg_taxi__zones') }}

),

manual_zones as (

    select '264' as zone_id, 'Unknown' as zone_name, 'Unknown' as borough
    union all
    select '265' as zone_id, 'Outside of NYC' as zone_name, 'N/A' as borough
    union all
    select '57' as zone_id, 'Unknown' as zone_name, 'Unknown' as borough
    union all
    select '105' as zone_id, 'Unknown' as zone_name, 'Unknown' as borough
    union all
    select '104' as zone_id, 'Unknown' as zone_name, 'Unknown' as borough

)

select * from zones
union all
select * from manual_zones