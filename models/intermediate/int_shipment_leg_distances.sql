with po as (

    select * from {{ ref('stg_erp__purchase_orders') }}

),

reroute_flag as (

    -- Check if this PO had a Cape of Good Hope reroute event
    select
        po_id,
        max(is_cape_reroute_flag) as is_cape_reroute
    from {{ ref('int_container_milestone_lifecycle') }}
    group by po_id

),

ocean_legs as (

    select
        po.po_id,
        1 as leg_sequence,
        'OCEAN_DEEP_SEA' as mode_code,
        po.origin_port_locode as origin_locode,
        -- Gateway port assumed from tracking, default to NLRTM for oceanic leg terminus
        'NLRTM' as destination_locode,
        po.gross_weight_tonnes,
        -- Distance logic: Suez route ~11,000 km vs Cape route ~19,500 km
        case 
            when r.is_cape_reroute = 1 then 19500.0
            else 11000.0
        end as distance_km,
        r.is_cape_reroute

    from po
    left join reroute_flag r on po.po_id = r.po_id

),

inland_legs as (

    select
        po.po_id,
        2 as leg_sequence,
        'INLAND_RAIL_ELEC' as mode_code,
        'NLRTM' as origin_locode,
        po.destination_hub_locode as destination_locode,
        po.gross_weight_tonnes,
        450.0 as distance_km,
        0 as is_cape_reroute

    from po

),

combined_legs as (

    select * from ocean_legs
    union all
    select * from inland_legs

),

enriched_with_emissions as (

    select
        c.po_id,
        c.leg_sequence,
        c.mode_code,
        c.origin_locode,
        c.destination_locode,
        c.distance_km,
        c.gross_weight_tonnes,
        c.is_cape_reroute,
        g.co2e_grams_per_tkm,

        -- Reusable Jinja carbon calculation macro
        {{ calculate_glec_emissions('c.distance_km', 'c.gross_weight_tonnes', 'g.co2e_grams_per_tkm') }} as emissions_tco2e

    from combined_legs c
    left join {{ ref('seed_glec_carbon_factors') }} g 
        on c.mode_code = g.mode_code

)

select * from enriched_with_emissions