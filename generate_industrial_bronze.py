import os
import random
from datetime import datetime, timedelta
import pandas as pd
import duckdb

random.seed(42)
os.makedirs("data/bronze", exist_ok=True)

NUM_POS = 50_000

print(f"Generating {NUM_POS:,} industrial purchase orders...")

suppliers = [
    ("VEND-CN-01", "CNSHA", "China North Component Hub"),
    ("VEND-CN-02", "CNNBO", "Zhejiang Heavy Industrial"),
    ("VEND-IN-01", "INBOM", "Western India Forgings"),
    ("VEND-VN-01", "VNVUT", "Mekong Electronics Assemblers")
]

destinations = ["DEDUI", "DEMHG", "FRLYS"] # Duisburg, Mannheim, Lyon
incoterms = ["FOB", "CIF", "DDP"]
skus = [
    ("SKU-EV-BATT-01", 450.0, 1200.0),   # Heavy EV battery
    ("SKU-CHIP-MC-04", 0.05, 35.0),     # Lightweight semiconductor
    ("SKU-SOLAR-PV-09", 22.0, 180.0),   # Solar panels
    ("SKU-IND-PUMP-22", 85.0, 650.0)    # Industrial machinery
]

po_records = []
base_start = datetime(2025, 6, 1)

for i in range(1, NUM_POS + 1):
    po_num = f"PO-2025-{i:07d}"
    vend_id, pol, _ = random.choice(suppliers)
    pod_final = random.choice(destinations)
    incoterm = random.choice(incoterms)
    sku, unit_wt, unit_val = random.choice(skus)
    qty = random.randint(50, 4000)
    gross_wt_kg = round(qty * unit_wt, 2)
    val_eur = round(qty * unit_val, 2)
    
    po_date = base_start + timedelta(days=random.randint(0, 365))
    promised_date = po_date + timedelta(days=40)
    
    po_records.append({
        "po_number": po_num,
        "vendor_id": vend_id,
        "origin_port_locode": pol,
        "destination_hub_locode": pod_final,
        "sku_code": sku,
        "ordered_quantity": qty,
        "gross_weight_kg": gross_wt_kg,
        "incoterm": incoterm,
        "created_at": po_date,
        "promised_delivery_date": promised_date,
        "declared_value_eur": val_eur
    })

df_pos = pd.DataFrame(po_records)
df_pos.to_parquet("data/bronze/raw_erp_purchase_orders.parquet", index=False)
print("-> Saved data/bronze/raw_erp_purchase_orders.parquet")

print(f"Generating ~{NUM_POS * 9:,} container lifecycle events with operational noise...")

carriers = ["MSC", "MAERSK", "HAPAG_LLOYD", "CMA_CGM"]
emea_gateways = ["NLRTM", "BEANR", "DEHAM"]

event_steps = [
    ("BOOKING_CONFIRMED", 0),
    ("CONTAINER_GATED_IN", 2),
    ("VESSEL_DEPARTED", 5),
    ("TRANSIT_CHECKPOINT", 18),   # Rerouting around Cape of Good Hope
    ("VESSEL_BERTHED", 38),
    ("CONTAINER_DISCHARGED", 40),
    ("CUSTOMS_CLEARED", 43),
    ("INLAND_DEPARTED", 45),
    ("DELIVERED_DC", 48)
]

event_records = []
event_counter = 1

for po in po_records:
    po_num = po["po_number"]
    container_id = f"{random.choice(['MSCU', 'MSKU', 'HLXU', 'CMAU'])}{random.randint(1000000, 9999999)}"
    carrier = random.choice(carriers)
    origin_loc = po["origin_port_locode"]
    pod_loc = random.choice(emea_gateways)
    final_loc = po["destination_hub_locode"]
    start_time = po["created_at"]
    
    is_diverted = random.random() < 0.65
    diversion_delay = 12 if is_diverted else 0
    
    is_congested = random.random() < 0.15
    dwell_delay = 5 if is_congested else 0

    for step_name, base_day in event_steps:
        day_offset = base_day
        if base_day >= 18 and is_diverted:
            day_offset += diversion_delay
        if base_day >= 40 and is_congested:
            day_offset += dwell_delay
            
        actual_event_time = start_time + timedelta(
            days=day_offset,
            hours=random.randint(0, 23),
            minutes=random.randint(0, 59)
        )
        
        logging_lag = timedelta(hours=random.randint(1, 48))
        recorded_time = actual_event_time + logging_lag
        
        if base_day <= 5:
            loc = origin_loc
        elif base_day == 18:
            loc = "ZACPT" if is_diverted else "EGSUE"
        elif base_day <= 43:
            loc = pod_loc
        else:
            loc = final_loc

        if random.random() < 0.005:
            loc = None

        event_records.append({
            "event_id": f"EVT-{event_counter:08d}",
            "po_number": po_num,
            "container_id": container_id,
            "carrier_code": carrier,
            "milestone_name": step_name,
            "current_locode": loc,
            "event_occurred_at": actual_event_time,
            "recorded_at": recorded_time
        })
        event_counter += 1

random.shuffle(event_records)

df_events = pd.DataFrame(event_records)
df_events.to_parquet("data/bronze/raw_carrier_milestone_events.parquet", index=False)
print("-> Saved data/bronze/raw_carrier_milestone_events.parquet")

print("Registering raw Parquet files in DuckDB warehouse...")
con = duckdb.connect("warehouse.duckdb")
con.execute("CREATE SCHEMA IF NOT EXISTS raw_bronze;")

con.execute("""
    CREATE OR REPLACE VIEW raw_bronze.raw_erp_purchase_orders AS 
    SELECT * FROM read_parquet('data/bronze/raw_erp_purchase_orders.parquet');
""")

con.execute("""
    CREATE OR REPLACE VIEW raw_bronze.raw_carrier_milestone_events AS 
    SELECT * FROM read_parquet('data/bronze/raw_carrier_milestone_events.parquet');
""")

print("Done! Total Bronze rows registered:")
print(" - raw_erp_purchase_orders:", con.execute("SELECT COUNT(*) FROM raw_bronze.raw_erp_purchase_orders").fetchone()[0])
print(" - raw_carrier_milestone_events:", con.execute("SELECT COUNT(*) FROM raw_bronze.raw_carrier_milestone_events").fetchone()[0])
con.close()