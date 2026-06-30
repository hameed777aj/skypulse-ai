-- ============================================================================
-- SKYPULSE AI — Feature Showcase: Iceberg Tables & Hybrid Tables
-- ============================================================================
-- Demonstrates:
-- 1. Iceberg Tables — Open table format for lakehouse interoperability
-- 2. Hybrid Tables — Low-latency transactional lookups
-- ============================================================================

USE DATABASE SKYPULSE_AI;
USE WAREHOUSE SKYPULSE_TRANSFORM_WH;

-- =============================================================================
-- 1. ICEBERG TABLE — Open format for external tool compatibility
-- =============================================================================
-- Iceberg tables store data in Apache Iceberg format, allowing tools like
-- Spark, Flink, Trino, and Presto to read directly from the same files.
-- Perfect for SkyPulse's data lakehouse strategy.

-- Note: Requires external volume configuration (shown as reference)

-- Create external volume for Iceberg (S3-backed)
-- In production, configure with your S3 bucket:
/*
CREATE OR REPLACE EXTERNAL VOLUME SKYPULSE_ICEBERG_VOL
    STORAGE_LOCATIONS = (
        (
            NAME = 'skypulse-iceberg-us-west-2'
            STORAGE_BASE_URL = 's3://skypulse-data-lake/iceberg/'
            STORAGE_PROVIDER = 'S3'
            STORAGE_AWS_ROLE_ARN = 'arn:aws:iam::123456789012:role/skypulse-snowflake-iceberg'
        )
    );
*/

-- Create Iceberg table for historical flight analytics
-- (allows external Spark jobs to read the same data)
CREATE SCHEMA IF NOT EXISTS SKYPULSE_AI.LAKEHOUSE;
USE SCHEMA SKYPULSE_AI.LAKEHOUSE;

/*
CREATE OR REPLACE ICEBERG TABLE FLIGHT_HISTORY_ICEBERG (
    flight_number       VARCHAR(10),
    flight_date         DATE,
    origin_iata         CHAR(3),
    destination_iata    CHAR(3),
    departure_delay_min INTEGER,
    arrival_delay_min   INTEGER,
    pax_flown           INTEGER,
    load_factor_pct     FLOAT,
    revenue_total       DECIMAL(12,2),
    fuel_consumed_kg    INTEGER,
    delay_category      VARCHAR(50),
    weather_condition   VARCHAR(30)
)
    CATALOG = 'SNOWFLAKE'
    EXTERNAL_VOLUME = 'SKYPULSE_ICEBERG_VOL'
    BASE_LOCATION = 'flight_history/'
    CATALOG_SYNC = 'SKYPULSE_ICEBERG_CATALOG';

-- Populate Iceberg table from Silver layer
INSERT INTO FLIGHT_HISTORY_ICEBERG
SELECT
    fe.flight_number,
    d.full_date AS flight_date,
    orig.iata_code AS origin_iata,
    dest.iata_code AS destination_iata,
    fe.departure_delay_min,
    fe.arrival_delay_min,
    fe.pax_flown,
    fe.load_factor_pct,
    fe.revenue_total,
    fe.fuel_consumed_kg,
    dl.delay_category,
    w.weather_condition
FROM SKYPULSE_AI.SILVER.FACT_FLIGHT_EVENT fe
JOIN SKYPULSE_AI.SILVER.DIM_DATE d ON fe.flight_date_key = d.date_key
JOIN SKYPULSE_AI.SILVER.DIM_AIRPORT orig ON fe.origin_airport_key = orig.airport_key
JOIN SKYPULSE_AI.SILVER.DIM_AIRPORT dest ON fe.dest_airport_key = dest.airport_key
LEFT JOIN SKYPULSE_AI.SILVER.FACT_DELAY dl ON fe.flight_event_key = dl.flight_event_key
LEFT JOIN SKYPULSE_AI.SILVER.DIM_WEATHER w ON orig.iata_code = w.airport_iata
    AND DATE_TRUNC('hour', fe.scheduled_departure) = DATE_TRUNC('hour', w.observation_time);
*/

-- =============================================================================
-- 2. HYBRID TABLE — Low-latency gate assignment lookups
-- =============================================================================
-- Hybrid tables support single-row operations with ACID transactions at
-- low latency — perfect for real-time operational systems like gate management.

USE SCHEMA SKYPULSE_AI.GOLD;

CREATE OR REPLACE HYBRID TABLE GATE_ASSIGNMENT_LIVE (
    assignment_id       INTEGER      NOT NULL AUTOINCREMENT,
    airport_iata        CHAR(3)      NOT NULL,
    terminal            VARCHAR(5)   NOT NULL,
    gate_number         VARCHAR(10)  NOT NULL,
    flight_number       VARCHAR(10),
    assignment_status   VARCHAR(20)  NOT NULL DEFAULT 'AVAILABLE',  -- AVAILABLE, ASSIGNED, BOARDING, OCCUPIED, MAINTENANCE
    assigned_from       TIMESTAMP_NTZ,
    assigned_to         TIMESTAMP_NTZ,
    aircraft_type       VARCHAR(10),
    is_widebody_capable BOOLEAN      DEFAULT FALSE,
    has_jet_bridge      BOOLEAN      DEFAULT TRUE,
    last_updated        TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    updated_by          VARCHAR(50),
    PRIMARY KEY (assignment_id),
    INDEX idx_gate_airport (airport_iata, gate_number),
    INDEX idx_gate_flight (flight_number)
)
COMMENT = 'Real-time gate assignments - hybrid table for low-latency transactional access';

-- Populate with LHR gates (Terminals 2 & 5)
INSERT INTO GATE_ASSIGNMENT_LIVE (airport_iata, terminal, gate_number, assignment_status, is_widebody_capable, has_jet_bridge)
SELECT
    'LHR' AS airport_iata,
    t.terminal,
    t.terminal || LPAD(g.gate_num::VARCHAR, 2, '0') AS gate_number,
    'AVAILABLE' AS assignment_status,
    CASE WHEN g.gate_num <= 10 THEN TRUE ELSE FALSE END AS is_widebody_capable,
    TRUE AS has_jet_bridge
FROM (SELECT column1 AS terminal FROM VALUES ('T2'),('T5')) t
CROSS JOIN (SELECT seq4() + 1 AS gate_num FROM TABLE(GENERATOR(ROWCOUNT => 30))) g;

-- Simulate real-time gate assignment
UPDATE GATE_ASSIGNMENT_LIVE
SET 
    flight_number = 'SP0101',
    assignment_status = 'ASSIGNED',
    assigned_from = CURRENT_TIMESTAMP(),
    assigned_to = DATEADD('minute', 90, CURRENT_TIMESTAMP()),
    aircraft_type = 'A350',
    last_updated = CURRENT_TIMESTAMP(),
    updated_by = 'AUTO_ASSIGN_SYSTEM'
WHERE airport_iata = 'LHR'
  AND terminal = 'T5'
  AND gate_number = 'T501'
  AND assignment_status = 'AVAILABLE';

-- Point lookup (sub-millisecond with hybrid tables)
SELECT * FROM GATE_ASSIGNMENT_LIVE
WHERE airport_iata = 'LHR' AND gate_number = 'T501';

-- Current gate utilization dashboard
SELECT
    airport_iata,
    terminal,
    COUNT(*) AS total_gates,
    COUNT(CASE WHEN assignment_status = 'AVAILABLE' THEN 1 END) AS available,
    COUNT(CASE WHEN assignment_status = 'ASSIGNED' THEN 1 END) AS assigned,
    COUNT(CASE WHEN assignment_status = 'BOARDING' THEN 1 END) AS boarding,
    COUNT(CASE WHEN assignment_status = 'OCCUPIED' THEN 1 END) AS occupied,
    ROUND(COUNT(CASE WHEN assignment_status != 'AVAILABLE' THEN 1 END) * 100.0 / COUNT(*), 1) AS utilization_pct
FROM GATE_ASSIGNMENT_LIVE
GROUP BY airport_iata, terminal;
