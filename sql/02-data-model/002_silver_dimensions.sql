-- ============================================================================
-- SKYPULSE AI — Silver Layer: Dimension Tables
-- ============================================================================
-- Conformed star schema dimensions. SCD Type 2 on key entities.
-- PII columns tagged for GDPR compliance.
-- ============================================================================

USE DATABASE SKYPULSE_AI;
USE SCHEMA SILVER;
USE WAREHOUSE SKYPULSE_TRANSFORM_WH;

-- =============================================================================
-- DIM_DATE — Standard date dimension (granularity: day)
-- =============================================================================

CREATE OR REPLACE TABLE DIM_DATE (
    date_key            INTEGER      NOT NULL,   -- YYYYMMDD format
    full_date           DATE         NOT NULL,
    day_of_week         TINYINT      NOT NULL,   -- 1=Monday, 7=Sunday (ISO)
    day_name            VARCHAR(10)  NOT NULL,
    day_of_month        TINYINT      NOT NULL,
    day_of_year         SMALLINT     NOT NULL,
    week_of_year        TINYINT      NOT NULL,
    iso_week            TINYINT      NOT NULL,
    month_number        TINYINT      NOT NULL,
    month_name          VARCHAR(10)  NOT NULL,
    quarter             TINYINT      NOT NULL,
    year                SMALLINT     NOT NULL,
    is_weekend          BOOLEAN      NOT NULL,
    is_holiday          BOOLEAN      DEFAULT FALSE,
    holiday_name        VARCHAR(100),
    fiscal_quarter      TINYINT,
    fiscal_year         SMALLINT,
    season              VARCHAR(10),            -- WINTER, SPRING, SUMMER, AUTUMN
    CONSTRAINT pk_dim_date PRIMARY KEY (date_key)
)
COMMENT = 'Standard date dimension covering 2020-2027';

-- =============================================================================
-- DIM_TIME — Time dimension (granularity: minute)
-- =============================================================================

CREATE OR REPLACE TABLE DIM_TIME (
    time_key            INTEGER      NOT NULL,   -- HHMM format (0000-2359)
    full_time           TIME         NOT NULL,
    hour_24             TINYINT      NOT NULL,
    hour_12             TINYINT      NOT NULL,
    minute              TINYINT      NOT NULL,
    am_pm               VARCHAR(2)   NOT NULL,
    time_band           VARCHAR(20)  NOT NULL,   -- 'RED_EYE','EARLY_MORNING','MORNING','MIDDAY','AFTERNOON','EVENING','NIGHT'
    is_peak_hour        BOOLEAN      NOT NULL,
    CONSTRAINT pk_dim_time PRIMARY KEY (time_key)
)
COMMENT = 'Time-of-day dimension at minute granularity';

-- =============================================================================
-- DIM_AIRPORT — Airport/station reference
-- =============================================================================

CREATE OR REPLACE TABLE DIM_AIRPORT (
    airport_key         INTEGER      NOT NULL AUTOINCREMENT,
    iata_code           CHAR(3)      NOT NULL,
    icao_code           CHAR(4),
    airport_name        VARCHAR(200) NOT NULL,
    city                VARCHAR(100) NOT NULL,
    country             VARCHAR(100) NOT NULL,
    country_code        CHAR(2)      NOT NULL,
    region              VARCHAR(50),            -- EU, NA, APAC, MEA, LATAM
    latitude            FLOAT,
    longitude           FLOAT,
    elevation_ft        INTEGER,
    timezone            VARCHAR(50)  NOT NULL,
    utc_offset          FLOAT,
    hub_type            VARCHAR(20),            -- 'PRIMARY_HUB','SECONDARY_HUB','FOCUS_CITY','OUTSTATION'
    runway_count        TINYINT,
    terminal_count      TINYINT,
    annual_capacity_m   FLOAT,                  -- Annual passenger capacity (millions)
    is_active           BOOLEAN      DEFAULT TRUE,
    CONSTRAINT pk_dim_airport PRIMARY KEY (airport_key),
    CONSTRAINT uq_airport_iata UNIQUE (iata_code)
)
COMMENT = 'Airport reference dimension with operational attributes';

-- =============================================================================
-- DIM_AIRCRAFT — Fleet dimension
-- =============================================================================

CREATE OR REPLACE TABLE DIM_AIRCRAFT (
    aircraft_key        INTEGER      NOT NULL AUTOINCREMENT,
    registration        VARCHAR(10)  NOT NULL,
    aircraft_type       VARCHAR(10)  NOT NULL,   -- 'A320','B738','A350','B787'
    aircraft_family     VARCHAR(50)  NOT NULL,   -- 'A320 Family','737 NG','A350 XWB'
    manufacturer        VARCHAR(50)  NOT NULL,
    model_variant       VARCHAR(50),
    seat_capacity_total INTEGER      NOT NULL,
    seats_first         INTEGER      DEFAULT 0,
    seats_business      INTEGER      DEFAULT 0,
    seats_premium_eco   INTEGER      DEFAULT 0,
    seats_economy       INTEGER      NOT NULL,
    max_range_nm        INTEGER,
    delivery_date       DATE,
    aircraft_age_years  FLOAT,
    engine_type         VARCHAR(100),
    engine_count        TINYINT,
    is_widebody         BOOLEAN      NOT NULL,
    status              VARCHAR(20)  DEFAULT 'ACTIVE',  -- ACTIVE, MAINTENANCE, STORED, RETIRED
    last_heavy_check    DATE,
    next_heavy_check    DATE,
    CONSTRAINT pk_dim_aircraft PRIMARY KEY (aircraft_key),
    CONSTRAINT uq_aircraft_reg UNIQUE (registration)
)
COMMENT = 'Fleet aircraft dimension with maintenance and configuration details';

-- =============================================================================
-- DIM_PASSENGER — SCD Type 2 (tracks loyalty tier changes)
-- =============================================================================

CREATE OR REPLACE TABLE DIM_PASSENGER (
    passenger_key       INTEGER      NOT NULL AUTOINCREMENT,
    passenger_id        VARCHAR(20)  NOT NULL,   -- Business key (e.g., FFN number)
    -- PII Fields (tagged)
    first_name          VARCHAR(100) NOT NULL,
    last_name           VARCHAR(100) NOT NULL,
    email               VARCHAR(200),
    phone               VARCHAR(30),
    date_of_birth       DATE,
    passport_country    CHAR(2),
    -- Demographics
    gender              VARCHAR(10),
    nationality         CHAR(2),
    home_airport        CHAR(3),
    preferred_language  CHAR(2)      DEFAULT 'EN',
    -- Loyalty
    loyalty_program     VARCHAR(50),            -- 'SKYMILES_GOLD','SKYMILES_SILVER','SKYMILES_PLATINUM','NONE'
    loyalty_tier        VARCHAR(20)  NOT NULL,   -- 'BRONZE','SILVER','GOLD','PLATINUM','DIAMOND'
    loyalty_join_date   DATE,
    lifetime_miles      BIGINT       DEFAULT 0,
    ytd_miles           INTEGER      DEFAULT 0,
    ytd_segments        INTEGER      DEFAULT 0,
    -- Preferences
    meal_preference     VARCHAR(20),            -- 'STANDARD','VEGETARIAN','VEGAN','HALAL','KOSHER'
    seat_preference     VARCHAR(10),            -- 'WINDOW','AISLE','MIDDLE'
    communication_pref  VARCHAR(20),            -- 'EMAIL','SMS','PUSH','NONE'
    -- SCD2 metadata
    effective_from      TIMESTAMP_NTZ NOT NULL DEFAULT CURRENT_TIMESTAMP(),
    effective_to        TIMESTAMP_NTZ DEFAULT '9999-12-31 23:59:59'::TIMESTAMP_NTZ,
    is_current          BOOLEAN      DEFAULT TRUE,
    -- Record metadata
    created_at          TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    updated_at          TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    CONSTRAINT pk_dim_passenger PRIMARY KEY (passenger_key)
)
COMMENT = 'Passenger dimension with SCD Type 2 for loyalty tier tracking';

-- Apply PII tags for governance
ALTER TABLE DIM_PASSENGER MODIFY COLUMN first_name SET TAG PII_CLASSIFICATION = 'NAME';
ALTER TABLE DIM_PASSENGER MODIFY COLUMN last_name SET TAG PII_CLASSIFICATION = 'NAME';
ALTER TABLE DIM_PASSENGER MODIFY COLUMN email SET TAG PII_CLASSIFICATION = 'EMAIL';
ALTER TABLE DIM_PASSENGER MODIFY COLUMN phone SET TAG PII_CLASSIFICATION = 'PHONE';
ALTER TABLE DIM_PASSENGER MODIFY COLUMN date_of_birth SET TAG PII_CLASSIFICATION = 'DOB';
ALTER TABLE DIM_PASSENGER MODIFY COLUMN passport_country SET TAG PII_CLASSIFICATION = 'PASSPORT';

-- Apply sensitivity tag
ALTER TABLE DIM_PASSENGER SET TAG DATA_SENSITIVITY = 'CONFIDENTIAL';
ALTER TABLE DIM_PASSENGER SET TAG DATA_DOMAIN = 'PASSENGER';

-- =============================================================================
-- DIM_ROUTE — Route/city pair dimension
-- =============================================================================

CREATE OR REPLACE TABLE DIM_ROUTE (
    route_key           INTEGER      NOT NULL AUTOINCREMENT,
    route_code          VARCHAR(10)  NOT NULL,   -- e.g., 'LHR-JFK'
    origin_iata         CHAR(3)      NOT NULL,
    destination_iata    CHAR(3)      NOT NULL,
    distance_km         INTEGER      NOT NULL,
    distance_nm         INTEGER      NOT NULL,
    flight_time_mins    INTEGER,                 -- Typical block time
    route_type          VARCHAR(20)  NOT NULL,   -- 'DOMESTIC','SHORT_HAUL','MEDIUM_HAUL','LONG_HAUL','ULTRA_LONG_HAUL'
    market_type         VARCHAR(20),             -- 'BUSINESS','LEISURE','VFR','MIXED'
    competition_level   VARCHAR(10),             -- 'LOW','MEDIUM','HIGH'
    is_seasonal         BOOLEAN      DEFAULT FALSE,
    is_active           BOOLEAN      DEFAULT TRUE,
    CONSTRAINT pk_dim_route PRIMARY KEY (route_key),
    CONSTRAINT uq_route_code UNIQUE (route_code)
)
COMMENT = 'Route dimension with market and operational attributes';

-- =============================================================================
-- DIM_WEATHER — Hourly weather observations per airport
-- =============================================================================

CREATE OR REPLACE TABLE DIM_WEATHER (
    weather_key         INTEGER      NOT NULL AUTOINCREMENT,
    airport_iata        CHAR(3)      NOT NULL,
    observation_time    TIMESTAMP_NTZ NOT NULL,
    -- Conditions
    temperature_c       FLOAT,
    feels_like_c        FLOAT,
    humidity_pct        FLOAT,
    wind_speed_kts      FLOAT,
    wind_gust_kts       FLOAT,
    wind_direction_deg  INTEGER,
    visibility_km       FLOAT,
    pressure_hpa        FLOAT,
    precipitation_mm    FLOAT,
    snow_depth_cm       FLOAT,
    cloud_cover_pct     FLOAT,
    -- Derived categoricals
    weather_condition   VARCHAR(30),             -- 'CLEAR','CLOUDY','RAIN','SNOW','FOG','THUNDERSTORM','ICE'
    severity            VARCHAR(10),             -- 'NONE','MILD','MODERATE','SEVERE'
    is_vfr              BOOLEAN,                 -- Visual flight rules conditions
    is_deicing_required BOOLEAN,
    CONSTRAINT pk_dim_weather PRIMARY KEY (weather_key)
)
CLUSTER BY (airport_iata, TO_DATE(observation_time))
COMMENT = 'Hourly weather dimension per airport for delay correlation analysis';

-- =============================================================================
-- DIM_DELAY_REASON — Delay cause code reference (IATA standard)
-- =============================================================================

CREATE OR REPLACE TABLE DIM_DELAY_REASON (
    delay_reason_key    INTEGER      NOT NULL AUTOINCREMENT,
    iata_delay_code     VARCHAR(5)   NOT NULL,
    delay_category      VARCHAR(50)  NOT NULL,   -- 'WEATHER','ATC','TECHNICAL','CREW','PASSENGER','SECURITY','AIRPORT','REACTIONARY'
    delay_subcategory   VARCHAR(100) NOT NULL,
    description         VARCHAR(500),
    is_airline_fault    BOOLEAN      NOT NULL,   -- Determines compensation liability
    is_controllable     BOOLEAN      NOT NULL,
    CONSTRAINT pk_dim_delay_reason PRIMARY KEY (delay_reason_key),
    CONSTRAINT uq_delay_code UNIQUE (iata_delay_code)
)
COMMENT = 'IATA standard delay cause codes for root cause analysis';

-- =============================================================================
-- DIM_CABIN_CLASS — Service class reference
-- =============================================================================

CREATE OR REPLACE TABLE DIM_CABIN_CLASS (
    cabin_class_key     TINYINT      NOT NULL,
    cabin_code          CHAR(1)      NOT NULL,   -- F, J, W, Y
    cabin_name          VARCHAR(20)  NOT NULL,   -- 'FIRST','BUSINESS','PREMIUM_ECONOMY','ECONOMY'
    service_level       TINYINT      NOT NULL,   -- 1=highest, 4=lowest
    avg_fare_multiplier FLOAT,                   -- Relative to economy
    CONSTRAINT pk_dim_cabin PRIMARY KEY (cabin_class_key)
)
COMMENT = 'Cabin class reference dimension';

-- Insert static cabin class data
INSERT INTO DIM_CABIN_CLASS VALUES 
    (1, 'F', 'FIRST', 1, 5.2),
    (2, 'J', 'BUSINESS', 2, 3.1),
    (3, 'W', 'PREMIUM_ECONOMY', 3, 1.6),
    (4, 'Y', 'ECONOMY', 4, 1.0);
