-- ============================================================================
-- SKYPULSE AI — Feature Showcase: Iceberg Tables (Reference Only)
-- ============================================================================
-- NOTE: Iceberg Tables require an External Volume (S3 bucket) and
-- Hybrid Tables are NOT available on Free Trial accounts.
-- These are documented here for the presentation but NOT executed.
-- ============================================================================

USE DATABASE SKYPULSE_AI;
USE SCHEMA GOLD;
USE WAREHOUSE SKYPULSE_TRANSFORM_WH;

-- =============================================================================
-- HYBRID TABLE ALTERNATIVE — Standard table with same structure
-- Demonstrates the CONCEPT of low-latency gate lookups
-- =============================================================================

CREATE OR REPLACE TABLE GATE_ASSIGNMENT_LIVE (
    assignment_id       INTEGER NOT NULL AUTOINCREMENT,
    airport_iata        CHAR(3) NOT NULL,
    terminal            VARCHAR(5) NOT NULL,
    gate_number         VARCHAR(10) NOT NULL,
    flight_number       VARCHAR(10),
    assignment_status   VARCHAR(20) NOT NULL DEFAULT 'AVAILABLE',
    assigned_from       TIMESTAMP_NTZ,
    assigned_to         TIMESTAMP_NTZ,
    aircraft_type       VARCHAR(10),
    is_widebody_capable BOOLEAN DEFAULT FALSE,
    has_jet_bridge      BOOLEAN DEFAULT TRUE,
    last_updated        TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    updated_by          VARCHAR(50),
    CONSTRAINT pk_gate_assignment PRIMARY KEY (assignment_id)
)
COMMENT = 'Gate assignments - in production this would be a HYBRID TABLE for sub-ms lookups';

-- Populate with LHR gates
INSERT INTO GATE_ASSIGNMENT_LIVE (airport_iata, terminal, gate_number, assignment_status, is_widebody_capable, has_jet_bridge)
SELECT
    'LHR' AS airport_iata,
    t.terminal,
    t.terminal || LPAD(g.gate_num::VARCHAR, 2, '0') AS gate_number,
    'AVAILABLE' AS assignment_status,
    CASE WHEN g.gate_num <= 10 THEN TRUE ELSE FALSE END AS is_widebody_capable,
    TRUE AS has_jet_bridge
FROM (SELECT column1 AS terminal FROM VALUES ('T2'),('T5')) t
CROSS JOIN (SELECT seq4() + 1 AS gate_num FROM TABLE(GENERATOR(ROWCOUNT => 20))) g;

-- Simulate a gate assignment
UPDATE GATE_ASSIGNMENT_LIVE
SET flight_number = 'SP0101',
    assignment_status = 'ASSIGNED',
    assigned_from = CURRENT_TIMESTAMP(),
    assigned_to = DATEADD('minute', 90, CURRENT_TIMESTAMP()),
    aircraft_type = 'A350',
    last_updated = CURRENT_TIMESTAMP(),
    updated_by = 'AUTO_ASSIGN_SYSTEM'
WHERE airport_iata = 'LHR' AND gate_number = 'T501' AND assignment_status = 'AVAILABLE';

-- Gate utilization view
SELECT
    airport_iata, terminal,
    COUNT(*) AS total_gates,
    COUNT(CASE WHEN assignment_status = 'AVAILABLE' THEN 1 END) AS available,
    COUNT(CASE WHEN assignment_status != 'AVAILABLE' THEN 1 END) AS in_use,
    ROUND(COUNT(CASE WHEN assignment_status != 'AVAILABLE' THEN 1 END) * 100.0 / COUNT(*), 1) AS utilization_pct
FROM GATE_ASSIGNMENT_LIVE
GROUP BY airport_iata, terminal;

-- =============================================================================
-- ICEBERG TABLE — Reference design (requires External Volume - not on trial)
-- =============================================================================
-- In production, this would be:
-- CREATE OR REPLACE ICEBERG TABLE FLIGHT_HISTORY_ICEBERG (...)
--     CATALOG = 'SNOWFLAKE'
--     EXTERNAL_VOLUME = 'skypulse_iceberg_vol'
--     BASE_LOCATION = 'flight_history/';
-- 
-- Benefits: Open Parquet format readable by Spark, Flink, Trino, Presto
-- without going through Snowflake compute.
