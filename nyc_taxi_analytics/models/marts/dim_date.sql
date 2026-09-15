{{
    config(
        materialized = 'table'
    )
}}

with date_spine as (
    
    {{ dbt_utils.date_spine(
        datepart="day",
       start_date="(select min(date(pickup_datetime)) from " ~ ref('int_taxi__trips') ~ " where extract(year from pickup_datetime) = 2019)",
       end_date="(select date_add(max(date(pickup_datetime)), interval 1 day) from " ~ ref('int_taxi__trips') ~ " where extract(year from pickup_datetime) = 2019)"    
    ) }}

)
select * from date_spine