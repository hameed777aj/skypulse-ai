-- ============================================================================
-- SKYPULSE AI — AI/ML: Cortex ML Forecasting
-- ============================================================================
-- Uses Snowflake Cortex ML FORECAST to predict:
-- 1. Flight delay minutes for upcoming flights
-- 2. Passenger demand per route (next 14 days)
-- 3. Revenue forecasting
-- No external ML infrastructure required — runs natively in Snowflake!
-- ============================================================================

USE DATABASE SKYPULSE_AI;
USE SCHEMA ML;
USE WAREHOUSE SKYPULSE_ML_WH;

-- =============================================================================
-- 1. FLIGHT DELAY FORECASTING
-- =============================================================================

-- Step 1: Prepare time-series training data (daily avg delay per route)
CREATE OR REPLACE VIEW V_DELAY_TIMESERIES AS
SELECT
    r.route_code,
    d.full_date AS ds,
    AVG(fe.arrival_delay_min) AS y  -- Target: average arrival delay
FROM SKYPULSE_AI.SILVER.FACT_FLIGHT_EVENT fe
JOIN SKYPULSE_AI.SILVER.DIM_ROUTE r ON fe.route_key = r.route_key
JOIN SKYPULSE_AI.SILVER.DIM_DATE d ON fe.flight_date_key = d.date_key
WHERE fe.flight_status = 'LANDED'
  AND d.full_date >= DATEADD('day', -90, CURRENT_DATE())
GROUP BY r.route_code, d.full_date
HAVING COUNT(*) >= 1;  -- At least 1 flight per day per route

-- Step 2: Build the forecasting model
CREATE OR REPLACE SNOWFLAKE.ML.FORECAST DELAY_FORECAST_MODEL(
    INPUT_DATA => SYSTEM$REFERENCE('VIEW', 'V_DELAY_TIMESERIES'),
    SERIES_COLNAME => 'ROUTE_CODE',
    TIMESTAMP_COLNAME => 'DS',
    TARGET_COLNAME => 'Y'
);

-- Step 3: Generate 14-day delay forecast per route
CALL DELAY_FORECAST_MODEL!FORECAST(
    FORECASTING_PERIODS => 14,
    CONFIG_OBJECT => {'prediction_interval': 0.95}
);

-- Step 4: Store forecast results for dashboard consumption
CREATE OR REPLACE TABLE DELAY_FORECAST_RESULTS AS
SELECT 
    series AS route_code,
    ts AS forecast_date,
    forecast AS predicted_avg_delay_min,
    lower_bound AS delay_lower_95,
    upper_bound AS delay_upper_95,
    CURRENT_TIMESTAMP() AS model_run_at
FROM TABLE(RESULT_SCAN(LAST_QUERY_ID()));

-- View: Which routes are predicted to have worst delays next week?
SELECT 
    route_code,
    forecast_date,
    ROUND(predicted_avg_delay_min, 1) AS predicted_delay,
    ROUND(delay_upper_95, 1) AS worst_case_delay,
    CASE 
        WHEN predicted_avg_delay_min > 45 THEN 'CRITICAL'
        WHEN predicted_avg_delay_min > 25 THEN 'HIGH'
        WHEN predicted_avg_delay_min > 15 THEN 'MODERATE'
        ELSE 'LOW'
    END AS risk_level
FROM DELAY_FORECAST_RESULTS
WHERE forecast_date BETWEEN CURRENT_DATE() AND DATEADD('day', 7, CURRENT_DATE())
ORDER BY predicted_avg_delay_min DESC;

-- =============================================================================
-- 2. PASSENGER DEMAND FORECASTING
-- =============================================================================

-- Prepare: Daily passenger volumes per route
CREATE OR REPLACE VIEW V_DEMAND_TIMESERIES AS
SELECT
    r.route_code,
    d.full_date AS ds,
    SUM(fe.pax_booked) AS y  -- Target: total passengers
FROM SKYPULSE_AI.SILVER.FACT_FLIGHT_EVENT fe
JOIN SKYPULSE_AI.SILVER.DIM_ROUTE r ON fe.route_key = r.route_key
JOIN SKYPULSE_AI.SILVER.DIM_DATE d ON fe.flight_date_key = d.date_key
WHERE d.full_date >= DATEADD('day', -90, CURRENT_DATE())
GROUP BY r.route_code, d.full_date;

-- Build demand forecast model
CREATE OR REPLACE SNOWFLAKE.ML.FORECAST DEMAND_FORECAST_MODEL(
    INPUT_DATA => SYSTEM$REFERENCE('VIEW', 'V_DEMAND_TIMESERIES'),
    SERIES_COLNAME => 'ROUTE_CODE',
    TIMESTAMP_COLNAME => 'DS',
    TARGET_COLNAME => 'Y'
);

-- Generate 14-day demand forecast
CALL DEMAND_FORECAST_MODEL!FORECAST(
    FORECASTING_PERIODS => 14,
    CONFIG_OBJECT => {'prediction_interval': 0.9}
);

-- Store results
CREATE OR REPLACE TABLE DEMAND_FORECAST_RESULTS AS
SELECT 
    series AS route_code,
    ts AS forecast_date,
    forecast AS predicted_pax,
    lower_bound AS pax_lower_90,
    upper_bound AS pax_upper_90,
    CURRENT_TIMESTAMP() AS model_run_at
FROM TABLE(RESULT_SCAN(LAST_QUERY_ID()));

-- Insight: Routes where demand exceeds current capacity
SELECT 
    df.route_code,
    df.forecast_date,
    ROUND(df.predicted_pax) AS predicted_passengers,
    r.flight_time_mins,
    -- Compare with typical capacity
    CASE 
        WHEN r.route_type IN ('LONG_HAUL','ULTRA_LONG_HAUL') THEN 315  -- A350
        ELSE 180  -- A320
    END AS aircraft_capacity,
    ROUND(df.predicted_pax / CASE 
        WHEN r.route_type IN ('LONG_HAUL','ULTRA_LONG_HAUL') THEN 315
        ELSE 180
    END * 100, 1) AS predicted_load_factor,
    CASE 
        WHEN df.predicted_pax > 
            CASE WHEN r.route_type IN ('LONG_HAUL','ULTRA_LONG_HAUL') THEN 315 * 0.95
                 ELSE 180 * 0.95 END 
        THEN 'CAPACITY_RISK'
        ELSE 'OK'
    END AS capacity_alert
FROM DEMAND_FORECAST_RESULTS df
JOIN SKYPULSE_AI.SILVER.DIM_ROUTE r ON df.route_code = r.route_code
WHERE df.forecast_date BETWEEN CURRENT_DATE() AND DATEADD('day', 7, CURRENT_DATE())
ORDER BY predicted_load_factor DESC;

-- =============================================================================
-- 3. REVENUE FORECASTING
-- =============================================================================

-- Daily total revenue time series
CREATE OR REPLACE VIEW V_REVENUE_TIMESERIES AS
SELECT
    d.full_date AS ds,
    SUM(fe.revenue_total) AS y
FROM SKYPULSE_AI.SILVER.FACT_FLIGHT_EVENT fe
JOIN SKYPULSE_AI.SILVER.DIM_DATE d ON fe.flight_date_key = d.date_key
WHERE d.full_date >= DATEADD('day', -90, CURRENT_DATE())
  AND fe.revenue_total > 0
GROUP BY d.full_date
HAVING SUM(fe.revenue_total) > 0;

-- Build revenue forecast
CREATE OR REPLACE SNOWFLAKE.ML.FORECAST REVENUE_FORECAST_MODEL(
    INPUT_DATA => SYSTEM$REFERENCE('VIEW', 'V_REVENUE_TIMESERIES'),
    TIMESTAMP_COLNAME => 'DS',
    TARGET_COLNAME => 'Y'
);

CALL REVENUE_FORECAST_MODEL!FORECAST(
    FORECASTING_PERIODS => 30,
    CONFIG_OBJECT => {'prediction_interval': 0.9}
);

CREATE OR REPLACE TABLE REVENUE_FORECAST_RESULTS AS
SELECT 
    ts AS forecast_date,
    ROUND(forecast, 2) AS predicted_daily_revenue,
    ROUND(lower_bound, 2) AS revenue_lower_90,
    ROUND(upper_bound, 2) AS revenue_upper_90,
    CURRENT_TIMESTAMP() AS model_run_at
FROM TABLE(RESULT_SCAN(LAST_QUERY_ID()));

-- 30-day revenue outlook
SELECT 
    forecast_date,
    predicted_daily_revenue,
    SUM(predicted_daily_revenue) OVER (ORDER BY forecast_date) AS cumulative_revenue,
    revenue_lower_90,
    revenue_upper_90
FROM REVENUE_FORECAST_RESULTS
ORDER BY forecast_date;

-- =============================================================================
-- Model performance metrics
-- =============================================================================

-- Check model evaluation metrics (revenue model may have limited data for some routes)
CALL DELAY_FORECAST_MODEL!SHOW_EVALUATION_METRICS();
CALL DEMAND_FORECAST_MODEL!SHOW_EVALUATION_METRICS();
