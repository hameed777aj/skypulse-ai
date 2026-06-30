-- ============================================================================
-- SKYPULSE AI — AI/ML: Cortex ML Classification
-- ============================================================================
-- Uses Snowflake Cortex ML CLASSIFICATION to predict:
-- 1. Customer churn (will this loyalty member leave?)
-- 2. Flight cancellation likelihood
-- ============================================================================

USE DATABASE SKYPULSE_AI;
USE SCHEMA ML;
USE WAREHOUSE SKYPULSE_ML_WH;

-- =============================================================================
-- 1. CUSTOMER CHURN PREDICTION
-- =============================================================================

-- Training data with labels (fully qualified table references)
CREATE OR REPLACE VIEW V_CHURN_TRAINING_DATA AS
WITH passenger_activity AS (
    SELECT
        p.passenger_key,
        CASE p.loyalty_tier
            WHEN 'BRONZE' THEN 1 WHEN 'SILVER' THEN 2 WHEN 'GOLD' THEN 3
            WHEN 'PLATINUM' THEN 4 WHEN 'DIAMOND' THEN 5 ELSE 0
        END AS tier_level,
        p.lifetime_miles,
        p.ytd_miles,
        p.ytd_segments,
        COUNT(DISTINCT b.booking_key) AS total_bookings,
        COALESCE(SUM(b.total_amount), 0) AS total_revenue,
        COALESCE(AVG(b.total_amount), 0) AS avg_booking_value,
        COALESCE(AVG(b.days_before_departure), 30) AS avg_advance_purchase,
        COALESCE(AVG(fe.arrival_delay_min), 0) AS avg_delay_experienced,
        COUNT(CASE WHEN fe.arrival_delay_min > 60 THEN 1 END) AS major_delays,
        COALESCE(AVG(f.sentiment_score), 0) AS avg_sentiment,
        COALESCE(AVG(f.nps_score), 5) AS avg_nps,
        COUNT(CASE WHEN f.sentiment_label = 'NEGATIVE' THEN 1 END) AS negative_feedbacks,
        DATEDIFF('day', MAX(d.full_date), CURRENT_DATE()) AS days_since_last_activity
    FROM SKYPULSE_AI.SILVER.DIM_PASSENGER p
    LEFT JOIN SKYPULSE_AI.SILVER.FACT_BOOKING b ON p.passenger_key = b.passenger_key
    LEFT JOIN SKYPULSE_AI.SILVER.DIM_DATE d ON b.flight_date_key = d.date_key
    LEFT JOIN SKYPULSE_AI.SILVER.FACT_FLIGHT_EVENT fe ON b.flight_event_key = fe.flight_event_key
    LEFT JOIN SKYPULSE_AI.SILVER.FACT_PASSENGER_FEEDBACK f ON p.passenger_key = f.passenger_key
    WHERE p.is_current = TRUE
    GROUP BY p.passenger_key, p.loyalty_tier, p.lifetime_miles, p.ytd_miles, p.ytd_segments
)
SELECT
    passenger_key,
    tier_level,
    lifetime_miles,
    ytd_miles,
    ytd_segments,
    total_bookings,
    total_revenue,
    avg_booking_value,
    avg_advance_purchase,
    avg_delay_experienced,
    major_delays,
    avg_sentiment,
    avg_nps,
    negative_feedbacks,
    days_since_last_activity,
    -- Label: churned if inactive 60+ days
    CASE WHEN COALESCE(days_since_last_activity, 999) > 60 THEN 'CHURNED' ELSE 'ACTIVE' END AS churn_label
FROM passenger_activity;

-- Build classification model
CREATE OR REPLACE SNOWFLAKE.ML.CLASSIFICATION CHURN_PREDICTION_MODEL(
    INPUT_DATA => SYSTEM$REFERENCE('VIEW', 'V_CHURN_TRAINING_DATA'),
    TARGET_COLNAME => 'CHURN_LABEL'
);

-- Show model metrics
CALL CHURN_PREDICTION_MODEL!SHOW_EVALUATION_METRICS();
CALL CHURN_PREDICTION_MODEL!SHOW_FEATURE_IMPORTANCE();

-- =============================================================================
-- 2. FLIGHT CANCELLATION PREDICTION
-- =============================================================================

-- Training data (fully qualified)
CREATE OR REPLACE VIEW V_CANCELLATION_TRAINING AS
SELECT
    fe.flight_event_key,
    d.day_of_week,
    d.month_number,
    CASE WHEN d.is_weekend THEN 1 ELSE 0 END AS is_weekend,
    HOUR(fe.scheduled_departure) AS departure_hour,
    r.route_type,
    r.distance_km,
    ac.aircraft_age_years,
    CASE WHEN ac.is_widebody THEN 1 ELSE 0 END AS is_widebody,
    fe.pax_booked,
    fe.seat_capacity,
    fe.load_factor_pct,
    COALESCE(w.wind_speed_kts, 0) AS wind_speed,
    COALESCE(w.visibility_km, 10) AS visibility,
    COALESCE(w.precipitation_mm, 0) AS precipitation,
    COALESCE(w.weather_condition, 'CLEAR') AS weather_condition,
    COALESCE(w.severity, 'NONE') AS weather_severity,
    COALESCE(CASE WHEN w.is_deicing_required THEN 1 ELSE 0 END, 0) AS deicing_required,
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

-- What drives cancellations?
CALL CANCELLATION_PREDICTION_MODEL!SHOW_FEATURE_IMPORTANCE();
