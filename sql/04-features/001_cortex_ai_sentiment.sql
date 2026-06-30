-- ============================================================================
-- SKYPULSE AI — Feature Showcase: Cortex AI (LLM Functions)
-- ============================================================================
-- Demonstrates Snowflake Cortex AI built-in LLM capabilities:
-- 1. SENTIMENT() — Analyze passenger feedback sentiment
-- 2. SUMMARIZE() — Auto-summarize lengthy complaints
-- 3. TRANSLATE() — Multi-language support
-- 4. COMPLETE() — Generate personalized responses
-- 5. EXTRACT_ANSWER() — Q&A over unstructured text
-- ============================================================================

USE DATABASE SKYPULSE_AI;
USE SCHEMA SILVER;
USE WAREHOUSE SKYPULSE_ML_WH;

-- =============================================================================
-- 1. SENTIMENT ANALYSIS — Score all feedback in batch
-- =============================================================================

-- Enrich feedback table with AI-generated sentiment scores
UPDATE FACT_PASSENGER_FEEDBACK
SET 
    sentiment_score = SNOWFLAKE.CORTEX.SENTIMENT(feedback_text),
    sentiment_label = CASE 
        WHEN SNOWFLAKE.CORTEX.SENTIMENT(feedback_text) > 0.3 THEN 'POSITIVE'
        WHEN SNOWFLAKE.CORTEX.SENTIMENT(feedback_text) < -0.3 THEN 'NEGATIVE'
        ELSE 'NEUTRAL'
    END,
    processed_at = CURRENT_TIMESTAMP()
WHERE feedback_text IS NOT NULL
  AND processed_at IS NULL;

-- View sentiment distribution
SELECT 
    sentiment_label,
    COUNT(*) AS feedback_count,
    ROUND(AVG(sentiment_score), 3) AS avg_score,
    ROUND(AVG(nps_score), 1) AS avg_nps,
    ROUND(AVG(overall_rating), 1) AS avg_rating
FROM FACT_PASSENGER_FEEDBACK
WHERE sentiment_label IS NOT NULL
GROUP BY sentiment_label
ORDER BY avg_score DESC;

-- =============================================================================
-- 2. SUMMARIZE — Auto-summarize negative feedback for ops team
-- =============================================================================

-- Create a view of critical feedback with AI summaries
CREATE OR REPLACE VIEW SKYPULSE_AI.GOLD.V_CRITICAL_FEEDBACK_SUMMARY AS
SELECT
    f.feedback_key,
    p.first_name || ' ' || p.last_name AS passenger_name,
    p.loyalty_tier,
    f.feedback_channel,
    f.feedback_timestamp,
    f.feedback_text,
    SNOWFLAKE.CORTEX.SUMMARIZE(f.feedback_text) AS ai_summary,
    f.sentiment_score,
    f.nps_score,
    fe.flight_number,
    fe.departure_delay_min,
    r.route_code
FROM SKYPULSE_AI.SILVER.FACT_PASSENGER_FEEDBACK f
LEFT JOIN SKYPULSE_AI.SILVER.DIM_PASSENGER p ON f.passenger_key = p.passenger_key AND p.is_current = TRUE
LEFT JOIN SKYPULSE_AI.SILVER.FACT_FLIGHT_EVENT fe ON f.flight_event_key = fe.flight_event_key
LEFT JOIN SKYPULSE_AI.SILVER.DIM_ROUTE r ON f.route_key = r.route_key
WHERE f.sentiment_score < -0.5
ORDER BY f.sentiment_score ASC;

-- Demo query: Show top 5 most critical feedback with AI summaries
SELECT * FROM SKYPULSE_AI.GOLD.V_CRITICAL_FEEDBACK_SUMMARY LIMIT 5;

-- =============================================================================
-- 3. COMPLETE — Generate personalized recovery responses
-- =============================================================================

-- Generate AI-powered customer response for a dissatisfied Diamond member
SELECT
    f.feedback_key,
    p.first_name,
    p.loyalty_tier,
    f.feedback_text,
    SNOWFLAKE.CORTEX.COMPLETE(
        'mistral-large2',
        'You are a customer service manager at SkyPulse Airways, a premium airline. ' ||
        'Write a personalized, empathetic response to this ' || p.loyalty_tier || ' loyalty member named ' || p.first_name || '. ' ||
        'Acknowledge their specific complaint, apologize sincerely, and offer a concrete resolution. ' ||
        'Keep the tone professional but warm. Maximum 150 words. ' ||
        'Customer feedback: ' || f.feedback_text
    ) AS ai_generated_response
FROM FACT_PASSENGER_FEEDBACK f
JOIN DIM_PASSENGER p ON f.passenger_key = p.passenger_key AND p.is_current = TRUE
WHERE f.sentiment_score < -0.6
  AND p.loyalty_tier IN ('DIAMOND', 'PLATINUM')
LIMIT 3;

-- =============================================================================
-- 4. EXTRACT_ANSWER — Structured extraction from unstructured feedback
-- =============================================================================

-- Extract specific issues mentioned in feedback
SELECT
    f.feedback_key,
    f.feedback_text,
    SNOWFLAKE.CORTEX.EXTRACT_ANSWER(
        f.feedback_text, 
        'What specific problem did the customer experience?'
    ) AS extracted_problem,
    SNOWFLAKE.CORTEX.EXTRACT_ANSWER(
        f.feedback_text, 
        'What compensation or resolution does the customer want?'
    ) AS desired_resolution,
    SNOWFLAKE.CORTEX.EXTRACT_ANSWER(
        f.feedback_text, 
        'How long was the delay or wait time mentioned?'
    ) AS delay_mentioned
FROM FACT_PASSENGER_FEEDBACK f
WHERE f.sentiment_score < -0.4
LIMIT 10;

-- =============================================================================
-- 5. TRANSLATE — Multi-language feedback processing
-- =============================================================================

-- Simulate: translate feedback for international ops team
SELECT
    f.feedback_key,
    f.feedback_text AS original_english,
    SNOWFLAKE.CORTEX.TRANSLATE(f.feedback_text, 'en', 'fr') AS french_translation,
    SNOWFLAKE.CORTEX.TRANSLATE(f.feedback_text, 'en', 'de') AS german_translation,
    SNOWFLAKE.CORTEX.TRANSLATE(f.feedback_text, 'en', 'ja') AS japanese_translation
FROM FACT_PASSENGER_FEEDBACK f
WHERE f.sentiment_label = 'POSITIVE'
LIMIT 3;

-- =============================================================================
-- 6. COMPLETE — Delay cause analysis report generation
-- =============================================================================

-- Generate an executive summary of today's delays using AI
WITH delay_summary AS (
    SELECT
        d.delay_category,
        COUNT(*) AS delay_count,
        AVG(d.delay_minutes) AS avg_minutes,
        SUM(d.total_cost_impact) AS total_cost,
        SUM(d.pax_affected) AS total_pax
    FROM FACT_DELAY d
    JOIN DIM_DATE dt ON d.flight_date_key = dt.date_key
    WHERE dt.full_date >= DATEADD('day', -7, CURRENT_DATE())
    GROUP BY d.delay_category
)
SELECT SNOWFLAKE.CORTEX.COMPLETE(
    'mistral-large2',
    'You are an airline operations analyst. Based on this delay data from the past 7 days, ' ||
    'write a concise executive briefing (max 200 words) highlighting key concerns and recommendations. ' ||
    'Data: ' || (
        SELECT LISTAGG(
            delay_category || ': ' || delay_count || ' delays, avg ' || ROUND(avg_minutes) || ' min, cost GBP' || ROUND(total_cost) || ', ' || total_pax || ' pax affected',
            '; '
        ) FROM delay_summary
    )
) AS executive_delay_briefing;
