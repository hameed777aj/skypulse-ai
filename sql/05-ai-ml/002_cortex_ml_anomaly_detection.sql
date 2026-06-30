-- ============================================================================
-- SKYPULSE AI — AI/ML: Cortex ML Anomaly Detection
-- ============================================================================
-- Uses Snowflake Cortex ML ANOMALY_DETECTION to identify:
-- 1. Unusual delay patterns (route-level)
-- 2. Fuel consumption outliers
-- ============================================================================

USE DATABASE SKYPULSE_AI;
USE SCHEMA ML;
USE WAREHOUSE SKYPULSE_ML_WH;

-- =============================================================================
-- 1. DELAY PATTERN ANOMALY DETECTION
-- =============================================================================

-- Training data: daily delay metrics per airport (first 60 days)
CREATE OR REPLACE VIEW V_DELAY_ANOMALY_TRAINING AS
SELECT
    orig.iata_code AS airport_code,
    d.full_date AS ds,
    AVG(fe.departure_delay_min) AS avg_delay
FROM SKYPULSE_AI.SILVER.FACT_FLIGHT_EVENT fe
JOIN SKYPULSE_AI.SILVER.DIM_AIRPORT orig ON fe.origin_airport_key = orig.airport_key
JOIN SKYPULSE_AI.SILVER.DIM_DATE d ON fe.flight_date_key = d.date_key
WHERE d.full_date BETWEEN DATEADD('day', -90, CURRENT_DATE()) AND DATEADD('day', -15, CURRENT_DATE())
GROUP BY orig.iata_code, d.full_date
HAVING COUNT(*) >= 1;

-- Scoring data: last 14 days (must be AFTER training period)
CREATE OR REPLACE VIEW V_DELAY_ANOMALY_SCORING AS
SELECT
    orig.iata_code AS airport_code,
    d.full_date AS ds,
    AVG(fe.departure_delay_min) AS avg_delay
FROM SKYPULSE_AI.SILVER.FACT_FLIGHT_EVENT fe
JOIN SKYPULSE_AI.SILVER.DIM_AIRPORT orig ON fe.origin_airport_key = orig.airport_key
JOIN SKYPULSE_AI.SILVER.DIM_DATE d ON fe.flight_date_key = d.date_key
WHERE d.full_date > DATEADD('day', -15, CURRENT_DATE())
GROUP BY orig.iata_code, d.full_date
HAVING COUNT(*) >= 1;

-- Build anomaly detection model on training window
CREATE OR REPLACE SNOWFLAKE.ML.ANOMALY_DETECTION DELAY_ANOMALY_MODEL(
    INPUT_DATA => SYSTEM$REFERENCE('VIEW', 'V_DELAY_ANOMALY_TRAINING'),
    SERIES_COLNAME => 'AIRPORT_CODE',
    TIMESTAMP_COLNAME => 'DS',
    TARGET_COLNAME => 'AVG_DELAY',
    LABEL_COLNAME => ''
);

-- Detect anomalies on SCORING data (after training period)
CALL DELAY_ANOMALY_MODEL!DETECT_ANOMALIES(
    INPUT_DATA => SYSTEM$REFERENCE('VIEW', 'V_DELAY_ANOMALY_SCORING'),
    SERIES_COLNAME => 'AIRPORT_CODE',
    TIMESTAMP_COLNAME => 'DS',
    TARGET_COLNAME => 'AVG_DELAY',
    CONFIG_OBJECT => {'prediction_interval': 0.99}
);

-- Store results
CREATE OR REPLACE TABLE DELAY_ANOMALY_RESULTS AS
SELECT * FROM TABLE(RESULT_SCAN(LAST_QUERY_ID()));

-- View detected anomalies
SELECT
    series AS airport_code,
    ts AS anomaly_date,
    y AS actual_avg_delay,
    forecast AS expected_delay,
    ROUND(y - forecast, 1) AS deviation_minutes,
    is_anomaly,
    CASE 
        WHEN y > forecast + 30 THEN 'SEVERE_ABOVE_NORMAL'
        WHEN y > forecast + 15 THEN 'ABOVE_NORMAL'
        WHEN y < forecast - 15 THEN 'BELOW_NORMAL'
        ELSE 'WITHIN_RANGE'
    END AS anomaly_type
FROM DELAY_ANOMALY_RESULTS
WHERE is_anomaly = TRUE
ORDER BY ABS(y - forecast) DESC
LIMIT 20;

-- =============================================================================
-- 2. FUEL CONSUMPTION ANOMALY DETECTION
-- =============================================================================

-- Training data (first 60 days)
CREATE OR REPLACE VIEW V_FUEL_ANOMALY_TRAINING AS
SELECT
    ac.registration AS aircraft_reg,
    d.full_date AS ds,
    AVG(fe.fuel_efficiency_l_per_100km) AS avg_fuel_efficiency
FROM SKYPULSE_AI.SILVER.FACT_FLIGHT_EVENT fe
JOIN SKYPULSE_AI.SILVER.DIM_AIRCRAFT ac ON fe.aircraft_key = ac.aircraft_key
JOIN SKYPULSE_AI.SILVER.DIM_DATE d ON fe.flight_date_key = d.date_key
WHERE fe.fuel_consumed_kg > 0
  AND fe.distance_flown_km > 0
  AND d.full_date BETWEEN DATEADD('day', -90, CURRENT_DATE()) AND DATEADD('day', -15, CURRENT_DATE())
GROUP BY ac.registration, d.full_date
HAVING COUNT(*) >= 1;

-- Scoring data (last 14 days)
CREATE OR REPLACE VIEW V_FUEL_ANOMALY_SCORING AS
SELECT
    ac.registration AS aircraft_reg,
    d.full_date AS ds,
    AVG(fe.fuel_efficiency_l_per_100km) AS avg_fuel_efficiency
FROM SKYPULSE_AI.SILVER.FACT_FLIGHT_EVENT fe
JOIN SKYPULSE_AI.SILVER.DIM_AIRCRAFT ac ON fe.aircraft_key = ac.aircraft_key
JOIN SKYPULSE_AI.SILVER.DIM_DATE d ON fe.flight_date_key = d.date_key
WHERE fe.fuel_consumed_kg > 0
  AND fe.distance_flown_km > 0
  AND d.full_date > DATEADD('day', -15, CURRENT_DATE())
GROUP BY ac.registration, d.full_date
HAVING COUNT(*) >= 1;

-- Build model
CREATE OR REPLACE SNOWFLAKE.ML.ANOMALY_DETECTION FUEL_ANOMALY_MODEL(
    INPUT_DATA => SYSTEM$REFERENCE('VIEW', 'V_FUEL_ANOMALY_TRAINING'),
    SERIES_COLNAME => 'AIRCRAFT_REG',
    TIMESTAMP_COLNAME => 'DS',
    TARGET_COLNAME => 'AVG_FUEL_EFFICIENCY',
    LABEL_COLNAME => ''
);

-- Detect anomalies
CALL FUEL_ANOMALY_MODEL!DETECT_ANOMALIES(
    INPUT_DATA => SYSTEM$REFERENCE('VIEW', 'V_FUEL_ANOMALY_SCORING'),
    SERIES_COLNAME => 'AIRCRAFT_REG',
    TIMESTAMP_COLNAME => 'DS',
    TARGET_COLNAME => 'AVG_FUEL_EFFICIENCY',
    CONFIG_OBJECT => {'prediction_interval': 0.95}
);

CREATE OR REPLACE TABLE FUEL_ANOMALY_RESULTS AS
SELECT * FROM TABLE(RESULT_SCAN(LAST_QUERY_ID()));

-- Aircraft with unusual fuel consumption
SELECT
    series AS aircraft_reg,
    ts AS anomaly_date,
    ROUND(y, 2) AS actual_fuel_eff,
    ROUND(forecast, 2) AS expected_fuel_eff,
    ROUND((y - forecast) / NULLIF(forecast, 0) * 100, 1) AS pct_deviation,
    is_anomaly,
    CASE 
        WHEN y > forecast * 1.15 THEN 'HIGH_BURN - Check engine'
        WHEN y < forecast * 0.85 THEN 'LOW_BURN - Verify sensor'
        ELSE 'MARGINAL'
    END AS maintenance_recommendation
FROM FUEL_ANOMALY_RESULTS
WHERE is_anomaly = TRUE
ORDER BY ABS(y - forecast) DESC
LIMIT 15;

-- =============================================================================
-- COMBINED ANOMALY VIEW
-- =============================================================================

CREATE OR REPLACE VIEW SKYPULSE_AI.GOLD.V_ALL_ANOMALIES AS
SELECT 'DELAY' AS domain, series AS entity, ts AS detected_at,
       y AS actual_value, forecast AS expected_value, is_anomaly
FROM SKYPULSE_AI.ML.DELAY_ANOMALY_RESULTS WHERE is_anomaly = TRUE
UNION ALL
SELECT 'FUEL', series, ts, y, forecast, is_anomaly
FROM SKYPULSE_AI.ML.FUEL_ANOMALY_RESULTS WHERE is_anomaly = TRUE
ORDER BY detected_at DESC;
