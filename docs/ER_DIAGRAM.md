# SkyPulse AI — Entity Relationship Diagram

## Medallion Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                          SNOWFLAKE AI DATA CLOUD                                 │
├─────────────────────────────────────────────────────────────────────────────────┤
│                                                                                  │
│  ┌──────────────┐      ┌──────────────────┐      ┌────────────────────────┐    │
│  │    BRONZE    │      │      SILVER      │      │         GOLD           │    │
│  │  (Raw/Land) │ ───► │  (Star Schema)   │ ───► │  (Dynamic Tables/ML)   │    │
│  └──────────────┘      └──────────────────┘      └────────────────────────┘    │
│                                                                                  │
│  7 Raw Tables           9 Dims + 5 Facts          5 Dynamic Tables              │
│  VARIANT/JSON           Typed, Validated          Auto-Refreshing               │
│  Append-Only            SCD Type 2                Real-Time Aggregates           │
│  90-Day Retention       PII Tagged                ML Features                    │
│                                                                                  │
└─────────────────────────────────────────────────────────────────────────────────┘
```

---

## Silver Layer — Star Schema ER Diagram

```
                              ┌─────────────────┐
                              │    DIM_DATE      │
                              ├─────────────────┤
                              │ PK date_key     │
                              │    full_date    │
                              │    day_name     │
                              │    month_name   │
                              │    quarter      │
                              │    year         │
                              │    season       │
                              │    is_weekend   │
                              └────────┬────────┘
                                       │
           ┌───────────────────────────┼───────────────────────────┐
           │                           │                           │
           ▼                           ▼                           ▼
┌─────────────────┐         ┌─────────────────────────────────────────────────┐
│  DIM_AIRPORT    │         │              FACT_FLIGHT_EVENT                   │
├─────────────────┤         ├─────────────────────────────────────────────────┤
│ PK airport_key  │◄────────│ PK flight_event_key                             │
│    iata_code    │         │ FK flight_date_key ──────► DIM_DATE             │
│    airport_name │         │ FK origin_airport_key ───► DIM_AIRPORT          │
│    city         │         │ FK dest_airport_key ─────► DIM_AIRPORT          │
│    country      │         │ FK aircraft_key ─────────► DIM_AIRCRAFT         │
│    region       │         │ FK route_key ────────────► DIM_ROUTE            │
│    timezone     │         │    flight_number                                │
│    hub_type     │         │    scheduled_departure                          │
└─────────────────┘         │    actual_departure                             │
                            │    flight_status                                │
┌─────────────────┐         │    departure_delay_min                          │
│  DIM_AIRCRAFT   │         │    arrival_delay_min                            │
├─────────────────┤         │    pax_booked                                   │
│ PK aircraft_key │◄────────│    pax_flown                                    │
│    registration │         │    seat_capacity                                │
│    aircraft_type│         │    load_factor_pct                              │
│    manufacturer │         │    revenue_total                                │
│    seat_capacity│         │    fuel_consumed_kg                             │
│    is_widebody  │         └──────────────────┬──────────────────────────────┘
│    engine_type  │                            │
│    status       │                            │ 1:N
└─────────────────┘                            │
                                               ▼
┌─────────────────┐         ┌─────────────────────────────────────────────────┐
│  DIM_ROUTE      │         │              FACT_BOOKING                        │
├─────────────────┤         ├─────────────────────────────────────────────────┤
│ PK route_key    │◄────────│ PK booking_key                                  │
│    route_code   │         │ FK passenger_key ────────► DIM_PASSENGER         │
│    origin_iata  │         │ FK flight_event_key ─────► FACT_FLIGHT_EVENT     │
│    dest_iata    │         │ FK route_key ────────────► DIM_ROUTE             │
│    distance_km  │         │ FK flight_date_key ──────► DIM_DATE              │
│    route_type   │         │ FK cabin_class_key ──────► DIM_CABIN_CLASS       │
│    market_type  │         │ FK origin_airport_key ───► DIM_AIRPORT           │
│    is_seasonal  │         │ FK dest_airport_key ─────► DIM_AIRPORT           │
└─────────────────┘         │    booking_reference                             │
                            │    booking_channel                               │
┌─────────────────┐         │    booking_status                                │
│ DIM_CABIN_CLASS │         │    fare_amount                                   │
├─────────────────┤         │    total_amount                                  │
│ PK cabin_class_ │◄────────│    ancillary_revenue                             │
│    key          │         │    days_before_departure                         │
│    cabin_code   │         └─────────────────────────────────────────────────┘
│    cabin_name   │
│    service_level│
└─────────────────┘

┌─────────────────────┐     ┌─────────────────────────────────────────────────┐
│  DIM_PASSENGER      │     │              FACT_DELAY                           │
│  (SCD Type 2)       │     ├─────────────────────────────────────────────────┤
├─────────────────────┤     │ PK delay_key                                    │
│ PK passenger_key    │     │ FK flight_event_key ─────► FACT_FLIGHT_EVENT     │
│    passenger_id     │     │ FK flight_date_key ──────► DIM_DATE              │
│    first_name   [PII]     │ FK airport_key ──────────► DIM_AIRPORT           │
│    last_name    [PII]     │ FK delay_reason_key ─────► DIM_DELAY_REASON      │
│    email        [PII]     │    delay_minutes                                 │
│    phone        [PII]     │    delay_category                                │
│    date_of_birth[PII]     │    pax_affected                                  │
│    loyalty_tier      │     │    compensation_amount                           │
│    lifetime_miles    │     │    rebooking_cost                                │
│    ytd_miles         │     │    total_cost_impact                             │
│    effective_from    │     │    caused_missed_connections                     │
│    effective_to      │     └─────────────────────────────────────────────────┘
│    is_current        │
└──────────┬───────────┘    ┌─────────────────────────────────────────────────┐
           │                │          FACT_PASSENGER_FEEDBACK                  │
           │                ├─────────────────────────────────────────────────┤
           ├───────────────►│ PK feedback_key                                  │
           │                │ FK passenger_key ────────► DIM_PASSENGER          │
           │                │ FK flight_event_key ─────► FACT_FLIGHT_EVENT      │
           │                │ FK flight_date_key ──────► DIM_DATE               │
           │                │ FK route_key ────────────► DIM_ROUTE              │
           │                │    feedback_channel                               │
           │                │    feedback_text                                  │
           │                │    nps_score                                      │
           │                │    sentiment_score   [AI-generated]               │
           │                │    sentiment_label   [AI-generated]               │
           │                │    ai_summary        [AI-generated]               │
           │                └─────────────────────────────────────────────────┘
           │
           │                ┌─────────────────────────────────────────────────┐
           │                │          FACT_LOYALTY_ACTIVITY                    │
           │                ├─────────────────────────────────────────────────┤
           └───────────────►│ PK activity_key                                  │
                            │ FK passenger_key ────────► DIM_PASSENGER          │
                            │ FK activity_date_key ────► DIM_DATE               │
                            │    activity_type                                  │
                            │    miles_earned                                   │
                            │    miles_redeemed                                 │
                            │    monetary_value                                 │
                            └─────────────────────────────────────────────────┘

┌─────────────────────┐
│  DIM_DELAY_REASON   │
├─────────────────────┤     ┌─────────────────────────────────────────────────┐
│ PK delay_reason_key │     │              DIM_WEATHER                          │
│    iata_delay_code  │     ├─────────────────────────────────────────────────┤
│    delay_category   │     │ PK weather_key                                   │
│    delay_subcategory│     │    airport_iata                                  │
│    is_airline_fault │     │    observation_time                              │
│    is_controllable  │     │    temperature_c                                 │
└─────────────────────┘     │    wind_speed_kts                                │
                            │    visibility_km                                  │
                            │    weather_condition                              │
                            │    severity                                       │
                            │    is_deicing_required                            │
                            └─────────────────────────────────────────────────┘
```

---

## Gold Layer — Dynamic Tables & ML

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           GOLD LAYER                                          │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  ┌─────────────────────┐  ┌─────────────────────┐  ┌────────────────────┐  │
│  │  DT_FLIGHT_STATUS   │  │  DT_PASSENGER_RISK  │  │  DT_OPS_ANOMALY   │  │
│  │  (refreshes: 1 min) │  │  (refreshes: 1 hr)  │  │  (refreshes: 5m)  │  │
│  ├─────────────────────┤  ├─────────────────────┤  ├────────────────────┤  │
│  │ flight_number       │  │ passenger_id        │  │ flight_number      │  │
│  │ origin → destination│  │ loyalty_tier        │  │ anomaly_type       │  │
│  │ flight_status       │  │ churn_risk_level    │  │ severity           │  │
│  │ delay_severity      │  │ days_since_booking  │  │ departure_delay    │  │
│  │ load_factor_pct     │  │ avg_sentiment       │  │ detected_at        │  │
│  │ aircraft_type       │  │ revenue_last_90d    │  │                    │  │
│  └─────────────────────┘  └─────────────────────┘  └────────────────────┘  │
│                                                                              │
│  ┌─────────────────────┐  ┌─────────────────────┐  ┌────────────────────┐  │
│  │ DT_ROUTE_PERFORMANCE│  │    DT_DAILY_KPI     │  │    ALERT_LOG       │  │
│  │ (refreshes: 1 day)  │  │  (refreshes: 30m)   │  │  (task-generated)  │  │
│  ├─────────────────────┤  ├─────────────────────┤  ├────────────────────┤  │
│  │ route_code          │  │ total_flights       │  │ alert_type         │  │
│  │ otp_15min_pct       │  │ otp_pct             │  │ severity           │  │
│  │ avg_load_factor     │  │ avg_delay_min       │  │ flight_number      │  │
│  │ total_revenue       │  │ total_passengers    │  │ message            │  │
│  │ delay_costs         │  │ total_revenue       │  │ created_at         │  │
│  │ avg_sentiment       │  │ avg_nps             │  │                    │  │
│  └─────────────────────┘  └─────────────────────┘  └────────────────────┘  │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## ML Schema — Trained Models & Features

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           ML LAYER                                            │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  CORTEX ML MODELS (Trained)         CORTEX AI FUNCTIONS (Built-in)           │
│  ─────────────────────────          ─────────────────────────────            │
│  • DELAY_FORECAST_MODEL             • SNOWFLAKE.CORTEX.SENTIMENT()           │
│  • DEMAND_FORECAST_MODEL            • SNOWFLAKE.CORTEX.SUMMARIZE()           │
│  • REVENUE_FORECAST_MODEL           • SNOWFLAKE.CORTEX.COMPLETE()            │
│  • DELAY_ANOMALY_MODEL              • SNOWFLAKE.CORTEX.TRANSLATE()           │
│  • FUEL_ANOMALY_MODEL               • SNOWFLAKE.CORTEX.EXTRACT_ANSWER()     │
│  • CHURN_PREDICTION_MODEL                                                    │
│  • CANCELLATION_PREDICTION_MODEL    CUSTOM FUNCTIONS                         │
│                                     ─────────────────                        │
│  RESULT TABLES                      • CALCULATE_DELAY_RISK (Python UDF)      │
│  ─────────────────                  • GENERATE_PASSENGER_FEATURES (UDTF)     │
│  • DELAY_FORECAST_RESULTS           • BUILD_ML_FEATURES (Stored Proc)        │
│  • DEMAND_FORECAST_RESULTS          • OPS_CHATBOT (SQL UDF)                  │
│  • REVENUE_FORECAST_RESULTS                                                  │
│  • DELAY_ANOMALY_RESULTS                                                     │
│  • FUEL_ANOMALY_RESULTS                                                      │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## Data Flow Diagram

```
  EXTERNAL SOURCES                    SNOWFLAKE PROCESSING                    CONSUMERS
  ────────────────                    ─────────────────                    ──────────

  Flight OPS API  ──┐                ┌─────────┐   ┌──────────┐
  Booking System  ──┤  ──Streams──►  │ BRONZE  │──►│  SILVER  │──┐
  Passenger CRM   ──┤                │  (Raw)  │   │  (Star)  │  │     ┌──────────────┐
  Weather API     ──┤                └─────────┘   └──────────┘  ├────►│  Ops Team    │
  Feedback Forms  ──┤                                    │       │     │  (Dashboards)│
  IoT Sensors     ──┘                                    │       │     └──────────────┘
                                                         ▼       │
                                                   ┌──────────┐  │     ┌──────────────┐
                                    ┌─Tasks────►   │   GOLD   │──┼────►│  Executives  │
                                    │              │(Dynamic) │  │     │  (KPIs)      │
                                    │              └──────────┘  │     └──────────────┘
                                    │                    │       │
                                    │                    ▼       │     ┌──────────────┐
                              ┌──────────┐        ┌──────────┐  ├────►│  Data Science│
                              │  Cortex  │◄───────│    ML    │──┘     │  (Models)    │
                              │    AI    │        │ (Models) │        └──────────────┘
                              └──────────┘        └──────────┘
                                    │                                  ┌──────────────┐
                                    ▼                                  │  Partner     │
                              ┌──────────┐                        ┌──►│  Airports    │
                              │  Alerts  │──► Ops Notifications   │   │  (Shares)    │
                              └──────────┘                        │   └──────────────┘
                                                                  │
                              ┌──────────┐                        │
                              │  Shares  │────────────────────────┘
                              └──────────┘
```

---

## Mermaid Diagram (paste into mermaid.live for rendered view)

```mermaid
erDiagram
    DIM_DATE ||--o{ FACT_FLIGHT_EVENT : "flight_date_key"
    DIM_DATE ||--o{ FACT_BOOKING : "flight_date_key"
    DIM_DATE ||--o{ FACT_DELAY : "flight_date_key"
    DIM_DATE ||--o{ FACT_PASSENGER_FEEDBACK : "flight_date_key"
    DIM_DATE ||--o{ FACT_LOYALTY_ACTIVITY : "activity_date_key"
    
    DIM_AIRPORT ||--o{ FACT_FLIGHT_EVENT : "origin_airport_key"
    DIM_AIRPORT ||--o{ FACT_FLIGHT_EVENT : "dest_airport_key"
    DIM_AIRPORT ||--o{ FACT_DELAY : "airport_key"
    
    DIM_AIRCRAFT ||--o{ FACT_FLIGHT_EVENT : "aircraft_key"
    
    DIM_ROUTE ||--o{ FACT_FLIGHT_EVENT : "route_key"
    DIM_ROUTE ||--o{ FACT_BOOKING : "route_key"
    
    DIM_PASSENGER ||--o{ FACT_BOOKING : "passenger_key"
    DIM_PASSENGER ||--o{ FACT_PASSENGER_FEEDBACK : "passenger_key"
    DIM_PASSENGER ||--o{ FACT_LOYALTY_ACTIVITY : "passenger_key"
    
    DIM_CABIN_CLASS ||--o{ FACT_BOOKING : "cabin_class_key"
    
    DIM_DELAY_REASON ||--o{ FACT_DELAY : "delay_reason_key"
    
    FACT_FLIGHT_EVENT ||--o{ FACT_BOOKING : "flight_event_key"
    FACT_FLIGHT_EVENT ||--o{ FACT_DELAY : "flight_event_key"
    FACT_FLIGHT_EVENT ||--o{ FACT_PASSENGER_FEEDBACK : "flight_event_key"

    DIM_DATE {
        int date_key PK
        date full_date
        string day_name
        string month_name
        int quarter
        int year
        string season
    }
    
    DIM_AIRPORT {
        int airport_key PK
        string iata_code UK
        string airport_name
        string city
        string country
        string hub_type
    }
    
    DIM_AIRCRAFT {
        int aircraft_key PK
        string registration UK
        string aircraft_type
        string manufacturer
        int seat_capacity_total
        boolean is_widebody
    }
    
    DIM_PASSENGER {
        int passenger_key PK
        string passenger_id
        string first_name
        string last_name
        string loyalty_tier
        bigint lifetime_miles
        boolean is_current
    }
    
    DIM_ROUTE {
        int route_key PK
        string route_code UK
        string origin_iata
        string destination_iata
        int distance_km
        string route_type
    }
    
    FACT_FLIGHT_EVENT {
        bigint flight_event_key PK
        string flight_number
        int flight_date_key FK
        int origin_airport_key FK
        int dest_airport_key FK
        int aircraft_key FK
        int route_key FK
        string flight_status
        int departure_delay_min
        int pax_booked
        float load_factor_pct
        decimal revenue_total
    }
    
    FACT_BOOKING {
        bigint booking_key PK
        string booking_reference
        int passenger_key FK
        bigint flight_event_key FK
        string booking_channel
        string booking_status
        decimal total_amount
    }
    
    FACT_DELAY {
        bigint delay_key PK
        bigint flight_event_key FK
        int delay_reason_key FK
        int delay_minutes
        string delay_category
        decimal total_cost_impact
    }
    
    FACT_PASSENGER_FEEDBACK {
        bigint feedback_key PK
        int passenger_key FK
        string feedback_text
        float sentiment_score
        string sentiment_label
        int nps_score
    }
    
    FACT_LOYALTY_ACTIVITY {
        bigint activity_key PK
        int passenger_key FK
        string activity_type
        int miles_earned
        int miles_redeemed
    }
```
