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

## Snowflake Features Used (12)

| # | Feature | Use Case |
|---|---------|----------|
| 1 | Cortex AI (LLM) | Sentiment, summarization, translation, response generation |
| 2 | Cortex ML (Forecast) | Delay, demand & revenue prediction |
| 3 | Cortex ML (Anomaly Detection) | Ops & fuel anomalies |
| 4 | Cortex ML (Classification) | Churn & cancellation prediction |
| 5 | Dynamic Tables | Real-time operational dashboards (5 tables) |
| 6 | Streams & Tasks | CDC pipeline automation (4 streams, 4 tasks) |
| 7 | Snowpark Python | Feature engineering UDFs/UDTFs |
| 8 | Time Travel | Regulatory audit compliance |
| 9 | Data Sharing | Airport OTP collaboration (secure views + shares) |
| 10 | Tags & Governance | PII classification, masking policies, row access |
| 11 | Alerts | Proactive operational notifications (5 alerts) |
| 12 | Multi-cluster Warehouses | Workload isolation (ingest, transform, analytics, ML) |

## Project Structure

```
skypulse-ai/
├── README.md                          ← You are here
├── deploy.sh                          ← Automated deployment (SnowSQL + MFA)
├── .env.example                       ← Connection config template
├── Makefile                           ← Convenience commands
├── docs/
│   ├── ARCHITECTURE.md                ← Detailed architecture & design
│   ├── SETUP_GUIDE.md                 ← Step-by-step deployment guide
│   └── semantic_model.yaml            ← Cortex Analyst semantic model
├── presentation/
│   ├── PRESENTATION_OUTLINE.md        ← Slide-by-slide talk track
│   └── DEMO_QUICKSTART.sql            ← Live demo worksheet (5 min)
└── sql/
    ├── 01-setup/                      ← Database, schemas, warehouses, roles
    ├── 02-data-model/                 ← Bronze → Silver → Gold schema
    ├── 03-sample-data/                ← Self-generating demo data
    ├── 04-features/                   ← Cortex AI, governance, sharing, alerts
    └── 05-ai-ml/                      ← ML models (forecast, anomaly, classification)
```

## Quick Start

### Prerequisites
- Snowflake Enterprise Edition account (Free Trial works)
- AWS US West (Oregon) region recommended
- ACCOUNTADMIN role access

### Deployment (5 minutes)

**Option A: Automated deployment via SnowSQL (recommended)**
```bash
# Configure credentials
cp .env.example .env   # Edit with your Snowflake account details

# Deploy everything (one command, ~10 minutes)
./deploy.sh
```

**Option B: Run scripts in numbered order in Snowflake UI**
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

**Facts:** Flight Event (2,400+), Booking (2,400+), Delay (288), Passenger Feedback (301), Loyalty Activity (1,500+)

**Gold Layer:** Dynamic Tables for real-time ops (flight status, passenger risk, route performance, anomalies, daily KPIs)

## Key Design Decisions

1. **Star Schema over normalized** — Optimized for Snowflake's columnar engine and analytical queries
2. **SCD Type 2 on Passengers** — Track loyalty tier changes for churn analysis and regulatory compliance
3. **Dynamic Tables over materialized views** — Declarative, auto-refreshing, with configurable lag
4. **PII Tags + Masking Policies** — GDPR built-in, not bolted on
5. **Cortex ML over external ML** — Zero infrastructure, managed models, integrated into SQL workflows
6. **Gate Assignment as standard table** — In production, this would be a Hybrid Table for sub-ms lookups (not available on trial)

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
