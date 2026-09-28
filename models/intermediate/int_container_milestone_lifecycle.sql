with events as (

    select * from {{ ref('stg_carrier__milestone_events') }}

),

ordered_events as (

    select
        event_id,
        po_id,
        container_id,
        carrier_code,
        milestone_name,
        location_locode,
        event_occurred_at,
        recorded_at,
        telemetry_lag_hours,

        -- Sequence container events chronologically per container
        row_number() over (
            partition by container_id 
            order by event_occurred_at asc
        ) as milestone_sequence_number,

        -- Previous milestone details
        lag(milestone_name) over (
            partition by container_id 
            order by event_occurred_at asc
        ) as previous_milestone_name,

        lag(event_occurred_at) over (
            partition by container_id 
            order by event_occurred_at asc
        ) as previous_event_at,

        -- Next milestone details
        lead(milestone_name) over (
            partition by container_id 
            order by event_occurred_at asc
        ) as next_milestone_name,

        lead(event_occurred_at) over (
            partition by container_id 
            order by event_occurred_at asc
        ) as next_event_at

    from events

),

dwell_calculated as (

    select
        *,

        -- Duration spent in previous transition state (in days)
        round(
            date_diff('second', previous_event_at, event_occurred_at) / 86400.0,
            2
        ) as days_since_previous_milestone,

        -- Flag Suez vs Cape of Good Hope rerouting
        case 
            when milestone_name = 'TRANSIT_CHECKPOINT' and location_locode = 'ZACPT' then 1
            else 0
        end as is_cape_reroute_flag,

        -- Terminal dwell alert: containers sitting at port terminal > 5 days
        case 
            when milestone_name = 'CUSTOMS_CLEARED' 
                 and (date_diff('second', previous_event_at, event_occurred_at) / 86400.0) > 5.0
            then 1
            else 0
        end as is_excessive_port_dwell_flag

    from ordered_events

)

select * from dwell_calculated