-- ============================================================================
-- SKYPULSE AI — Silver Layer: Fact Tables
-- ============================================================================
-- Transactional and event grain fact tables forming the core of the
-- star schema analytical model.
-- ============================================================================

USE DATABASE SKYPULSE_AI;
USE SCHEMA SILVER;
USE WAREHOUSE SKYPULSE_TRANSFORM_WH;

-- =============================================================================
-- FACT_FLIGHT_EVENT — One row per flight operation (the master flight fact)
-- Grain: One flight leg on one date
-- =============================================================================

CREATE OR REPLACE TABLE FACT_FLIGHT_EVENT (
    flight_event_key    BIGINT       NOT NULL AUTOINCREMENT,
    -- Dimensional keys
    flight_number       VARCHAR(10)  NOT NULL,   -- e.g., 'SP1234'
    flight_date_key     INTEGER      NOT NULL,   -- FK → DIM_DATE
    origin_airport_key  INTEGER      NOT NULL,   -- FK → DIM_AIRPORT
    dest_airport_key    INTEGER      NOT NULL,   -- FK → DIM_AIRPORT
    aircraft_key        INTEGER      NOT NULL,   -- FK → DIM_AIRCRAFT
    route_key           INTEGER      NOT NULL,   -- FK → DIM_ROUTE
    -- Schedule
    scheduled_departure TIMESTAMP_NTZ NOT NULL,
    scheduled_arrival   TIMESTAMP_NTZ NOT NULL,
    -- Actuals
    actual_departure    TIMESTAMP_NTZ,
    actual_arrival      TIMESTAMP_NTZ,
    -- Status
    flight_status       VARCHAR(20)  NOT NULL,   -- 'SCHEDULED','DEPARTED','AIRBORNE','LANDED','CANCELLED','DIVERTED'
    -- Measures
    departure_delay_min INTEGER      DEFAULT 0,
    arrival_delay_min   INTEGER      DEFAULT 0,
    block_time_min      INTEGER,                 -- Actual gate-to-gate time
    air_time_min        INTEGER,                 -- Wheels-up to wheels-down
    taxi_out_min        INTEGER,
    taxi_in_min         INTEGER,
    distance_flown_km   INTEGER,
    -- Load & Revenue
    pax_booked          INTEGER      NOT NULL,
    pax_flown           INTEGER,
    seat_capacity       INTEGER      NOT NULL,
    load_factor_pct     FLOAT,                   -- pax_flown / seat_capacity
    revenue_total       DECIMAL(12,2),
    revenue_per_pax     DECIMAL(8,2),
    -- Fuel
    fuel_loaded_kg      INTEGER,
    fuel_consumed_kg    INTEGER,
    fuel_efficiency_l_per_100km FLOAT,
    -- Crew
    crew_captain_id     VARCHAR(20),
    crew_fo_id          VARCHAR(20),
    cabin_crew_count    TINYINT,
    -- Gate info
    departure_gate      VARCHAR(10),
    arrival_gate        VARCHAR(10),
    departure_terminal  VARCHAR(5),
    arrival_terminal    VARCHAR(5),
    -- Metadata
    created_at          TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    updated_at          TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    CONSTRAINT pk_fact_flight PRIMARY KEY (flight_event_key)
)
CLUSTER BY (flight_date_key, origin_airport_key)
COMMENT = 'Master flight operations fact - one row per flight leg per date';

ALTER TABLE FACT_FLIGHT_EVENT SET TAG DATA_DOMAIN = 'FLIGHT_OPS';

-- =============================================================================
-- FACT_BOOKING — One row per booking segment
-- Grain: One passenger on one flight segment in one booking
-- =============================================================================

CREATE OR REPLACE TABLE FACT_BOOKING (
    booking_key         BIGINT       NOT NULL AUTOINCREMENT,
    -- Business keys
    booking_reference   VARCHAR(10)  NOT NULL,   -- PNR (e.g., 'ABC123')
    -- Dimensional keys
    passenger_key       INTEGER      NOT NULL,   -- FK → DIM_PASSENGER
    flight_event_key    BIGINT,                  -- FK → FACT_FLIGHT_EVENT (null if not yet operated)
    route_key           INTEGER      NOT NULL,   -- FK → DIM_ROUTE
    booking_date_key    INTEGER      NOT NULL,   -- FK → DIM_DATE (when booked)
    flight_date_key     INTEGER      NOT NULL,   -- FK → DIM_DATE (travel date)
    cabin_class_key     TINYINT      NOT NULL,   -- FK → DIM_CABIN_CLASS
    origin_airport_key  INTEGER      NOT NULL,   -- FK → DIM_AIRPORT
    dest_airport_key    INTEGER      NOT NULL,   -- FK → DIM_AIRPORT
    -- Booking details
    booking_channel     VARCHAR(20)  NOT NULL,   -- 'WEB','MOBILE','CALL_CENTER','TRAVEL_AGENT','CORPORATE'
    booking_status      VARCHAR(20)  NOT NULL,   -- 'CONFIRMED','CANCELLED','NO_SHOW','CHECKED_IN','BOARDED','FLOWN'
    fare_class          CHAR(1)      NOT NULL,   -- Y, B, H, K, M, L, Q, etc.
    fare_basis          VARCHAR(20),
    -- Measures
    fare_amount         DECIMAL(10,2) NOT NULL,
    tax_amount          DECIMAL(10,2) DEFAULT 0,
    total_amount        DECIMAL(10,2) NOT NULL,
    ancillary_revenue   DECIMAL(8,2)  DEFAULT 0, -- Bags, upgrades, seats, meals
    currency_code       CHAR(3)      DEFAULT 'GBP',
    -- Ancillary flags
    has_checked_bag     BOOLEAN      DEFAULT FALSE,
    has_seat_selection  BOOLEAN      DEFAULT FALSE,
    has_meal_preorder   BOOLEAN      DEFAULT FALSE,
    has_lounge_access   BOOLEAN      DEFAULT FALSE,
    is_upgrade          BOOLEAN      DEFAULT FALSE,
    -- Booking timing
    days_before_departure INTEGER,               -- Advance purchase days
    booking_lead_category VARCHAR(20),           -- 'SAME_DAY','1-3_DAYS','4-7_DAYS','8-14_DAYS','15-30_DAYS','31-60_DAYS','61+'
    -- Metadata
    created_at          TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    updated_at          TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    CONSTRAINT pk_fact_booking PRIMARY KEY (booking_key)
)
CLUSTER BY (flight_date_key, origin_airport_key)
COMMENT = 'Booking fact - one row per passenger-segment in a PNR';

ALTER TABLE FACT_BOOKING SET TAG DATA_DOMAIN = 'COMMERCIAL';

-- =============================================================================
-- FACT_DELAY — One row per delay event
-- Grain: One delay cause per flight
-- =============================================================================

CREATE OR REPLACE TABLE FACT_DELAY (
    delay_key           BIGINT       NOT NULL AUTOINCREMENT,
    -- Dimensional keys
    flight_event_key    BIGINT       NOT NULL,   -- FK → FACT_FLIGHT_EVENT
    flight_date_key     INTEGER      NOT NULL,   -- FK → DIM_DATE
    airport_key         INTEGER      NOT NULL,   -- FK → DIM_AIRPORT (where delay occurred)
    delay_reason_key    INTEGER      NOT NULL,   -- FK → DIM_DELAY_REASON
    weather_key         INTEGER,                 -- FK → DIM_WEATHER (if weather-related)
    -- Measures
    delay_minutes       INTEGER      NOT NULL,
    delay_category      VARCHAR(50)  NOT NULL,   -- Denormalized for fast filtering
    -- Impact
    pax_affected        INTEGER,
    compensation_amount DECIMAL(10,2) DEFAULT 0,
    rebooking_cost      DECIMAL(10,2) DEFAULT 0,
    hotel_cost          DECIMAL(10,2) DEFAULT 0,
    meal_voucher_cost   DECIMAL(8,2)  DEFAULT 0,
    total_cost_impact   DECIMAL(12,2),
    -- Downstream
    caused_missed_connections INTEGER DEFAULT 0,
    reactionary_delay_min     INTEGER DEFAULT 0,  -- Delay propagated to next rotation
    -- Metadata
    created_at          TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    CONSTRAINT pk_fact_delay PRIMARY KEY (delay_key)
)
CLUSTER BY (flight_date_key, airport_key)
COMMENT = 'Delay event fact with cause codes and financial impact';

ALTER TABLE FACT_DELAY SET TAG DATA_DOMAIN = 'FLIGHT_OPS';

-- =============================================================================
-- FACT_PASSENGER_FEEDBACK — One row per feedback submission
-- Grain: One feedback per passenger per journey
-- =============================================================================

CREATE OR REPLACE TABLE FACT_PASSENGER_FEEDBACK (
    feedback_key        BIGINT       NOT NULL AUTOINCREMENT,
    -- Dimensional keys
    passenger_key       INTEGER,                 -- FK → DIM_PASSENGER (nullable for anonymous)
    flight_event_key    BIGINT,                  -- FK → FACT_FLIGHT_EVENT
    flight_date_key     INTEGER      NOT NULL,   -- FK → DIM_DATE
    route_key           INTEGER,                 -- FK → DIM_ROUTE
    -- Feedback details
    feedback_channel    VARCHAR(20)  NOT NULL,   -- 'NPS_SURVEY','SOCIAL_MEDIA','IN_APP','EMAIL','CALL_CENTER'
    feedback_timestamp  TIMESTAMP_NTZ NOT NULL,
    -- Text (for Cortex AI analysis)
    feedback_text       VARCHAR(5000),
    feedback_subject    VARCHAR(200),
    -- Scores
    nps_score           TINYINT,                 -- 0-10
    overall_rating      TINYINT,                 -- 1-5 stars
    -- Category ratings (1-5)
    rating_boarding     TINYINT,
    rating_cabin_crew   TINYINT,
    rating_food         TINYINT,
    rating_entertainment TINYINT,
    rating_seat_comfort TINYINT,
    rating_punctuality  TINYINT,
    rating_value        TINYINT,
    -- AI-derived (populated by Cortex)
    sentiment_score     FLOAT,                   -- -1.0 to 1.0
    sentiment_label     VARCHAR(10),             -- 'POSITIVE','NEUTRAL','NEGATIVE'
    ai_summary          VARCHAR(500),
    ai_topics           ARRAY,                   -- Extracted topics
    ai_action_required  BOOLEAN,
    ai_priority         VARCHAR(10),             -- 'LOW','MEDIUM','HIGH','CRITICAL'
    -- Metadata
    created_at          TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    processed_at        TIMESTAMP_NTZ,
    CONSTRAINT pk_fact_feedback PRIMARY KEY (feedback_key)
)
CLUSTER BY (flight_date_key, feedback_channel)
COMMENT = 'Passenger feedback fact with AI-enriched sentiment and topic analysis';

ALTER TABLE FACT_PASSENGER_FEEDBACK SET TAG DATA_DOMAIN = 'PASSENGER';

-- =============================================================================
-- FACT_LOYALTY_ACTIVITY — Miles earned and redeemed
-- Grain: One loyalty transaction
-- =============================================================================

CREATE OR REPLACE TABLE FACT_LOYALTY_ACTIVITY (
    activity_key        BIGINT       NOT NULL AUTOINCREMENT,
    -- Dimensional keys
    passenger_key       INTEGER      NOT NULL,   -- FK → DIM_PASSENGER
    activity_date_key   INTEGER      NOT NULL,   -- FK → DIM_DATE
    -- Activity details
    activity_type       VARCHAR(20)  NOT NULL,   -- 'EARN_FLIGHT','EARN_PARTNER','EARN_CARD','REDEEM_FLIGHT','REDEEM_UPGRADE','REDEEM_PARTNER','EXPIRE','TIER_BONUS'
    activity_source     VARCHAR(50),             -- Partner name or flight number
    -- Measures
    miles_earned        INTEGER      DEFAULT 0,
    miles_redeemed      INTEGER      DEFAULT 0,
    miles_expired       INTEGER      DEFAULT 0,
    qualifying_miles    INTEGER      DEFAULT 0,  -- Count toward tier status
    balance_after       BIGINT,
    -- Value
    monetary_value      DECIMAL(8,2),            -- Estimated GBP value of miles
    -- Metadata
    created_at          TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    CONSTRAINT pk_fact_loyalty PRIMARY KEY (activity_key)
)
CLUSTER BY (activity_date_key, passenger_key)
COMMENT = 'Loyalty program activity fact - earning, redemption, expiry';

ALTER TABLE FACT_LOYALTY_ACTIVITY SET TAG DATA_DOMAIN = 'COMMERCIAL';
