-- ============================================================================
-- SKYPULSE AI — DEMO QUICKSTART
-- ============================================================================
-- Run this single worksheet during the presentation for maximum impact.
-- Each section is a self-contained "wow moment" — run them sequentially.
-- Estimated total demo time: 4-5 minutes
-- ============================================================================

-- Setup context
USE DATABASE SKYPULSE_AI;
USE WAREHOUSE SKYPULSE_ML_WH;

-- ═══════════════════════════════════════════════════════════════════════════════
-- DEMO 1: Real-time Operations Dashboard (30 sec)
-- ═══════════════════════════════════════════════════════════════════════════════

-- "Here's our operational heartbeat — refreshing every minute"
SELECT
    flight_number,
    origin_iata || ' → ' || dest_iata AS route,
    flight_status,
    departure_delay_min,
    delay_severity,
    load_factor_pct || '%' AS load_factor,
    aircraft_type
FROM SKYPULSE_AI.GOLD.DT_FLIGHT_STATUS
ORDER BY departure_delay_min DESC
LIMIT 10;

-- ═══════════════════════════════════════════════════════════════════════════════
-- DEMO 2: Cortex AI Sentiment — Live Analysis (60 sec)
-- ═══════════════════════════════════════════════════════════════════════════════

-- "Watch Cortex AI analyze customer sentiment in real-time — no model training needed"
SELECT
    LEFT(feedback_text, 80) || '...' AS feedback_preview,
    SNOWFLAKE.CORTEX.SENTIMENT(feedback_text) AS sentiment_score,
    CASE 
        WHEN SNOWFLAKE.CORTEX.SENTIMENT(feedback_text) > 0.3 THEN 'POSITIVE'
        WHEN SNOWFLAKE.CORTEX.SENTIMENT(feedback_text) < -0.3 THEN 'NEGATIVE'
        ELSE 'NEUTRAL'
    END AS verdict,
    nps_score,
    feedback_channel
FROM SKYPULSE_AI.SILVER.FACT_PASSENGER_FEEDBACK
WHERE feedback_text IS NOT NULL
ORDER BY feedback_timestamp DESC
LIMIT 5;

-- "Now let's generate an AI-powered response for our most upset Diamond member"
USE SCHEMA SILVER;
SELECT
    p.first_name || ' ' || p.last_name AS customer,
    p.loyalty_tier,
    LEFT(f.feedback_text, 60) || '...' AS complaint,
    SNOWFLAKE.CORTEX.COMPLETE(
        'mistral-large2',
        'You are a premium airline customer service manager. Write a brief (3 sentences max), ' ||
        'empathetic, personalized apology to ' || p.first_name || ', a ' || p.loyalty_tier || 
        ' loyalty member. Reference their specific issue and offer compensation. ' ||
        'Their complaint: ' || f.feedback_text
    ) AS ai_generated_response
FROM FACT_PASSENGER_FEEDBACK f
JOIN DIM_PASSENGER p ON f.passenger_key = p.passenger_key AND p.is_current = TRUE
WHERE f.sentiment_score < -0.6
  AND p.loyalty_tier IN ('DIAMOND', 'PLATINUM')
ORDER BY f.sentiment_score ASC
LIMIT 1;

-- ═══════════════════════════════════════════════════════════════════════════════
-- DEMO 3: Churn Prediction — Who's About to Leave? (45 sec)
-- ═══════════════════════════════════════════════════════════════════════════════

-- "Our ML model identifies high-value passengers at risk of churning"
SELECT
    full_name,
    loyalty_tier,
    churn_risk_level,
    days_since_last_booking || ' days inactive' AS inactivity,
    ROUND(revenue_last_90d, 0) || ' GBP' AS recent_revenue,
    ROUND(avg_sentiment_90d, 2) AS sentiment,
    negative_feedback_count AS complaints,
    major_delays_experienced AS bad_experiences,
    CASE 
        WHEN churn_risk_level = 'CRITICAL' THEN 'Personal call + 50K bonus miles'
        WHEN churn_risk_level = 'HIGH' THEN 'Targeted upgrade voucher'
        ELSE 'Re-engagement campaign'
    END AS recommended_action
FROM SKYPULSE_AI.GOLD.DT_PASSENGER_RISK
WHERE churn_risk_level IN ('CRITICAL', 'HIGH')
ORDER BY 
    CASE churn_risk_level WHEN 'CRITICAL' THEN 1 WHEN 'HIGH' THEN 2 ELSE 3 END,
    revenue_last_90d DESC
LIMIT 8;

-- ═══════════════════════════════════════════════════════════════════════════════
-- DEMO 3B: ML Forecasting — What delays are coming? (30 sec)
-- ═══════════════════════════════════════════════════════════════════════════════

-- "Our forecasting model predicts delays per route for the next 7 days"
SELECT
    route_code,
    forecast_date,
    ROUND(predicted_avg_delay_min, 1) AS predicted_delay_min,
    ROUND(delay_upper_95, 1) AS worst_case,
    CASE 
        WHEN predicted_avg_delay_min > 30 THEN 'HIGH RISK'
        WHEN predicted_avg_delay_min > 15 THEN 'MODERATE'
        ELSE 'LOW'
    END AS risk_level
FROM SKYPULSE_AI.ML.DELAY_FORECAST_RESULTS
WHERE forecast_date BETWEEN CURRENT_DATE() AND DATEADD('day', 7, CURRENT_DATE())
ORDER BY predicted_avg_delay_min DESC
LIMIT 10;

-- ═══════════════════════════════════════════════════════════════════════════════
-- DEMO 4: Delay Cost Analysis — The $95M Problem (30 sec)
-- ═══════════════════════════════════════════════════════════════════════════════

-- "Here's where the money goes — and why prediction saves millions"
SELECT
    delay_category,
    COUNT(*) AS incidents,
    ROUND(AVG(delay_minutes), 0) || ' min' AS avg_delay,
    TO_CHAR(SUM(pax_affected), '999,999') AS passengers_hit,
    '£' || TO_CHAR(ROUND(SUM(total_cost_impact), 0), '999,999,999') AS total_cost,
    CASE 
        WHEN delay_category = 'WEATHER' THEN 'Predict & proactively rebook'
        WHEN delay_category = 'REACTIONARY' THEN 'Break the delay chain'
        WHEN delay_category = 'TECHNICAL' THEN 'Predictive maintenance'
        WHEN delay_category = 'ATC' THEN 'Optimize slot management'
        ELSE 'Improve resource planning'
    END AS ai_solution
FROM SKYPULSE_AI.SILVER.FACT_DELAY
GROUP BY delay_category
ORDER BY SUM(total_cost_impact) DESC;

-- ═══════════════════════════════════════════════════════════════════════════════
-- DEMO 5: Data Governance — PII Protection (20 sec)
-- ═══════════════════════════════════════════════════════════════════════════════

-- "Governance isn't optional for airlines — we built it in from day one"
-- Show PII tags
SELECT
    TAG_NAME,
    TAG_VALUE,
    COLUMN_NAME
FROM TABLE(INFORMATION_SCHEMA.TAG_REFERENCES_ALL_COLUMNS(
    'SKYPULSE_AI.SILVER.DIM_PASSENGER', 'TABLE'
))
WHERE TAG_NAME = 'PII_CLASSIFICATION'
ORDER BY TAG_VALUE;

-- ═══════════════════════════════════════════════════════════════════════════════
-- DEMO 6: AI Ops Chatbot (30 sec)
-- ═══════════════════════════════════════════════════════════════════════════════

-- "Business users can ask questions in natural language"
SELECT SKYPULSE_AI.GOLD.OPS_CHATBOT('What is our on-time performance and how many passengers did we serve?');

-- ═══════════════════════════════════════════════════════════════════════════════
-- DEMO 7: The Bottom Line (15 sec)
-- ═══════════════════════════════════════════════════════════════════════════════

-- "Here's the ROI story"
SELECT 
    'Delay prediction savings' AS initiative, '$28.5M' AS year_1_value
UNION ALL SELECT 'Churn prevention', '$6.2M'
UNION ALL SELECT 'Sentiment-driven recovery', '$8.0M'  
UNION ALL SELECT 'Anomaly detection', '$4.8M'
UNION ALL SELECT '─── TOTAL BENEFIT ───', '$47.5M'
UNION ALL SELECT 'Platform cost', '($2.1M)'
UNION ALL SELECT '═══ NET ROI ═══', '22.6x';
