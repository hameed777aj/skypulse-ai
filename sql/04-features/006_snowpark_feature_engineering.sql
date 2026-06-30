-- ============================================================================
-- SKYPULSE AI — Feature Showcase: Snowpark Python
-- ============================================================================
-- Demonstrates Snowpark for Python-based feature engineering and
-- data transformation running natively inside Snowflake.
-- ============================================================================

USE DATABASE SKYPULSE_AI;
USE SCHEMA ML;
USE WAREHOUSE SKYPULSE_ML_WH;

-- =============================================================================
-- 1. PYTHON UDF — Flight delay risk scoring function
-- =============================================================================

CREATE OR REPLACE FUNCTION CALCULATE_DELAY_RISK(
    historical_otp_pct FLOAT,
    weather_severity VARCHAR,
    time_of_day INTEGER,
    day_of_week INTEGER,
    airport_congestion_level VARCHAR,
    aircraft_age_years FLOAT
)
RETURNS FLOAT
LANGUAGE PYTHON
RUNTIME_VERSION = '3.11'
HANDLER = 'calculate_risk'
AS
$$
def calculate_risk(historical_otp_pct, weather_severity, time_of_day, 
                   day_of_week, airport_congestion_level, aircraft_age_years):
    """
    Calculate a flight delay risk score (0-100) based on multiple factors.
    Higher score = higher risk of delay.
    """
    risk_score = 0.0
    
    # Factor 1: Historical route performance (weight: 30%)
    if historical_otp_pct is not None:
        route_risk = max(0, (100 - historical_otp_pct)) * 0.3
        risk_score += route_risk
    
    # Factor 2: Weather severity (weight: 25%)
    weather_risk_map = {
        'NONE': 0, 'MILD': 5, 'MODERATE': 15, 'SEVERE': 25
    }
    risk_score += weather_risk_map.get(weather_severity, 0)
    
    # Factor 3: Time of day - peak hours higher risk (weight: 15%)
    if time_of_day is not None:
        if 7 <= time_of_day <= 9 or 17 <= time_of_day <= 19:
            risk_score += 12  # Peak hours
        elif 21 <= time_of_day or time_of_day <= 5:
            risk_score += 3   # Off-peak
        else:
            risk_score += 7   # Standard
    
    # Factor 4: Day of week (weight: 10%)
    if day_of_week is not None:
        if day_of_week in (1, 5):  # Monday, Friday - business travel peaks
            risk_score += 8
        elif day_of_week in (6, 7):  # Weekend
            risk_score += 4
        else:
            risk_score += 6
    
    # Factor 5: Airport congestion (weight: 10%)
    congestion_risk_map = {
        'LOW': 2, 'MEDIUM': 6, 'HIGH': 10
    }
    risk_score += congestion_risk_map.get(airport_congestion_level, 5)
    
    # Factor 6: Aircraft age (weight: 10%)
    if aircraft_age_years is not None:
        age_risk = min(10, aircraft_age_years * 1.5)
        risk_score += age_risk
    
    return min(100.0, max(0.0, round(risk_score, 2)))
$$;

-- Test the UDF
SELECT 
    CALCULATE_DELAY_RISK(85.0, 'MODERATE', 8, 1, 'HIGH', 4.5) AS high_risk_scenario,
    CALCULATE_DELAY_RISK(95.0, 'NONE', 14, 3, 'LOW', 2.0) AS low_risk_scenario,
    CALCULATE_DELAY_RISK(72.0, 'SEVERE', 18, 5, 'HIGH', 6.0) AS extreme_risk_scenario;

-- =============================================================================
-- 2. PYTHON UDTF — Feature engineering for ML model
-- =============================================================================

CREATE OR REPLACE FUNCTION GENERATE_PASSENGER_FEATURES(
    passenger_key INTEGER,
    loyalty_tier VARCHAR,
    lifetime_miles BIGINT,
    ytd_miles INTEGER,
    ytd_segments INTEGER,
    days_since_last_booking INTEGER,
    avg_sentiment FLOAT,
    negative_feedback_count INTEGER,
    major_delays_experienced INTEGER,
    bookings_last_90d INTEGER,
    revenue_last_90d FLOAT
)
RETURNS TABLE (
    feature_name VARCHAR,
    feature_value FLOAT
)
LANGUAGE PYTHON
RUNTIME_VERSION = '3.11'
HANDLER = 'FeatureGenerator'
AS
$$
class FeatureGenerator:
    def process(self, passenger_key, loyalty_tier, lifetime_miles, ytd_miles,
                ytd_segments, days_since_last_booking, avg_sentiment,
                negative_feedback_count, major_delays_experienced,
                bookings_last_90d, revenue_last_90d):
        
        # Tier encoding
        tier_map = {'BRONZE': 1, 'SILVER': 2, 'GOLD': 3, 'PLATINUM': 4, 'DIAMOND': 5}
        yield ('tier_encoded', float(tier_map.get(loyalty_tier, 0)))
        
        # Engagement score (0-100)
        engagement = min(100, (bookings_last_90d or 0) * 15 + 
                        (ytd_segments or 0) * 2)
        yield ('engagement_score', float(engagement))
        
        # Recency score (higher = more recent = better)
        recency = max(0, 100 - (days_since_last_booking or 180) * 0.5)
        yield ('recency_score', float(recency))
        
        # Monetary value score
        monetary = min(100, (revenue_last_90d or 0) / 50.0)
        yield ('monetary_score', float(monetary))
        
        # Satisfaction score (combining sentiment and delays)
        satisfaction = 50.0  # Baseline
        if avg_sentiment is not None:
            satisfaction += avg_sentiment * 30
        satisfaction -= (negative_feedback_count or 0) * 10
        satisfaction -= (major_delays_experienced or 0) * 8
        satisfaction = max(0, min(100, satisfaction))
        yield ('satisfaction_score', float(satisfaction))
        
        # Churn probability estimate (simplified logistic)
        churn_features = (
            (1 - recency/100) * 0.3 +
            (1 - engagement/100) * 0.25 +
            (1 - satisfaction/100) * 0.25 +
            (1 - monetary/100) * 0.2
        )
        yield ('churn_probability', float(min(1.0, max(0.0, churn_features))))
        
        # Customer lifetime value estimate (simplified)
        if lifetime_miles and ytd_miles:
            years_active = max(1, lifetime_miles / max(1, ytd_miles))
            clv = (revenue_last_90d or 0) * 4 * min(10, years_active)
            yield ('estimated_clv', float(clv))
        else:
            yield ('estimated_clv', 0.0)
$$;

-- =============================================================================
-- 3. STORED PROCEDURE — Build ML feature table using Snowpark
-- =============================================================================

CREATE OR REPLACE PROCEDURE BUILD_ML_FEATURES()
RETURNS VARCHAR
LANGUAGE PYTHON
RUNTIME_VERSION = '3.11'
PACKAGES = ('snowflake-snowpark-python')
HANDLER = 'build_features'
AS
$$
def build_features(session):
    """
    Build a feature table for ML model training by joining multiple data sources
    and computing derived features using Snowpark DataFrame API.
    """
    from snowflake.snowpark.functions import col, avg, count, sum as sum_, max as max_, \
        datediff, current_date, lit, when, coalesce
    
    # Load source tables
    passengers = session.table("SKYPULSE_AI.SILVER.DIM_PASSENGER").filter(col("IS_CURRENT") == True)
    bookings = session.table("SKYPULSE_AI.SILVER.FACT_BOOKING")
    flights = session.table("SKYPULSE_AI.SILVER.FACT_FLIGHT_EVENT")
    feedback = session.table("SKYPULSE_AI.SILVER.FACT_PASSENGER_FEEDBACK")
    dates = session.table("SKYPULSE_AI.SILVER.DIM_DATE")
    
    # Compute booking features (last 90 days)
    recent_bookings = bookings.join(
        dates, bookings["FLIGHT_DATE_KEY"] == dates["DATE_KEY"]
    ).filter(
        col("FULL_DATE") >= current_date() - 90
    ).group_by("PASSENGER_KEY").agg(
        count("BOOKING_KEY").alias("BOOKINGS_90D"),
        sum_("TOTAL_AMOUNT").alias("REVENUE_90D"),
        avg("TOTAL_AMOUNT").alias("AVG_BOOKING_VALUE"),
        sum_("ANCILLARY_REVENUE").alias("ANCILLARY_90D"),
        max_("FULL_DATE").alias("LAST_BOOKING_DATE")
    )
    
    # Compute flight experience features
    flight_experience = bookings.join(
        flights, bookings["FLIGHT_EVENT_KEY"] == flights["FLIGHT_EVENT_KEY"]
    ).join(
        dates, flights["FLIGHT_DATE_KEY"] == dates["DATE_KEY"]
    ).filter(
        col("FULL_DATE") >= current_date() - 180
    ).group_by(bookings["PASSENGER_KEY"]).agg(
        avg(flights["ARRIVAL_DELAY_MIN"]).alias("AVG_DELAY_EXPERIENCED"),
        count(when(flights["ARRIVAL_DELAY_MIN"] > 60, lit(1))).alias("MAJOR_DELAYS_180D"),
        avg(flights["LOAD_FACTOR_PCT"]).alias("AVG_LOAD_FACTOR")
    )
    
    # Compute feedback features
    feedback_features = feedback.filter(
        col("FEEDBACK_TIMESTAMP") >= current_date() - 180
    ).group_by("PASSENGER_KEY").agg(
        avg("SENTIMENT_SCORE").alias("AVG_SENTIMENT"),
        count(when(col("SENTIMENT_LABEL") == "NEGATIVE", lit(1))).alias("NEGATIVE_COUNT"),
        avg("NPS_SCORE").alias("AVG_NPS")
    )
    
    # Join all features together
    ml_features = passengers.select(
        col("PASSENGER_KEY"),
        col("PASSENGER_ID"),
        col("LOYALTY_TIER"),
        col("LIFETIME_MILES"),
        col("YTD_MILES"),
        col("YTD_SEGMENTS")
    ).join(
        recent_bookings, "PASSENGER_KEY", "left"
    ).join(
        flight_experience, "PASSENGER_KEY", "left"
    ).join(
        feedback_features, "PASSENGER_KEY", "left"
    )
    
    # Write to ML schema
    ml_features.write.mode("overwrite").save_as_table("SKYPULSE_AI.ML.PASSENGER_FEATURES")
    
    row_count = session.table("SKYPULSE_AI.ML.PASSENGER_FEATURES").count()
    return f"ML feature table built successfully with {row_count} rows"
$$;

-- Execute the feature engineering pipeline
-- CALL BUILD_ML_FEATURES();

-- =============================================================================
-- 4. Apply delay risk scoring across today's flights
-- =============================================================================

CREATE OR REPLACE VIEW SKYPULSE_AI.GOLD.V_FLIGHT_DELAY_RISK AS
SELECT
    fe.flight_number,
    fe.scheduled_departure,
    orig.iata_code AS origin,
    dest.iata_code AS destination,
    ac.aircraft_type,
    ac.aircraft_age_years,
    fe.load_factor_pct,
    w.weather_condition,
    w.severity AS weather_severity,
    CALCULATE_DELAY_RISK(
        -- Historical OTP for this route (simplified)
        (SELECT COUNT(CASE WHEN f2.arrival_delay_min <= 15 THEN 1 END) * 100.0 / NULLIF(COUNT(*), 0)
         FROM SKYPULSE_AI.SILVER.FACT_FLIGHT_EVENT f2
         WHERE f2.route_key = fe.route_key
           AND f2.flight_date_key >= TO_NUMBER(TO_CHAR(DATEADD('day', -30, CURRENT_DATE()), 'YYYYMMDD'))),
        w.severity,
        HOUR(fe.scheduled_departure),
        d.day_of_week,
        CASE WHEN orig.iata_code IN ('LHR','JFK') THEN 'HIGH'
             WHEN orig.iata_code IN ('CDG','FRA','AMS') THEN 'MEDIUM'
             ELSE 'LOW' END,
        ac.aircraft_age_years
    ) AS delay_risk_score,
    CASE 
        WHEN CALCULATE_DELAY_RISK(85, w.severity, HOUR(fe.scheduled_departure), d.day_of_week, 'HIGH', ac.aircraft_age_years) > 70 THEN 'HIGH'
        WHEN CALCULATE_DELAY_RISK(85, w.severity, HOUR(fe.scheduled_departure), d.day_of_week, 'HIGH', ac.aircraft_age_years) > 40 THEN 'MEDIUM'
        ELSE 'LOW'
    END AS risk_category
FROM SKYPULSE_AI.SILVER.FACT_FLIGHT_EVENT fe
JOIN SKYPULSE_AI.SILVER.DIM_DATE d ON fe.flight_date_key = d.date_key
JOIN SKYPULSE_AI.SILVER.DIM_AIRPORT orig ON fe.origin_airport_key = orig.airport_key
JOIN SKYPULSE_AI.SILVER.DIM_AIRPORT dest ON fe.dest_airport_key = dest.airport_key
JOIN SKYPULSE_AI.SILVER.DIM_AIRCRAFT ac ON fe.aircraft_key = ac.aircraft_key
LEFT JOIN SKYPULSE_AI.SILVER.DIM_WEATHER w ON orig.iata_code = w.airport_iata
    AND DATE_TRUNC('hour', fe.scheduled_departure) = DATE_TRUNC('hour', w.observation_time)
WHERE d.full_date = CURRENT_DATE()
  AND fe.flight_status = 'SCHEDULED';
