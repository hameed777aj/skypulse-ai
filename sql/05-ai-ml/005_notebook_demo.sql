-- ============================================================================
-- SKYPULSE AI — AI/ML: Snowflake Notebook Demo Script
-- ============================================================================
-- This script contains the SQL and Python cells for a Snowflake Notebook
-- that tells the complete SkyPulse AI story interactively.
-- 
-- To use: Create a new Snowflake Notebook and paste these cells in order.
-- Each section represents one notebook cell.
-- ============================================================================

-- ============================================================================
-- CELL 1 (Markdown): Title
-- ============================================================================
/*
# SkyPulse AI — Intelligent Airline Operations Platform
## Snowflake AI Innovation Day | London | June 2026

**Business Problem:** SkyPulse Airways loses $187M annually to delays, churn, and operational inefficiency.

**Solution:** AI-powered data platform on Snowflake predicting delays, preventing churn, and optimizing operations.

**Projected ROI:** $47.5M Year 1 savings (22.6x return on platform investment)
*/

-- ============================================================================
-- CELL 2 (SQL): Operational Overview
-- ============================================================================

-- Today's operations at a glance
SELECT
    COUNT(*) AS total_flights,
    COUNT(CASE WHEN arrival_delay_min <= 15 THEN 1 END) AS on_time,
    ROUND(COUNT(CASE WHEN arrival_delay_min <= 15 THEN 1 END) * 100.0 / COUNT(*), 1) AS otp_pct,
    ROUND(AVG(arrival_delay_min), 1) AS avg_delay_min,
    SUM(pax_flown) AS total_passengers,
    ROUND(AVG(load_factor_pct), 1) AS avg_load_factor,
    ROUND(SUM(revenue_total), 0) AS total_revenue_gbp
FROM SKYPULSE_AI.SILVER.FACT_FLIGHT_EVENT fe
JOIN SKYPULSE_AI.SILVER.DIM_DATE d ON fe.flight_date_key = d.date_key
WHERE d.full_date >= DATEADD('day', -7, CURRENT_DATE())
  AND fe.flight_status = 'LANDED';

-- ============================================================================
-- CELL 3 (SQL): Delay Cost Analysis
-- ============================================================================

-- Total cost of delays by category (the $95M problem)
SELECT
    dl.delay_category,
    COUNT(*) AS incidents,
    ROUND(AVG(dl.delay_minutes), 0) AS avg_delay_min,
    SUM(dl.pax_affected) AS total_pax_affected,
    ROUND(SUM(dl.compensation_amount), 0) AS compensation_gbp,
    ROUND(SUM(dl.rebooking_cost), 0) AS rebooking_gbp,
    ROUND(SUM(dl.hotel_cost), 0) AS hotel_gbp,
    ROUND(SUM(dl.total_cost_impact), 0) AS total_cost_gbp,
    ROUND(SUM(dl.total_cost_impact) / NULLIF(SUM(dl.pax_affected), 0), 2) AS cost_per_pax
FROM SKYPULSE_AI.SILVER.FACT_DELAY dl
GROUP BY dl.delay_category
ORDER BY total_cost_gbp DESC;

-- ============================================================================
-- CELL 4 (Python): Delay Visualization
-- ============================================================================

/*
# Python cell for Snowflake Notebook
import streamlit as st
import pandas as pd
import plotly.express as px

# Get data from previous cell
delay_data = session.sql("""
    SELECT delay_category, COUNT(*) as incidents, 
           ROUND(SUM(total_cost_impact), 0) as total_cost
    FROM SKYPULSE_AI.SILVER.FACT_DELAY 
    GROUP BY delay_category 
    ORDER BY total_cost DESC
""").to_pandas()

# Create visualization
fig = px.bar(delay_data, x='DELAY_CATEGORY', y='TOTAL_COST',
             color='INCIDENTS', title='Delay Cost Impact by Category (GBP)',
             labels={'TOTAL_COST': 'Total Cost (GBP)', 'DELAY_CATEGORY': 'Category'})
st.plotly_chart(fig)
*/

-- ============================================================================
-- CELL 5 (SQL): Cortex AI Sentiment Demo (LIVE)
-- ============================================================================

-- Real-time sentiment analysis on the most recent feedback
SELECT
    f.feedback_key,
    LEFT(f.feedback_text, 100) || '...' AS feedback_preview,
    SNOWFLAKE.CORTEX.SENTIMENT(f.feedback_text) AS live_sentiment_score,
    CASE 
        WHEN SNOWFLAKE.CORTEX.SENTIMENT(f.feedback_text) > 0.3 THEN 'POSITIVE'
        WHEN SNOWFLAKE.CORTEX.SENTIMENT(f.feedback_text) < -0.3 THEN 'NEGATIVE'
        ELSE 'NEUTRAL'
    END AS sentiment,
    f.nps_score,
    p.loyalty_tier
FROM SKYPULSE_AI.SILVER.FACT_PASSENGER_FEEDBACK f
LEFT JOIN SKYPULSE_AI.SILVER.DIM_PASSENGER p 
    ON f.passenger_key = p.passenger_key AND p.is_current = TRUE
ORDER BY f.feedback_timestamp DESC
LIMIT 10;

-- ============================================================================
-- CELL 6 (SQL): AI-Generated Customer Response (LIVE)
-- ============================================================================

-- Watch Cortex AI generate a personalized response in real-time
SELECT
    p.first_name || ' ' || p.last_name AS customer,
    p.loyalty_tier,
    LEFT(f.feedback_text, 80) AS complaint_preview,
    SNOWFLAKE.CORTEX.COMPLETE(
        'mistral-large2',
        'Write a 2-sentence empathetic apology to ' || p.first_name || 
        ' (a ' || p.loyalty_tier || ' member) regarding: ' || f.feedback_text ||
        ' Include a specific compensation offer.'
    ) AS ai_response
FROM SKYPULSE_AI.SILVER.FACT_PASSENGER_FEEDBACK f
JOIN SKYPULSE_AI.SILVER.DIM_PASSENGER p 
    ON f.passenger_key = p.passenger_key AND p.is_current = TRUE
WHERE f.sentiment_score < -0.6
  AND p.loyalty_tier IN ('DIAMOND', 'PLATINUM')
ORDER BY f.sentiment_score ASC
LIMIT 3;

-- ============================================================================
-- CELL 7 (SQL): Churn Risk — At-Risk High-Value Passengers
-- ============================================================================

SELECT
    churn_risk_level,
    loyalty_tier,
    COUNT(*) AS passengers_at_risk,
    ROUND(AVG(revenue_last_90d), 0) AS avg_revenue_90d,
    ROUND(AVG(days_since_last_booking), 0) AS avg_days_inactive,
    ROUND(AVG(avg_sentiment_90d), 2) AS avg_sentiment
FROM SKYPULSE_AI.GOLD.DT_PASSENGER_RISK
WHERE churn_risk_level IN ('CRITICAL', 'HIGH')
GROUP BY churn_risk_level, loyalty_tier
ORDER BY churn_risk_level, loyalty_tier DESC;

-- ============================================================================
-- CELL 8 (SQL): Route Performance Comparison
-- ============================================================================

-- Which routes make money vs which lose money to delays?
SELECT
    r.route_code,
    r.route_type,
    COUNT(DISTINCT fe.flight_event_key) AS flights,
    ROUND(AVG(fe.load_factor_pct), 1) AS avg_load_factor,
    ROUND(AVG(fe.arrival_delay_min), 1) AS avg_delay,
    ROUND(SUM(fe.revenue_total), 0) AS total_revenue,
    ROUND(COALESCE(SUM(dl.total_cost_impact), 0), 0) AS delay_costs,
    ROUND(SUM(fe.revenue_total) - COALESCE(SUM(dl.total_cost_impact), 0), 0) AS net_contribution,
    ROUND(COALESCE(SUM(dl.total_cost_impact), 0) / NULLIF(SUM(fe.revenue_total), 0) * 100, 1) AS delay_cost_pct_revenue
FROM SKYPULSE_AI.SILVER.FACT_FLIGHT_EVENT fe
JOIN SKYPULSE_AI.SILVER.DIM_ROUTE r ON fe.route_key = r.route_key
LEFT JOIN SKYPULSE_AI.SILVER.FACT_DELAY dl ON fe.flight_event_key = dl.flight_event_key
JOIN SKYPULSE_AI.SILVER.DIM_DATE d ON fe.flight_date_key = d.date_key
WHERE d.full_date >= DATEADD('day', -30, CURRENT_DATE())
GROUP BY r.route_code, r.route_type
ORDER BY net_contribution DESC;

-- ============================================================================
-- CELL 9 (Python): ML Model Results Visualization
-- ============================================================================

/*
# Churn risk distribution
import streamlit as st
import pandas as pd
import plotly.express as px

churn_data = session.sql("""
    SELECT churn_risk_level, loyalty_tier, COUNT(*) as count
    FROM SKYPULSE_AI.GOLD.DT_PASSENGER_RISK
    GROUP BY churn_risk_level, loyalty_tier
""").to_pandas()

fig = px.sunburst(churn_data, path=['CHURN_RISK_LEVEL', 'LOYALTY_TIER'], values='COUNT',
                  title='Customer Churn Risk by Tier',
                  color='CHURN_RISK_LEVEL',
                  color_discrete_map={'CRITICAL':'red', 'HIGH':'orange', 'MEDIUM':'yellow', 'LOW':'green'})
st.plotly_chart(fig)
*/

-- ============================================================================
-- CELL 10 (SQL): Business Impact Summary
-- ============================================================================

-- The bottom line: quantified business impact
SELECT
    '30% reduction in delay compensation' AS initiative,
    ROUND(SUM(compensation_amount) * 0.30, 0) AS projected_saving_gbp,
    'Predictive delay model + proactive rebooking' AS how
FROM SKYPULSE_AI.SILVER.FACT_DELAY
UNION ALL
SELECT
    '12% churn prevention (high-value members)',
    ROUND((SELECT SUM(revenue_last_90d) * 4 * 0.12 FROM SKYPULSE_AI.GOLD.DT_PASSENGER_RISK 
           WHERE churn_risk_level IN ('CRITICAL','HIGH')), 0),
    'ML churn prediction + targeted retention'
UNION ALL
SELECT
    '15% NPS improvement',
    8000000,  -- Industry benchmark
    'AI-powered feedback triage + personalized recovery'
UNION ALL
SELECT
    '20% fewer unplanned disruptions',
    ROUND((SELECT SUM(total_cost_impact) * 0.20 FROM SKYPULSE_AI.SILVER.FACT_DELAY 
           WHERE delay_category IN ('TECHNICAL','REACTIONARY')), 0),
    'Anomaly detection + predictive maintenance alerts';
