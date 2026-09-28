with source as (

    select * from {{ source('raw_bronze', 'raw_carrier_milestone_events') }}

),

renamed as (

    select
        -- Primary Key
        cast(event_id as varchar) as event_id,

        -- Foreign Keys & Tracking
        cast(po_number as varchar) as po_id,
        cast(container_id as varchar) as container_id,
        cast(carrier_code as varchar) as carrier_code,

        -- Milestone Context
        cast(milestone_name as varchar) as milestone_name,
        cast(current_locode as varchar) as location_locode,

        -- Timestamps
        cast(event_occurred_at as timestamp) as event_occurred_at,
        cast(recorded_at as timestamp) as recorded_at,

        -- Ingestion telemetry lag in hours
        round(
            date_diff('second', cast(event_occurred_at as timestamp), cast(recorded_at as timestamp)) / 3600.0, 
            2
        ) as telemetry_lag_hours

    from source

)

select * from renamed