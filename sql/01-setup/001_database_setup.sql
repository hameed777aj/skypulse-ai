-- ============================================================================
-- SKYPULSE AI — Database & Schema Setup
-- Snowflake AI Innovation Day Hackathon 2026
-- ============================================================================
-- This script creates the foundational database, schemas, warehouses, and
-- governance structures for the SkyPulse AI platform.
-- ============================================================================

-- Use ACCOUNTADMIN for initial setup (or SYSADMIN if preferred)
USE ROLE ACCOUNTADMIN;

-- =============================================================================
-- 1. VIRTUAL WAREHOUSES (Multi-cluster for different workload profiles)
-- =============================================================================

CREATE WAREHOUSE IF NOT EXISTS SKYPULSE_INGEST_WH
    WAREHOUSE_SIZE = 'XSMALL'
    AUTO_SUSPEND = 60
    AUTO_RESUME = TRUE
    INITIALLY_SUSPENDED = TRUE
    COMMENT = 'Ingestion workloads - streaming and batch loads';

CREATE WAREHOUSE IF NOT EXISTS SKYPULSE_TRANSFORM_WH
    WAREHOUSE_SIZE = 'SMALL'
    AUTO_SUSPEND = 120
    AUTO_RESUME = TRUE
    INITIALLY_SUSPENDED = TRUE
    COMMENT = 'Transformation workloads - ELT pipelines, dynamic tables';

CREATE WAREHOUSE IF NOT EXISTS SKYPULSE_ANALYTICS_WH
    WAREHOUSE_SIZE = 'MEDIUM'
    AUTO_SUSPEND = 300
    AUTO_RESUME = TRUE
    INITIALLY_SUSPENDED = TRUE
    COMMENT = 'Analytics and dashboards - BI queries';

CREATE WAREHOUSE IF NOT EXISTS SKYPULSE_ML_WH
    WAREHOUSE_SIZE = 'MEDIUM'
    AUTO_SUSPEND = 300
    AUTO_RESUME = TRUE
    INITIALLY_SUSPENDED = TRUE
    COMMENT = 'ML training and inference - Cortex AI workloads';

-- =============================================================================
-- 2. DATABASE
-- =============================================================================

CREATE DATABASE IF NOT EXISTS SKYPULSE_AI
    COMMENT = 'SkyPulse Airways AI-Powered Operations & Customer Experience Platform';

USE DATABASE SKYPULSE_AI;

-- =============================================================================
-- 3. SCHEMAS (Medallion Architecture)
-- =============================================================================

-- Bronze: Raw ingestion landing zone
CREATE SCHEMA IF NOT EXISTS BRONZE
    COMMENT = 'Raw data landing zone - schema-on-read, append-only'
    DATA_RETENTION_TIME_IN_DAYS = 90;

-- Silver: Cleansed, conformed dimensional model
CREATE SCHEMA IF NOT EXISTS SILVER
    COMMENT = 'Conformed star schema - validated dimensions and facts'
    DATA_RETENTION_TIME_IN_DAYS = 30;

-- Gold: Business-ready aggregates and ML features
CREATE SCHEMA IF NOT EXISTS GOLD
    COMMENT = 'Business-ready dynamic tables, ML features, curated views'
    DATA_RETENTION_TIME_IN_DAYS = 14;

-- Sandbox: Development and experimentation
CREATE SCHEMA IF NOT EXISTS SANDBOX
    COMMENT = 'Development sandbox for ad-hoc analysis and experimentation';

-- ML: Model registry and inference artifacts
CREATE SCHEMA IF NOT EXISTS ML
    COMMENT = 'ML model artifacts, training data, and inference results';

-- =============================================================================
-- 4. DATA GOVERNANCE — Tags for PII Classification (GDPR Compliance)
-- =============================================================================

USE SCHEMA SILVER;

CREATE OR REPLACE TAG PII_CLASSIFICATION
    ALLOWED_VALUES 'NAME', 'EMAIL', 'PHONE', 'PASSPORT', 'ADDRESS', 'DOB', 'PAYMENT'
    COMMENT = 'Classifies columns containing Personally Identifiable Information';

CREATE OR REPLACE TAG DATA_SENSITIVITY
    ALLOWED_VALUES 'PUBLIC', 'INTERNAL', 'CONFIDENTIAL', 'RESTRICTED'
    COMMENT = 'Data sensitivity classification for access control';

CREATE OR REPLACE TAG DATA_DOMAIN
    ALLOWED_VALUES 'PASSENGER', 'FLIGHT_OPS', 'COMMERCIAL', 'MAINTENANCE', 'FINANCE'
    COMMENT = 'Business domain ownership tag';

-- =============================================================================
-- 5. ROLES (RBAC)
-- =============================================================================

CREATE ROLE IF NOT EXISTS SKYPULSE_ADMIN;
CREATE ROLE IF NOT EXISTS SKYPULSE_ANALYST;
CREATE ROLE IF NOT EXISTS SKYPULSE_DATA_ENGINEER;
CREATE ROLE IF NOT EXISTS SKYPULSE_DATA_SCIENTIST;

-- Grant database access
GRANT USAGE ON DATABASE SKYPULSE_AI TO ROLE SKYPULSE_ADMIN;
GRANT USAGE ON DATABASE SKYPULSE_AI TO ROLE SKYPULSE_ANALYST;
GRANT USAGE ON DATABASE SKYPULSE_AI TO ROLE SKYPULSE_DATA_ENGINEER;
GRANT USAGE ON DATABASE SKYPULSE_AI TO ROLE SKYPULSE_DATA_SCIENTIST;

-- Grant schema access
GRANT USAGE ON ALL SCHEMAS IN DATABASE SKYPULSE_AI TO ROLE SKYPULSE_ADMIN;
GRANT USAGE ON SCHEMA SKYPULSE_AI.SILVER TO ROLE SKYPULSE_ANALYST;
GRANT USAGE ON SCHEMA SKYPULSE_AI.GOLD TO ROLE SKYPULSE_ANALYST;
GRANT USAGE ON ALL SCHEMAS IN DATABASE SKYPULSE_AI TO ROLE SKYPULSE_DATA_ENGINEER;
GRANT USAGE ON ALL SCHEMAS IN DATABASE SKYPULSE_AI TO ROLE SKYPULSE_DATA_SCIENTIST;

-- Grant warehouse access
GRANT USAGE ON WAREHOUSE SKYPULSE_ANALYTICS_WH TO ROLE SKYPULSE_ANALYST;
GRANT USAGE ON WAREHOUSE SKYPULSE_TRANSFORM_WH TO ROLE SKYPULSE_DATA_ENGINEER;
GRANT USAGE ON WAREHOUSE SKYPULSE_INGEST_WH TO ROLE SKYPULSE_DATA_ENGINEER;
GRANT USAGE ON WAREHOUSE SKYPULSE_ML_WH TO ROLE SKYPULSE_DATA_SCIENTIST;

-- Assign roles to SYSADMIN hierarchy
GRANT ROLE SKYPULSE_ADMIN TO ROLE SYSADMIN;
GRANT ROLE SKYPULSE_ANALYST TO ROLE SKYPULSE_ADMIN;
GRANT ROLE SKYPULSE_DATA_ENGINEER TO ROLE SKYPULSE_ADMIN;
GRANT ROLE SKYPULSE_DATA_SCIENTIST TO ROLE SKYPULSE_ADMIN;

-- =============================================================================
-- 6. Set working context for subsequent scripts
-- =============================================================================

USE ROLE ACCOUNTADMIN;
USE DATABASE SKYPULSE_AI;
USE SCHEMA SILVER;
USE WAREHOUSE SKYPULSE_TRANSFORM_WH;
