-- ============================================================================
-- SKYPULSE AI — Streams & Tasks: CDC Pipeline
-- ============================================================================
-- Demonstrates Snowflake's change data capture (Streams) and scheduled
-- automation (Tasks) for real-time data pipeline orchestration.
-- ============================================================================

USE DATABASE SKYPULSE_AI;
USE SCHEMA SILVER;
USE WAREHOUSE SKYPULSE_TRANSFORM_WH;

-- =============================================================================
-- STREAMS — Change Data Capture on Bronze tables
-- =============================================================================

-- Stream on raw bookings to detect new/changed reservations
CREATE OR REPLACE STREAM STREAM_RAW_BOOKINGS
    ON TABLE SKYPULSE_AI.BRONZE.RAW_BOOKINGS
    APPEND_ONLY = TRUE
    COMMENT = 'CDC stream for new booking ingestions';

-- Stream on raw flights for operational status updates
CREATE OR REPLACE STREAM STREAM_RAW_FLIGHTS
    ON TABLE SKYPULSE_AI.BRONZE.RAW_FLIGHTS
    APPEND_ONLY = TRUE
    COMMENT = 'CDC stream for flight status updates';

-- Stream on raw feedback for real-time sentiment processing
CREATE OR REPLACE STREAM STREAM_RAW_FEEDBACK
    ON TABLE SKYPULSE_AI.BRONZE.RAW_FEEDBACK
    APPEND_ONLY = TRUE
    COMMENT = 'CDC stream for new customer feedback requiring AI processing';

-- Stream on Silver fact for downstream alerting
CREATE OR REPLACE STREAM STREAM_FACT_DELAY
    ON TABLE SKYPULSE_AI.SILVER.FACT_DELAY
    COMMENT = 'CDC stream on delay events for alerting pipeline';

-- =============================================================================
-- TASKS — Scheduled Pipeline Orchestration
-- =============================================================================

-- -----------------------------------------------------------------------------
-- Task 1: Process new bookings (every 5 minutes)
-- Transforms raw booking JSON into the FACT_BOOKING star schema
-- -----------------------------------------------------------------------------

CREATE OR REPLACE TASK TASK_PROCESS_BOOKINGS
    WAREHOUSE = SKYPULSE_TRANSFORM_WH
    SCHEDULE = '5 MINUTE'
    COMMENT = 'Process new bookings from Bronze to Silver every 5 minutes'
    WHEN SYSTEM$STREAM_HAS_DATA('STREAM_RAW_BOOKINGS')
AS
MERGE INTO SKYPULSE_AI.SILVER.FACT_BOOKING tgt
USING (
    SELECT
        raw_data:booking_reference::VARCHAR(10) AS booking_reference,
        raw_data:passenger_id::VARCHAR(20) AS passenger_id,
        raw_data:flight_number::VARCHAR(10) AS flight_number,
        raw_data:route_code::VARCHAR(10) AS route_code,
        raw_data:booking_date::DATE AS booking_date,
        raw_data:flight_date::DATE AS flight_date,
        raw_data:cabin_class::CHAR(1) AS cabin_code,
        raw_data:origin::CHAR(3) AS origin_iata,
        raw_data:destination::CHAR(3) AS destination_iata,
        raw_data:channel::VARCHAR(20) AS booking_channel,
        raw_data:status::VARCHAR(20) AS booking_status,
        raw_data:fare_class::CHAR(1) AS fare_class,
        raw_data:fare_amount::DECIMAL(10,2) AS fare_amount,
        raw_data:tax_amount::DECIMAL(10,2) AS tax_amount,
        raw_data:total_amount::DECIMAL(10,2) AS total_amount,
        raw_data:ancillary_revenue::DECIMAL(8,2) AS ancillary_revenue,
        raw_data:has_checked_bag::BOOLEAN AS has_checked_bag,
        raw_data:has_seat_selection::BOOLEAN AS has_seat_selection,
        DATEDIFF('day', raw_data:booking_date::DATE, raw_data:flight_date::DATE) AS days_before_departure
    FROM STREAM_RAW_BOOKINGS
) src
ON tgt.booking_reference = src.booking_reference
   AND tgt.passenger_key = (SELECT passenger_key FROM DIM_PASSENGER WHERE passenger_id = src.passenger_id AND is_current = TRUE)
WHEN NOT MATCHED THEN INSERT (
    booking_reference, passenger_key, route_key, booking_date_key, flight_date_key,
    cabin_class_key, origin_airport_key, dest_airport_key, booking_channel,
    booking_status, fare_class, fare_amount, tax_amount, total_amount,
    ancillary_revenue, has_checked_bag, has_seat_selection, days_before_departure
)
VALUES (
    src.booking_reference,
    (SELECT passenger_key FROM DIM_PASSENGER WHERE passenger_id = src.passenger_id AND is_current = TRUE),
    (SELECT route_key FROM DIM_ROUTE WHERE route_code = src.route_code),
    TO_NUMBER(TO_CHAR(src.booking_date, 'YYYYMMDD')),
    TO_NUMBER(TO_CHAR(src.flight_date, 'YYYYMMDD')),
    (SELECT cabin_class_key FROM DIM_CABIN_CLASS WHERE cabin_code = src.cabin_code),
    (SELECT airport_key FROM DIM_AIRPORT WHERE iata_code = src.origin_iata),
    (SELECT airport_key FROM DIM_AIRPORT WHERE iata_code = src.destination_iata),
    src.booking_channel, src.booking_status, src.fare_class,
    src.fare_amount, src.tax_amount, src.total_amount, src.ancillary_revenue,
    src.has_checked_bag, src.has_seat_selection, src.days_before_departure
)
WHEN MATCHED AND tgt.booking_status != src.booking_status THEN UPDATE SET
    tgt.booking_status = src.booking_status,
    tgt.updated_at = CURRENT_TIMESTAMP();

-- -----------------------------------------------------------------------------
-- Task 2: Process flight status updates (every 2 minutes)
-- -----------------------------------------------------------------------------

CREATE OR REPLACE TASK TASK_PROCESS_FLIGHTS
    WAREHOUSE = SKYPULSE_TRANSFORM_WH
    SCHEDULE = '2 MINUTE'
    COMMENT = 'Process flight status updates from Bronze to Silver'
    WHEN SYSTEM$STREAM_HAS_DATA('STREAM_RAW_FLIGHTS')
AS
MERGE INTO SKYPULSE_AI.SILVER.FACT_FLIGHT_EVENT tgt
USING (
    SELECT
        raw_data:flight_number::VARCHAR(10) AS flight_number,
        TO_NUMBER(TO_CHAR(raw_data:flight_date::DATE, 'YYYYMMDD')) AS flight_date_key,
        raw_data:status::VARCHAR(20) AS flight_status,
        raw_data:actual_departure::TIMESTAMP_NTZ AS actual_departure,
        raw_data:actual_arrival::TIMESTAMP_NTZ AS actual_arrival,
        raw_data:departure_delay_min::INTEGER AS departure_delay_min,
        raw_data:arrival_delay_min::INTEGER AS arrival_delay_min,
        raw_data:pax_flown::INTEGER AS pax_flown,
        raw_data:fuel_consumed_kg::INTEGER AS fuel_consumed_kg
    FROM STREAM_RAW_FLIGHTS
) src
ON tgt.flight_number = src.flight_number AND tgt.flight_date_key = src.flight_date_key
WHEN MATCHED THEN UPDATE SET
    tgt.flight_status = src.flight_status,
    tgt.actual_departure = COALESCE(src.actual_departure, tgt.actual_departure),
    tgt.actual_arrival = COALESCE(src.actual_arrival, tgt.actual_arrival),
    tgt.departure_delay_min = COALESCE(src.departure_delay_min, tgt.departure_delay_min),
    tgt.arrival_delay_min = COALESCE(src.arrival_delay_min, tgt.arrival_delay_min),
    tgt.pax_flown = COALESCE(src.pax_flown, tgt.pax_flown),
    tgt.fuel_consumed_kg = COALESCE(src.fuel_consumed_kg, tgt.fuel_consumed_kg),
    tgt.load_factor_pct = COALESCE(src.pax_flown, tgt.pax_flown) * 100.0 / NULLIF(tgt.seat_capacity, 0),
    tgt.updated_at = CURRENT_TIMESTAMP();

-- -----------------------------------------------------------------------------
-- Task 3: Process feedback with Cortex AI enrichment (every 10 minutes)
-- This is the AI-powered pipeline — sentiment analysis + summarization
-- -----------------------------------------------------------------------------

CREATE OR REPLACE TASK TASK_PROCESS_FEEDBACK_AI
    WAREHOUSE = SKYPULSE_ML_WH
    SCHEDULE = '10 MINUTE'
    COMMENT = 'Process new feedback with Cortex AI sentiment analysis and summarization'
    WHEN SYSTEM$STREAM_HAS_DATA('STREAM_RAW_FEEDBACK')
AS
INSERT INTO SKYPULSE_AI.SILVER.FACT_PASSENGER_FEEDBACK (
    passenger_key, flight_date_key, feedback_channel, feedback_timestamp,
    feedback_text, feedback_subject, nps_score, overall_rating,
    sentiment_score, sentiment_label, ai_summary, ai_action_required, ai_priority
)
SELECT
    p.passenger_key,
    TO_NUMBER(TO_CHAR(raw_data:flight_date::DATE, 'YYYYMMDD')) AS flight_date_key,
    s.channel AS feedback_channel,
    s.ingest_timestamp AS feedback_timestamp,
    raw_data:feedback_text::VARCHAR AS feedback_text,
    raw_data:subject::VARCHAR AS feedback_subject,
    raw_data:nps_score::TINYINT AS nps_score,
    raw_data:overall_rating::TINYINT AS overall_rating,
    -- Cortex AI Sentiment Analysis
    SNOWFLAKE.CORTEX.SENTIMENT(raw_data:feedback_text::VARCHAR) AS sentiment_score,
    CASE 
        WHEN SNOWFLAKE.CORTEX.SENTIMENT(raw_data:feedback_text::VARCHAR) > 0.3 THEN 'POSITIVE'
        WHEN SNOWFLAKE.CORTEX.SENTIMENT(raw_data:feedback_text::VARCHAR) < -0.3 THEN 'NEGATIVE'
        ELSE 'NEUTRAL'
    END AS sentiment_label,
    -- Cortex AI Summarization
    SNOWFLAKE.CORTEX.SUMMARIZE(raw_data:feedback_text::VARCHAR) AS ai_summary,
    -- Action required if negative sentiment or low NPS
    CASE WHEN SNOWFLAKE.CORTEX.SENTIMENT(raw_data:feedback_text::VARCHAR) < -0.5 
              OR raw_data:nps_score::TINYINT <= 3 THEN TRUE ELSE FALSE END AS ai_action_required,
    CASE 
        WHEN SNOWFLAKE.CORTEX.SENTIMENT(raw_data:feedback_text::VARCHAR) < -0.7 THEN 'CRITICAL'
        WHEN SNOWFLAKE.CORTEX.SENTIMENT(raw_data:feedback_text::VARCHAR) < -0.5 THEN 'HIGH'
        WHEN SNOWFLAKE.CORTEX.SENTIMENT(raw_data:feedback_text::VARCHAR) < -0.3 THEN 'MEDIUM'
        ELSE 'LOW'
    END AS ai_priority
FROM STREAM_RAW_FEEDBACK s
LEFT JOIN SKYPULSE_AI.SILVER.DIM_PASSENGER p 
    ON s.raw_data:passenger_id::VARCHAR = p.passenger_id AND p.is_current = TRUE;

-- -----------------------------------------------------------------------------
-- Task 4: Alert on critical delays (child task, triggered by delay stream)
-- -----------------------------------------------------------------------------

CREATE OR REPLACE TASK TASK_DELAY_ALERTING
    WAREHOUSE = SKYPULSE_TRANSFORM_WH
    SCHEDULE = '5 MINUTE'
    COMMENT = 'Check for new critical delays and generate alerts'
    WHEN SYSTEM$STREAM_HAS_DATA('STREAM_FACT_DELAY')
AS
BEGIN
    -- Log critical delays for alerting system
    INSERT INTO SKYPULSE_AI.GOLD.ALERT_LOG (
        alert_type, severity, flight_number, message, created_at
    )
    SELECT
        'CRITICAL_DELAY',
        'HIGH',
        fe.flight_number,
        'Flight ' || fe.flight_number || ' delayed ' || sd.delay_minutes || ' min due to ' || sd.delay_category,
        CURRENT_TIMESTAMP()
    FROM STREAM_FACT_DELAY sd
    JOIN SKYPULSE_AI.SILVER.FACT_FLIGHT_EVENT fe ON sd.flight_event_key = fe.flight_event_key
    WHERE sd.delay_minutes > 120;
END;

-- =============================================================================
-- ALERT LOG TABLE (for Task 4)
-- =============================================================================

USE SCHEMA GOLD;

CREATE OR REPLACE TABLE ALERT_LOG (
    alert_id            BIGINT       NOT NULL AUTOINCREMENT,
    alert_type          VARCHAR(50)  NOT NULL,
    severity            VARCHAR(10)  NOT NULL,
    flight_number       VARCHAR(10),
    message             VARCHAR(1000) NOT NULL,
    acknowledged        BOOLEAN      DEFAULT FALSE,
    acknowledged_by     VARCHAR(100),
    created_at          TIMESTAMP_NTZ NOT NULL,
    CONSTRAINT pk_alert_log PRIMARY KEY (alert_id)
)
COMMENT = 'Operational alert log generated by automated tasks';

-- =============================================================================
-- RESUME TASKS (they are created in suspended state)
-- =============================================================================

-- Uncomment to activate in production:
-- ALTER TASK SKYPULSE_AI.SILVER.TASK_PROCESS_BOOKINGS RESUME;
-- ALTER TASK SKYPULSE_AI.SILVER.TASK_PROCESS_FLIGHTS RESUME;
-- ALTER TASK SKYPULSE_AI.SILVER.TASK_PROCESS_FEEDBACK_AI RESUME;
-- ALTER TASK SKYPULSE_AI.SILVER.TASK_DELAY_ALERTING RESUME;
