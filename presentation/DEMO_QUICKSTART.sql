-- ============================================================================
-- SKYPULSE AI — DEMO QUICKSTART
-- ============================================================================
-- Run this single worksheet during the presentation for maximum impact.
-- Each section is a self-contained "wow moment" — run them sequentially.
-- Estimated total demo time: 5-6 minutes
-- ============================================================================

-- Setup context (run this first)
USE ROLE ACCOUNTADMIN;
USE DATABASE SKYPULSE_AI;
USE SCHEMA SILVER;
USE WAREHOUSE SKYPULSE_ML_WH;

-- ═══════════════════════════════════════════════════════════════════════════════
-- DEMO 1: Operations Overview (30 sec)
-- ═══════════════════════════════════════════════════════════════════════════════

-- "Here's our operational summary — 2,400 flights across 20 routes"
SELECT
    fe.flight_number,
    orig.iata_code || ' -> ' || dest.iata_code AS route,
    fe.flight_status,
    fe.departure_delay_min,
    CASE
        WHEN fe.arrival_delay_min > 180 THEN 'SEVERE'
        WHEN fe.arrival_delay_min > 60  THEN 'SIGNIFICANT'
        WHEN fe.arrival_delay_min > 15  THEN 'MINOR'
        ELSE 'ON_TIME'
    END AS delay_severity,
    fe.load_factor_pct || '%' AS load_factor,
    ac.aircraft_type
FROM SKYPULSE_AI.SILVER.FACT_FLIGHT_EVENT fe
JOIN SKYPULSE_AI.SILVER.DIM_AIRPORT orig ON fe.origin_airport_key = orig.airport_key
JOIN SKYPULSE_AI.SILVER.DIM_AIRPORT dest ON fe.dest_airport_key = dest.airport_key
JOIN SKYPULSE_AI.SILVER.DIM_AIRCRAFT ac ON fe.aircraft_key = ac.aircraft_key
ORDER BY fe.departure_delay_min DESC
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

-- "Now let's generate an AI-powered response for our most upset loyalty member"
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
FROM SKYPULSE_AI.SILVER.FACT_PASSENGER_FEEDBACK f
JOIN SKYPULSE_AI.SILVER.DIM_PASSENGER p ON f.passenger_key = p.passenger_key AND p.is_current = TRUE
WHERE f.sentiment_score < -0.5
  AND p.loyalty_tier IN ('DIAMOND', 'PLATINUM', 'GOLD')
ORDER BY f.sentiment_score ASC
LIMIT 1;

-- ═══════════════════════════════════════════════════════════════════════════════
-- DEMO 3: Churn Risk Analysis (45 sec)
-- ═══════════════════════════════════════════════════════════════════════════════

-- "Which high-value passengers are at risk of leaving?"
SELECT
    p.first_name || ' ' || p.last_name AS passenger_name,
    p.loyalty_tier,
    p.lifetime_miles,
    p.ytd_segments,
    COUNT(DISTINCT b.booking_key) AS recent_bookings,
    ROUND(COALESCE(AVG(f.sentiment_score), 0), 2) AS avg_sentiment,
    COUNT(CASE WHEN fe.arrival_delay_min > 60 THEN 1 END) AS major_delays,
    CASE 
        WHEN COUNT(DISTINCT b.booking_key) = 0 AND COALESCE(AVG(f.sentiment_score), 0) < 0 THEN 'CRITICAL'
        WHEN COUNT(DISTINCT b.booking_key) <= 1 OR COALESCE(AVG(f.sentiment_score), 0) < -0.3 THEN 'HIGH'
        ELSE 'MEDIUM'
    END AS churn_risk,
    CASE 
        WHEN COUNT(DISTINCT b.booking_key) = 0 THEN 'Personal call + 50K bonus miles'
        WHEN COALESCE(AVG(f.sentiment_score), 0) < -0.3 THEN 'Service recovery + upgrade voucher'
        ELSE 'Re-engagement campaign'
    END AS recommended_action
FROM SKYPULSE_AI.SILVER.DIM_PASSENGER p
LEFT JOIN SKYPULSE_AI.SILVER.FACT_BOOKING b ON p.passenger_key = b.passenger_key
LEFT JOIN SKYPULSE_AI.SILVER.FACT_FLIGHT_EVENT fe ON b.flight_event_key = fe.flight_event_key
LEFT JOIN SKYPULSE_AI.SILVER.FACT_PASSENGER_FEEDBACK f ON p.passenger_key = f.passenger_key
WHERE p.is_current = TRUE
  AND p.loyalty_tier IN ('DIAMOND', 'PLATINUM', 'GOLD')
GROUP BY p.first_name, p.last_name, p.loyalty_tier, p.lifetime_miles, p.ytd_segments
ORDER BY churn_risk, p.lifetime_miles DESC
LIMIT 10;

-- ═══════════════════════════════════════════════════════════════════════════════
-- DEMO 3B: ML Forecasting — What delays are coming? (30 sec)
-- ═══════════════════════════════════════════════════════════════════════════════

-- "Our Cortex ML model predicts delays per route for the next 7 days"
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
    SUM(pax_affected) AS passengers_hit,
    ROUND(SUM(total_cost_impact), 0) AS total_cost_gbp,
    CASE 
        WHEN delay_category = 'WEATHER' THEN 'Predict and proactively rebook'
        WHEN delay_category = 'REACTIONARY' THEN 'Break the delay chain'
        WHEN delay_category = 'TECHNICAL' THEN 'Predictive maintenance'
        WHEN delay_category = 'ATC' THEN 'Optimize slot management'
        ELSE 'Improve resource planning'
    END AS ai_solution
FROM SKYPULSE_AI.SILVER.FACT_DELAY
GROUP BY delay_category
ORDER BY SUM(total_cost_impact) DESC;

-- ═══════════════════════════════════════════════════════════════════════════════
-- DEMO 5: Data Governance — PII Masking in Action (20 sec)
-- ═══════════════════════════════════════════════════════════════════════════════

-- "Governance built in from day one — PII is masked based on role"
-- Show that masking policies are applied
SELECT
    passenger_id,
    first_name,
    last_name,
    email,
    phone,
    loyalty_tier,
    lifetime_miles
FROM SKYPULSE_AI.SILVER.DIM_PASSENGER
WHERE loyalty_tier = 'DIAMOND'
  AND is_current = TRUE
LIMIT 5;

-- ═══════════════════════════════════════════════════════════════════════════════
-- DEMO 6: AI Ops Chatbot (30 sec)
-- ═══════════════════════════════════════════════════════════════════════════════

-- "Business users can ask questions in natural language"
SELECT SKYPULSE_AI.GOLD.OPS_CHATBOT('What is our on-time performance and how many passengers did we serve this week?');

-- ═══════════════════════════════════════════════════════════════════════════════
-- DEMO 7: Anomaly Detection Results (20 sec)
-- ═══════════════════════════════════════════════════════════════════════════════

-- "Our anomaly model flagged these aircraft for unusual fuel consumption"
SELECT
    series AS aircraft,
    ts AS detected_date,
    ROUND(y, 2) AS actual_fuel_efficiency,
    ROUND(forecast, 2) AS expected,
    ROUND((y - forecast) / NULLIF(forecast, 0) * 100, 1) AS pct_deviation,
    CASE 
        WHEN y > forecast * 1.15 THEN 'HIGH BURN - Check engine'
        WHEN y < forecast * 0.85 THEN 'LOW BURN - Verify sensor'
        ELSE 'MARGINAL'
    END AS recommendation
FROM SKYPULSE_AI.ML.FUEL_ANOMALY_RESULTS
WHERE is_anomaly = TRUE
ORDER BY ABS(y - forecast) DESC
LIMIT 5;

-- ═══════════════════════════════════════════════════════════════════════════════
-- DEMO 8: The Bottom Line (15 sec)
-- ═══════════════════════════════════════════════════════════════════════════════

-- "Here's the ROI story"
SELECT 
    'Delay prediction savings' AS initiative, '$28.5M' AS year_1_value
UNION ALL SELECT 'Churn prevention', '$6.2M'
UNION ALL SELECT 'Sentiment-driven recovery', '$8.0M'  
UNION ALL SELECT 'Anomaly detection', '$4.8M'
UNION ALL SELECT '--- TOTAL BENEFIT ---', '$47.5M'
UNION ALL SELECT 'Platform cost', '($2.1M)'
UNION ALL SELECT '=== NET ROI ===', '22.6x';
