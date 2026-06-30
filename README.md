# SkyPulse AI

**Intelligent Airline Operations & Customer Experience Platform**

Built on Snowflake AI Data Cloud | Snowflake AI Innovation Day London | June 2026

---

## The Problem

SkyPulse Airways loses **$187M annually** to flight delays, customer churn, and operational inefficiency. Data lives in silos — flight ops, CRM, maintenance, and commercial teams can't collaborate effectively.

## The Solution

A unified AI-powered data platform on Snowflake that:
- Predicts flight delays 4-6 hours ahead
- Prevents customer churn with ML-driven early warning
- Analyzes passenger sentiment in real-time using Cortex AI
- Detects operational anomalies automatically
- Shares performance data with partner airports

## Business Impact

| Initiative | Year 1 Savings |
|-----------|---------------|
| Delay prediction + proactive rebooking | $28.5M |
| Churn prevention (12% reduction) | $6.2M |
| Sentiment-driven service recovery | $8.0M |
| Anomaly detection on operations | $4.8M |
| **Total** | **$47.5M** |
| Platform cost | ~$2.1M |
| **ROI** | **22.6x** |

## Snowflake Features Used (14)

| # | Feature | Use Case |
|---|---------|----------|
| 1 | Cortex AI (LLM) | Sentiment, summarization, response generation |
| 2 | Cortex ML (Forecast) | Delay & demand prediction |
| 3 | Cortex ML (Anomaly Detection) | Ops & fuel anomalies |
| 4 | Cortex ML (Classification) | Churn & cancellation prediction |
| 5 | Cortex Search | Semantic search over feedback |
| 6 | Dynamic Tables | Real-time operational dashboards |
| 7 | Streams & Tasks | CDC pipeline automation |
| 8 | Snowpark Python | Feature engineering UDFs/UDTFs |
| 9 | Time Travel | Regulatory audit compliance |
| 10 | Data Sharing | Airport OTP collaboration |
| 11 | Hybrid Tables | Low-latency gate management |
| 12 | Iceberg Tables | Lakehouse interoperability |
| 13 | Tags & Governance | PII classification & masking |
| 14 | Alerts | Proactive operational notifications |

## Project Structure

```
skypulse-ai/
├── README.md                          ← You are here
├── RUN_ALL.sql                        ← Single script to deploy everything
├── docs/
│   └── ARCHITECTURE.md                ← Detailed architecture & design
├── presentation/
│   ├── PRESENTATION_OUTLINE.md        ← Slide-by-slide talk track
│   └── DEMO_QUICKSTART.sql            ← Live demo worksheet (5 min)
└── sql/
    ├── 01-setup/
    │   └── 001_database_setup.sql     ← Database, schemas, warehouses, roles
    ├── 02-data-model/
    │   ├── 001_bronze_raw_tables.sql  ← Raw ingestion layer
    │   ├── 002_silver_dimensions.sql  ← Star schema dimensions
    │   ├── 003_silver_facts.sql       ← Transactional fact tables
    │   ├── 004_gold_dynamic_tables.sql← Real-time materialized views
    │   └── 005_streams_and_tasks.sql  ← CDC pipelines
    ├── 03-sample-data/
    │   ├── 001_load_date_dimension.sql
    │   ├── 002_load_reference_data.sql
    │   ├── 003_load_passengers.sql
    │   ├── 004_load_flights_and_bookings.sql
    │   ├── 005_load_delays_and_feedback.sql
    │   └── 006_load_loyalty_activity.sql
    ├── 04-features/
    │   ├── 001_cortex_ai_sentiment.sql
    │   ├── 002_time_travel_governance.sql
    │   ├── 003_data_sharing.sql
    │   ├── 004_alerts_and_notifications.sql
    │   ├── 005_iceberg_and_hybrid_tables.sql
    │   └── 006_snowpark_feature_engineering.sql
    └── 05-ai-ml/
        ├── 001_cortex_ml_forecasting.sql
        ├── 002_cortex_ml_anomaly_detection.sql
        ├── 003_cortex_ml_classification.sql
        ├── 004_cortex_search_and_analyst.sql
        └── 005_notebook_demo.sql
```

## Quick Start

### Prerequisites
- Snowflake Enterprise Edition account (Free Trial works)
- AWS US West (Oregon) region recommended
- ACCOUNTADMIN role access

### Deployment (5 minutes)

**Option A: Run the all-in-one script**
```sql
-- Open RUN_ALL.sql in a Snowflake worksheet and execute
```

**Option B: Run scripts in numbered order**
```
01-setup → 02-data-model → 03-sample-data → 04-features → 05-ai-ml
```

### Demo

1. Deploy the platform (Option A or B above)
2. Open `presentation/DEMO_QUICKSTART.sql` in a Snowflake worksheet
3. Run each section sequentially during your presentation
4. Refer to `presentation/PRESENTATION_OUTLINE.md` for talking points

## Data Model

**Architecture:** Medallion (Bronze → Silver → Gold) with Star Schema in Silver

**Dimensions:** Date, Time, Airport, Aircraft, Passenger (SCD2), Route, Weather, Delay Reason, Cabin Class

**Facts:** Flight Event, Booking, Delay, Passenger Feedback, Loyalty Activity

**Gold Layer:** Dynamic Tables for real-time ops (flight status, passenger risk, route performance, anomalies, daily KPIs)

## Key Design Decisions

1. **Star Schema over normalized** — Optimized for Snowflake's columnar engine and analytical queries
2. **SCD Type 2 on Passengers** — Track loyalty tier changes for churn analysis and regulatory compliance
3. **Dynamic Tables over materialized views** — Declarative, auto-refreshing, with configurable lag
4. **PII Tags + Masking Policies** — GDPR built-in, not bolted on
5. **Cortex ML over external ML** — Zero infrastructure, managed models, integrated into SQL workflows
6. **Hybrid Tables for operational lookups** — Sub-millisecond gate assignments without leaving Snowflake

## Estimated Snowflake Costs

| Component | Monthly Estimate |
|-----------|-----------------|
| Warehouses (mostly auto-suspended) | $800-1,200 |
| Storage (1-5 TB compressed) | $23-115 |
| Cortex AI consumption | $200-500 |
| Cortex ML model training | $100-300 |
| Dynamic Table refresh | $150-400 |
| **Total** | **~$1,500-2,500/mo** |

## Production Roadmap (12 weeks)

| Phase | Duration | Activities |
|-------|----------|-----------|
| Data Integration | Weeks 1-4 | Connect PSS (Amadeus/Sabre), ACARS, weather APIs, CRM |
| Model Tuning | Weeks 5-8 | Train on real data, validate accuracy, A/B test retention offers |
| UAT & Launch | Weeks 9-12 | Ops team training, Streamlit dashboards, alert tuning |

## Team

Built for Snowflake AI Innovation Day London, June 30, 2026.

---

*"From reactive to predictive. From data silos to AI intelligence."*
