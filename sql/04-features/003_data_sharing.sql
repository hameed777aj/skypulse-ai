-- ============================================================================
-- SKYPULSE AI — Feature Showcase: Data Sharing & Marketplace
-- ============================================================================
-- Demonstrates:
-- 1. Secure Data Sharing — Share anonymized OTP stats with partner airports
-- 2. Reader Account — For airports without Snowflake accounts
-- 3. Data Marketplace concepts — Consume weather data
-- 4. Listings — Publish anonymized industry benchmarks
-- ============================================================================

USE DATABASE SKYPULSE_AI;
USE SCHEMA GOLD;
USE WAREHOUSE SKYPULSE_ANALYTICS_WH;

-- =============================================================================
-- 1. SECURE VIEW — Anonymized data for sharing (no PII exposed)
-- =============================================================================

-- Create a secure view that airports can access for their OTP performance
CREATE OR REPLACE SECURE VIEW SV_AIRPORT_PERFORMANCE_SHARE AS
SELECT
    orig.iata_code AS airport_code,
    orig.airport_name,
    d.full_date AS operation_date,
    d.day_name,
    d.season,
    -- Aggregated metrics (no individual passenger/flight identifiers)
    COUNT(DISTINCT fe.flight_event_key) AS total_departures,
    COUNT(CASE WHEN fe.arrival_delay_min <= 15 THEN 1 END) AS on_time_flights,
    ROUND(COUNT(CASE WHEN fe.arrival_delay_min <= 15 THEN 1 END) * 100.0 / 
          NULLIF(COUNT(*), 0), 1) AS otp_percentage,
    ROUND(AVG(fe.departure_delay_min), 1) AS avg_departure_delay,
    ROUND(AVG(fe.arrival_delay_min), 1) AS avg_arrival_delay,
    COUNT(CASE WHEN fe.flight_status = 'CANCELLED' THEN 1 END) AS cancellations,
    ROUND(AVG(fe.load_factor_pct), 1) AS avg_load_factor,
    ROUND(AVG(fe.taxi_out_min), 1) AS avg_taxi_out,
    -- Delay causes (aggregated)
    COUNT(CASE WHEN dl.delay_category = 'WEATHER' THEN 1 END) AS weather_delays,
    COUNT(CASE WHEN dl.delay_category = 'ATC' THEN 1 END) AS atc_delays,
    COUNT(CASE WHEN dl.delay_category = 'TECHNICAL' THEN 1 END) AS technical_delays,
    COUNT(CASE WHEN dl.delay_category = 'AIRPORT' THEN 1 END) AS airport_delays
FROM SKYPULSE_AI.SILVER.FACT_FLIGHT_EVENT fe
JOIN SKYPULSE_AI.SILVER.DIM_AIRPORT orig ON fe.origin_airport_key = orig.airport_key
JOIN SKYPULSE_AI.SILVER.DIM_DATE d ON fe.flight_date_key = d.date_key
LEFT JOIN SKYPULSE_AI.SILVER.FACT_DELAY dl ON fe.flight_event_key = dl.flight_event_key
WHERE d.full_date >= DATEADD('day', -90, CURRENT_DATE())
GROUP BY orig.iata_code, orig.airport_name, d.full_date, d.day_name, d.season
HAVING COUNT(DISTINCT fe.flight_event_key) >= 3;  -- Minimum threshold for anonymity

-- Verify the share view works
SELECT airport_code, operation_date, total_departures, otp_percentage, avg_departure_delay
FROM SV_AIRPORT_PERFORMANCE_SHARE
WHERE airport_code = 'LHR'
ORDER BY operation_date DESC
LIMIT 10;

-- =============================================================================
-- 2. CREATE SHARE — Publish to partner airports
-- =============================================================================

-- Create the share
CREATE OR REPLACE SHARE SKYPULSE_AIRPORT_OTP_SHARE
    COMMENT = 'SkyPulse Airways - Daily OTP and delay statistics per airport (anonymized)';

-- Grant access to the share
GRANT USAGE ON DATABASE SKYPULSE_AI TO SHARE SKYPULSE_AIRPORT_OTP_SHARE;
GRANT USAGE ON SCHEMA SKYPULSE_AI.GOLD TO SHARE SKYPULSE_AIRPORT_OTP_SHARE;
GRANT SELECT ON VIEW SKYPULSE_AI.GOLD.SV_AIRPORT_PERFORMANCE_SHARE TO SHARE SKYPULSE_AIRPORT_OTP_SHARE;

-- In production, add consumer accounts:
-- ALTER SHARE SKYPULSE_AIRPORT_OTP_SHARE ADD ACCOUNTS = '<heathrow_account>', '<gatwick_account>';

-- =============================================================================
-- 3. ROUTE BENCHMARK SHARE — Industry comparison data
-- =============================================================================

CREATE OR REPLACE SECURE VIEW SV_ROUTE_BENCHMARKS AS
SELECT
    r.route_type,
    r.origin_iata || '-' || r.destination_iata AS route_pair,
    d.month_name,
    d.year,
    -- Performance benchmarks (anonymized)
    COUNT(*) AS total_flights,
    ROUND(AVG(fe.load_factor_pct), 1) AS avg_load_factor,
    ROUND(AVG(fe.arrival_delay_min), 1) AS avg_delay_min,
    ROUND(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY fe.arrival_delay_min), 1) AS median_delay,
    ROUND(PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY fe.arrival_delay_min), 1) AS p95_delay,
    ROUND(AVG(fe.fuel_efficiency_l_per_100km), 2) AS avg_fuel_efficiency,
    ROUND(AVG(fe.revenue_per_pax), 2) AS avg_yield_per_pax
FROM SKYPULSE_AI.SILVER.FACT_FLIGHT_EVENT fe
JOIN SKYPULSE_AI.SILVER.DIM_ROUTE r ON fe.route_key = r.route_key
JOIN SKYPULSE_AI.SILVER.DIM_DATE d ON fe.flight_date_key = d.date_key
GROUP BY r.route_type, r.origin_iata, r.destination_iata, d.month_name, d.year;

-- =============================================================================
-- 4. MARKETPLACE SIMULATION — Consume external weather data
-- =============================================================================

-- In a real implementation, you'd subscribe to a weather dataset from Snowflake Marketplace
-- For demo, show how shared data integrates seamlessly

-- Simulated: Create a "shared database" representing marketplace weather data
CREATE DATABASE IF NOT EXISTS WEATHER_MARKETPLACE_DEMO
    COMMENT = 'Simulates a Snowflake Marketplace weather data subscription';

CREATE SCHEMA IF NOT EXISTS WEATHER_MARKETPLACE_DEMO.PUBLIC;

CREATE OR REPLACE VIEW WEATHER_MARKETPLACE_DEMO.PUBLIC.V_AIRPORT_WEATHER AS
SELECT
    airport_iata,
    observation_time,
    temperature_c,
    wind_speed_kts,
    visibility_km,
    weather_condition,
    severity,
    is_deicing_required
FROM SKYPULSE_AI.SILVER.DIM_WEATHER;

-- Demonstrate cross-database join (as if consuming marketplace data)
SELECT
    fe.flight_number,
    fe.scheduled_departure,
    fe.departure_delay_min,
    w.weather_condition,
    w.severity AS weather_severity,
    w.wind_speed_kts,
    w.visibility_km,
    CASE WHEN fe.departure_delay_min > 30 AND w.severity IN ('MODERATE','SEVERE') 
         THEN 'WEATHER_CORRELATED' ELSE 'OTHER_CAUSE' END AS delay_attribution
FROM SKYPULSE_AI.SILVER.FACT_FLIGHT_EVENT fe
JOIN SKYPULSE_AI.SILVER.DIM_AIRPORT orig ON fe.origin_airport_key = orig.airport_key
LEFT JOIN WEATHER_MARKETPLACE_DEMO.PUBLIC.V_AIRPORT_WEATHER w 
    ON orig.iata_code = w.airport_iata
    AND DATE_TRUNC('hour', fe.scheduled_departure) = DATE_TRUNC('hour', w.observation_time)
WHERE fe.departure_delay_min > 30
ORDER BY fe.departure_delay_min DESC
LIMIT 20;
