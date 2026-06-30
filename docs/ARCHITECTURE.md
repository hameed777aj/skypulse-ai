# SkyPulse AI — Architecture & Use Case Design

## The Business Problem

SkyPulse Airways (fictional mid-size airline, 45M passengers/year, 800 routes) faces:

| Challenge | Annual Cost Impact |
|-----------|-------------------|
| Flight delays & cancellations | $95M (compensation, rebooking, fuel waste) |
| Customer churn (loyalty members leaving) | $52M (lost lifetime value) |
| Overbooking & yield loss | $28M (empty seats vs denied boarding) |
| Reactive maintenance | $12M (unplanned AOG events) |
| **Total** | **$187M** |

## The Solution: SkyPulse AI Platform on Snowflake

A unified AI-powered data platform that:
1. **Predicts flight delays** 4-6 hours ahead using weather, historical patterns, and aircraft telemetry
2. **Prevents customer churn** by identifying at-risk loyalty members and triggering retention offers
3. **Analyzes customer sentiment** in real-time from feedback, social media, and NPS surveys
4. **Detects operational anomalies** (baggage handling spikes, gate congestion, fuel consumption outliers)
5. **Optimizes crew scheduling** using predictive demand and fatigue modeling

## Quantifiable Business Impact (Projected Year 1)

| Capability | Metric | Value |
|-----------|--------|-------|
| Delay prediction & proactive rebooking | 30% fewer compensation claims | $28.5M saved |
| Churn prevention (12% reduction) | Retained loyalty revenue | $6.2M saved |
| Sentiment-driven service recovery | 15% NPS improvement | $8M revenue uplift |
| Anomaly detection on ops | 20% fewer unplanned disruptions | $4.8M saved |
| **Total Year 1 ROI** | | **$47.5M** |
| Platform cost (Snowflake + engineering) | | ~$2.1M |
| **Net ROI** | | **22.6x** |

## Snowflake Features Showcased (12+)

| # | Feature | How We Use It |
|---|---------|--------------|
| 1 | **Cortex AI (LLM Functions)** | Sentiment analysis on passenger feedback, summarization of delay reports |
| 2 | **Cortex ML (Forecasting)** | Flight delay prediction model |
| 3 | **Cortex ML (Anomaly Detection)** | Detect baggage handling & ops anomalies |
| 4 | **Cortex ML (Classification)** | Customer churn prediction |
| 5 | **Dynamic Tables** | Real-time materialized views for ops dashboards |
| 6 | **Streams & Tasks** | CDC pipeline for booking changes and flight status updates |
| 7 | **Snowpark (Python)** | Feature engineering for ML models |
| 8 | **Time Travel** | Audit trail for regulatory compliance (passenger manifests) |
| 9 | **Data Sharing / Marketplace** | Consume weather data; share anonymized delay stats with airports |
| 10 | **Snowflake Notebooks** | Interactive analysis and model training |
| 11 | **Hybrid Tables** | Low-latency lookup for real-time gate assignment |
| 12 | **Tags & Data Governance** | PII classification on passenger data (GDPR) |
| 13 | **Alerts** | Automated alerting on delay probability thresholds |
| 14 | **Iceberg Tables** | Open format for data lakehouse interop |

## Data Architecture

```
                    ┌──────────────────────────────────────────┐
                    │          SNOWFLAKE DATA CLOUD             │
                    ├──────────────────────────────────────────┤
                    │                                          │
  SOURCES           │   BRONZE (RAW)     SILVER (CLEAN)  GOLD  │   CONSUMERS
  ───────           │   ────────────     ──────────────  ────  │   ─────────
                    │                                          │
  Flight APIs  ───► │   RAW_FLIGHTS ──►  DIM_FLIGHTS           │
  Booking Sys  ───► │   RAW_BOOKINGS──►  FACT_BOOKINGS  ──►   │ ──► Ops Dashboard
  Passenger DB ───► │   RAW_PSGR   ──►  DIM_PASSENGERS        │ ──► Cortex AI Models
  Weather APIs ───► │   RAW_WEATHER──►  DIM_WEATHER     ──►   │ ──► Alerts & Actions
  Feedback     ───► │   RAW_FEEDBACK──► FACT_FEEDBACK          │ ──► Data Shares
  IoT Sensors  ───► │   RAW_TELEMETRY►  FACT_TELEMETRY        │ ──► Notebooks
                    │                                          │
                    │   Streams ──► Tasks ──► Dynamic Tables    │
                    │                                          │
                    └──────────────────────────────────────────┘
```

## Data Model: Medallion + Star Schema Hybrid

### Bronze Layer (Raw Ingestion)
- Raw JSON/CSV landing zone
- Schema-on-read, append-only
- Retained for Time Travel (90 days)

### Silver Layer (Conformed Dimensions & Facts)
- Star schema with proper keys and types
- SCD Type 2 on passengers and aircraft
- Data quality validated

### Gold Layer (Business-Ready)
- Dynamic Tables for real-time aggregations
- Pre-computed ML features
- Curated for dashboards and sharing

## Schema Design (Star Schema)

### Dimensions
- `DIM_PASSENGER` — SCD2, loyalty tier, demographics, PII-tagged
- `DIM_FLIGHT` — Route, aircraft, schedule
- `DIM_AIRCRAFT` — Fleet details, maintenance status
- `DIM_AIRPORT` — IATA codes, timezone, capacity
- `DIM_DATE` — Standard date dimension
- `DIM_WEATHER` — Hourly conditions per airport

### Facts
- `FACT_BOOKING` — Grain: one row per booking segment
- `FACT_FLIGHT_EVENT` — Grain: one row per flight operation (actual vs scheduled)
- `FACT_PASSENGER_FEEDBACK` — Grain: one feedback per journey
- `FACT_DELAY` — Grain: one row per delay event with cause codes
- `FACT_LOYALTY_ACTIVITY` — Miles earned/redeemed

### Real-time (Dynamic Tables)
- `DT_FLIGHT_STATUS` — Current delay probability per flight
- `DT_PASSENGER_RISK` — Churn risk score per loyalty member
- `DT_OPS_ANOMALY` — Active anomalies in operations
