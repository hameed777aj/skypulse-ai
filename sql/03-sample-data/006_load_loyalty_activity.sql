-- ============================================================================
-- SKYPULSE AI — Sample Data: Loyalty Activity
-- ============================================================================

USE DATABASE SKYPULSE_AI;
USE SCHEMA SILVER;
USE WAREHOUSE SKYPULSE_TRANSFORM_WH;

-- =============================================================================
-- FACT_LOYALTY_ACTIVITY — Miles earned from flights
-- =============================================================================

INSERT INTO FACT_LOYALTY_ACTIVITY (
    passenger_key, activity_date_key, activity_type, activity_source,
    miles_earned, miles_redeemed, miles_expired, qualifying_miles,
    balance_after, monetary_value
)
-- Earn miles from bookings
SELECT
    b.passenger_key,
    b.flight_date_key AS activity_date_key,
    'EARN_FLIGHT' AS activity_type,
    fe.flight_number AS activity_source,
    -- Miles based on distance and cabin class
    CASE b.cabin_class_key
        WHEN 1 THEN r.distance_nm * 3    -- First: 300%
        WHEN 2 THEN r.distance_nm * 2    -- Business: 200%
        WHEN 3 THEN ROUND(r.distance_nm * 1.5)  -- Premium Eco: 150%
        ELSE r.distance_nm               -- Economy: 100%
    END AS miles_earned,
    0 AS miles_redeemed,
    0 AS miles_expired,
    r.distance_nm AS qualifying_miles,
    NULL AS balance_after,  -- Would be computed with running total
    -- Approximate value: 1 mile = 0.01 GBP
    ROUND(r.distance_nm * 0.01, 2) AS monetary_value
FROM FACT_BOOKING b
JOIN FACT_FLIGHT_EVENT fe ON b.flight_event_key = fe.flight_event_key
JOIN DIM_ROUTE r ON b.route_key = r.route_key
WHERE b.booking_status = 'FLOWN'
  AND UNIFORM(1, 100, RANDOM()) <= 60;  -- Not all pax are loyalty members

-- Add some redemption activity
INSERT INTO FACT_LOYALTY_ACTIVITY (
    passenger_key, activity_date_key, activity_type, activity_source,
    miles_earned, miles_redeemed, miles_expired, qualifying_miles,
    balance_after, monetary_value
)
SELECT
    p.passenger_key,
    TO_NUMBER(TO_CHAR(DATEADD('day', -UNIFORM(1, 90, RANDOM()), CURRENT_DATE()), 'YYYYMMDD')) AS activity_date_key,
    CASE WHEN UNIFORM(1, 3, RANDOM()) = 1 THEN 'REDEEM_FLIGHT'
         WHEN UNIFORM(1, 3, RANDOM()) = 2 THEN 'REDEEM_UPGRADE'
         ELSE 'REDEEM_PARTNER'
    END AS activity_type,
    CASE WHEN UNIFORM(1, 3, RANDOM()) = 1 THEN 'Award Flight LHR-JFK'
         WHEN UNIFORM(1, 3, RANDOM()) = 2 THEN 'Cabin Upgrade'
         ELSE 'Partner Hotel Redemption'
    END AS activity_source,
    0 AS miles_earned,
    UNIFORM(10000, 150000, RANDOM()) AS miles_redeemed,
    0 AS miles_expired,
    0 AS qualifying_miles,
    NULL AS balance_after,
    ROUND(UNIFORM(10000, 150000, RANDOM()) * 0.01, 2) AS monetary_value
FROM DIM_PASSENGER p
WHERE p.is_current = TRUE
  AND p.loyalty_tier IN ('GOLD', 'PLATINUM', 'DIAMOND')
  AND UNIFORM(1, 100, RANDOM()) <= 30;

-- Add partner earn (credit cards, hotels)
INSERT INTO FACT_LOYALTY_ACTIVITY (
    passenger_key, activity_date_key, activity_type, activity_source,
    miles_earned, miles_redeemed, miles_expired, qualifying_miles,
    balance_after, monetary_value
)
SELECT
    p.passenger_key,
    TO_NUMBER(TO_CHAR(DATEADD('day', -UNIFORM(1, 90, RANDOM()), CURRENT_DATE()), 'YYYYMMDD')) AS activity_date_key,
    CASE WHEN UNIFORM(1, 2, RANDOM()) = 1 THEN 'EARN_CARD' ELSE 'EARN_PARTNER' END AS activity_type,
    CASE WHEN UNIFORM(1, 3, RANDOM()) = 1 THEN 'SkyPulse Amex Card'
         WHEN UNIFORM(1, 3, RANDOM()) = 2 THEN 'Marriott Partner'
         ELSE 'Hertz Car Rental'
    END AS activity_source,
    UNIFORM(500, 5000, RANDOM()) AS miles_earned,
    0 AS miles_redeemed,
    0 AS miles_expired,
    0 AS qualifying_miles,
    NULL AS balance_after,
    ROUND(UNIFORM(500, 5000, RANDOM()) * 0.01, 2) AS monetary_value
FROM DIM_PASSENGER p
WHERE p.is_current = TRUE
  AND UNIFORM(1, 100, RANDOM()) <= 40;

SELECT 'FACT_LOYALTY_ACTIVITY loaded: ' || COUNT(*) || ' rows' FROM FACT_LOYALTY_ACTIVITY;
SELECT activity_type, COUNT(*), SUM(miles_earned) AS total_earned, SUM(miles_redeemed) AS total_redeemed
FROM FACT_LOYALTY_ACTIVITY GROUP BY activity_type ORDER BY COUNT(*) DESC;
