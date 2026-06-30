-- ============================================================================
-- SKYPULSE AI — AI/ML: Cortex ML Anomaly Detection
-- ============================================================================
-- Uses Snowflake Cortex ML ANOMALY_DETECTION to automatically identify:
-- 1. Unusual delay patterns (route-level)
-- 2. Baggage handling anomalies
-- 3. Fuel consumption outliers
-- 4. Revenue anomalies (potential fraud or system errors)
-- ============================================================================

USE DATABASE SKYPULSE_AI;
USE SCHEMA ML;
USE WAREHOUSE SKYPULSE_ML_WH;

-- =============================================================================
-- 1. DELAY PATTERN ANOMALY DETECTION
-- =============================================================================

-- Training data: daily delay metrics per airport
CREATE OR REPLACE VIEW V_DELAY_ANOMALY_TRAINING AS
SELECT
    orig.iata_code AS airport_code,
    d.full_date AS ds,
    AVG(fe.departure_delay_min) AS avg_delay,
    COUNT(CASE WHEN fe.departure_delay_min > 60 THEN 1 END) AS major_delay_count,
    COUNT(*) AS total_flights,
    COUNT(CASE WHEN fe.flight_status = 'CANCELLED' THEN 1 END) AS cancellations
FROM SKYPULSE_AI.SILVER.FACT_FLIGHT_EVENT fe
JOIN SKYPULSE_AI.SILVER.DIM_AIRPORT orig ON fe.origin_airport_key = orig.airport_key
JOIN SKYPULSE_AI.SILVER.DIM_DATE d ON fe.flight_date_key = d.date_key
WHERE d.full_date >= DATEADD('day', -90, CURRENT_DATE())
GROUP BY orig.iata_code, d.full_date;

-- Build anomaly detection model
CREATE OR REPLACE SNOWFLAKE.ML.ANOMALY_DETECTION DELAY_ANOMALY_MODEL(
    INPUT_DATA => SYSTEM$REFERENCE('VIEW', 'V_DELAY_ANOMALY_TRAINING'),
    SERIES_COLNAME => 'AIRPORT_CODE',
    TIMESTAMP_COLNAME => 'DS',
    TARGET_COLNAME => 'AVG_DELAY',
    LABEL_COLNAME => ''  -- Unsupervised
);

-- Detect anomalies in recent data
CALL DELAY_ANOMALY_MODEL!DETECT_ANOMALIES(
    INPUT_DATA => SYSTEM$REFERENCE('VIEW', 'V_DELAY_ANOMALY_TRAINING'),
    SERIES_COLNAME => 'AIRPORT_CODE',
    TIMESTAMP_COLNAME => 'DS',
    TARGET_COLNAME => 'AVG_DELAY',
    CONFIG_OBJECT => {'prediction_interval': 0.99}
);

-- Store and analyze anomaly results
CREATE OR REPLACE TABLE DELAY_ANOMALY_RESULTS AS
SELECT *
FROM TABLE(RESULT_SCAN(LAST_QUERY_ID()));

-- View detected anomalies (unusual delay days)
SELECT
    series AS airport_code,
    ts AS anomaly_date,
    y AS actual_avg_delay,
    forecast AS expected_delay,
    ROUND(y - forecast, 1) AS deviation_minutes,
    is_anomaly,
    percentile,
    CASE 
        WHEN y > forecast + 30 THEN 'SEVERE_ABOVE_NORMAL'
        WHEN y > forecast + 15 THEN 'ABOVE_NORMAL'
        WHEN y < forecast - 15 THEN 'BELOW_NORMAL (unusual improvement)'
        ELSE 'WITHIN_RANGE'
    END AS anomaly_type
FROM DELAY_ANOMALY_RESULTS
WHERE is_anomaly = TRUE
ORDER BY ABS(y - forecast) DESC
LIMIT 20;

-- =============================================================================
-- 2. FUEL CONSUMPTION ANOMALY DETECTION
-- =============================================================================

-- Fuel efficiency time series per aircraft
CREATE OR REPLACE VIEW V_FUEL_ANOMALY_TRAINING AS
SELECT
    ac.registration AS aircraft_reg,
    d.full_date AS ds,
    AVG(fe.fuel_efficiency_l_per_100km) AS avg_fuel_efficiency,
    AVG(fe.fuel_consumed_kg * 1.0 / NULLIF(fe.distance_flown_km, 0)) AS fuel_per_km,
    COUNT(*) AS flights_count
FROM SKYPULSE_AI.SILVER.FACT_FLIGHT_EVENT fe
JOIN SKYPULSE_AI.SILVER.DIM_AIRCRAFT ac ON fe.aircraft_key = ac.aircraft_key
JOIN SKYPULSE_AI.SILVER.DIM_DATE d ON fe.flight_date_key = d.date_key
WHERE fe.fuel_consumed_kg > 0
  AND fe.distance_flown_km > 0
  AND d.full_date >= DATEADD('day', -90, CURRENT_DATE())
GROUP BY ac.registration, d.full_date
HAVING COUNT(*) >= 1;

-- Build fuel anomaly model
CREATE OR REPLACE SNOWFLAKE.ML.ANOMALY_DETECTION FUEL_ANOMALY_MODEL(
    INPUT_DATA => SYSTEM$REFERENCE('VIEW', 'V_FUEL_ANOMALY_TRAINING'),
    SERIES_COLNAME => 'AIRCRAFT_REG',
    TIMESTAMP_COLNAME => 'DS',
    TARGET_COLNAME => 'AVG_FUEL_EFFICIENCY',
    LABEL_COLNAME => ''
);

-- Detect fuel anomalies
CALL FUEL_ANOMALY_MODEL!DETECT_ANOMALIES(
    INPUT_DATA => SYSTEM$REFERENCE('VIEW', 'V_FUEL_ANOMALY_TRAINING'),
    SERIES_COLNAME => 'AIRCRAFT_REG',
    TIMESTAMP_COLNAME => 'DS',
    TARGET_COLNAME => 'AVG_FUEL_EFFICIENCY',
    CONFIG_OBJECT => {'prediction_interval': 0.95}
);

CREATE OR REPLACE TABLE FUEL_ANOMALY_RESULTS AS
SELECT *
FROM TABLE(RESULT_SCAN(LAST_QUERY_ID()));

-- Aircraft with unusual fuel consumption (potential maintenance issue)
SELECT
    series AS aircraft_reg,
    ts AS anomaly_date,
    ROUND(y, 2) AS actual_fuel_eff,
    ROUND(forecast, 2) AS expected_fuel_eff,
    ROUND((y - forecast) / NULLIF(forecast, 0) * 100, 1) AS pct_deviation,
    is_anomaly,
    CASE 
        WHEN y > forecast * 1.15 THEN 'HIGH_BURN - Check engine/airframe'
        WHEN y < forecast * 0.85 THEN 'LOW_BURN - Verify sensor accuracy'
        ELSE 'MARGINAL'
    END AS maintenance_recommendation
FROM FUEL_ANOMALY_RESULTS
WHERE is_anomaly = TRUE
ORDER BY ABS(y - forecast) DESC
LIMIT 15;

-- =============================================================================
-- 3. REVENUE ANOMALY DETECTION (Booking patterns)
-- =============================================================================

-- Daily revenue per booking channel
CREATE OR REPLACE VIEW V_REVENUE_ANOMALY_TRAINING AS
SELECT
    b.booking_channel,
    d.full_date AS ds,
    SUM(b.total_amount) AS daily_revenue,
    COUNT(*) AS booking_count,
    AVG(b.total_amount) AS avg_booking_value
FROM SKYPULSE_AI.SILVER.FACT_BOOKING b
JOIN SKYPULSE_AI.SILVER.DIM_DATE d ON b.booking_date_key = d.date_key
WHERE d.full_date >= DATEADD('day', -90, CURRENT_DATE())
GROUP BY b.booking_channel, d.full_date;

-- Build revenue anomaly model
CREATE OR REPLACE SNOWFLAKE.ML.ANOMALY_DETECTION REVENUE_ANOMALY_MODEL(
    INPUT_DATA => SYSTEM$REFERENCE('VIEW', 'V_REVENUE_ANOMALY_TRAINING'),
    SERIES_COLNAME => 'BOOKING_CHANNEL',
    TIMESTAMP_COLNAME => 'DS',
    TARGET_COLNAME => 'DAILY_REVENUE',
    LABEL_COLNAME => ''
);

-- Detect revenue anomalies
CALL REVENUE_ANOMALY_MODEL!DETECT_ANOMALIES(
    INPUT_DATA => SYSTEM$REFERENCE('VIEW', 'V_REVENUE_ANOMALY_TRAINING'),
    SERIES_COLNAME => 'BOOKING_CHANNEL',
    TIMESTAMP_COLNAME => 'DS',
    TARGET_COLNAME => 'DAILY_REVENUE',
    CONFIG_OBJECT => {'prediction_interval': 0.95}
);

CREATE OR REPLACE TABLE REVENUE_ANOMALY_RESULTS AS
SELECT *
FROM TABLE(RESULT_SCAN(LAST_QUERY_ID()));

-- Suspicious booking patterns (potential fraud or system errors)
SELECT
    series AS booking_channel,
    ts AS anomaly_date,
    ROUND(y, 2) AS actual_revenue,
    ROUND(forecast, 2) AS expected_revenue,
    ROUND(y - forecast, 2) AS deviation_gbp,
    ROUND((y - forecast) / NULLIF(forecast, 0) * 100, 1) AS pct_deviation,
    is_anomaly,
    CASE 
        WHEN y > forecast * 2 THEN 'SPIKE - Investigate for bulk purchase or system error'
        WHEN y < forecast * 0.3 THEN 'DROP - Investigate for outage or pricing error'
        ELSE 'UNUSUAL'
    END AS investigation_reason
FROM REVENUE_ANOMALY_RESULTS
WHERE is_anomaly = TRUE
ORDER BY ABS(y - forecast) DESC
LIMIT 20;

-- =============================================================================
-- EXECUTIVE SUMMARY: All Anomalies Dashboard View
-- =============================================================================

CREATE OR REPLACE VIEW SKYPULSE_AI.GOLD.V_ALL_ANOMALIES AS
SELECT 'DELAY' AS anomaly_domain, series AS entity, ts AS detected_at, 
       y AS actual_value, forecast AS expected_value, is_anomaly, percentile
FROM DELAY_ANOMALY_RESULTS WHERE is_anomaly = TRUE
UNION ALL
SELECT 'FUEL' AS anomaly_domain, series AS entity, ts AS detected_at,
       y AS actual_value, forecast AS expected_value, is_anomaly, percentile
FROM FUEL_ANOMALY_RESULTS WHERE is_anomaly = TRUE
UNION ALL
SELECT 'REVENUE' AS anomaly_domain, series AS entity, ts AS detected_at,
       y AS actual_value, forecast AS expected_value, is_anomaly, percentile
FROM REVENUE_ANOMALY_RESULTS WHERE is_anomaly = TRUE
ORDER BY detected_at DESC;
