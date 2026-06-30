-- ============================================================================
-- SKYPULSE AI — AI/ML: Cortex Analyst & LLM Functions
-- ============================================================================
-- Demonstrates:
-- 1. Cortex COMPLETE — Natural language ops chatbot
-- 2. Cortex Analyst view — NL-to-SQL ready
-- 3. Semantic model stage
-- ============================================================================

USE DATABASE SKYPULSE_AI;
USE SCHEMA ML;
USE WAREHOUSE SKYPULSE_ML_WH;

-- =============================================================================
-- 1. CORTEX ANALYST — Analytical view for NL queries
-- =============================================================================

CREATE OR REPLACE VIEW SKYPULSE_AI.GOLD.V_ANALYST_FLIGHT_OPS AS
SELECT
    fe.flight_number,
    d.full_date AS flight_date,
    d.day_name,
    d.month_name,
    d.season,
    d.is_weekend,
    orig.iata_code AS origin,
    orig.airport_name AS origin_airport,
    orig.city AS origin_city,
    dest.iata_code AS destination,
    dest.airport_name AS dest_airport,
    r.route_type,
    r.distance_km,
    ac.aircraft_type,
    ac.is_widebody,
    fe.flight_status,
    fe.departure_delay_min,
    fe.arrival_delay_min,
    fe.pax_booked AS passengers_booked,
    fe.pax_flown AS passengers_flown,
    fe.seat_capacity,
    fe.load_factor_pct AS load_factor,
    fe.revenue_total,
    fe.revenue_per_pax,
    fe.fuel_consumed_kg,
    fe.fuel_efficiency_l_per_100km AS fuel_efficiency,
    CASE WHEN fe.arrival_delay_min <= 15 THEN 'ON_TIME' ELSE 'DELAYED' END AS punctuality
FROM SKYPULSE_AI.SILVER.FACT_FLIGHT_EVENT fe
JOIN SKYPULSE_AI.SILVER.DIM_DATE d ON fe.flight_date_key = d.date_key
JOIN SKYPULSE_AI.SILVER.DIM_AIRPORT orig ON fe.origin_airport_key = orig.airport_key
JOIN SKYPULSE_AI.SILVER.DIM_AIRPORT dest ON fe.dest_airport_key = dest.airport_key
JOIN SKYPULSE_AI.SILVER.DIM_ROUTE r ON fe.route_key = r.route_key
JOIN SKYPULSE_AI.SILVER.DIM_AIRCRAFT ac ON fe.aircraft_key = ac.aircraft_key;

-- =============================================================================
-- 2. OPS CHATBOT — Natural language interface using COMPLETE
-- =============================================================================

CREATE OR REPLACE FUNCTION SKYPULSE_AI.GOLD.OPS_CHATBOT(user_question VARCHAR)
RETURNS VARCHAR
LANGUAGE SQL
AS
$$
    SELECT SNOWFLAKE.CORTEX.COMPLETE(
        'mistral-large2',
        CONCAT(
            'You are an AI operations assistant for SkyPulse Airways. ',
            'Answer the following question using the context provided. ',
            'Be concise and data-driven. ',
            CHR(10), CHR(10),
            'CONTEXT: Operational summary - ',
            (SELECT
                'Total flights: ' || COUNT(*) ||
                ', On-time: ' || COUNT(CASE WHEN arrival_delay_min <= 15 THEN 1 END) ||
                ', Delayed: ' || COUNT(CASE WHEN arrival_delay_min > 15 THEN 1 END) ||
                ', Cancelled: ' || COUNT(CASE WHEN flight_status = 'CANCELLED' THEN 1 END) ||
                ', Avg delay: ' || ROUND(AVG(arrival_delay_min), 1) || ' min' ||
                ', Total pax: ' || SUM(COALESCE(pax_flown, 0)) ||
                ', Avg load: ' || ROUND(AVG(load_factor_pct), 1) || '%'
             FROM SKYPULSE_AI.SILVER.FACT_FLIGHT_EVENT fe
             JOIN SKYPULSE_AI.SILVER.DIM_DATE d ON fe.flight_date_key = d.date_key
             WHERE d.full_date >= DATEADD('day', -7, CURRENT_DATE())),
            CHR(10), CHR(10),
            'QUESTION: ', user_question
        )
    )
$$;

-- Test the chatbot
SELECT SKYPULSE_AI.GOLD.OPS_CHATBOT('What is our on-time performance this week?');

-- =============================================================================
-- 3. SEMANTIC MODEL STAGE
-- =============================================================================

CREATE STAGE IF NOT EXISTS SKYPULSE_AI.ML.SEMANTIC_MODELS
    DIRECTORY = (ENABLE = TRUE)
    COMMENT = 'Stores semantic model YAML for Cortex Analyst';
