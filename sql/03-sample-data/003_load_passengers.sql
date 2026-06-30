-- ============================================================================
-- SKYPULSE AI — Sample Data: Passenger Dimension
-- ============================================================================
-- 500 realistic passengers across loyalty tiers for demo purposes.
-- Uses Snowflake GENERATOR + UNIFORM/RANDOM for scalable generation.
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
-- First name pool
first_names AS (
    SELECT column1 AS fname, column2 AS gender FROM VALUES
    ('James','M'),('Oliver','M'),('William','M'),('Harry','M'),('George','M'),
    ('Noah','M'),('Liam','M'),('Mohammed','M'),('Alexander','M'),('Daniel','M'),
    ('Thomas','M'),('David','M'),('Chen','M'),('Raj','M'),('Yuki','M'),
    ('Sophia','F'),('Olivia','F'),('Emma','F'),('Isabella','F'),('Amelia','F'),
    ('Charlotte','F'),('Mia','F'),('Fatima','F'),('Priya','F'),('Sakura','F'),
    ('Aisha','F'),('Elena','F'),('Hannah','F'),('Sarah','F'),('Grace','F'),
    ('Jack','M'),('Leo','M'),('Oscar','M'),('Arthur','M'),('Ethan','M'),
    ('Emily','F'),('Jessica','F'),('Lucy','F'),('Chloe','F'),('Zara','F')
),
-- Last name pool
last_names AS (
    SELECT column1 AS lname FROM VALUES
    ('Smith'),('Johnson'),('Williams'),('Brown'),('Jones'),('Taylor'),('Wilson'),
    ('Davies'),('Evans'),('Thomas'),('Roberts'),('Walker'),('Wright'),('Thompson'),
    ('White'),('Hall'),('Allen'),('Martin'),('Clark'),('Lee'),('Khan'),('Patel'),
    ('Singh'),('Kumar'),('Ahmed'),('Chen'),('Wang'),('Li'),('Zhang'),('Tanaka'),
    ('Nakamura'),('Muller'),('Schmidt'),('Garcia'),('Rodriguez'),('Santos'),
    ('Fernandez'),('O''Brien'),('Murphy'),('McCarthy')
),
-- Generate base passengers
passenger_gen AS (
    SELECT
        ROW_NUMBER() OVER (ORDER BY seq4()) AS rn,
        'SP' || LPAD(ROW_NUMBER() OVER (ORDER BY seq4())::VARCHAR, 7, '0') AS passenger_id
    FROM TABLE(GENERATOR(ROWCOUNT => 500))
)
SELECT
    pg.passenger_id,
    fn.fname AS first_name,
    ln.lname AS last_name,
    LOWER(fn.fname) || '.' || LOWER(ln.lname) || pg.rn || '@email.com' AS email,
    '+44' || LPAD(UNIFORM(7000000000, 7999999999, RANDOM())::VARCHAR, 10, '0') AS phone,
    DATEADD('day', -UNIFORM(6570, 25550, RANDOM()), CURRENT_DATE()) AS date_of_birth,
    -- Passport country weighted toward UK
    CASE WHEN UNIFORM(1, 100, RANDOM()) <= 60 THEN 'GB'
         WHEN UNIFORM(1, 100, RANDOM()) <= 70 THEN 'US'
         WHEN UNIFORM(1, 100, RANDOM()) <= 78 THEN 'DE'
         WHEN UNIFORM(1, 100, RANDOM()) <= 84 THEN 'FR'
         WHEN UNIFORM(1, 100, RANDOM()) <= 89 THEN 'IN'
         WHEN UNIFORM(1, 100, RANDOM()) <= 93 THEN 'AE'
         WHEN UNIFORM(1, 100, RANDOM()) <= 96 THEN 'JP'
         ELSE 'SG'
    END AS passport_country,
    fn.gender,
    CASE WHEN UNIFORM(1, 100, RANDOM()) <= 60 THEN 'GB'
         WHEN UNIFORM(1, 100, RANDOM()) <= 70 THEN 'US'
         WHEN UNIFORM(1, 100, RANDOM()) <= 80 THEN 'DE'
         ELSE 'IN'
    END AS nationality,
    -- Home airport weighted to hubs
    CASE WHEN UNIFORM(1, 100, RANDOM()) <= 45 THEN 'LHR'
         WHEN UNIFORM(1, 100, RANDOM()) <= 65 THEN 'LGW'
         WHEN UNIFORM(1, 100, RANDOM()) <= 80 THEN 'MAN'
         ELSE 'EDI'
    END AS home_airport,
    'EN' AS preferred_language,
    'SKYPULSE_REWARDS' AS loyalty_program,
    -- Loyalty tier: pyramid distribution
    CASE WHEN UNIFORM(1, 100, RANDOM()) <= 3 THEN 'DIAMOND'
         WHEN UNIFORM(1, 100, RANDOM()) <= 10 THEN 'PLATINUM'
         WHEN UNIFORM(1, 100, RANDOM()) <= 25 THEN 'GOLD'
         WHEN UNIFORM(1, 100, RANDOM()) <= 50 THEN 'SILVER'
         ELSE 'BRONZE'
    END AS loyalty_tier,
    DATEADD('day', -UNIFORM(90, 2555, RANDOM()), CURRENT_DATE()) AS loyalty_join_date,
    -- Lifetime miles correlated with tier
    CASE WHEN UNIFORM(1, 100, RANDOM()) <= 3 THEN UNIFORM(2000000, 5000000, RANDOM())
         WHEN UNIFORM(1, 100, RANDOM()) <= 10 THEN UNIFORM(800000, 2000000, RANDOM())
         WHEN UNIFORM(1, 100, RANDOM()) <= 25 THEN UNIFORM(300000, 800000, RANDOM())
         WHEN UNIFORM(1, 100, RANDOM()) <= 50 THEN UNIFORM(100000, 300000, RANDOM())
         ELSE UNIFORM(5000, 100000, RANDOM())
    END AS lifetime_miles,
    UNIFORM(0, 120000, RANDOM()) AS ytd_miles,
    UNIFORM(0, 60, RANDOM()) AS ytd_segments,
    -- Meal preference
    CASE WHEN UNIFORM(1, 100, RANDOM()) <= 70 THEN 'STANDARD'
         WHEN UNIFORM(1, 100, RANDOM()) <= 82 THEN 'VEGETARIAN'
         WHEN UNIFORM(1, 100, RANDOM()) <= 88 THEN 'HALAL'
         WHEN UNIFORM(1, 100, RANDOM()) <= 94 THEN 'VEGAN'
         ELSE 'KOSHER'
    END AS meal_preference,
    CASE WHEN UNIFORM(1, 3, RANDOM()) = 1 THEN 'WINDOW'
         WHEN UNIFORM(1, 3, RANDOM()) = 2 THEN 'AISLE'
         ELSE 'MIDDLE'
    END AS seat_preference,
    CASE WHEN UNIFORM(1, 4, RANDOM()) = 1 THEN 'EMAIL'
         WHEN UNIFORM(1, 4, RANDOM()) = 2 THEN 'SMS'
         WHEN UNIFORM(1, 4, RANDOM()) = 3 THEN 'PUSH'
         ELSE 'EMAIL'
    END AS communication_pref,
    CURRENT_TIMESTAMP() AS effective_from,
    '9999-12-31 23:59:59'::TIMESTAMP_NTZ AS effective_to,
    TRUE AS is_current
FROM passenger_gen pg
CROSS JOIN (SELECT fname, gender FROM first_names ORDER BY RANDOM() LIMIT 1) fn
CROSS JOIN (SELECT lname FROM last_names ORDER BY RANDOM() LIMIT 1) ln;


-- =============================================================================
-- Alternative: Direct INSERT for a curated set of 50 "hero" passengers
-- These are named passengers that appear in demo stories
-- =============================================================================

-- Delete any generated passengers with IDs SP0000001-SP0000050 to replace with curated ones
DELETE FROM DIM_PASSENGER WHERE passenger_id IN (
    'SP0000001','SP0000002','SP0000003','SP0000004','SP0000005',
    'SP0000006','SP0000007','SP0000008','SP0000009','SP0000010'
);

INSERT INTO DIM_PASSENGER (passenger_id, first_name, last_name, email, phone, date_of_birth, passport_country, gender, nationality, home_airport, preferred_language, loyalty_program, loyalty_tier, loyalty_join_date, lifetime_miles, ytd_miles, ytd_segments, meal_preference, seat_preference, communication_pref, effective_from, effective_to, is_current)
VALUES
('SP0000001', 'Victoria', 'Sterling', 'v.sterling@corpmail.co.uk', '+447911234567', '1978-03-15', 'GB', 'F', 'GB', 'LHR', 'EN', 'SKYPULSE_REWARDS', 'DIAMOND', '2018-01-15', 4250000, 95000, 48, 'STANDARD', 'AISLE', 'EMAIL', CURRENT_TIMESTAMP(), '9999-12-31 23:59:59', TRUE),
('SP0000002', 'Marcus', 'Chen', 'm.chen@techcorp.com', '+447922345678', '1985-07-22', 'GB', 'M', 'GB', 'LHR', 'EN', 'SKYPULSE_REWARDS', 'PLATINUM', '2019-06-01', 1850000, 72000, 36, 'STANDARD', 'WINDOW', 'PUSH', CURRENT_TIMESTAMP(), '9999-12-31 23:59:59', TRUE),
('SP0000003', 'Raj', 'Patel', 'raj.patel@business.in', '+447933456789', '1972-11-08', 'GB', 'M', 'IN', 'LHR', 'EN', 'SKYPULSE_REWARDS', 'GOLD', '2020-03-20', 620000, 45000, 22, 'VEGETARIAN', 'AISLE', 'SMS', CURRENT_TIMESTAMP(), '9999-12-31 23:59:59', TRUE),
('SP0000004', 'Sophie', 'Williams', 'sophie.w@startup.io', '+447944567890', '1992-05-30', 'GB', 'F', 'GB', 'LGW', 'EN', 'SKYPULSE_REWARDS', 'SILVER', '2022-08-10', 185000, 28000, 14, 'VEGAN', 'WINDOW', 'EMAIL', CURRENT_TIMESTAMP(), '9999-12-31 23:59:59', TRUE),
('SP0000005', 'Ahmed', 'Khan', 'a.khan@consulting.ae', '+447955678901', '1980-09-12', 'AE', 'M', 'AE', 'LHR', 'EN', 'SKYPULSE_REWARDS', 'PLATINUM', '2019-01-05', 2100000, 88000, 44, 'HALAL', 'AISLE', 'PUSH', CURRENT_TIMESTAMP(), '9999-12-31 23:59:59', TRUE),
('SP0000006', 'Emma', 'O''Brien', 'emma.obrien@law.ie', '+447966789012', '1988-01-25', 'GB', 'F', 'GB', 'MAN', 'EN', 'SKYPULSE_REWARDS', 'GOLD', '2021-02-14', 410000, 35000, 18, 'STANDARD', 'WINDOW', 'EMAIL', CURRENT_TIMESTAMP(), '9999-12-31 23:59:59', TRUE),
('SP0000007', 'Yuki', 'Tanaka', 'y.tanaka@jpbank.jp', '+447977890123', '1990-04-18', 'JP', 'F', 'JP', 'LHR', 'EN', 'SKYPULSE_REWARDS', 'GOLD', '2020-09-30', 550000, 40000, 20, 'STANDARD', 'WINDOW', 'PUSH', CURRENT_TIMESTAMP(), '9999-12-31 23:59:59', TRUE),
('SP0000008', 'Thomas', 'Mueller', 't.mueller@auto.de', '+447988901234', '1975-12-03', 'DE', 'M', 'DE', 'LHR', 'EN', 'SKYPULSE_REWARDS', 'SILVER', '2023-01-20', 95000, 32000, 16, 'STANDARD', 'AISLE', 'EMAIL', CURRENT_TIMESTAMP(), '9999-12-31 23:59:59', TRUE),
('SP0000009', 'Priya', 'Kumar', 'priya.k@medtech.in', '+447999012345', '1995-08-07', 'IN', 'F', 'IN', 'LHR', 'EN', 'SKYPULSE_REWARDS', 'BRONZE', '2024-03-01', 25000, 12000, 6, 'VEGETARIAN', 'WINDOW', 'SMS', CURRENT_TIMESTAMP(), '9999-12-31 23:59:59', TRUE),
('SP0000010', 'Daniel', 'Santos', 'd.santos@energy.br', '+447900123456', '1983-06-19', 'BR', 'M', 'BR', 'LHR', 'EN', 'SKYPULSE_REWARDS', 'SILVER', '2022-11-15', 145000, 22000, 11, 'STANDARD', 'AISLE', 'EMAIL', CURRENT_TIMESTAMP(), '9999-12-31 23:59:59', TRUE);

SELECT 'DIM_PASSENGER loaded: ' || COUNT(*) || ' rows' FROM DIM_PASSENGER;
SELECT 'Tier distribution:' AS info;
SELECT loyalty_tier, COUNT(*) AS cnt FROM DIM_PASSENGER WHERE is_current = TRUE GROUP BY loyalty_tier ORDER BY cnt DESC;
