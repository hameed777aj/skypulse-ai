-- ============================================================================
-- SKYPULSE AI — Feature Showcase: Alerts & Notifications
-- ============================================================================
-- Demonstrates Snowflake's native alerting system for proactive
-- operational monitoring — no external tools required.
-- ============================================================================

USE DATABASE SKYPULSE_AI;
USE SCHEMA GOLD;
USE WAREHOUSE SKYPULSE_TRANSFORM_WH;

-- =============================================================================
-- 1. ALERT: Critical delay threshold exceeded
-- =============================================================================

CREATE OR REPLACE ALERT ALERT_CRITICAL_DELAY
    WAREHOUSE = SKYPULSE_TRANSFORM_WH
    SCHEDULE = '5 MINUTE'
    IF (EXISTS (
        SELECT 1
        FROM SKYPULSE_AI.SILVER.FACT_FLIGHT_EVENT fe
        JOIN SKYPULSE_AI.SILVER.DIM_DATE d ON fe.flight_date_key = d.date_key
        WHERE d.full_date = CURRENT_DATE()
          AND fe.departure_delay_min > 120
          AND fe.flight_status = 'SCHEDULED'
    ))
    THEN
        CALL SYSTEM$SEND_EMAIL(
            'skypulse_ops_notifications',
            'ops-control@skypulse-airways.com',
            'ALERT: Critical Flight Delay Detected',
            'One or more flights have exceeded 120-minute delay threshold. Immediate action required. Check DT_OPS_ANOMALY for details.'
        );

-- =============================================================================
-- 2. ALERT: Customer churn risk spike
-- =============================================================================

CREATE OR REPLACE ALERT ALERT_CHURN_RISK_SPIKE
    WAREHOUSE = SKYPULSE_TRANSFORM_WH
    SCHEDULE = '1 HOUR'
    IF (EXISTS (
        SELECT 1
        FROM DT_PASSENGER_RISK
        WHERE churn_risk_level = 'CRITICAL'
          AND loyalty_tier IN ('DIAMOND', 'PLATINUM')
        HAVING COUNT(*) > 5  -- More than 5 premium members at critical risk
    ))
    THEN
        CALL SYSTEM$SEND_EMAIL(
            'skypulse_ops_notifications',
            'loyalty-team@skypulse-airways.com',
            'ALERT: High-Value Customer Churn Risk Spike',
            'Multiple Diamond/Platinum members have entered CRITICAL churn risk. Immediate retention intervention recommended.'
        );

-- =============================================================================
-- 3. ALERT: OTP drops below target
-- =============================================================================

CREATE OR REPLACE ALERT ALERT_OTP_BELOW_TARGET
    WAREHOUSE = SKYPULSE_TRANSFORM_WH
    SCHEDULE = '30 MINUTE'
    IF (EXISTS (
        SELECT 1
        FROM SKYPULSE_AI.SILVER.FACT_FLIGHT_EVENT fe
        JOIN SKYPULSE_AI.SILVER.DIM_DATE d ON fe.flight_date_key = d.date_key
        WHERE d.full_date = CURRENT_DATE()
          AND fe.flight_status = 'LANDED'
        GROUP BY d.full_date
        HAVING (COUNT(CASE WHEN fe.arrival_delay_min <= 15 THEN 1 END) * 100.0 / COUNT(*)) < 75
    ))
    THEN
        CALL SYSTEM$SEND_EMAIL(
            'skypulse_ops_notifications',
            'ops-director@skypulse-airways.com',
            'ALERT: Daily OTP Below 75% Target',
            'On-time performance has dropped below the 75% threshold today. Review current disruptions and consider proactive passenger communications.'
        );

-- =============================================================================
-- 4. ALERT: Negative sentiment surge
-- =============================================================================

CREATE OR REPLACE ALERT ALERT_SENTIMENT_SURGE
    WAREHOUSE = SKYPULSE_ML_WH
    SCHEDULE = '15 MINUTE'
    IF (EXISTS (
        SELECT 1
        FROM SKYPULSE_AI.SILVER.FACT_PASSENGER_FEEDBACK
        WHERE feedback_timestamp >= DATEADD('hour', -1, CURRENT_TIMESTAMP())
          AND sentiment_score < -0.6
        HAVING COUNT(*) > 10  -- More than 10 very negative feedbacks in 1 hour
    ))
    THEN
        CALL SYSTEM$SEND_EMAIL(
            'skypulse_ops_notifications',
            'customer-experience@skypulse-airways.com',
            'ALERT: Negative Sentiment Surge Detected',
            'Unusual spike in highly negative customer feedback in the last hour. Possible service disruption. Check V_CRITICAL_FEEDBACK_SUMMARY for details.'
        );

-- =============================================================================
-- 5. ALERT: Fuel efficiency anomaly
-- =============================================================================

CREATE OR REPLACE ALERT ALERT_FUEL_ANOMALY
    WAREHOUSE = SKYPULSE_TRANSFORM_WH
    SCHEDULE = '1 HOUR'
    IF (EXISTS (
        SELECT 1
        FROM SKYPULSE_AI.SILVER.FACT_FLIGHT_EVENT fe
        JOIN SKYPULSE_AI.SILVER.DIM_DATE d ON fe.flight_date_key = d.date_key
        WHERE d.full_date = CURRENT_DATE()
          AND fe.fuel_consumed_kg > fe.fuel_loaded_kg * 0.92
          AND fe.flight_status = 'LANDED'
    ))
    THEN
        CALL SYSTEM$SEND_EMAIL(
            'skypulse_ops_notifications',
            'engineering@skypulse-airways.com',
            'ALERT: High Fuel Consumption Detected',
            'One or more flights today consumed >92% of loaded fuel. Engineering review recommended for aircraft performance check.'
        );

-- =============================================================================
-- Resume alerts for production (uncomment when ready)
-- =============================================================================

-- ALTER ALERT ALERT_CRITICAL_DELAY RESUME;
-- ALTER ALERT ALERT_CHURN_RISK_SPIKE RESUME;
-- ALTER ALERT ALERT_OTP_BELOW_TARGET RESUME;
-- ALTER ALERT ALERT_SENTIMENT_SURGE RESUME;
-- ALTER ALERT ALERT_FUEL_ANOMALY RESUME;

-- Check alert status
SHOW ALERTS IN SCHEMA SKYPULSE_AI.GOLD;
