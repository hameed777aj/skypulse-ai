-- ============================================================================
-- SKYPULSE AI — Feature Showcase: Time Travel & Data Governance
-- ============================================================================
-- Demonstrates:
-- 1. Time Travel — Query historical states, recover accidental changes
-- 2. Data Governance — PII masking, access policies, audit
-- 3. Tags — Automated PII classification
-- ============================================================================

USE DATABASE SKYPULSE_AI;
USE SCHEMA SILVER;
USE WAREHOUSE SKYPULSE_ANALYTICS_WH;

-- =============================================================================
-- 1. TIME TRAVEL — Regulatory Compliance & Audit Trail
-- =============================================================================

-- Scenario: Auditor requests "passenger manifest for SP0101 on June 15, 2026"
-- Even if data has been updated since, we can query the historical state

-- Query the flight data as it existed 24 hours ago
SELECT 
    fe.flight_number,
    fe.scheduled_departure,
    fe.flight_status,
    fe.pax_booked,
    fe.pax_flown
FROM FACT_FLIGHT_EVENT AT(OFFSET => -86400) fe  -- 24 hours ago
WHERE fe.flight_number = 'SP0101'
LIMIT 5;

-- Query passenger data before a loyalty tier change (SCD2 + Time Travel)
SELECT 
    passenger_id,
    first_name,
    last_name,
    loyalty_tier,
    effective_from,
    effective_to
FROM DIM_PASSENGER AT(OFFSET => -604800)  -- 7 days ago
WHERE passenger_id = 'SP0000001';

-- Demonstrate: What did our delay data look like at a specific timestamp?
SELECT 
    delay_category,
    COUNT(*) AS delay_count,
    ROUND(AVG(delay_minutes), 1) AS avg_delay,
    ROUND(SUM(total_cost_impact), 2) AS total_cost
FROM FACT_DELAY AT(TIMESTAMP => '2026-06-25 09:00:00'::TIMESTAMP_NTZ)
GROUP BY delay_category
ORDER BY total_cost DESC;

-- =============================================================================
-- Scenario: Accidental UPDATE — Recover using Time Travel
-- =============================================================================

-- Simulate: Someone accidentally updates all passengers to BRONZE tier
-- (DO NOT RUN THIS - demonstration only)
-- UPDATE DIM_PASSENGER SET loyalty_tier = 'BRONZE' WHERE is_current = TRUE;

-- Recovery: Restore from before the accident
-- CREATE OR REPLACE TABLE DIM_PASSENGER_RECOVERED
--     CLONE DIM_PASSENGER AT(OFFSET => -300);  -- 5 minutes ago

-- Verify recovery
-- SELECT loyalty_tier, COUNT(*) 
-- FROM DIM_PASSENGER_RECOVERED 
-- WHERE is_current = TRUE 
-- GROUP BY loyalty_tier;

-- =============================================================================
-- 2. DATA GOVERNANCE — Dynamic Data Masking
-- =============================================================================

-- Create masking policy for PII (email)
CREATE OR REPLACE MASKING POLICY EMAIL_MASK AS (val STRING) RETURNS STRING ->
    CASE
        WHEN CURRENT_ROLE() IN ('SKYPULSE_ADMIN', 'SKYPULSE_DATA_ENGINEER') THEN val
        WHEN CURRENT_ROLE() = 'SKYPULSE_ANALYST' THEN 
            REGEXP_REPLACE(val, '(.{2})(.*)(@.*)', '\\1***\\3')
        ELSE '***MASKED***'
    END;

-- Create masking policy for phone numbers
CREATE OR REPLACE MASKING POLICY PHONE_MASK AS (val STRING) RETURNS STRING ->
    CASE
        WHEN CURRENT_ROLE() IN ('SKYPULSE_ADMIN') THEN val
        ELSE REGEXP_REPLACE(val, '(.{4})(.*)(.{4})', '\\1****\\3')
    END;

-- Create masking policy for names (partial mask for analysts)
CREATE OR REPLACE MASKING POLICY NAME_MASK AS (val STRING) RETURNS STRING ->
    CASE
        WHEN CURRENT_ROLE() IN ('SKYPULSE_ADMIN', 'SKYPULSE_DATA_ENGINEER') THEN val
        WHEN CURRENT_ROLE() = 'SKYPULSE_ANALYST' THEN LEFT(val, 1) || '****'
        ELSE '***'
    END;

-- Apply masking policies to PII columns
ALTER TABLE DIM_PASSENGER MODIFY COLUMN email SET MASKING POLICY EMAIL_MASK;
ALTER TABLE DIM_PASSENGER MODIFY COLUMN phone SET MASKING POLICY PHONE_MASK;

-- Demonstrate: Same query, different results per role
-- As ADMIN (full access):
SELECT passenger_id, first_name, last_name, email, phone, loyalty_tier
FROM DIM_PASSENGER
WHERE is_current = TRUE AND loyalty_tier = 'DIAMOND'
LIMIT 5;

-- =============================================================================
-- 3. ROW ACCESS POLICY — Region-based data access
-- =============================================================================

-- Analysts can only see passengers from their assigned region
CREATE OR REPLACE ROW ACCESS POLICY PASSENGER_REGION_POLICY AS (home_airport VARCHAR) RETURNS BOOLEAN ->
    CASE
        WHEN CURRENT_ROLE() IN ('SKYPULSE_ADMIN', 'SKYPULSE_DATA_ENGINEER') THEN TRUE
        -- Analysts see only UK-based passengers
        WHEN CURRENT_ROLE() = 'SKYPULSE_ANALYST' AND home_airport IN ('LHR','LGW','MAN','EDI') THEN TRUE
        ELSE FALSE
    END;

-- Apply row access policy
-- ALTER TABLE DIM_PASSENGER ADD ROW ACCESS POLICY PASSENGER_REGION_POLICY ON (home_airport);

-- =============================================================================
-- 4. TAG-BASED GOVERNANCE — Query tagged columns
-- =============================================================================

-- Find all columns tagged as PII across the database
SELECT
    TAG_NAME,
    TAG_VALUE,
    OBJECT_DATABASE,
    OBJECT_SCHEMA,
    OBJECT_NAME,
    COLUMN_NAME
FROM TABLE(INFORMATION_SCHEMA.TAG_REFERENCES_ALL_COLUMNS(
    'SKYPULSE_AI.SILVER.DIM_PASSENGER', 'TABLE'
))
WHERE TAG_NAME = 'PII_CLASSIFICATION'
ORDER BY TAG_VALUE, COLUMN_NAME;

-- =============================================================================
-- 5. ACCESS HISTORY — Audit who accessed PII data
-- =============================================================================

-- Query access history for compliance reporting
SELECT
    query_start_time,
    user_name,
    role_name,
    direct_objects_accessed,
    base_objects_accessed
FROM SNOWFLAKE.ACCOUNT_USAGE.ACCESS_HISTORY
WHERE query_start_time >= DATEADD('day', -7, CURRENT_TIMESTAMP())
  AND ARRAY_CONTAINS('SKYPULSE_AI.SILVER.DIM_PASSENGER'::VARIANT, base_objects_accessed:objectName)
ORDER BY query_start_time DESC
LIMIT 20;
