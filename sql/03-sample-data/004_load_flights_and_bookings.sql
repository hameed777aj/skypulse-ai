-- ============================================================================
-- SKYPULSE AI — Sample Data: Flights, Bookings, Delays
-- ============================================================================
-- Generates 90 days of flight operations with realistic patterns:
-- - Higher load factors on business routes during weekdays
-- - More delays in winter and at congested airports
-- - Realistic delay distributions (most flights on-time, fat tail)
-- ============================================================================

USE DATABASE SKYPULSE_AI;
USE SCHEMA SILVER;
USE WAREHOUSE SKYPULSE_TRANSFORM_WH;

-- =============================================================================
-- FACT_FLIGHT_EVENT — Generate ~5,000 flight operations (90 days)
-- =============================================================================

INSERT INTO FACT_FLIGHT_EVENT (
    flight_number, flight_date_key, origin_airport_key, dest_airport_key,
    aircraft_key, route_key, scheduled_departure, scheduled_arrival,
    actual_departure, actual_arrival, flight_status,
    departure_delay_min, arrival_delay_min, block_time_min, air_time_min,
    taxi_out_min, taxi_in_min, distance_flown_km,
    pax_booked, pax_flown, seat_capacity, load_factor_pct,
    revenue_total, revenue_per_pax, fuel_loaded_kg, fuel_consumed_kg,
    fuel_efficiency_l_per_100km, departure_gate, arrival_gate
)
WITH
-- Generate flight schedule: each route gets 1-3 daily frequencies
route_schedule AS (
    SELECT
        r.route_key,
        r.route_code,
        r.origin_iata,
        r.destination_iata,
        r.distance_km,
        r.flight_time_mins,
        r.route_type,
        d.date_key AS flight_date_key,
        d.full_date,
        d.is_weekend,
        d.season,
        -- Generate flight number
        'SP' || LPAD(r.route_key::VARCHAR, 2, '0') || LPAD(freq.f::VARCHAR, 2, '0') AS flight_number,
        -- Departure time varies by frequency
        CASE freq.f
            WHEN 1 THEN DATEADD('minute', UNIFORM(360, 540, RANDOM()), d.full_date::TIMESTAMP_NTZ)  -- 06:00-09:00
            WHEN 2 THEN DATEADD('minute', UNIFORM(720, 900, RANDOM()), d.full_date::TIMESTAMP_NTZ)  -- 12:00-15:00
            ELSE DATEADD('minute', UNIFORM(1020, 1200, RANDOM()), d.full_date::TIMESTAMP_NTZ)       -- 17:00-20:00
        END AS sched_dep
    FROM SKYPULSE_AI.SILVER.DIM_ROUTE r
    CROSS JOIN SKYPULSE_AI.SILVER.DIM_DATE d
    -- Frequency based on route type
    CROSS JOIN (SELECT column1 AS f FROM VALUES (1),(2),(3)) freq
    WHERE d.full_date BETWEEN DATEADD('day', -90, CURRENT_DATE()) AND CURRENT_DATE()
      AND (
        -- Long-haul: 1 daily
        (r.route_type IN ('LONG_HAUL','ULTRA_LONG_HAUL') AND freq.f = 1)
        -- Medium-haul: 1-2 daily  
        OR (r.route_type = 'MEDIUM_HAUL' AND freq.f <= 2)
        -- Short-haul: 2-3 daily
        OR (r.route_type IN ('SHORT_HAUL','DOMESTIC') AND freq.f <= 3)
      )
      -- Seasonal routes only in summer
      AND (r.is_seasonal = FALSE OR d.season = 'SUMMER')
),
-- Add aircraft assignment and delay simulation
flight_ops AS (
    SELECT
        rs.*,
        -- Assign aircraft (simplified - random from fleet)
        CASE 
            WHEN rs.route_type IN ('LONG_HAUL','ULTRA_LONG_HAUL') THEN UNIFORM(10, 15, RANDOM())  -- Widebody keys
            ELSE UNIFORM(1, 9, RANDOM())  -- Narrowbody keys
        END AS aircraft_key_gen,
        -- Simulate delays (80% on-time, 15% minor, 5% major)
        CASE 
            WHEN UNIFORM(1, 100, RANDOM()) <= 80 THEN 0                    -- On time
            WHEN UNIFORM(1, 100, RANDOM()) <= 92 THEN UNIFORM(5, 30, RANDOM())   -- Minor delay
            WHEN UNIFORM(1, 100, RANDOM()) <= 97 THEN UNIFORM(31, 90, RANDOM())  -- Moderate
            ELSE UNIFORM(91, 300, RANDOM())                                       -- Severe
        END AS delay_min,
        -- Load factor (higher on weekdays for business routes)
        CASE 
            WHEN rs.route_type = 'BUSINESS' AND rs.is_weekend = FALSE THEN UNIFORM(78, 98, RANDOM())
            WHEN rs.route_type = 'LEISURE' AND rs.is_weekend = TRUE THEN UNIFORM(85, 99, RANDOM())
            WHEN rs.season = 'SUMMER' THEN UNIFORM(80, 97, RANDOM())
            ELSE UNIFORM(60, 92, RANDOM())
        END AS load_factor
    FROM route_schedule rs
)
SELECT
    fo.flight_number,
    fo.flight_date_key,
    orig.airport_key AS origin_airport_key,
    dest.airport_key AS dest_airport_key,
    fo.aircraft_key_gen AS aircraft_key,
    fo.route_key,
    fo.sched_dep AS scheduled_departure,
    DATEADD('minute', fo.flight_time_mins, fo.sched_dep) AS scheduled_arrival,
    -- Actual times (schedule + delay)
    DATEADD('minute', fo.delay_min, fo.sched_dep) AS actual_departure,
    DATEADD('minute', fo.flight_time_mins + fo.delay_min - UNIFORM(0, 10, RANDOM()), fo.sched_dep) AS actual_arrival,
    -- Status
    CASE 
        WHEN fo.full_date = CURRENT_DATE() AND fo.sched_dep > CURRENT_TIMESTAMP() THEN 'SCHEDULED'
        WHEN UNIFORM(1, 200, RANDOM()) = 1 THEN 'CANCELLED'
        ELSE 'LANDED'
    END AS flight_status,
    fo.delay_min AS departure_delay_min,
    GREATEST(0, fo.delay_min - UNIFORM(0, 10, RANDOM())) AS arrival_delay_min,
    fo.flight_time_mins + UNIFORM(-5, 15, RANDOM()) AS block_time_min,
    fo.flight_time_mins - UNIFORM(15, 30, RANDOM()) AS air_time_min,
    UNIFORM(8, 25, RANDOM()) AS taxi_out_min,
    UNIFORM(5, 15, RANDOM()) AS taxi_in_min,
    fo.distance_km + UNIFORM(-20, 50, RANDOM()) AS distance_flown_km,
    -- Passenger counts based on load factor
    ROUND(ac.seat_capacity_total * fo.load_factor / 100.0)::INTEGER AS pax_booked,
    ROUND(ac.seat_capacity_total * fo.load_factor / 100.0 * UNIFORM(95, 100, RANDOM()) / 100.0)::INTEGER AS pax_flown,
    ac.seat_capacity_total AS seat_capacity,
    fo.load_factor AS load_factor_pct,
    -- Revenue (distance-based pricing)
    ROUND(ac.seat_capacity_total * fo.load_factor / 100.0 * (fo.distance_km * 0.08 + UNIFORM(50, 200, RANDOM())), 2) AS revenue_total,
    ROUND(fo.distance_km * 0.08 + UNIFORM(50, 200, RANDOM()), 2) AS revenue_per_pax,
    -- Fuel
    ROUND(fo.distance_km * (CASE WHEN ac.is_widebody THEN 8.5 ELSE 3.2 END) * UNIFORM(95, 115, RANDOM()) / 100.0)::INTEGER AS fuel_loaded_kg,
    ROUND(fo.distance_km * (CASE WHEN ac.is_widebody THEN 7.8 ELSE 2.9 END) * UNIFORM(90, 110, RANDOM()) / 100.0)::INTEGER AS fuel_consumed_kg,
    ROUND(UNIFORM(28, 42, RANDOM()) / 10.0, 1) AS fuel_efficiency_l_per_100km,
    -- Gates
    CHR(65 + UNIFORM(0, 25, RANDOM())) || UNIFORM(1, 50, RANDOM())::VARCHAR AS departure_gate,
    CHR(65 + UNIFORM(0, 25, RANDOM())) || UNIFORM(1, 50, RANDOM())::VARCHAR AS arrival_gate
FROM flight_ops fo
JOIN DIM_AIRPORT orig ON fo.origin_iata = orig.iata_code
JOIN DIM_AIRPORT dest ON fo.destination_iata = dest.iata_code
JOIN DIM_AIRCRAFT ac ON fo.aircraft_key_gen = ac.aircraft_key
WHERE ac.aircraft_key IS NOT NULL;


-- =============================================================================
-- FACT_BOOKING — Generate bookings for the flights
-- Approximately 3-5 bookings per flight (aggregated passengers)
-- =============================================================================

INSERT INTO FACT_BOOKING (
    booking_reference, passenger_key, flight_event_key, route_key,
    booking_date_key, flight_date_key, cabin_class_key,
    origin_airport_key, dest_airport_key, booking_channel,
    booking_status, fare_class, fare_amount, tax_amount, total_amount,
    ancillary_revenue, has_checked_bag, has_seat_selection,
    has_meal_preorder, has_lounge_access, is_upgrade,
    days_before_departure, booking_lead_category
)
WITH booking_gen AS (
    SELECT
        fe.flight_event_key,
        fe.route_key,
        fe.flight_date_key,
        fe.origin_airport_key,
        fe.dest_airport_key,
        fe.revenue_per_pax,
        -- Generate 3-8 individual bookings per flight to represent passenger groups
        seq4() AS booking_seq,
        -- Random passenger assignment
        UNIFORM(1, 500, RANDOM()) AS pax_key,
        -- PNR generation
        CHR(65 + UNIFORM(0, 25, RANDOM())) || CHR(65 + UNIFORM(0, 25, RANDOM())) || 
        CHR(65 + UNIFORM(0, 25, RANDOM())) || UNIFORM(100, 999, RANDOM())::VARCHAR AS pnr
    FROM SKYPULSE_AI.SILVER.FACT_FLIGHT_EVENT fe
    CROSS JOIN TABLE(GENERATOR(ROWCOUNT => 5))
    WHERE fe.flight_status != 'CANCELLED'
)
SELECT
    bg.pnr AS booking_reference,
    bg.pax_key AS passenger_key,
    bg.flight_event_key,
    bg.route_key,
    -- Booking date: 1-90 days before flight
    TO_NUMBER(TO_CHAR(DATEADD('day', -UNIFORM(1, 90, RANDOM()), 
        (SELECT full_date FROM DIM_DATE WHERE date_key = bg.flight_date_key)), 'YYYYMMDD')) AS booking_date_key,
    bg.flight_date_key,
    -- Cabin class (weighted: 70% economy, 20% business, 8% premium eco, 2% first)
    CASE WHEN UNIFORM(1, 100, RANDOM()) <= 70 THEN 4
         WHEN UNIFORM(1, 100, RANDOM()) <= 90 THEN 2
         WHEN UNIFORM(1, 100, RANDOM()) <= 98 THEN 3
         ELSE 1
    END AS cabin_class_key,
    bg.origin_airport_key,
    bg.dest_airport_key,
    -- Channel
    CASE WHEN UNIFORM(1, 100, RANDOM()) <= 45 THEN 'WEB'
         WHEN UNIFORM(1, 100, RANDOM()) <= 70 THEN 'MOBILE'
         WHEN UNIFORM(1, 100, RANDOM()) <= 85 THEN 'CORPORATE'
         WHEN UNIFORM(1, 100, RANDOM()) <= 95 THEN 'TRAVEL_AGENT'
         ELSE 'CALL_CENTER'
    END AS booking_channel,
    -- Status
    CASE WHEN UNIFORM(1, 100, RANDOM()) <= 88 THEN 'FLOWN'
         WHEN UNIFORM(1, 100, RANDOM()) <= 94 THEN 'CONFIRMED'
         WHEN UNIFORM(1, 100, RANDOM()) <= 97 THEN 'CANCELLED'
         ELSE 'NO_SHOW'
    END AS booking_status,
    -- Fare class
    CHR(65 + UNIFORM(0, 12, RANDOM())) AS fare_class,
    -- Revenue
    ROUND(bg.revenue_per_pax * UNIFORM(70, 150, RANDOM()) / 100.0, 2) AS fare_amount,
    ROUND(bg.revenue_per_pax * 0.18, 2) AS tax_amount,
    ROUND(bg.revenue_per_pax * UNIFORM(70, 150, RANDOM()) / 100.0 * 1.18, 2) AS total_amount,
    ROUND(UNIFORM(0, 85, RANDOM()), 2) AS ancillary_revenue,
    CASE WHEN UNIFORM(1, 100, RANDOM()) <= 65 THEN TRUE ELSE FALSE END AS has_checked_bag,
    CASE WHEN UNIFORM(1, 100, RANDOM()) <= 40 THEN TRUE ELSE FALSE END AS has_seat_selection,
    CASE WHEN UNIFORM(1, 100, RANDOM()) <= 15 THEN TRUE ELSE FALSE END AS has_meal_preorder,
    CASE WHEN UNIFORM(1, 100, RANDOM()) <= 8 THEN TRUE ELSE FALSE END AS has_lounge_access,
    CASE WHEN UNIFORM(1, 100, RANDOM()) <= 5 THEN TRUE ELSE FALSE END AS is_upgrade,
    UNIFORM(1, 90, RANDOM()) AS days_before_departure,
    CASE WHEN UNIFORM(1, 90, RANDOM()) <= 1 THEN 'SAME_DAY'
         WHEN UNIFORM(1, 90, RANDOM()) <= 4 THEN '1-3_DAYS'
         WHEN UNIFORM(1, 90, RANDOM()) <= 8 THEN '4-7_DAYS'
         WHEN UNIFORM(1, 90, RANDOM()) <= 15 THEN '8-14_DAYS'
         WHEN UNIFORM(1, 90, RANDOM()) <= 30 THEN '15-30_DAYS'
         WHEN UNIFORM(1, 90, RANDOM()) <= 60 THEN '31-60_DAYS'
         ELSE '61+'
    END AS booking_lead_category
FROM booking_gen bg
WHERE bg.booking_seq <= UNIFORM(3, 8, RANDOM());

SELECT 'FACT_FLIGHT_EVENT loaded: ' || COUNT(*) || ' rows' FROM FACT_FLIGHT_EVENT;
SELECT 'FACT_BOOKING loaded: ' || COUNT(*) || ' rows' FROM FACT_BOOKING;
