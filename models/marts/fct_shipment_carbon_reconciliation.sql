with po as (

    select * from {{ ref('stg_erp__purchase_orders') }}

),

lifecycle_summary as (

    select
        po_id,
        container_id,
        carrier_code,
        min(case when milestone_name = 'VESSEL_DEPARTED' then event_occurred_at end) as actual_departure_at,
        max(case when milestone_name = 'DELIVERED_DC' then event_occurred_at end) as actual_delivery_at,
        max(is_cape_reroute_flag) as is_cape_reroute,
        max(is_excessive_port_dwell_flag) as had_excessive_port_dwell

    from {{ ref('int_container_milestone_lifecycle') }}
    group by po_id, container_id, carrier_code

),

emissions_summary as (

    select
        po_id,
        sum(case when mode_code = 'OCEAN_DEEP_SEA' then emissions_tco2e else 0 end) as ocean_emissions_tco2e,
        sum(case when mode_code = 'INLAND_RAIL_ELEC' then emissions_tco2e else 0 end) as inland_emissions_tco2e,
        sum(emissions_tco2e) as total_emissions_tco2e,
        sum(distance_km) as total_transit_distance_km

    from {{ ref('int_shipment_leg_distances') }}
    group by po_id

),

final as (

    select
        -- Primary Key
        po.po_id,

        -- Dimension Keys
        po.vendor_id,
        po.origin_port_locode,
        po.destination_hub_locode,
        po.sku_id,
        l.container_id,
        l.carrier_code,

        -- Commercial Attributes
        po.incoterm,
        po.ordered_quantity,
        po.gross_weight_tonnes,
        po.declared_value_eur,

        -- Timeline Milestones
        po.po_created_at,
        po.promised_delivery_at,
        l.actual_departure_at,
        l.actual_delivery_at,

        -- Transit Time & SLA Performance (in days)
        round(
            date_diff('second', l.actual_departure_at, l.actual_delivery_at) / 86400.0,
            2
        ) as actual_transit_days,

        round(
            date_diff('second', po.promised_delivery_at, l.actual_delivery_at) / 86400.0,
            2
        ) as delivery_delay_days,

        case 
            when l.actual_delivery_at > po.promised_delivery_at then 1 
            else 0 
        end as is_delayed_flag,

        -- Risk & Geopolitical Impact Flags
        l.is_cape_reroute,
        l.had_excessive_port_dwell,

        -- Carbon Metrics (tCO2e)
        e.total_transit_distance_km,
        e.ocean_emissions_tco2e,
        e.inland_emissions_tco2e,
        e.total_emissions_tco2e,

        -- Emissions Intensity (kg CO2e per 1,000 EUR order value)
        round(
            (e.total_emissions_tco2e * 1000.0) / nullif(po.declared_value_eur / 1000.0, 0),
            3
        ) as emissions_intensity_kg_per_keur

    from po
    inner join lifecycle_summary l on po.po_id = l.po_id
    inner join emissions_summary e on po.po_id = e.po_id

)

select * from final