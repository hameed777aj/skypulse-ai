-- ============================================================================
-- SKYPULSE AI — Sample Data: Date Dimension Generator
-- ============================================================================
-- Generates a complete date dimension from 2024-01-01 to 2026-12-31
-- Uses Snowflake's GENERATOR function — no external data needed.
-- ============================================================================

USE DATABASE SKYPULSE_AI;
USE SCHEMA SILVER;
USE WAREHOUSE SKYPULSE_TRANSFORM_WH;

-- Generate 3 years of dates (2024-2026)
INSERT INTO DIM_DATE
WITH date_series AS (
    SELECT
        DATEADD('day', seq4(), '2024-01-01'::DATE) AS gen_date
    FROM TABLE(GENERATOR(ROWCOUNT => 1096))  -- ~3 years
)
SELECT
    TO_NUMBER(TO_CHAR(gen_date, 'YYYYMMDD')) AS date_key,
    gen_date AS full_date,
    DAYOFWEEKISO(gen_date) AS day_of_week,
    DAYNAME(gen_date) AS day_name,
    DAY(gen_date) AS day_of_month,
    DAYOFYEAR(gen_date) AS day_of_year,
    WEEKOFYEAR(gen_date) AS week_of_year,
    WEEKISO(gen_date) AS iso_week,
    MONTH(gen_date) AS month_number,
    MONTHNAME(gen_date) AS month_name,
    QUARTER(gen_date) AS quarter,
    YEAR(gen_date) AS year,
    CASE WHEN DAYOFWEEKISO(gen_date) IN (6, 7) THEN TRUE ELSE FALSE END AS is_weekend,
    -- UK/EU bank holidays (simplified set)
    CASE WHEN (MONTH(gen_date) = 1 AND DAY(gen_date) = 1)      -- New Year
           OR (MONTH(gen_date) = 12 AND DAY(gen_date) = 25)     -- Christmas
           OR (MONTH(gen_date) = 12 AND DAY(gen_date) = 26)     -- Boxing Day
           OR (MONTH(gen_date) = 5 AND DAY(gen_date) BETWEEN 25 AND 31 AND DAYOFWEEKISO(gen_date) = 1)  -- Late May BH
         THEN TRUE ELSE FALSE END AS is_holiday,
    CASE WHEN (MONTH(gen_date) = 1 AND DAY(gen_date) = 1) THEN 'New Year''s Day'
         WHEN (MONTH(gen_date) = 12 AND DAY(gen_date) = 25) THEN 'Christmas Day'
         WHEN (MONTH(gen_date) = 12 AND DAY(gen_date) = 26) THEN 'Boxing Day'
         ELSE NULL END AS holiday_name,
    -- Fiscal year (April start for UK airline)
    CASE WHEN MONTH(gen_date) >= 4 THEN QUARTER(gen_date) - 1 ELSE QUARTER(gen_date) + 3 END AS fiscal_quarter,
    CASE WHEN MONTH(gen_date) >= 4 THEN YEAR(gen_date) ELSE YEAR(gen_date) - 1 END AS fiscal_year,
    -- Season
    CASE
        WHEN MONTH(gen_date) IN (12, 1, 2) THEN 'WINTER'
        WHEN MONTH(gen_date) IN (3, 4, 5) THEN 'SPRING'
        WHEN MONTH(gen_date) IN (6, 7, 8) THEN 'SUMMER'
        ELSE 'AUTUMN'
    END AS season
FROM date_series;

-- =============================================================================
-- TIME DIMENSION (every minute of the day)
-- =============================================================================

INSERT INTO DIM_TIME
WITH time_series AS (
    SELECT
        seq4() AS minute_of_day
    FROM TABLE(GENERATOR(ROWCOUNT => 1440))  -- 24 * 60 = 1440 minutes
)
SELECT
    (minute_of_day / 60) * 100 + MOD(minute_of_day, 60) AS time_key,  -- HHMM format
    TIME_FROM_PARTS(minute_of_day / 60, MOD(minute_of_day, 60), 0) AS full_time,
    minute_of_day / 60 AS hour_24,
    CASE WHEN minute_of_day / 60 = 0 THEN 12
         WHEN minute_of_day / 60 > 12 THEN minute_of_day / 60 - 12
         ELSE minute_of_day / 60 END AS hour_12,
    MOD(minute_of_day, 60) AS minute,
    CASE WHEN minute_of_day / 60 < 12 THEN 'AM' ELSE 'PM' END AS am_pm,
    CASE
        WHEN minute_of_day / 60 BETWEEN 0 AND 4 THEN 'RED_EYE'
        WHEN minute_of_day / 60 BETWEEN 5 AND 7 THEN 'EARLY_MORNING'
        WHEN minute_of_day / 60 BETWEEN 8 AND 11 THEN 'MORNING'
        WHEN minute_of_day / 60 BETWEEN 12 AND 13 THEN 'MIDDAY'
        WHEN minute_of_day / 60 BETWEEN 14 AND 16 THEN 'AFTERNOON'
        WHEN minute_of_day / 60 BETWEEN 17 AND 20 THEN 'EVENING'
        ELSE 'NIGHT'
    END AS time_band,
    CASE WHEN minute_of_day / 60 BETWEEN 7 AND 9 OR minute_of_day / 60 BETWEEN 17 AND 19 THEN TRUE ELSE FALSE END AS is_peak_hour
FROM time_series;

SELECT 'DIM_DATE loaded: ' || COUNT(*) || ' rows' FROM DIM_DATE;
SELECT 'DIM_TIME loaded: ' || COUNT(*) || ' rows' FROM DIM_TIME;
