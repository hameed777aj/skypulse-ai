-- ============================================================================
-- SKYPULSE AI — Bronze Layer: Raw Ingestion Tables
-- ============================================================================
-- Raw data landing zone using VARIANT for semi-structured data and
-- standard columns for structured feeds. Append-only, schema-on-read.
-- ============================================================================

USE DATABASE SKYPULSE_AI;
USE SCHEMA BRONZE;
USE WAREHOUSE SKYPULSE_INGEST_WH;

-- =============================================================================
-- RAW FLIGHT DATA (from airline operational systems)
-- =============================================================================

CREATE OR REPLACE TABLE RAW_FLIGHTS (
    ingest_timestamp    TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    source_system       VARCHAR(50),
    file_name           VARCHAR(500),
    raw_data            VARIANT,
    CONSTRAINT pk_raw_flights PRIMARY KEY (ingest_timestamp, source_system)
)
CLUSTER BY (TO_DATE(ingest_timestamp))
COMMENT = 'Raw flight schedule and operation data from OPS systems';

-- =============================================================================
-- RAW BOOKING DATA (from reservation system)
-- =============================================================================

CREATE OR REPLACE TABLE RAW_BOOKINGS (
    ingest_timestamp    TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    source_system       VARCHAR(50),
    file_name           VARCHAR(500),
    raw_data            VARIANT
)
CLUSTER BY (TO_DATE(ingest_timestamp))
COMMENT = 'Raw booking/reservation data from PSS (Passenger Service System)';

-- =============================================================================
-- RAW PASSENGER DATA (from CRM / loyalty system)
-- =============================================================================

CREATE OR REPLACE TABLE RAW_PASSENGERS (
    ingest_timestamp    TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    source_system       VARCHAR(50),
    file_name           VARCHAR(500),
    raw_data            VARIANT
)
COMMENT = 'Raw passenger profile and loyalty data from CRM';

-- =============================================================================
-- RAW WEATHER DATA (from external weather API / Marketplace)
-- =============================================================================

CREATE OR REPLACE TABLE RAW_WEATHER (
    ingest_timestamp    TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    station_id          VARCHAR(20),
    observation_time    TIMESTAMP_NTZ,
    raw_data            VARIANT
)
CLUSTER BY (TO_DATE(observation_time))
COMMENT = 'Raw weather observations from NOAA / weather marketplace feeds';

-- =============================================================================
-- RAW PASSENGER FEEDBACK (surveys, social, NPS)
-- =============================================================================

CREATE OR REPLACE TABLE RAW_FEEDBACK (
    ingest_timestamp    TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    channel             VARCHAR(30),  -- 'NPS_SURVEY', 'SOCIAL_MEDIA', 'IN_APP', 'EMAIL'
    raw_data            VARIANT
)
CLUSTER BY (channel)
COMMENT = 'Raw customer feedback from multiple channels';

-- =============================================================================
-- RAW AIRCRAFT TELEMETRY (IoT sensor data)
-- =============================================================================

CREATE OR REPLACE TABLE RAW_TELEMETRY (
    ingest_timestamp    TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    aircraft_reg        VARCHAR(10),
    sensor_type         VARCHAR(50),
    raw_data            VARIANT
)
CLUSTER BY (aircraft_reg, TO_DATE(ingest_timestamp))
COMMENT = 'Raw IoT sensor data from aircraft systems (engines, APU, hydraulics)';

-- =============================================================================
-- RAW CREW DATA
-- =============================================================================

CREATE OR REPLACE TABLE RAW_CREW (
    ingest_timestamp    TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    source_system       VARCHAR(50),
    raw_data            VARIANT
)
COMMENT = 'Raw crew scheduling and duty time data';

-- =============================================================================
-- FILE FORMATS for staged data loading
-- =============================================================================

CREATE OR REPLACE FILE FORMAT CSV_FORMAT
    TYPE = 'CSV'
    FIELD_DELIMITER = ','
    SKIP_HEADER = 1
    NULL_IF = ('NULL', 'null', '')
    EMPTY_FIELD_AS_NULL = TRUE
    FIELD_OPTIONALLY_ENCLOSED_BY = '"'
    COMPRESSION = 'AUTO';

CREATE OR REPLACE FILE FORMAT JSON_FORMAT
    TYPE = 'JSON'
    STRIP_OUTER_ARRAY = TRUE
    COMPRESSION = 'AUTO';

CREATE OR REPLACE FILE FORMAT PARQUET_FORMAT
    TYPE = 'PARQUET'
    COMPRESSION = 'SNAPPY';
