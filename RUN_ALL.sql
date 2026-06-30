-- ============================================================================
-- SKYPULSE AI — MASTER DEPLOYMENT SCRIPT
-- ============================================================================
-- Run this single script to deploy the entire SkyPulse AI platform.
-- 
-- Prerequisites:
--   - Snowflake Enterprise Edition (Free Trial works)
--   - ACCOUNTADMIN role
--   - Estimated time: 3-5 minutes
--   - Estimated credit usage: ~0.5 credits
--
-- Execution order:
--   1. Database, schemas, warehouses, roles
--   2. Data model (Bronze → Silver → Gold)
--   3. Sample data generation
--   4. Feature demonstrations
--   5. AI/ML models (optional - run separately for demo)
-- ============================================================================

-- ╔══════════════════════════════════════════════════════════════════════╗
-- ║  PHASE 1: INFRASTRUCTURE SETUP                                      ║
-- ╚══════════════════════════════════════════════════════════════════════╝

-- Run: sql/01-setup/001_database_setup.sql
-- (Copy and paste contents, or use Snowflake CLI: snowsql -f ...)

-- Quick inline version for hackathon:
USE ROLE ACCOUNTADMIN;

CREATE WAREHOUSE IF NOT EXISTS SKYPULSE_INGEST_WH
    WAREHOUSE_SIZE = 'XSMALL' AUTO_SUSPEND = 60 AUTO_RESUME = TRUE INITIALLY_SUSPENDED = TRUE;
CREATE WAREHOUSE IF NOT EXISTS SKYPULSE_TRANSFORM_WH
    WAREHOUSE_SIZE = 'SMALL' AUTO_SUSPEND = 120 AUTO_RESUME = TRUE INITIALLY_SUSPENDED = TRUE;
CREATE WAREHOUSE IF NOT EXISTS SKYPULSE_ANALYTICS_WH
    WAREHOUSE_SIZE = 'MEDIUM' AUTO_SUSPEND = 300 AUTO_RESUME = TRUE INITIALLY_SUSPENDED = TRUE;
CREATE WAREHOUSE IF NOT EXISTS SKYPULSE_ML_WH
    WAREHOUSE_SIZE = 'MEDIUM' AUTO_SUSPEND = 300 AUTO_RESUME = TRUE INITIALLY_SUSPENDED = TRUE;

CREATE DATABASE IF NOT EXISTS SKYPULSE_AI;
USE DATABASE SKYPULSE_AI;

CREATE SCHEMA IF NOT EXISTS BRONZE DATA_RETENTION_TIME_IN_DAYS = 90;
CREATE SCHEMA IF NOT EXISTS SILVER DATA_RETENTION_TIME_IN_DAYS = 30;
CREATE SCHEMA IF NOT EXISTS GOLD DATA_RETENTION_TIME_IN_DAYS = 14;
CREATE SCHEMA IF NOT EXISTS SANDBOX;
CREATE SCHEMA IF NOT EXISTS ML;

USE WAREHOUSE SKYPULSE_TRANSFORM_WH;

-- Tags for governance
USE SCHEMA SILVER;
CREATE TAG IF NOT EXISTS PII_CLASSIFICATION
    ALLOWED_VALUES 'NAME', 'EMAIL', 'PHONE', 'PASSPORT', 'ADDRESS', 'DOB', 'PAYMENT';
CREATE TAG IF NOT EXISTS DATA_SENSITIVITY
    ALLOWED_VALUES 'PUBLIC', 'INTERNAL', 'CONFIDENTIAL', 'RESTRICTED';
CREATE TAG IF NOT EXISTS DATA_DOMAIN
    ALLOWED_VALUES 'PASSENGER', 'FLIGHT_OPS', 'COMMERCIAL', 'MAINTENANCE', 'FINANCE';

-- ╔══════════════════════════════════════════════════════════════════════╗
-- ║  PHASE 2: DATA MODEL                                                ║
-- ╚══════════════════════════════════════════════════════════════════════╝

-- Run these scripts in order:
--   sql/02-data-model/001_bronze_raw_tables.sql
--   sql/02-data-model/002_silver_dimensions.sql
--   sql/02-data-model/003_silver_facts.sql
--   sql/02-data-model/004_gold_dynamic_tables.sql
--   sql/02-data-model/005_streams_and_tasks.sql

-- ╔══════════════════════════════════════════════════════════════════════╗
-- ║  PHASE 3: SAMPLE DATA                                               ║
-- ╚══════════════════════════════════════════════════════════════════════╝

-- Run these scripts in order:
--   sql/03-sample-data/001_load_date_dimension.sql
--   sql/03-sample-data/002_load_reference_data.sql
--   sql/03-sample-data/003_load_passengers.sql
--   sql/03-sample-data/004_load_flights_and_bookings.sql
--   sql/03-sample-data/005_load_delays_and_feedback.sql
--   sql/03-sample-data/006_load_loyalty_activity.sql

-- ╔══════════════════════════════════════════════════════════════════════╗
-- ║  PHASE 4: FEATURE SHOWCASES                                         ║
-- ╚══════════════════════════════════════════════════════════════════════╝

-- Run selectively based on demo needs:
--   sql/04-features/001_cortex_ai_sentiment.sql       ← MUST for demo
--   sql/04-features/002_time_travel_governance.sql    ← Governance demo
--   sql/04-features/003_data_sharing.sql              ← Sharing demo
--   sql/04-features/004_alerts_and_notifications.sql  ← Alerts demo
--   sql/04-features/005_iceberg_and_hybrid_tables.sql ← Advanced features
--   sql/04-features/006_snowpark_feature_engineering.sql ← Python demo

-- ╔══════════════════════════════════════════════════════════════════════╗
-- ║  PHASE 5: AI/ML MODELS                                              ║
-- ╚══════════════════════════════════════════════════════════════════════╝

-- Run selectively (these take 1-2 minutes each for model training):
--   sql/05-ai-ml/001_cortex_ml_forecasting.sql       ← Delay forecast
--   sql/05-ai-ml/002_cortex_ml_anomaly_detection.sql ← Anomaly detection
--   sql/05-ai-ml/003_cortex_ml_classification.sql    ← Churn prediction
--   sql/05-ai-ml/004_cortex_search_and_analyst.sql   ← Search & chatbot
--   sql/05-ai-ml/005_notebook_demo.sql               ← Notebook content

-- ╔══════════════════════════════════════════════════════════════════════╗
-- ║  VERIFICATION                                                        ║
-- ╚══════════════════════════════════════════════════════════════════════╝

-- Run after deployment to verify everything loaded correctly:
SELECT 'DIM_DATE' AS table_name, COUNT(*) AS row_count FROM SKYPULSE_AI.SILVER.DIM_DATE
UNION ALL SELECT 'DIM_TIME', COUNT(*) FROM SKYPULSE_AI.SILVER.DIM_TIME
UNION ALL SELECT 'DIM_AIRPORT', COUNT(*) FROM SKYPULSE_AI.SILVER.DIM_AIRPORT
UNION ALL SELECT 'DIM_AIRCRAFT', COUNT(*) FROM SKYPULSE_AI.SILVER.DIM_AIRCRAFT
UNION ALL SELECT 'DIM_PASSENGER', COUNT(*) FROM SKYPULSE_AI.SILVER.DIM_PASSENGER
UNION ALL SELECT 'DIM_ROUTE', COUNT(*) FROM SKYPULSE_AI.SILVER.DIM_ROUTE
UNION ALL SELECT 'DIM_WEATHER', COUNT(*) FROM SKYPULSE_AI.SILVER.DIM_WEATHER
UNION ALL SELECT 'DIM_DELAY_REASON', COUNT(*) FROM SKYPULSE_AI.SILVER.DIM_DELAY_REASON
UNION ALL SELECT 'FACT_FLIGHT_EVENT', COUNT(*) FROM SKYPULSE_AI.SILVER.FACT_FLIGHT_EVENT
UNION ALL SELECT 'FACT_BOOKING', COUNT(*) FROM SKYPULSE_AI.SILVER.FACT_BOOKING
UNION ALL SELECT 'FACT_DELAY', COUNT(*) FROM SKYPULSE_AI.SILVER.FACT_DELAY
UNION ALL SELECT 'FACT_PASSENGER_FEEDBACK', COUNT(*) FROM SKYPULSE_AI.SILVER.FACT_PASSENGER_FEEDBACK
UNION ALL SELECT 'FACT_LOYALTY_ACTIVITY', COUNT(*) FROM SKYPULSE_AI.SILVER.FACT_LOYALTY_ACTIVITY
ORDER BY table_name;

-- Expected results:
-- DIM_DATE:              ~1,096 rows
-- DIM_TIME:              1,440 rows
-- DIM_AIRPORT:           20 rows
-- DIM_AIRCRAFT:          16 rows
-- DIM_PASSENGER:         ~500 rows
-- DIM_ROUTE:             20 rows
-- DIM_WEATHER:           ~8,600+ rows
-- DIM_DELAY_REASON:      32 rows
-- FACT_FLIGHT_EVENT:     ~5,000+ rows
-- FACT_BOOKING:          ~15,000+ rows
-- FACT_DELAY:            ~800+ rows
-- FACT_PASSENGER_FEEDBACK: ~500 rows
-- FACT_LOYALTY_ACTIVITY: ~2,000+ rows

-- ╔══════════════════════════════════════════════════════════════════════╗
-- ║  READY FOR DEMO!                                                     ║
-- ╚══════════════════════════════════════════════════════════════════════╝

-- Open: presentation/DEMO_QUICKSTART.sql
-- Follow: presentation/PRESENTATION_OUTLINE.md
-- Good luck! 🛫
