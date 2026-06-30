-- ============================================================================
-- SKYPULSE AI — Sample Data: Delays, Feedback & Weather
-- ============================================================================
-- Generates delay events correlated with weather and feedback with
-- realistic sentiment for Cortex AI demonstration.
-- ============================================================================

USE DATABASE SKYPULSE_AI;
USE SCHEMA SILVER;
USE WAREHOUSE SKYPULSE_TRANSFORM_WH;

-- =============================================================================
-- FACT_DELAY — Generate delay events for delayed flights
-- =============================================================================

INSERT INTO FACT_DELAY (
    flight_event_key, flight_date_key, airport_key, delay_reason_key,
    delay_minutes, delay_category, pax_affected,
    compensation_amount, rebooking_cost, hotel_cost, meal_voucher_cost,
    total_cost_impact, caused_missed_connections, reactionary_delay_min
)
SELECT
    fe.flight_event_key,
    fe.flight_date_key,
    fe.origin_airport_key AS airport_key,
    -- Random delay reason (weighted)
    CASE 
        WHEN UNIFORM(1, 100, RANDOM()) <= 25 THEN (SELECT delay_reason_key FROM DIM_DELAY_REASON WHERE iata_delay_code = '61')  -- Reactionary
        WHEN UNIFORM(1, 100, RANDOM()) <= 45 THEN (SELECT delay_reason_key FROM DIM_DELAY_REASON WHERE iata_delay_code = '71')  -- Weather
        WHEN UNIFORM(1, 100, RANDOM()) <= 60 THEN (SELECT delay_reason_key FROM DIM_DELAY_REASON WHERE iata_delay_code = '81')  -- ATC
        WHEN UNIFORM(1, 100, RANDOM()) <= 75 THEN (SELECT delay_reason_key FROM DIM_DELAY_REASON WHERE iata_delay_code = '41')  -- Technical
        WHEN UNIFORM(1, 100, RANDOM()) <= 85 THEN (SELECT delay_reason_key FROM DIM_DELAY_REASON WHERE iata_delay_code = '33')  -- Airport
        WHEN UNIFORM(1, 100, RANDOM()) <= 92 THEN (SELECT delay_reason_key FROM DIM_DELAY_REASON WHERE iata_delay_code = '56')  -- Crew
        ELSE (SELECT delay_reason_key FROM DIM_DELAY_REASON WHERE iata_delay_code = '15')  -- Passenger
    END AS delay_reason_key,
    fe.departure_delay_min AS delay_minutes,
    -- Denormalized category
    CASE 
        WHEN UNIFORM(1, 100, RANDOM()) <= 25 THEN 'REACTIONARY'
        WHEN UNIFORM(1, 100, RANDOM()) <= 45 THEN 'WEATHER'
        WHEN UNIFORM(1, 100, RANDOM()) <= 60 THEN 'ATC'
        WHEN UNIFORM(1, 100, RANDOM()) <= 75 THEN 'TECHNICAL'
        WHEN UNIFORM(1, 100, RANDOM()) <= 85 THEN 'AIRPORT'
        WHEN UNIFORM(1, 100, RANDOM()) <= 92 THEN 'CREW'
        ELSE 'PASSENGER'
    END AS delay_category,
    fe.pax_flown AS pax_affected,
    -- EU261 compensation: >3hrs = EUR250-600 per pax (simplified)
    CASE WHEN fe.departure_delay_min >= 180 THEN fe.pax_flown * UNIFORM(250, 600, RANDOM()) ELSE 0 END AS compensation_amount,
    CASE WHEN fe.departure_delay_min >= 300 THEN UNIFORM(5, 20, RANDOM()) * UNIFORM(200, 500, RANDOM()) ELSE 0 END AS rebooking_cost,
    CASE WHEN fe.departure_delay_min >= 480 THEN UNIFORM(10, 50, RANDOM()) * UNIFORM(80, 200, RANDOM()) ELSE 0 END AS hotel_cost,
    CASE WHEN fe.departure_delay_min >= 120 THEN fe.pax_flown * UNIFORM(8, 15, RANDOM()) ELSE 0 END AS meal_voucher_cost,
    -- Total cost
    0 AS total_cost_impact,  -- Will be computed below
    CASE WHEN fe.departure_delay_min >= 60 THEN UNIFORM(0, 15, RANDOM()) ELSE 0 END AS caused_missed_connections,
    CASE WHEN fe.departure_delay_min >= 30 THEN ROUND(fe.departure_delay_min * UNIFORM(10, 50, RANDOM()) / 100.0) ELSE 0 END AS reactionary_delay_min
FROM FACT_FLIGHT_EVENT fe
WHERE fe.departure_delay_min > 15
  AND fe.flight_status != 'CANCELLED';

-- Update total cost
UPDATE FACT_DELAY 
SET total_cost_impact = compensation_amount + rebooking_cost + hotel_cost + meal_voucher_cost;


-- =============================================================================
-- FACT_PASSENGER_FEEDBACK — Realistic feedback with varied sentiment
-- This is the KEY TABLE for Cortex AI demonstration
-- =============================================================================

INSERT INTO FACT_PASSENGER_FEEDBACK (
    passenger_key, flight_event_key, flight_date_key, route_key,
    feedback_channel, feedback_timestamp, feedback_text, feedback_subject,
    nps_score, overall_rating, rating_boarding, rating_cabin_crew,
    rating_food, rating_entertainment, rating_seat_comfort, rating_punctuality, rating_value
)
-- Positive feedback (40%)
SELECT
    UNIFORM(1, 500, RANDOM()) AS passenger_key,
    fe.flight_event_key,
    fe.flight_date_key,
    fe.route_key,
    CASE WHEN UNIFORM(1, 4, RANDOM()) = 1 THEN 'NPS_SURVEY'
         WHEN UNIFORM(1, 4, RANDOM()) = 2 THEN 'IN_APP'
         WHEN UNIFORM(1, 4, RANDOM()) = 3 THEN 'EMAIL'
         ELSE 'SOCIAL_MEDIA'
    END AS feedback_channel,
    DATEADD('hour', UNIFORM(2, 48, RANDOM()), fe.actual_arrival) AS feedback_timestamp,
    -- Positive feedback text variants
    CASE UNIFORM(1, 10, RANDOM())
        WHEN 1 THEN 'Excellent flight experience! The crew were incredibly attentive and professional. Smooth boarding process and the food in business class was restaurant quality. Will definitely fly SkyPulse again.'
        WHEN 2 THEN 'Great service as always. Departed on time, landed early. The new A350 has fantastic entertainment and the seats are very comfortable for a long-haul flight. My go-to airline for London to Dubai.'
        WHEN 3 THEN 'Impressed with the efficiency of the whole journey. Check-in via the app was seamless, priority boarding worked perfectly, and the cabin crew remembered my name. This is why I stay loyal to SkyPulse.'
        WHEN 4 THEN 'Beautiful new aircraft, incredibly quiet cabin. The food has improved significantly - the chef''s menu was a real treat. WiFi worked well throughout the flight. 5 stars from me.'
        WHEN 5 THEN 'Travelled with my family and the crew were wonderful with the children. Extra snacks, colouring books, and even a cockpit visit. Made what could be a stressful journey truly enjoyable.'
        WHEN 6 THEN 'Best transatlantic service I''ve experienced. The flat-bed in business was comfortable enough for a proper sleep. Arrived refreshed and ready for meetings. Worth every penny of the upgrade.'
        WHEN 7 THEN 'Consistently reliable. 20 flights this year with SkyPulse and not a single significant delay. The app keeps me informed every step of the way. Loyalty programme benefits are genuinely useful.'
        WHEN 8 THEN 'The lounge at Heathrow was excellent - great food selection and shower facilities before my overnight flight. Boarding was organised and efficient. Crew were warm and welcoming.'
        WHEN 9 THEN 'Upgraded to premium economy and it was absolutely worth it. The extra legroom and better meal service made the 7-hour flight very comfortable. Will book PE directly next time.'
        ELSE 'Quick short-haul to Paris, everything ran like clockwork. Good coffee, friendly crew, on-time arrival. Exactly what you want for a business trip. No complaints at all.'
    END AS feedback_text,
    'Great experience' AS feedback_subject,
    UNIFORM(8, 10, RANDOM()) AS nps_score,
    UNIFORM(4, 5, RANDOM()) AS overall_rating,
    UNIFORM(4, 5, RANDOM()) AS rating_boarding,
    UNIFORM(4, 5, RANDOM()) AS rating_cabin_crew,
    UNIFORM(3, 5, RANDOM()) AS rating_food,
    UNIFORM(3, 5, RANDOM()) AS rating_entertainment,
    UNIFORM(4, 5, RANDOM()) AS rating_seat_comfort,
    UNIFORM(4, 5, RANDOM()) AS rating_punctuality,
    UNIFORM(3, 5, RANDOM()) AS rating_value
FROM FACT_FLIGHT_EVENT fe
WHERE fe.departure_delay_min <= 15
  AND fe.flight_status = 'LANDED'
  AND UNIFORM(1, 100, RANDOM()) <= 8  -- 8% of on-time flights get positive feedback
ORDER BY RANDOM()
LIMIT 200;


-- Negative feedback (30%) — from delayed flights
INSERT INTO FACT_PASSENGER_FEEDBACK (
    passenger_key, flight_event_key, flight_date_key, route_key,
    feedback_channel, feedback_timestamp, feedback_text, feedback_subject,
    nps_score, overall_rating, rating_boarding, rating_cabin_crew,
    rating_food, rating_entertainment, rating_seat_comfort, rating_punctuality, rating_value
)
SELECT
    UNIFORM(1, 500, RANDOM()) AS passenger_key,
    fe.flight_event_key,
    fe.flight_date_key,
    fe.route_key,
    CASE WHEN UNIFORM(1, 4, RANDOM()) = 1 THEN 'NPS_SURVEY'
         WHEN UNIFORM(1, 4, RANDOM()) = 2 THEN 'IN_APP'
         WHEN UNIFORM(1, 4, RANDOM()) = 3 THEN 'SOCIAL_MEDIA'
         ELSE 'EMAIL'
    END AS feedback_channel,
    DATEADD('hour', UNIFORM(1, 24, RANDOM()), fe.actual_arrival) AS feedback_timestamp,
    -- Negative feedback text variants
    CASE UNIFORM(1, 10, RANDOM())
        WHEN 1 THEN 'Absolutely disgraceful. Flight delayed 3 hours with no explanation. Sat on the tarmac for 45 minutes before being told we had to go back to the gate. Missed my connection and no one at the desk could help. Had to book a hotel myself. Never again.'
        WHEN 2 THEN 'Terrible experience. Delayed by 2 hours, then the entertainment system didn''t work. Asked for a blanket three times and was ignored. The food was cold and inedible. For the price of this ticket, I expected much better. Very disappointed.'
        WHEN 3 THEN 'This is the third time in a row my flight has been significantly delayed. I''m a Gold member and I feel completely ignored. No proactive communication, no compensation, and the app showed incorrect information throughout. Considering switching to competitors.'
        WHEN 4 THEN 'Flight cancelled with 2 hours notice. Rebooked on a flight 8 hours later in a middle seat despite being a Platinum member with a business class ticket. No lounge access offered, no meal voucher for 3 hours. Customer service line had 90 minute wait. Shameful.'
        WHEN 5 THEN 'Delayed flight meant I missed my daughter''s school play. No weather issues, no ATC issues - just poor operational planning. The crew were apologetic but powerless. The airline needs to take responsibility for consistent underperformance on this route.'
        WHEN 6 THEN 'Baggage lost for the fourth time this year. Filed a claim and was told 5-7 days. It''s now been 3 weeks and I''m still chasing. The tracking system shows nothing useful. Had to buy clothes for a business conference. Compensation offered was insulting.'
        WHEN 7 THEN 'The rebooking process after our cancellation was chaotic. Staff at the airport were overwhelmed and clearly under-resourced. Waited 2 hours in line only to be told to call customer service. Called and waited another hour. This is not acceptable for a premium airline.'
        WHEN 8 THEN 'Paid extra for premium economy and the seat was broken - wouldn''t recline at all. Crew said they''d note it but offered no compensation or alternative. 11-hour flight in an upright position I''d paid a premium to avoid. Want a full refund of the upgrade cost.'
        WHEN 9 THEN 'WiFi didn''t work for the entire flight despite being advertised. Needed to join a critical video call. Crew had no solution. Asked for a refund of the WiFi purchase and was told to email customer service. Still waiting after 2 weeks for a response.'
        ELSE 'Boarded on time but then sat on the runway for 2 hours. No updates from the captain for the first hour. Children were getting restless, no extra water offered until passengers started complaining. Eventually took off but arrived exhausted and frustrated.'
    END AS feedback_text,
    CASE UNIFORM(1, 5, RANDOM())
        WHEN 1 THEN 'Unacceptable delay'
        WHEN 2 THEN 'Flight cancellation complaint'
        WHEN 3 THEN 'Poor service recovery'
        WHEN 4 THEN 'Lost baggage - URGENT'
        ELSE 'Disappointed loyal customer'
    END AS feedback_subject,
    UNIFORM(0, 4, RANDOM()) AS nps_score,
    UNIFORM(1, 2, RANDOM()) AS overall_rating,
    UNIFORM(1, 3, RANDOM()) AS rating_boarding,
    UNIFORM(2, 4, RANDOM()) AS rating_cabin_crew,
    UNIFORM(1, 3, RANDOM()) AS rating_food,
    UNIFORM(1, 3, RANDOM()) AS rating_entertainment,
    UNIFORM(2, 3, RANDOM()) AS rating_seat_comfort,
    UNIFORM(1, 1, RANDOM()) AS rating_punctuality,
    UNIFORM(1, 2, RANDOM()) AS rating_value
FROM FACT_FLIGHT_EVENT fe
WHERE fe.departure_delay_min > 60
  AND fe.flight_status = 'LANDED'
  AND UNIFORM(1, 100, RANDOM()) <= 25  -- 25% of significantly delayed flights get negative feedback
ORDER BY RANDOM()
LIMIT 150;


-- Neutral/mixed feedback (30%)
INSERT INTO FACT_PASSENGER_FEEDBACK (
    passenger_key, flight_event_key, flight_date_key, route_key,
    feedback_channel, feedback_timestamp, feedback_text, feedback_subject,
    nps_score, overall_rating, rating_boarding, rating_cabin_crew,
    rating_food, rating_entertainment, rating_seat_comfort, rating_punctuality, rating_value
)
SELECT
    UNIFORM(1, 500, RANDOM()) AS passenger_key,
    fe.flight_event_key,
    fe.flight_date_key,
    fe.route_key,
    CASE WHEN UNIFORM(1, 3, RANDOM()) = 1 THEN 'NPS_SURVEY'
         WHEN UNIFORM(1, 3, RANDOM()) = 2 THEN 'IN_APP'
         ELSE 'EMAIL'
    END AS feedback_channel,
    DATEADD('hour', UNIFORM(4, 72, RANDOM()), fe.actual_arrival) AS feedback_timestamp,
    CASE UNIFORM(1, 8, RANDOM())
        WHEN 1 THEN 'Flight was okay overall. Slight delay of 30 minutes which wasn''t ideal but they communicated well. Food was average, nothing special. Crew were polite. It got me there safely which is the main thing.'
        WHEN 2 THEN 'Mixed feelings about this flight. The check-in and boarding were smooth, but the aircraft felt dated compared to what I''ve seen on other airlines. Seat pitch was tight for a 5-hour flight. Crew were friendly though.'
        WHEN 3 THEN 'Decent service for the price. No frills but no major issues either. Would have appreciated better food options and more legroom. The entertainment selection was limited but manageable for a short flight.'
        WHEN 4 THEN 'Average experience. Got a minor delay which meant a rush at the connection, but made it. Wish the app had better real-time updates. Crew were professional but not particularly warm. Fine for occasional travel.'
        WHEN 5 THEN 'The outbound flight was excellent - on time, great crew, good food. The return was disappointing - 45 min delay, cold food, and the IFE screen had dead pixels. Inconsistency is frustrating when you''re a loyal customer.'
        WHEN 6 THEN 'Reasonably priced ticket and acceptable service. Nothing to write home about but nothing terrible either. Airport lounge was crowded for the tier I''m in. Would consider other options if prices are similar next time.'
        WHEN 7 THEN 'Fine for a short hop to Amsterdam. Quick turnaround, on-time departure. No food service on a 75-minute flight is understandable but a free coffee would be nice given the ticket price. Crew efficient if a bit rushed.'
        ELSE 'Standard service, met expectations but didn''t exceed them. The new seats are more comfortable than the old ones. WiFi was patchy - worked on and off. Arrived on time which is what matters most for business travel.'
    END AS feedback_text,
    'Flight feedback' AS feedback_subject,
    UNIFORM(5, 7, RANDOM()) AS nps_score,
    3 AS overall_rating,
    UNIFORM(3, 4, RANDOM()) AS rating_boarding,
    UNIFORM(3, 4, RANDOM()) AS rating_cabin_crew,
    UNIFORM(2, 4, RANDOM()) AS rating_food,
    UNIFORM(2, 4, RANDOM()) AS rating_entertainment,
    UNIFORM(3, 4, RANDOM()) AS rating_seat_comfort,
    UNIFORM(3, 4, RANDOM()) AS rating_punctuality,
    UNIFORM(3, 4, RANDOM()) AS rating_value
FROM FACT_FLIGHT_EVENT fe
WHERE fe.departure_delay_min BETWEEN 0 AND 60
  AND fe.flight_status = 'LANDED'
  AND UNIFORM(1, 100, RANDOM()) <= 5
ORDER BY RANDOM()
LIMIT 150;

-- =============================================================================
-- DIM_WEATHER — Generate weather for hub airports (last 90 days)
-- =============================================================================

INSERT INTO DIM_WEATHER (
    airport_iata, observation_time, temperature_c, feels_like_c,
    humidity_pct, wind_speed_kts, wind_gust_kts, wind_direction_deg,
    visibility_km, pressure_hpa, precipitation_mm, snow_depth_cm,
    cloud_cover_pct, weather_condition, severity, is_vfr, is_deicing_required
)
WITH weather_gen AS (
    SELECT
        a.iata_code,
        DATEADD('hour', seq4(), DATEADD('day', -90, CURRENT_DATE())::TIMESTAMP_NTZ) AS obs_time
    FROM DIM_AIRPORT a
    CROSS JOIN TABLE(GENERATOR(ROWCOUNT => 2160))  -- 90 days * 24 hours
    WHERE a.hub_type IN ('PRIMARY_HUB', 'SECONDARY_HUB', 'FOCUS_CITY')
)
SELECT
    wg.iata_code,
    wg.obs_time,
    -- Temperature varies by airport and season
    UNIFORM(-5, 28, RANDOM()) + 
        CASE WHEN wg.iata_code = 'DXB' THEN 20 
             WHEN wg.iata_code = 'SIN' THEN 18
             WHEN MONTH(wg.obs_time) IN (6,7,8) THEN 8 
             WHEN MONTH(wg.obs_time) IN (12,1,2) THEN -5 
             ELSE 0 END AS temperature_c,
    UNIFORM(-8, 25, RANDOM()) AS feels_like_c,
    UNIFORM(30, 95, RANDOM()) AS humidity_pct,
    UNIFORM(2, 35, RANDOM()) AS wind_speed_kts,
    CASE WHEN UNIFORM(1, 100, RANDOM()) <= 20 THEN UNIFORM(25, 55, RANDOM()) ELSE NULL END AS wind_gust_kts,
    UNIFORM(0, 359, RANDOM()) AS wind_direction_deg,
    UNIFORM(1, 30, RANDOM()) AS visibility_km,
    UNIFORM(990, 1035, RANDOM()) AS pressure_hpa,
    CASE WHEN UNIFORM(1, 100, RANDOM()) <= 30 THEN ROUND(UNIFORM(0, 15, RANDOM()) / 10.0, 1) ELSE 0 END AS precipitation_mm,
    CASE WHEN UNIFORM(1, 100, RANDOM()) <= 5 AND MONTH(wg.obs_time) IN (12,1,2) THEN UNIFORM(1, 20, RANDOM()) ELSE 0 END AS snow_depth_cm,
    UNIFORM(0, 100, RANDOM()) AS cloud_cover_pct,
    CASE WHEN UNIFORM(1, 100, RANDOM()) <= 40 THEN 'CLEAR'
         WHEN UNIFORM(1, 100, RANDOM()) <= 65 THEN 'CLOUDY'
         WHEN UNIFORM(1, 100, RANDOM()) <= 80 THEN 'RAIN'
         WHEN UNIFORM(1, 100, RANDOM()) <= 88 THEN 'FOG'
         WHEN UNIFORM(1, 100, RANDOM()) <= 94 THEN 'THUNDERSTORM'
         WHEN UNIFORM(1, 100, RANDOM()) <= 97 THEN 'SNOW'
         ELSE 'ICE'
    END AS weather_condition,
    CASE WHEN UNIFORM(1, 100, RANDOM()) <= 70 THEN 'NONE'
         WHEN UNIFORM(1, 100, RANDOM()) <= 88 THEN 'MILD'
         WHEN UNIFORM(1, 100, RANDOM()) <= 96 THEN 'MODERATE'
         ELSE 'SEVERE'
    END AS severity,
    CASE WHEN UNIFORM(1, 30, RANDOM()) > 5 THEN TRUE ELSE FALSE END AS is_vfr,
    CASE WHEN UNIFORM(-5, 28, RANDOM()) < 3 AND UNIFORM(1, 100, RANDOM()) <= 40 THEN TRUE ELSE FALSE END AS is_deicing_required
FROM weather_gen wg;

SELECT 'FACT_DELAY loaded: ' || COUNT(*) || ' rows' FROM FACT_DELAY;
SELECT 'FACT_PASSENGER_FEEDBACK loaded: ' || COUNT(*) || ' rows' FROM FACT_PASSENGER_FEEDBACK;
SELECT 'DIM_WEATHER loaded: ' || COUNT(*) || ' rows' FROM DIM_WEATHER;
SELECT 'Total delay cost impact: GBP ' || TO_CHAR(SUM(total_cost_impact), '999,999,999') FROM FACT_DELAY;
