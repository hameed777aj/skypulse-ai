-- ============================================================================
-- SKYPULSE AI — AI/ML: Cortex Search & Cortex Analyst
-- ============================================================================
-- Demonstrates:
-- 1. Cortex Search — Semantic search over unstructured feedback
-- 2. Cortex Analyst — Natural language to SQL for business users
-- 3. Document AI — Process delay reports and maintenance docs
-- ============================================================================

USE DATABASE SKYPULSE_AI;
USE SCHEMA ML;
USE WAREHOUSE SKYPULSE_ML_WH;

-- =============================================================================
-- 1. CORTEX SEARCH — Semantic Search over Passenger Feedback
-- =============================================================================

-- Create a Cortex Search service on feedback text
-- This enables semantic (meaning-based) search, not just keyword matching

CREATE OR REPLACE CORTEX SEARCH SERVICE FEEDBACK_SEARCH_SERVICE
    ON (
        SELECT
            f.feedback_key,
            f.feedback_text,
            f.feedback_subject,
            f.feedback_channel,
            f.sentiment_label,
            f.nps_score,
            f.feedback_timestamp,
            p.loyalty_tier,
            fe.flight_number,
            r.route_code
        FROM SKYPULSE_AI.SILVER.FACT_PASSENGER_FEEDBACK f
        LEFT JOIN SKYPULSE_AI.SILVER.DIM_PASSENGER p 
            ON f.passenger_key = p.passenger_key AND p.is_current = TRUE
        LEFT JOIN SKYPULSE_AI.SILVER.FACT_FLIGHT_EVENT fe 
            ON f.flight_event_key = fe.flight_event_key
        LEFT JOIN SKYPULSE_AI.SILVER.DIM_ROUTE r 
            ON f.route_key = r.route_key
    )
    TARGET_LAG = '1 hour'
    WAREHOUSE = SKYPULSE_ML_WH
    COMMENT = 'Semantic search over all passenger feedback for insight discovery';

-- Example semantic searches (run via Cortex Search API/UI):
-- "passengers complaining about cold food on long-haul flights"
-- "loyalty members threatening to switch airline"
-- "positive feedback about the new A350 aircraft"
-- "issues with baggage at Heathrow Terminal 5"
-- "crew related complaints from business class"

-- =============================================================================
-- 2. CORTEX ANALYST — Natural Language to SQL
-- =============================================================================

-- Cortex Analyst requires a semantic model YAML definition
-- This enables business users to ask questions in plain English

-- Create the semantic model specification (stored as a stage file)
CREATE OR REPLACE STAGE SKYPULSE_AI.ML.SEMANTIC_MODELS
    DIRECTORY = (ENABLE = TRUE)
    COMMENT = 'Stores semantic model definitions for Cortex Analyst';

-- The semantic model YAML would be uploaded to this stage
-- Below is the logical definition (actual YAML uploaded separately)

/*
SEMANTIC MODEL: skypulse_operations

TABLES:
  - SKYPULSE_AI.SILVER.FACT_FLIGHT_EVENT
  - SKYPULSE_AI.SILVER.FACT_BOOKING
  - SKYPULSE_AI.SILVER.FACT_DELAY
  - SKYPULSE_AI.SILVER.FACT_PASSENGER_FEEDBACK
  - SKYPULSE_AI.SILVER.DIM_PASSENGER
  - SKYPULSE_AI.SILVER.DIM_AIRPORT
  - SKYPULSE_AI.SILVER.DIM_ROUTE
  - SKYPULSE_AI.SILVER.DIM_DATE

EXAMPLE QUESTIONS:
  - "What was our on-time performance last week?"
  - "Which routes have the highest delay costs?"
  - "How many Diamond members gave negative feedback this month?"
  - "Compare load factors between LHR-JFK and LHR-DXB"
  - "What is the total revenue impact of weather-related delays?"
*/

-- =============================================================================
-- 3. SEMANTIC MODEL YAML (for Cortex Analyst)
-- =============================================================================

-- This is the actual semantic model content to be PUT to the stage:
-- PUT file://semantic_model.yaml @SKYPULSE_AI.ML.SEMANTIC_MODELS;

-- For the hackathon demo, create a simplified analytical view that
-- Cortex Analyst can query against:

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
    dest.city AS dest_city,
    r.route_type,
    r.distance_km,
    ac.aircraft_type,
    ac.is_widebody,
    fe.flight_status,
    fe.scheduled_departure,
    fe.actual_departure,
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
    -- Derived
    CASE WHEN fe.arrival_delay_min <= 15 THEN 'ON_TIME' ELSE 'DELAYED' END AS punctuality,
    CASE WHEN fe.flight_status = 'CANCELLED' THEN 'YES' ELSE 'NO' END AS was_cancelled
FROM SKYPULSE_AI.SILVER.FACT_FLIGHT_EVENT fe
JOIN SKYPULSE_AI.SILVER.DIM_DATE d ON fe.flight_date_key = d.date_key
JOIN SKYPULSE_AI.SILVER.DIM_AIRPORT orig ON fe.origin_airport_key = orig.airport_key
JOIN SKYPULSE_AI.SILVER.DIM_AIRPORT dest ON fe.dest_airport_key = dest.airport_key
JOIN SKYPULSE_AI.SILVER.DIM_ROUTE r ON fe.route_key = r.route_key
JOIN SKYPULSE_AI.SILVER.DIM_AIRCRAFT ac ON fe.aircraft_key = ac.aircraft_key;

-- =============================================================================
-- 4. COMPLETE (Chat) — Ops Chatbot using flight data context
-- =============================================================================

-- Create a function that acts as an airline ops chatbot
CREATE OR REPLACE FUNCTION OPS_CHATBOT(user_question VARCHAR)
RETURNS VARCHAR
LANGUAGE SQL
AS
$$
    SELECT SNOWFLAKE.CORTEX.COMPLETE(
        'mistral-large2',
        CONCAT(
            'You are an AI operations assistant for SkyPulse Airways. ',
            'Answer the following question using the context provided. ',
            'Be concise and data-driven. If you cannot answer from the context, say so. ',
            CHR(10), CHR(10),
            'CONTEXT: Today''s operational summary - ',
            (SELECT 
                'Total flights today: ' || COUNT(*) || 
                ', On-time: ' || COUNT(CASE WHEN arrival_delay_min <= 15 THEN 1 END) ||
                ', Delayed: ' || COUNT(CASE WHEN arrival_delay_min > 15 THEN 1 END) ||
                ', Cancelled: ' || COUNT(CASE WHEN flight_status = 'CANCELLED' THEN 1 END) ||
                ', Avg delay: ' || ROUND(AVG(arrival_delay_min), 1) || ' min' ||
                ', Total pax: ' || SUM(pax_flown) ||
                ', Avg load factor: ' || ROUND(AVG(load_factor_pct), 1) || '%'
             FROM SKYPULSE_AI.SILVER.FACT_FLIGHT_EVENT fe
             JOIN SKYPULSE_AI.SILVER.DIM_DATE d ON fe.flight_date_key = d.date_key
             WHERE d.full_date >= DATEADD('day', -1, CURRENT_DATE())),
            CHR(10), CHR(10),
            'QUESTION: ', user_question
        )
    )
$$;

-- Demo the chatbot
SELECT OPS_CHATBOT('What is our on-time performance today and which flights are most delayed?');
SELECT OPS_CHATBOT('Should we proactively communicate with passengers on delayed flights?');
SELECT OPS_CHATBOT('What are the main causes of delays this week?');

-- =============================================================================
-- 5. COMPLETE — Automated Delay Incident Report
-- =============================================================================

CREATE OR REPLACE PROCEDURE GENERATE_DELAY_REPORT(flight_number VARCHAR)
RETURNS VARCHAR
LANGUAGE SQL
AS
$$
DECLARE
    report VARCHAR;
BEGIN
    SELECT SNOWFLAKE.CORTEX.COMPLETE(
        'mistral-large2',
        'Generate a professional airline delay incident report based on this data. ' ||
        'Include: incident summary, root cause analysis, passenger impact, cost impact, and recommended actions. ' ||
        'Format with clear sections. Data: ' ||
        (SELECT 
            'Flight: ' || fe.flight_number || 
            ', Route: ' || r.route_code ||
            ', Date: ' || d.full_date ||
            ', Scheduled: ' || fe.scheduled_departure ||
            ', Actual: ' || fe.actual_departure ||
            ', Delay: ' || fe.departure_delay_min || ' minutes' ||
            ', Passengers affected: ' || fe.pax_flown ||
            ', Delay cause: ' || COALESCE(dl.delay_category, 'Unknown') ||
            ', Cost impact: GBP ' || COALESCE(dl.total_cost_impact, 0) ||
            ', Weather: ' || COALESCE(w.weather_condition, 'Unknown') ||
            ', Weather severity: ' || COALESCE(w.severity, 'None')
         FROM SKYPULSE_AI.SILVER.FACT_FLIGHT_EVENT fe
         JOIN SKYPULSE_AI.SILVER.DIM_DATE d ON fe.flight_date_key = d.date_key
         JOIN SKYPULSE_AI.SILVER.DIM_ROUTE r ON fe.route_key = r.route_key
         LEFT JOIN SKYPULSE_AI.SILVER.FACT_DELAY dl ON fe.flight_event_key = dl.flight_event_key
         JOIN SKYPULSE_AI.SILVER.DIM_AIRPORT orig ON fe.origin_airport_key = orig.airport_key
         LEFT JOIN SKYPULSE_AI.SILVER.DIM_WEATHER w ON orig.iata_code = w.airport_iata
             AND DATE_TRUNC('hour', fe.scheduled_departure) = DATE_TRUNC('hour', w.observation_time)
         WHERE fe.flight_number = :flight_number
         ORDER BY d.full_date DESC
         LIMIT 1)
    ) INTO report;
    RETURN report;
END;
$$;

-- Generate a report
-- CALL GENERATE_DELAY_REPORT('SP0101');
