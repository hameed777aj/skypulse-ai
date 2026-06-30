-- ============================================================================
-- SKYPULSE AI — Sample Data: Passenger Dimension
-- ============================================================================
-- Generates 500 realistic passengers with diverse names and loyalty tiers.
-- ============================================================================

USE DATABASE SKYPULSE_AI;
USE SCHEMA SILVER;
USE WAREHOUSE SKYPULSE_TRANSFORM_WH;

-- =============================================================================
-- Generate 500 passengers with realistic distributions
-- =============================================================================

INSERT INTO DIM_PASSENGER (
    passenger_id, first_name, last_name, email, phone, date_of_birth,
    passport_country, gender, nationality, home_airport, preferred_language,
    loyalty_program, loyalty_tier, loyalty_join_date, lifetime_miles,
    ytd_miles, ytd_segments, meal_preference, seat_preference,
    communication_pref, effective_from, effective_to, is_current
)
WITH
-- Arrays for random name selection
name_arrays AS (
    SELECT
        ARRAY_CONSTRUCT('James','Oliver','William','Harry','George','Noah','Liam','Mohammed','Alexander','Daniel','Thomas','David','Chen','Raj','Yuki','Jack','Leo','Oscar','Arthur','Ethan') AS male_names,
        ARRAY_CONSTRUCT('Sophia','Olivia','Emma','Isabella','Amelia','Charlotte','Mia','Fatima','Priya','Sakura','Aisha','Elena','Hannah','Sarah','Grace','Emily','Jessica','Lucy','Chloe','Zara') AS female_names,
        ARRAY_CONSTRUCT('Smith','Johnson','Williams','Brown','Jones','Taylor','Wilson','Davies','Evans','Thomas','Roberts','Walker','Wright','Thompson','White','Hall','Allen','Martin','Clark','Lee','Khan','Patel','Singh','Kumar','Ahmed','Chen','Wang','Li','Zhang','Tanaka') AS last_names
),
-- Generate base passenger rows
passenger_gen AS (
    SELECT
        ROW_NUMBER() OVER (ORDER BY seq4()) AS rn,
        'SP' || LPAD(ROW_NUMBER() OVER (ORDER BY seq4())::VARCHAR, 7, '0') AS passenger_id,
        UNIFORM(0, 1, RANDOM()) AS gender_flag,
        UNIFORM(0, 19, RANDOM()) AS fname_idx,
        UNIFORM(0, 29, RANDOM()) AS lname_idx
    FROM TABLE(GENERATOR(ROWCOUNT => 500))
)
SELECT
    pg.passenger_id,
    CASE WHEN pg.gender_flag = 0
        THEN GET(na.male_names, pg.fname_idx)::VARCHAR
        ELSE GET(na.female_names, pg.fname_idx)::VARCHAR
    END AS first_name,
    GET(na.last_names, pg.lname_idx)::VARCHAR AS last_name,
    LOWER(COALESCE(
        CASE WHEN pg.gender_flag = 0 THEN GET(na.male_names, pg.fname_idx)::VARCHAR ELSE GET(na.female_names, pg.fname_idx)::VARCHAR END,
        'user'
    )) || '.' || LOWER(COALESCE(GET(na.last_names, pg.lname_idx)::VARCHAR, 'name')) || pg.rn || '@email.com' AS email,
    '+44' || LPAD(UNIFORM(7000000000, 7999999999, RANDOM())::VARCHAR, 10, '0') AS phone,
    DATEADD('day', -UNIFORM(6570, 25550, RANDOM()), CURRENT_DATE()) AS date_of_birth,
    CASE WHEN UNIFORM(1, 100, RANDOM()) <= 60 THEN 'GB'
         WHEN UNIFORM(1, 100, RANDOM()) <= 75 THEN 'US'
         WHEN UNIFORM(1, 100, RANDOM()) <= 85 THEN 'DE'
         WHEN UNIFORM(1, 100, RANDOM()) <= 92 THEN 'IN'
         WHEN UNIFORM(1, 100, RANDOM()) <= 96 THEN 'AE'
         ELSE 'JP'
    END AS passport_country,
    CASE WHEN pg.gender_flag = 0 THEN 'M' ELSE 'F' END AS gender,
    CASE WHEN UNIFORM(1, 100, RANDOM()) <= 60 THEN 'GB'
         WHEN UNIFORM(1, 100, RANDOM()) <= 75 THEN 'US'
         WHEN UNIFORM(1, 100, RANDOM()) <= 85 THEN 'DE'
         ELSE 'IN'
    END AS nationality,
    CASE WHEN UNIFORM(1, 100, RANDOM()) <= 45 THEN 'LHR'
         WHEN UNIFORM(1, 100, RANDOM()) <= 65 THEN 'LGW'
         WHEN UNIFORM(1, 100, RANDOM()) <= 80 THEN 'MAN'
         ELSE 'EDI'
    END AS home_airport,
    'EN' AS preferred_language,
    'SKYPULSE_REWARDS' AS loyalty_program,
    CASE WHEN UNIFORM(1, 100, RANDOM()) <= 3 THEN 'DIAMOND'
         WHEN UNIFORM(1, 100, RANDOM()) <= 12 THEN 'PLATINUM'
         WHEN UNIFORM(1, 100, RANDOM()) <= 28 THEN 'GOLD'
         WHEN UNIFORM(1, 100, RANDOM()) <= 55 THEN 'SILVER'
         ELSE 'BRONZE'
    END AS loyalty_tier,
    DATEADD('day', -UNIFORM(90, 2555, RANDOM()), CURRENT_DATE()) AS loyalty_join_date,
    UNIFORM(5000, 3000000, RANDOM()) AS lifetime_miles,
    UNIFORM(0, 120000, RANDOM()) AS ytd_miles,
    UNIFORM(0, 60, RANDOM()) AS ytd_segments,
    CASE WHEN UNIFORM(1, 100, RANDOM()) <= 70 THEN 'STANDARD'
         WHEN UNIFORM(1, 100, RANDOM()) <= 82 THEN 'VEGETARIAN'
         WHEN UNIFORM(1, 100, RANDOM()) <= 90 THEN 'HALAL'
         WHEN UNIFORM(1, 100, RANDOM()) <= 96 THEN 'VEGAN'
         ELSE 'KOSHER'
    END AS meal_preference,
    CASE WHEN UNIFORM(1, 3, RANDOM()) = 1 THEN 'WINDOW'
         WHEN UNIFORM(1, 3, RANDOM()) = 2 THEN 'AISLE'
         ELSE 'MIDDLE'
    END AS seat_preference,
    CASE WHEN UNIFORM(1, 3, RANDOM()) = 1 THEN 'EMAIL'
         WHEN UNIFORM(1, 3, RANDOM()) = 2 THEN 'SMS'
         ELSE 'PUSH'
    END AS communication_pref,
    CURRENT_TIMESTAMP() AS effective_from,
    '9999-12-31 23:59:59'::TIMESTAMP_NTZ AS effective_to,
    TRUE AS is_current
FROM passenger_gen pg
CROSS JOIN name_arrays na;

-- =============================================================================
-- Overwrite first 10 with curated "hero" passengers for demo stories
-- =============================================================================

UPDATE DIM_PASSENGER SET first_name='Victoria', last_name='Sterling', email='v.sterling@corpmail.co.uk', loyalty_tier='DIAMOND', lifetime_miles=4250000, ytd_miles=95000, ytd_segments=48 WHERE passenger_id = 'SP0000001';
UPDATE DIM_PASSENGER SET first_name='Marcus', last_name='Chen', email='m.chen@techcorp.com', loyalty_tier='PLATINUM', lifetime_miles=1850000, ytd_miles=72000, ytd_segments=36 WHERE passenger_id = 'SP0000002';
UPDATE DIM_PASSENGER SET first_name='Raj', last_name='Patel', email='raj.patel@business.in', loyalty_tier='GOLD', lifetime_miles=620000, ytd_miles=45000, ytd_segments=22, meal_preference='VEGETARIAN' WHERE passenger_id = 'SP0000003';
UPDATE DIM_PASSENGER SET first_name='Sophie', last_name='Williams', email='sophie.w@startup.io', loyalty_tier='SILVER', lifetime_miles=185000, ytd_miles=28000, ytd_segments=14, meal_preference='VEGAN' WHERE passenger_id = 'SP0000004';
UPDATE DIM_PASSENGER SET first_name='Ahmed', last_name='Khan', email='a.khan@consulting.ae', loyalty_tier='PLATINUM', lifetime_miles=2100000, ytd_miles=88000, ytd_segments=44, meal_preference='HALAL' WHERE passenger_id = 'SP0000005';
UPDATE DIM_PASSENGER SET first_name='Emma', last_name='OBrien', email='emma.obrien@law.ie', loyalty_tier='GOLD', lifetime_miles=410000, ytd_miles=35000, ytd_segments=18 WHERE passenger_id = 'SP0000006';
UPDATE DIM_PASSENGER SET first_name='Yuki', last_name='Tanaka', email='y.tanaka@jpbank.jp', loyalty_tier='GOLD', lifetime_miles=550000, ytd_miles=40000, ytd_segments=20 WHERE passenger_id = 'SP0000007';
UPDATE DIM_PASSENGER SET first_name='Thomas', last_name='Mueller', email='t.mueller@auto.de', loyalty_tier='SILVER', lifetime_miles=95000, ytd_miles=32000, ytd_segments=16 WHERE passenger_id = 'SP0000008';
UPDATE DIM_PASSENGER SET first_name='Priya', last_name='Kumar', email='priya.k@medtech.in', loyalty_tier='BRONZE', lifetime_miles=25000, ytd_miles=12000, ytd_segments=6, meal_preference='VEGETARIAN' WHERE passenger_id = 'SP0000009';
UPDATE DIM_PASSENGER SET first_name='Daniel', last_name='Santos', email='d.santos@energy.br', loyalty_tier='SILVER', lifetime_miles=145000, ytd_miles=22000, ytd_segments=11 WHERE passenger_id = 'SP0000010';

SELECT 'DIM_PASSENGER loaded: ' || COUNT(*) || ' rows' AS status FROM DIM_PASSENGER;
SELECT loyalty_tier, COUNT(*) AS cnt FROM DIM_PASSENGER WHERE is_current = TRUE GROUP BY loyalty_tier ORDER BY cnt DESC;
