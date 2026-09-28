# EMEA Supply Chain Resilience & Carbon Accounting Pipeline

[![dbt Analytics Engineering CI](https://github.com/NMahmood65/emea_supply_chain_ae/actions/workflows/ci_pipeline.yml/badge.svg)](https://github.com/NMahmood65/emea_supply_chain_ae/actions/workflows/ci_pipeline.yml)

## Project Overview

Global supply chains face major disruptions. Recent geopolitical conflicts in the Red Sea forced container ships traveling between Asia and Europe to avoid the Suez Canal shortcut and take a long detour around Africa's Cape of Good Hope. This detour adds roughly 12 to 14 days to shipping schedules, delays customer deliveries, increases port congestion, and significantly drives up carbon emissions.

This project builds a modern, automated data system that models this real-world scenario across **500,000 container shipment events**. It processes raw shipment records, cleans messy operational tracking, calculates accurate Scope 3 transport carbon emissions, and ensures that every business report is verified for accuracy.

---

## The Journey: How Data Moves (The Medallion Architecture)

```text
[Raw Dispatches & Telemetry] (Bronze)
              │
              ▼
[Standardized & Cleaned Views] (Staging)
              │
              ▼
[Route Splitting & Carbon Logic] (Intermediate / Silver)
              │
              ▼
[Business-Ready Dashboards & Metrics] (Marts / Gold)


