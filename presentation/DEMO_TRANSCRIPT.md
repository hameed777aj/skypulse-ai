# SkyPulse AI — Demo Transcript

**Read this while presenting. Each section maps to a query in DEMO_QUICKSTART.sql.**
**Total time: 6-7 minutes**

---

## OPENING (30 seconds) — Before running any queries

> "Good afternoon everyone. I'm [your name], and today I'm going to show you SkyPulse AI — an intelligent airline operations platform built entirely on Snowflake's AI Data Cloud.
>
> Here's the problem we're solving: A mid-size airline like SkyPulse Airways, carrying 45 million passengers a year across 800 routes, loses 187 million dollars annually to flight delays, customer churn, and operational inefficiency.
>
> The root cause? Data silos. Flight operations, customer service, maintenance, and commercial teams all have their own systems. They can't see the full picture.
>
> Our solution unifies all that data into one AI-powered platform that predicts problems before they happen. Let me show you how."

---

## ABOUT THE SETUP (45 seconds) — Describe the architecture

> "Before I run the live demo, let me quickly explain what we built.
>
> This platform uses a medallion architecture — Bronze, Silver, and Gold layers — all inside Snowflake. Bronze is the raw ingestion zone for flight feeds, booking systems, weather APIs, and passenger feedback. Silver is a conformed star schema with proper dimensions and facts — airports, aircraft, passengers with SCD Type 2 tracking, routes, and weather. Gold is our real-time layer powered by Dynamic Tables that auto-refresh every minute.
>
> The data model has 500 passengers, 2,400 flights across 20 routes, delay events with IATA standard cause codes, and 300 pieces of customer feedback — all generated inside Snowflake using the GENERATOR function. No external data loads needed.
>
> We use 12 Snowflake features working together: Cortex AI for language intelligence, Cortex ML for forecasting and anomaly detection, Dynamic Tables for real-time views, Streams and Tasks for CDC automation, Snowpark Python for feature engineering, Data Sharing for airport collaboration, Tags and Masking for GDPR governance, and Alerts for proactive notifications.
>
> The entire platform deploys in under 11 minutes from a single command. Let me show you what it can do."

---

## DEMO 1: Real-time Operations Dashboard (30 seconds)

**[Run the first query in DEMO_QUICKSTART.sql]**

> "This is our operational heartbeat. You're looking at a Dynamic Table that refreshes every minute. It shows every flight in the network with its current status, delay severity, load factor, and aircraft type.
>
> This isn't a batch report that someone pulls at the end of the day. It's a living, breathing view of operations. Notice the delay severity categories — from 'ON_TIME' to 'SEVERE'. Operations control can see at a glance which flights need intervention right now.
>
> The Dynamic Table behind this does all the computation automatically. No scheduled jobs to maintain, no ETL to debug. You define the query once, Snowflake keeps it fresh."

---

## DEMO 2: Cortex AI Sentiment Analysis (60 seconds)

**[Run the sentiment query]**

> "Now here's where Cortex AI comes in. We're analyzing customer feedback sentiment in real-time using Snowflake's built-in LLM functions. Watch this.
>
> I'm running SNOWFLAKE.CORTEX.SENTIMENT on our passenger feedback. No model training, no external API calls, no infrastructure. It just works inside a SQL query. You can see each piece of feedback gets a sentiment score from minus one to plus one, and we classify it as positive, negative, or neutral.
>
> This powers our automated feedback triage — negative feedback from high-value loyalty members gets routed immediately to service recovery."

**[Run the COMPLETE query for AI response generation]**

> "Now watch this. We take the most negative feedback from a Diamond or Platinum member, and we ask Cortex AI to generate a personalized apology response.
>
> Look at the output — it references their specific complaint, it acknowledges their loyalty tier, and it offers a concrete compensation. This went from raw complaint text to a sendable response in under 3 seconds. Zero external APIs. Zero model hosting costs. This is the power of having AI built into the data platform."

---

## DEMO 3: Churn Prediction (45 seconds)

**[Run the DT_PASSENGER_RISK query]**

> "Moving to predictive analytics. Our Dynamic Table DT_PASSENGER_RISK continuously scores every loyalty member for churn risk. It combines booking recency, spend patterns, delay experiences, and sentiment into a risk level.
>
> Look at this list — these are our high-value members at critical or high risk. You can see their days of inactivity, their recent revenue, their average sentiment score, how many complaints they've filed, and how many bad delay experiences they've had.
>
> More importantly, each passenger gets a recommended retention action. A critical Diamond member gets a personal phone call plus 50,000 bonus miles. A high-risk Gold member gets a targeted upgrade voucher. This isn't spray-and-pray marketing — it's precision retention powered by ML."

**[Run the ML Forecast query]**

> "And here's our delay forecasting model. Cortex ML Forecast was trained on 90 days of historical delay data per route. It now predicts average delays for the next 7 days.
>
> You can see which routes are predicted to have the highest delays. This lets operations proactively adjust crew scheduling, pre-position spare aircraft, or even reach out to passengers before they're affected. That's the shift from reactive to predictive."

---

## DEMO 4: Delay Cost Analysis (30 seconds)

**[Run the delay cost query]**

> "Let's talk money. This query shows the total financial impact of delays by category. You can see weather, reactionary delays, ATC holds, technical issues — each with the number of incidents, average delay duration, passengers affected, and total cost in pounds.
>
> Under EU261 regulations, delays over 3 hours trigger automatic compensation of 250 to 600 euros per passenger. That's where the 95 million dollar annual problem comes from.
>
> But look at the last column — our AI solution for each category. Weather delays? We predict them and proactively rebook. Reactionary delays? We break the chain by identifying cascading disruptions early. Technical issues? Anomaly detection flags fuel consumption outliers before they become aircraft-on-ground events."

---

## DEMO 5: Data Governance (20 seconds)

**[Run the PII tags query]**

> "Airlines handle extremely sensitive data — passport numbers, payment details, personal information. GDPR isn't optional.
>
> We built governance in from day one, not bolted on after. Every PII column is tagged with its classification — name, email, phone, passport, date of birth. Dynamic masking policies ensure analysts see redacted data while admins see the full picture. Same query, different results based on your role. Zero application code changes needed."

---

## DEMO 6: AI Ops Chatbot (30 seconds)

**[Run the OPS_CHATBOT query]**

> "Finally — natural language access for business users. Our ops chatbot uses Cortex COMPLETE to answer questions in plain English, grounded in actual operational data.
>
> I'm asking: 'What is our on-time performance and how many passengers did we serve?' And it responds with the exact numbers from our data. No dashboard training needed. No SQL knowledge required. An ops manager can just ask a question and get an answer.
>
> This is built as a single SQL function. In production, you'd wrap this in a Streamlit app for the full chat experience."

---

## DEMO 7: The ROI (15 seconds)

**[Run the final ROI query]**

> "And here's the bottom line. Delay prediction saves 28.5 million. Churn prevention saves 6.2 million. Sentiment-driven recovery adds 8 million in revenue uplift. Anomaly detection prevents 4.8 million in disruption costs.
>
> Total year-one benefit: 47.5 million dollars. Platform cost including Snowflake consumption and engineering: 2.1 million. That's a 22.6x return on investment in year one."

---

## CLOSING (30 seconds)

> "To summarize what you've seen today:
>
> We took a 187 million dollar problem and built a unified AI platform on Snowflake that addresses it with a projected 47.5 million dollar saving in year one.
>
> We used 12 Snowflake features — not as a checklist, but because each one solves a specific operational need. Cortex AI for intelligence. Dynamic Tables for real-time. ML models for prediction. Data Sharing for collaboration. Governance for compliance.
>
> Everything you've seen runs today on a Snowflake Enterprise free trial account. Production deployment would take 12 weeks — 4 weeks for data integration with real airline systems like Amadeus, 4 weeks for model tuning on real data, and 4 weeks for UAT and Streamlit dashboard development. No new infrastructure to procure.
>
> SkyPulse AI: from reactive to predictive. From data silos to AI intelligence.
>
> Thank you. Happy to take questions."

---

## HANDLING QUESTIONS

**"How much credit did this use?"**
> "The full deployment including all 7 ML models takes about 0.5 Snowflake credits. In production with real data volumes, we estimate $1,500-2,500 per month — most warehouses are auto-suspended when not in use."

**"How do you handle real-time data?"**
> "Three mechanisms: Streams capture change data from source systems. Tasks process those changes on a schedule — every 2 minutes for flight status, every 5 for bookings, every 10 for feedback with AI enrichment. Dynamic Tables then materialize the business views automatically."

**"What about data quality?"**
> "The medallion architecture handles this by design. Bronze preserves raw data with no transformation. Silver applies validation, type casting, and schema conformance. If anything fails validation, it stays in Bronze for investigation. We also have 90-day Time Travel for full audit compliance."

**"Could this scale to a real airline?"**
> "Absolutely. The star schema is based on IATA industry standards. The delay codes are real IATA codes. SCD Type 2 on passengers handles the compliance requirements. Snowflake's elastic compute means you scale warehouses up for peak processing and down when idle — you only pay for what you use."

**"What would you do differently with more time?"**
> "Three things: First, connect to real data sources — Amadeus for bookings, ACARS for aircraft telemetry, NOAA for weather. Second, build Streamlit dashboards for the operations team so they don't need SQL. Third, implement Cortex Fine-tuning on our feedback data so the sentiment model is calibrated to airline-specific language."

**"Why Snowflake over alternatives?"**
> "Three reasons: First, Cortex AI and ML are built-in — no separate ML platform to manage, no model serving infrastructure, no API gateway. Second, everything runs in SQL — data engineers, analysts, and data scientists all work in the same environment. Third, features like Dynamic Tables, Streams, and Data Sharing mean we can build a production-grade real-time platform without any external orchestration tools."
