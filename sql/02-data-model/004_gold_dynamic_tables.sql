-- ============================================================================
-- SKYPULSE AI — Gold Layer: Dynamic Tables & Materialized Views
-- ============================================================================
-- Dynamic Tables provide continuously refreshed business-ready aggregations.
-- These power real-time dashboards and feed ML models with fresh features.
-- ============================================================================

USE DATABASE SKYPULSE_AI;
USE SCHEMA GOLD;
USE WAREHOUSE SKYPULSE_TRANSFORM_WH;

-- =============================================================================
-- DT_FLIGHT_STATUS — Real-time flight status with delay probability
-- Refreshes every 1 minute for operational dashboards
-- =============================================================================

CREATE OR REPLACE DYNAMIC TABLE DT_FLIGHT_STATUS
    TARGET_LAG = '1 minute'
    WAREHOUSE = SKYPULSE_TRANSFORM_WH
    COMMENT = 'Real-time flight status with operational metrics - refreshes every minute'
AS
SELECT
    fe.flight_event_key,
    fe.flight_number,
    fe.flight_date_key,
    d.full_date AS flight_date,
    fe.flight_status,
    -- Origin
    fe.origin_airport_key,
    orig.iata_code AS origin_iata,
    orig.airport_name AS origin_airport,
    -- Destination
    fe.dest_airport_key,
    dest.iata_code AS dest_iata,
    dest.airport_name AS dest_airport,
    -- Schedule
    fe.scheduled_departure,
    fe.scheduled_arrival,
    fe.actual_departure,
    fe.actual_arrival,
    -- Delays
    fe.departure_delay_min,
    fe.arrival_delay_min,
    CASE
        WHEN fe.arrival_delay_min > 180 THEN 'SEVERE'
        WHEN fe.arrival_delay_min > 60  THEN 'SIGNIFICANT'
        WHEN fe.arrival_delay_min > 15  THEN 'MINOR'
        WHEN fe.arrival_delay_min > 0   THEN 'SLIGHT'
        ELSE 'ON_TIME'
    END AS delay_severity,
    -- Load
    fe.pax_booked,
    fe.seat_capacity,
    fe.load_factor_pct,
    -- Aircraft
    ac.registration,
    ac.aircraft_type,
    -- Computed
    DATEDIFF('minute', fe.scheduled_departure, CURRENT_TIMESTAMP()) AS minutes_since_scheduled,
    CASE WHEN fe.flight_status IN ('SCHEDULED') AND fe.scheduled_departure < CURRENT_TIMESTAMP() THEN TRUE ELSE FALSE END AS is_delayed_departure
FROM SKYPULSE_AI.SILVER.FACT_FLIGHT_EVENT fe
JOIN SKYPULSE_AI.SILVER.DIM_DATE d ON fe.flight_date_key = d.date_key
JOIN SKYPULSE_AI.SILVER.DIM_AIRPORT orig ON fe.origin_airport_key = orig.airport_key
JOIN SKYPULSE_AI.SILVER.DIM_AIRPORT dest ON fe.dest_airport_key = dest.airport_key
JOIN SKYPULSE_AI.SILVER.DIM_AIRCRAFT ac ON fe.aircraft_key = ac.aircraft_key
WHERE d.full_date >= DATEADD('day', -1, CURRENT_DATE())
  AND d.full_date <= DATEADD('day', 1, CURRENT_DATE());

-- =============================================================================
-- DT_PASSENGER_RISK — Customer churn risk scores (updated daily)
-- =============================================================================

CREATE OR REPLACE DYNAMIC TABLE DT_PASSENGER_RISK
    TARGET_LAG = '1 hour'
    WAREHOUSE = SKYPULSE_TRANSFORM_WH
    COMMENT = 'Passenger churn risk scoring - refreshes hourly'
AS
SELECT
    p.passenger_key,
    p.passenger_id,
    p.first_name || ' ' || p.last_name AS full_name,
    p.loyalty_tier,
    p.lifetime_miles,
    p.ytd_miles,
    p.ytd_segments,
    -- Engagement metrics (last 90 days)
    COUNT(DISTINCT b.booking_key) AS bookings_last_90d,
    SUM(b.total_amount) AS revenue_last_90d,
    AVG(b.total_amount) AS avg_booking_value,
    MAX(d_bk.full_date) AS last_booking_date,
    DATEDIFF('day', MAX(d_bk.full_date), CURRENT_DATE()) AS days_since_last_booking,
    -- Feedback sentiment
    AVG(f.sentiment_score) AS avg_sentiment_90d,
    COUNT(CASE WHEN f.sentiment_label = 'NEGATIVE' THEN 1 END) AS negative_feedback_count,
    -- Delay experience
    AVG(fe.arrival_delay_min) AS avg_delay_experienced,
    COUNT(CASE WHEN fe.arrival_delay_min > 60 THEN 1 END) AS major_delays_experienced,
    -- Churn risk indicators
    CASE
        WHEN DATEDIFF('day', MAX(d_bk.full_date), CURRENT_DATE()) > 180 THEN 'CRITICAL'
        WHEN DATEDIFF('day', MAX(d_bk.full_date), CURRENT_DATE()) > 90
             AND AVG(f.sentiment_score) < -0.2 THEN 'HIGH'
        WHEN DATEDIFF('day', MAX(d_bk.full_date), CURRENT_DATE()) > 60
             OR COUNT(CASE WHEN fe.arrival_delay_min > 60 THEN 1 END) >= 3 THEN 'MEDIUM'
        ELSE 'LOW'
    END AS churn_risk_level,
    CURRENT_TIMESTAMP() AS scored_at
FROM SKYPULSE_AI.SILVER.DIM_PASSENGER p
LEFT JOIN SKYPULSE_AI.SILVER.FACT_BOOKING b 
    ON p.passenger_key = b.passenger_key
LEFT JOIN SKYPULSE_AI.SILVER.DIM_DATE d_bk 
    ON b.booking_date_key = d_bk.date_key
    AND d_bk.full_date >= DATEADD('day', -90, CURRENT_DATE())
LEFT JOIN SKYPULSE_AI.SILVER.FACT_FLIGHT_EVENT fe 
    ON b.flight_event_key = fe.flight_event_key
LEFT JOIN SKYPULSE_AI.SILVER.FACT_PASSENGER_FEEDBACK f 
    ON p.passenger_key = f.passenger_key
    AND f.feedback_timestamp >= DATEADD('day', -90, CURRENT_TIMESTAMP())
WHERE p.is_current = TRUE
  AND p.loyalty_tier != 'NONE'
GROUP BY 
    p.passenger_key, p.passenger_id, p.first_name, p.last_name,
    p.loyalty_tier, p.lifetime_miles, p.ytd_miles, p.ytd_segments;

-- =============================================================================
-- DT_ROUTE_PERFORMANCE — Route-level KPIs (daily refresh)
-- =============================================================================

CREATE OR REPLACE DYNAMIC TABLE DT_ROUTE_PERFORMANCE
    TARGET_LAG = '1 day'
    WAREHOUSE = SKYPULSE_TRANSFORM_WH
    COMMENT = 'Daily route performance metrics for network planning'
AS
SELECT
    r.route_key,
    r.route_code,
    r.origin_iata,
    r.destination_iata,
    r.route_type,
    d.full_date AS flight_date,
    -- Volume
    COUNT(DISTINCT fe.flight_event_key) AS flights_operated,
    SUM(fe.pax_flown) AS total_pax,
    AVG(fe.load_factor_pct) AS avg_load_factor,
    -- Punctuality
    AVG(fe.arrival_delay_min) AS avg_arrival_delay,
    COUNT(CASE WHEN fe.arrival_delay_min <= 15 THEN 1 END) * 100.0 / NULLIF(COUNT(*), 0) AS otp_15min_pct,
    COUNT(CASE WHEN fe.flight_status = 'CANCELLED' THEN 1 END) AS cancellations,
    -- Revenue
    SUM(b.total_amount) AS total_revenue,
    SUM(b.total_amount) / NULLIF(SUM(fe.pax_flown), 0) AS revenue_per_pax,
    SUM(b.ancillary_revenue) AS total_ancillary,
    -- Fuel
    AVG(fe.fuel_efficiency_l_per_100km) AS avg_fuel_efficiency,
    -- Customer satisfaction
    AVG(f.overall_rating) AS avg_customer_rating,
    AVG(f.sentiment_score) AS avg_sentiment
FROM SKYPULSE_AI.SILVER.DIM_ROUTE r
JOIN SKYPULSE_AI.SILVER.FACT_FLIGHT_EVENT fe ON r.route_key = fe.route_key
JOIN SKYPULSE_AI.SILVER.DIM_DATE d ON fe.flight_date_key = d.date_key
LEFT JOIN SKYPULSE_AI.SILVER.FACT_BOOKING b ON fe.flight_event_key = b.flight_event_key
LEFT JOIN SKYPULSE_AI.SILVER.FACT_PASSENGER_FEEDBACK f ON fe.flight_event_key = f.flight_event_key
WHERE d.full_date >= DATEADD('day', -365, CURRENT_DATE())
GROUP BY r.route_key, r.route_code, r.origin_iata, r.destination_iata, r.route_type, d.full_date;

-- =============================================================================
-- DT_OPS_ANOMALY — Active operational anomalies
-- =============================================================================

CREATE OR REPLACE DYNAMIC TABLE DT_OPS_ANOMALY
    TARGET_LAG = '5 minutes'
    WAREHOUSE = SKYPULSE_TRANSFORM_WH
    COMMENT = 'Real-time operational anomaly detection results'
AS
SELECT
    fe.flight_event_key,
    fe.flight_number,
    fe.flight_date_key,
    fe.origin_airport_key,
    orig.iata_code AS origin_iata,
    fe.scheduled_departure,
    -- Anomaly indicators
    CASE 
        WHEN fe.departure_delay_min > 120 AND fe.flight_status = 'SCHEDULED' THEN 'EXTENDED_GROUND_DELAY'
        WHEN fe.taxi_out_min > 45 THEN 'EXCESSIVE_TAXI'
        WHEN fe.fuel_consumed_kg > fe.fuel_loaded_kg * 0.95 THEN 'HIGH_FUEL_BURN'
        WHEN fe.load_factor_pct < 30 THEN 'SEVERELY_UNDERBOOKED'
        WHEN fe.pax_booked > fe.seat_capacity THEN 'OVERBOOKED'
        ELSE 'NORMAL'
    END AS anomaly_type,
    CASE 
        WHEN fe.departure_delay_min > 180 OR fe.fuel_consumed_kg > fe.fuel_loaded_kg * 0.95 THEN 'CRITICAL'
        WHEN fe.departure_delay_min > 120 OR fe.taxi_out_min > 45 THEN 'HIGH'
        WHEN fe.load_factor_pct < 30 OR fe.pax_booked > fe.seat_capacity THEN 'MEDIUM'
        ELSE 'LOW'
    END AS severity,
    fe.departure_delay_min,
    fe.pax_booked,
    fe.seat_capacity,
    CURRENT_TIMESTAMP() AS detected_at
FROM SKYPULSE_AI.SILVER.FACT_FLIGHT_EVENT fe
JOIN SKYPULSE_AI.SILVER.DIM_AIRPORT orig ON fe.origin_airport_key = orig.airport_key
JOIN SKYPULSE_AI.SILVER.DIM_DATE d ON fe.flight_date_key = d.date_key
WHERE d.full_date = CURRENT_DATE()
  AND (
    fe.departure_delay_min > 120
    OR fe.taxi_out_min > 45
    OR fe.fuel_consumed_kg > fe.fuel_loaded_kg * 0.95
    OR fe.load_factor_pct < 30
    OR fe.pax_booked > fe.seat_capacity
  );

-- =============================================================================
-- DT_DAILY_KPI — Executive daily summary
-- =============================================================================

CREATE OR REPLACE DYNAMIC TABLE DT_DAILY_KPI
    TARGET_LAG = '30 minutes'
    WAREHOUSE = SKYPULSE_TRANSFORM_WH
    COMMENT = 'Executive daily KPI summary - refreshes every 30 minutes'
AS
SELECT
    d.full_date AS report_date,
    -- Operations
    COUNT(DISTINCT fe.flight_event_key) AS total_flights,
    COUNT(CASE WHEN fe.flight_status = 'CANCELLED' THEN 1 END) AS cancelled_flights,
    COUNT(CASE WHEN fe.arrival_delay_min <= 15 THEN 1 END) * 100.0 / NULLIF(COUNT(*), 0) AS otp_pct,
    AVG(fe.arrival_delay_min) AS avg_delay_min,
    -- Passengers
    SUM(fe.pax_flown) AS total_passengers,
    AVG(fe.load_factor_pct) AS avg_load_factor,
    -- Revenue
    SUM(b.total_amount) AS total_revenue,
    SUM(b.ancillary_revenue) AS total_ancillary_revenue,
    -- Delays cost
    SUM(dl.total_cost_impact) AS total_delay_cost,
    -- Customer satisfaction
    AVG(f.nps_score) AS avg_nps,
    AVG(f.sentiment_score) AS avg_sentiment,
    COUNT(CASE WHEN f.ai_priority = 'CRITICAL' THEN 1 END) AS critical_feedback_count,
    -- Fuel
    SUM(fe.fuel_consumed_kg) AS total_fuel_kg,
    AVG(fe.fuel_efficiency_l_per_100km) AS avg_fuel_efficiency
FROM SKYPULSE_AI.SILVER.FACT_FLIGHT_EVENT fe
JOIN SKYPULSE_AI.SILVER.DIM_DATE d ON fe.flight_date_key = d.date_key
LEFT JOIN SKYPULSE_AI.SILVER.FACT_BOOKING b ON fe.flight_event_key = b.flight_event_key
LEFT JOIN SKYPULSE_AI.SILVER.FACT_DELAY dl ON fe.flight_event_key = dl.flight_event_key
LEFT JOIN SKYPULSE_AI.SILVER.FACT_PASSENGER_FEEDBACK f ON fe.flight_event_key = f.flight_event_key
WHERE d.full_date >= DATEADD('day', -7, CURRENT_DATE())
GROUP BY d.full_date;
