# SkyPulse AI — Presentation & Demo Script
## Snowflake AI Innovation Day | London | 30 June 2026

---

## Timing: 5-7 minutes (adjust based on hackathon format)

---

## SLIDE 1: Opening Hook (30 seconds)

**Title:** "Every minute of delay costs $187"

**Talking Points:**
- "Last year, the airline industry lost $35 billion to flight delays globally"
- "For SkyPulse Airways — our fictional mid-size carrier with 45 million passengers — that translates to $187 million in lost revenue, compensation, and customer churn"
- "Today we'll show you how Snowflake's AI Data Cloud turns that problem into a $47.5 million opportunity"

**Visual:** Single dramatic stat on screen. No busy slides.

---

## SLIDE 2: The Problem (45 seconds)

**Title:** "Four challenges, one platform"

| Challenge | Annual Impact |
|-----------|--------------|
| Flight delays & compensation (EU261) | $95M |
| Customer churn (loyalty members leaving) | $52M |
| Overbooking & revenue leakage | $28M |
| Reactive maintenance events | $12M |

**Talking Points:**
- "These aren't separate problems — they're interconnected. A delay causes churn, churn causes revenue loss, poor forecasting causes overbooking"
- "The root cause? Data silos. Flight ops, customer service, maintenance, and commercial teams each have their own systems"
- "We need a unified intelligence layer"

---

## SLIDE 3: The Solution — Architecture (45 seconds)

**Title:** "SkyPulse AI: Unified Intelligence on Snowflake"

**Visual:** The medallion architecture diagram (Bronze → Silver → Gold)

**Talking Points:**
- "Built entirely on Snowflake's AI Data Cloud — no external ML infrastructure"
- "Medallion architecture: raw ingestion, conformed star schema, real-time business views"
- "12 Snowflake features working together — not just using them for the sake of it, each solves a real operational need"
- Briefly list the layers: "Cortex AI for intelligence, Dynamic Tables for real-time, Streams & Tasks for automation, Data Sharing for collaboration"

---

## SLIDE 4: Data Model (30 seconds)

**Title:** "Enterprise-grade star schema"

**Visual:** ER diagram showing DIM/FACT relationships

**Talking Points:**
- "Star schema optimized for analytical queries — dimensions for airports, passengers, aircraft, routes; facts for flights, bookings, delays, feedback"
- "SCD Type 2 on passengers tracks loyalty tier changes over time"
- "PII tagged and masked for GDPR compliance — governance built in from day one, not bolted on"
- "500 passengers, 2,400 flights, 20 routes — fully generated inside Snowflake using GENERATOR, no external data loads needed"

---

## SLIDE 5: LIVE DEMO — Cortex AI Sentiment (90 seconds)

**What to show:** Run the sentiment analysis query live

**Demo Steps:**
1. Show raw feedback text (negative customer complaint)
2. Run `SNOWFLAKE.CORTEX.SENTIMENT()` — instant score appears
3. Run `SNOWFLAKE.CORTEX.SUMMARIZE()` — one-line summary
4. Run `SNOWFLAKE.CORTEX.COMPLETE()` — AI generates personalized apology response for a Diamond member
5. Show the response references their specific complaint and offers compensation

**Key Quote:** "From raw complaint to personalized recovery response — zero external APIs, zero model training, zero infrastructure. This is the power of Cortex built into the data platform."

---

## SLIDE 6: LIVE DEMO — Predictive Models (60 seconds)

**What to show:** Cortex ML forecasting and classification results

**Demo Steps:**
1. Show the delay forecast for next 7 days per route
2. Highlight: "LHR-JFK predicted 28-minute average delay next Tuesday — we can proactively rebook passengers NOW"
3. Show churn prediction: "Victoria Sterling, Diamond member, 82% churn probability. She's experienced 3 major delays and her sentiment dropped to -0.7. Recommended action: personal call from account manager"
4. Show the anomaly detection: "G-SPDA showing 15% above-normal fuel burn — flag for engineering before it becomes an AOG event"

**Key Quote:** "Prediction, not reaction. We're shifting from fire-fighting to fire-prevention."

---

## SLIDE 7: LIVE DEMO — Real-time Operations (60 seconds)

**What to show:** Dynamic Tables + Alerts + Gate Management

**Demo Steps:**
1. Show `DT_FLIGHT_STATUS` dynamic table — auto-refreshing every minute
2. Show `DT_OPS_ANOMALY` — real-time anomaly detection
3. Show the alert definitions — "When OTP drops below 75%, ops director gets notified automatically"
4. Show gate assignment table — "Low-latency lookup for real-time systems (Hybrid Table in production)"
5. Mention Streams & Tasks: "Every new booking triggers automatic star schema enrichment. Every new feedback gets AI sentiment scored within 10 minutes"

**Key Quote:** "This isn't a batch reporting system. It's a living, breathing operational nervous system."

---

## SLIDE 8: Feature Breadth (30 seconds)

**Title:** "12 Snowflake features, one cohesive platform"

**Visual:** Feature grid with checkmarks

| Feature | Use Case |
|---------|----------|
| Cortex AI (LLM) | Sentiment, summarization, translation, response generation |
| Cortex ML (Forecast) | Delay, demand & revenue prediction |
| Cortex ML (Anomaly) | Ops & fuel anomaly detection |
| Cortex ML (Classification) | Churn & cancellation prediction |
| Dynamic Tables | Real-time dashboards (5 tables) |
| Streams & Tasks | CDC pipeline automation |
| Snowpark Python | Feature engineering UDFs |
| Time Travel | Regulatory audit compliance |
| Data Sharing | Airport OTP collaboration |
| Tags & Governance | PII classification, masking & row access |
| Alerts | Proactive operational notifications |
| Multi-cluster Warehouses | Workload isolation |

---

## SLIDE 9: Business Impact (45 seconds)

**Title:** "$47.5M saved. 22.6x ROI."

| Initiative | Mechanism | Year 1 Value |
|-----------|-----------|-------------|
| Delay prediction + proactive rebooking | 30% fewer compensation claims | $28.5M |
| Churn prevention | 12% reduction in high-value attrition | $6.2M |
| Sentiment-driven service recovery | 15% NPS improvement | $8.0M |
| Anomaly detection | 20% fewer unplanned disruptions | $4.8M |
| **Total** | | **$47.5M** |
| Platform cost | Snowflake + engineering | ~$2.1M |
| **Net ROI** | | **22.6x** |

**Talking Points:**
- "These aren't aspirational — they're grounded in industry benchmarks"
- "EU261 compensation alone: if we prevent just 30% of eligible delays from exceeding 3 hours, that's $28.5M"
- "And the platform pays for itself 22 times over in year one"

---

## SLIDE 10: Viability & Next Steps (30 seconds)

**Title:** "Production-ready in 12 weeks"

**Talking Points:**
- "Everything you've seen runs today on a Snowflake Enterprise trial account"
- "Real-world implementation would need: actual data source connectors (Amadeus PSS, AIMS, ACARS), prod security/networking, Streamlit dashboards for ops teams"
- "Timeline: 4 weeks data integration, 4 weeks model tuning, 4 weeks UAT = 12 weeks to value"
- "No new infrastructure to procure — it's all Snowflake"

---

## SLIDE 11: Close (15 seconds)

**Title:** "From reactive to predictive. From data silos to AI intelligence."

**Closing line:** "SkyPulse AI: Because every passenger deserves a flight that runs on intelligence, not just fuel."

---

## DEMO RUNBOOK (Quick Reference)

### Pre-demo setup:
1. Run `./deploy.sh` (already done — platform is live)
2. Open Snowflake UI with `presentation/DEMO_QUICKSTART.sql` in a worksheet
3. Ensure warehouse `SKYPULSE_ML_WH` is running (auto-resumes on first query)

### If demo breaks:
- All queries are idempotent — safe to re-run
- Key queries have `LIMIT` clauses — they'll return fast even on cold warehouse
- The Cortex AI queries (sentiment, complete) work independently of the ML models

### Judges' likely questions:
1. **"How much would this cost to run?"** → ~$2.1M/year (4 warehouses mostly suspended, Cortex consumption-based)
2. **"How do you handle real-time data?"** → Streams for CDC, Dynamic Tables for materialization, Tasks for scheduling
3. **"What about data quality?"** → Bronze preserves raw, Silver validates + conforms, schema enforcement at each layer
4. **"How accurate are the ML models?"** → Cortex ML provides built-in evaluation metrics (SHOW_EVALUATION_METRICS). Cancellation model shows load_factor and departure_hour as top features.
5. **"Could this work for a real airline?"** → Yes — IATA standard delay codes, industry-standard star schema, SCD2 for compliance, PII tagging for GDPR
6. **"Why not Hybrid Tables / Iceberg?"** → Designed for them (gate assignments, lakehouse interop) but not available on trial. Production roadmap includes both.
