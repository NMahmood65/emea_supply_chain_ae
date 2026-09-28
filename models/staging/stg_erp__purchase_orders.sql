with source as (

    select * from {{ source('raw_bronze', 'raw_erp_purchase_orders') }}

),

renamed as (

    select
        -- Primary Key
        cast(po_number as varchar) as po_id,

        -- Foreign Keys & Locations
        cast(vendor_id as varchar) as vendor_id,
        cast(origin_port_locode as varchar) as origin_port_locode,
        cast(destination_hub_locode as varchar) as destination_hub_locode,

        -- SKU & Quantities
        cast(sku_code as varchar) as sku_id,
        cast(ordered_quantity as integer) as ordered_quantity,
        cast(gross_weight_kg as double) as gross_weight_kg,
        round(cast(gross_weight_kg as double) / 1000.0, 4) as gross_weight_tonnes,

        -- Commercial Terms
        cast(incoterm as varchar) as incoterm,
        cast(declared_value_eur as double) as declared_value_eur,

        -- Timestamps
        cast(created_at as timestamp) as po_created_at,
        cast(promised_delivery_date as timestamp) as promised_delivery_at

    from source

)

select * from renamed