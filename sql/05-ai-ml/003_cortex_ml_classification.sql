-- ============================================================================
-- SKYPULSE AI — AI/ML: Cortex ML Classification
-- ============================================================================
-- Uses Snowflake Cortex ML CLASSIFICATION to predict:
-- 1. Customer churn (will this loyalty member leave?)
-- 2. Flight cancellation likelihood
-- 3. Feedback priority routing
-- ============================================================================

USE DATABASE SKYPULSE_AI;
USE SCHEMA ML;
USE WAREHOUSE SKYPULSE_ML_WH;

-- =============================================================================
-- 1. CUSTOMER CHURN PREDICTION
-- =============================================================================

-- Step 1: Create labeled training data
-- Label: churned = passenger who was active but had no booking in 90+ days
CREATE OR REPLACE VIEW V_CHURN_TRAINING_DATA AS
WITH passenger_activity AS (
    SELECT
        p.passenger_key,
        p.loyalty_tier,
        p.lifetime_miles,
        p.ytd_miles,
        p.ytd_segments,
        -- Engagement features
        COUNT(DISTINCT b.booking_key) AS total_bookings_180d,
        COALESCE(SUM(b.total_amount), 0) AS total_revenue_180d,
        COALESCE(AVG(b.total_amount), 0) AS avg_booking_value,
        COALESCE(AVG(b.ancillary_revenue), 0) AS avg_ancillary,
        COALESCE(AVG(b.days_before_departure), 0) AS avg_advance_purchase,
        -- Channel preference
        MODE(b.booking_channel) AS preferred_channel,
        -- Flight experience
        COALESCE(AVG(fe.arrival_delay_min), 0) AS avg_delay_experienced,
        COUNT(CASE WHEN fe.arrival_delay_min > 60 THEN 1 END) AS major_delays,
        COUNT(CASE WHEN fe.flight_status = 'CANCELLED' THEN 1 END) AS cancellations_experienced,
        -- Satisfaction
        COALESCE(AVG(f.sentiment_score), 0) AS avg_sentiment,
        COALESCE(AVG(f.nps_score), 5) AS avg_nps,
        COUNT(CASE WHEN f.sentiment_label = 'NEGATIVE' THEN 1 END) AS negative_feedbacks,
        -- Recency
        MAX(d.full_date) AS last_activity_date,
        DATEDIFF('day', MAX(d.full_date), CURRENT_DATE()) AS days_since_last_activity,
        -- LABEL: Churned if no activity in 90+ days (for training on historical data)
        CASE 
            WHEN DATEDIFF('day', MAX(d.full_date), CURRENT_DATE()) > 90 THEN 'CHURNED'
            ELSE 'ACTIVE'
        END AS churn_label
    FROM SKYPULSE_AI.SILVER.DIM_PASSENGER p
    LEFT JOIN SKYPULSE_AI.SILVER.FACT_BOOKING b 
        ON p.passenger_key = b.passenger_key
    LEFT JOIN SKYPULSE_AI.SILVER.DIM_DATE d 
        ON b.flight_date_key = d.date_key
        AND d.full_date >= DATEADD('day', -180, CURRENT_DATE())
    LEFT JOIN SKYPULSE_AI.SILVER.FACT_FLIGHT_EVENT fe 
        ON b.flight_event_key = fe.flight_event_key
    LEFT JOIN SKYPULSE_AI.SILVER.FACT_PASSENGER_FEEDBACK f 
        ON p.passenger_key = f.passenger_key
    WHERE p.is_current = TRUE
      AND p.loyalty_tier != 'NONE'
    GROUP BY p.passenger_key, p.loyalty_tier, p.lifetime_miles, p.ytd_miles, p.ytd_segments
)
SELECT
    passenger_key,
    -- Features (encoded)
    CASE loyalty_tier
        WHEN 'BRONZE' THEN 1 WHEN 'SILVER' THEN 2 WHEN 'GOLD' THEN 3
        WHEN 'PLATINUM' THEN 4 WHEN 'DIAMOND' THEN 5
    END AS tier_level,
    lifetime_miles,
    ytd_miles,
    ytd_segments,
    total_bookings_180d,
    total_revenue_180d,
    avg_booking_value,
    avg_ancillary,
    avg_advance_purchase,
    avg_delay_experienced,
    major_delays,
    cancellations_experienced,
    avg_sentiment,
    avg_nps,
    negative_feedbacks,
    days_since_last_activity,
    -- Label
    churn_label
FROM passenger_activity;

-- Step 2: Build classification model
CREATE OR REPLACE SNOWFLAKE.ML.CLASSIFICATION CHURN_PREDICTION_MODEL(
    INPUT_DATA => SYSTEM$REFERENCE('VIEW', 'V_CHURN_TRAINING_DATA'),
    TARGET_COLNAME => 'CHURN_LABEL'
);

-- Step 3: Score current passengers
-- First create a view without the label for prediction
CREATE OR REPLACE VIEW V_CHURN_SCORING_DATA AS
SELECT * EXCLUDE churn_label FROM V_CHURN_TRAINING_DATA;

-- Run prediction
CALL CHURN_PREDICTION_MODEL!PREDICT(
    INPUT_DATA => SYSTEM$REFERENCE('VIEW', 'V_CHURN_SCORING_DATA')
);

-- Store results
CREATE OR REPLACE TABLE CHURN_PREDICTIONS AS
SELECT * FROM TABLE(RESULT_SCAN(LAST_QUERY_ID()));

-- Step 4: High-value at-risk passengers (retention target list)
SELECT
    cp.passenger_key,
    psg.first_name || ' ' || psg.last_name AS passenger_name,
    psg.loyalty_tier,
    psg.email,
    cp.churn_probability,
    cp.total_revenue_180d,
    cp.avg_sentiment,
    cp.major_delays,
    cp.days_since_last_activity,
    -- Estimated revenue at risk
    cp.total_revenue_180d * 2 AS annual_revenue_at_risk,
    -- Recommended action
    CASE 
        WHEN cp.churn_probability > 0.8 AND cp.tier_level >= 4 THEN 'URGENT: Personal call from account manager + bonus miles'
        WHEN cp.churn_probability > 0.8 THEN 'HIGH: Targeted retention offer (upgrade voucher)'
        WHEN cp.churn_probability > 0.6 AND cp.major_delays > 2 THEN 'MEDIUM: Apologize for delays + compensation'
        WHEN cp.churn_probability > 0.6 THEN 'MEDIUM: Re-engagement campaign with exclusive fares'
        ELSE 'LOW: Standard loyalty communications'
    END AS retention_action
FROM CHURN_PREDICTIONS cp
JOIN SKYPULSE_AI.SILVER.DIM_PASSENGER psg 
    ON cp.passenger_key = psg.passenger_key AND psg.is_current = TRUE
WHERE cp.churn_probability > 0.5
ORDER BY cp.total_revenue_180d * cp.churn_probability DESC  -- Revenue-weighted risk
LIMIT 50;

-- Model metrics
CALL CHURN_PREDICTION_MODEL!SHOW_EVALUATION_METRICS();
CALL CHURN_PREDICTION_MODEL!SHOW_FEATURE_IMPORTANCE();

-- =============================================================================
-- 2. FLIGHT CANCELLATION PREDICTION
-- =============================================================================

-- Training data: labeled flights (cancelled vs operated)
CREATE OR REPLACE VIEW V_CANCELLATION_TRAINING AS
SELECT
    fe.flight_event_key,
    -- Features
    d.day_of_week,
    d.month_number,
    d.is_weekend::INTEGER AS is_weekend,
    d.season,
    HOUR(fe.scheduled_departure) AS departure_hour,
    r.route_type,
    r.distance_km,
    ac.aircraft_age_years,
    ac.is_widebody::INTEGER AS is_widebody,
    fe.pax_booked,
    fe.seat_capacity,
    fe.load_factor_pct,
    COALESCE(w.wind_speed_kts, 0) AS wind_speed,
    COALESCE(w.visibility_km, 10) AS visibility,
    COALESCE(w.precipitation_mm, 0) AS precipitation,
    w.weather_condition,
    w.severity AS weather_severity,
    COALESCE(w.is_deicing_required::INTEGER, 0) AS deicing_required,
    -- Label
    CASE WHEN fe.flight_status = 'CANCELLED' THEN 'CANCELLED' ELSE 'OPERATED' END AS cancellation_label
FROM SKYPULSE_AI.SILVER.FACT_FLIGHT_EVENT fe
JOIN SKYPULSE_AI.SILVER.DIM_DATE d ON fe.flight_date_key = d.date_key
JOIN SKYPULSE_AI.SILVER.DIM_ROUTE r ON fe.route_key = r.route_key
JOIN SKYPULSE_AI.SILVER.DIM_AIRCRAFT ac ON fe.aircraft_key = ac.aircraft_key
JOIN SKYPULSE_AI.SILVER.DIM_AIRPORT orig ON fe.origin_airport_key = orig.airport_key
LEFT JOIN SKYPULSE_AI.SILVER.DIM_WEATHER w 
    ON orig.iata_code = w.airport_iata
    AND DATE_TRUNC('hour', fe.scheduled_departure) = DATE_TRUNC('hour', w.observation_time);

-- Build cancellation model
CREATE OR REPLACE SNOWFLAKE.ML.CLASSIFICATION CANCELLATION_PREDICTION_MODEL(
    INPUT_DATA => SYSTEM$REFERENCE('VIEW', 'V_CANCELLATION_TRAINING'),
    TARGET_COLNAME => 'CANCELLATION_LABEL',
    CONFIG_OBJECT => {'on_error': 'skip'}
);

-- Feature importance — what drives cancellations?
CALL CANCELLATION_PREDICTION_MODEL!SHOW_FEATURE_IMPORTANCE();

-- =============================================================================
-- 3. FEEDBACK PRIORITY CLASSIFICATION
-- =============================================================================

-- Auto-route feedback to correct team based on content
CREATE OR REPLACE VIEW V_FEEDBACK_PRIORITY_TRAINING AS
SELECT
    f.feedback_key,
    f.feedback_channel,
    f.nps_score,
    f.overall_rating,
    COALESCE(f.rating_punctuality, 3) AS rating_punctuality,
    COALESCE(f.rating_cabin_crew, 3) AS rating_cabin_crew,
    f.sentiment_score,
    CASE 
        WHEN p.loyalty_tier IN ('DIAMOND','PLATINUM') THEN 5
        WHEN p.loyalty_tier = 'GOLD' THEN 4
        WHEN p.loyalty_tier = 'SILVER' THEN 3
        WHEN p.loyalty_tier = 'BRONZE' THEN 2
        ELSE 1
    END AS passenger_value_tier,
    COALESCE(fe.departure_delay_min, 0) AS associated_delay,
    LENGTH(f.feedback_text) AS feedback_length,
    -- Label: priority level
    CASE 
        WHEN f.sentiment_score < -0.7 AND p.loyalty_tier IN ('DIAMOND','PLATINUM') THEN 'P1_CRITICAL'
        WHEN f.sentiment_score < -0.5 OR f.nps_score <= 2 THEN 'P2_HIGH'
        WHEN f.sentiment_score < -0.2 OR f.nps_score <= 5 THEN 'P3_MEDIUM'
        ELSE 'P4_LOW'
    END AS priority_label
FROM SKYPULSE_AI.SILVER.FACT_PASSENGER_FEEDBACK f
LEFT JOIN SKYPULSE_AI.SILVER.DIM_PASSENGER p 
    ON f.passenger_key = p.passenger_key AND p.is_current = TRUE
LEFT JOIN SKYPULSE_AI.SILVER.FACT_FLIGHT_EVENT fe 
    ON f.flight_event_key = fe.flight_event_key
WHERE f.sentiment_score IS NOT NULL;

-- Build priority classification
CREATE OR REPLACE SNOWFLAKE.ML.CLASSIFICATION FEEDBACK_PRIORITY_MODEL(
    INPUT_DATA => SYSTEM$REFERENCE('VIEW', 'V_FEEDBACK_PRIORITY_TRAINING'),
    TARGET_COLNAME => 'PRIORITY_LABEL',
    CONFIG_OBJECT => {'on_error': 'skip'}
);

CALL FEEDBACK_PRIORITY_MODEL!SHOW_EVALUATION_METRICS();
