with hubs as (

    select * from {{ ref('seed_un_locode_hubs') }}

)

select
    locode as hub_locode,
    hub_name,
    country_code,
    hub_type,
    latitude,
    longitude

from hubs