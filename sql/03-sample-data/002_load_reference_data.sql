-- ============================================================================
-- SKYPULSE AI — Sample Data: Reference/Dimension Data
-- ============================================================================
-- Realistic airports, aircraft, routes, delay codes, and passengers
-- ============================================================================

USE DATABASE SKYPULSE_AI;
USE SCHEMA SILVER;
USE WAREHOUSE SKYPULSE_TRANSFORM_WH;

-- =============================================================================
-- DIM_AIRPORT — Major airports in SkyPulse network
-- =============================================================================

INSERT INTO DIM_AIRPORT (iata_code, icao_code, airport_name, city, country, country_code, region, latitude, longitude, elevation_ft, timezone, utc_offset, hub_type, runway_count, terminal_count, annual_capacity_m, is_active)
VALUES
('LHR', 'EGLL', 'London Heathrow', 'London', 'United Kingdom', 'GB', 'EU', 51.4700, -0.4543, 83, 'Europe/London', 0, 'PRIMARY_HUB', 2, 5, 80.0, TRUE),
('LGW', 'EGKK', 'London Gatwick', 'London', 'United Kingdom', 'GB', 'EU', 51.1481, -0.1903, 202, 'Europe/London', 0, 'SECONDARY_HUB', 2, 2, 46.0, TRUE),
('MAN', 'EGCC', 'Manchester Airport', 'Manchester', 'United Kingdom', 'GB', 'EU', 53.3537, -2.2750, 257, 'Europe/London', 0, 'FOCUS_CITY', 2, 3, 30.0, TRUE),
('EDI', 'EGPH', 'Edinburgh Airport', 'Edinburgh', 'United Kingdom', 'GB', 'EU', 55.9500, -3.3725, 135, 'Europe/London', 0, 'FOCUS_CITY', 1, 1, 14.7, TRUE),
('JFK', 'KJFK', 'John F Kennedy Intl', 'New York', 'United States', 'US', 'NA', 40.6399, -73.7787, 13, 'America/New_York', -5, 'OUTSTATION', 4, 6, 62.0, TRUE),
('LAX', 'KLAX', 'Los Angeles Intl', 'Los Angeles', 'United States', 'US', 'NA', 33.9425, -118.4081, 126, 'America/Los_Angeles', -8, 'OUTSTATION', 4, 9, 88.0, TRUE),
('DXB', 'OMDB', 'Dubai International', 'Dubai', 'United Arab Emirates', 'AE', 'MEA', 25.2528, 55.3644, 62, 'Asia/Dubai', 4, 'OUTSTATION', 2, 3, 89.0, TRUE),
('SIN', 'WSSS', 'Singapore Changi', 'Singapore', 'Singapore', 'SG', 'APAC', 1.3502, 103.9940, 22, 'Asia/Singapore', 8, 'OUTSTATION', 2, 4, 85.0, TRUE),
('CDG', 'LFPG', 'Paris Charles de Gaulle', 'Paris', 'France', 'FR', 'EU', 49.0097, 2.5478, 392, 'Europe/Paris', 1, 'OUTSTATION', 4, 3, 76.0, TRUE),
('FRA', 'EDDF', 'Frankfurt Airport', 'Frankfurt', 'Germany', 'DE', 'EU', 50.0333, 8.5706, 364, 'Europe/Berlin', 1, 'OUTSTATION', 4, 2, 70.0, TRUE);


-- Additional airports
INSERT INTO DIM_AIRPORT (iata_code, icao_code, airport_name, city, country, country_code, region, latitude, longitude, elevation_ft, timezone, utc_offset, hub_type, runway_count, terminal_count, annual_capacity_m, is_active)
VALUES
('AMS', 'EHAM', 'Amsterdam Schiphol', 'Amsterdam', 'Netherlands', 'NL', 'EU', 52.3086, 4.7639, -11, 'Europe/Amsterdam', 1, 'OUTSTATION', 6, 1, 71.0, TRUE),
('BCN', 'LEBL', 'Barcelona El Prat', 'Barcelona', 'Spain', 'ES', 'EU', 41.2971, 2.0785, 12, 'Europe/Madrid', 1, 'OUTSTATION', 3, 2, 52.0, TRUE),
('IST', 'LTFM', 'Istanbul Airport', 'Istanbul', 'Turkey', 'TR', 'EU', 41.2608, 28.7419, 325, 'Europe/Istanbul', 3, 'OUTSTATION', 5, 1, 90.0, TRUE),
('HND', 'RJTT', 'Tokyo Haneda', 'Tokyo', 'Japan', 'JP', 'APAC', 35.5494, 139.7798, 35, 'Asia/Tokyo', 9, 'OUTSTATION', 4, 3, 87.0, TRUE),
('BOM', 'VABB', 'Mumbai Chhatrapati Shivaji', 'Mumbai', 'India', 'IN', 'APAC', 19.0896, 72.8656, 37, 'Asia/Kolkata', 5.5, 'OUTSTATION', 2, 2, 50.0, TRUE),
('CPT', 'FACT', 'Cape Town International', 'Cape Town', 'South Africa', 'ZA', 'MEA', -33.9649, 18.6017, 151, 'Africa/Johannesburg', 2, 'OUTSTATION', 2, 1, 14.0, TRUE),
('GRU', 'SBGR', 'Sao Paulo Guarulhos', 'Sao Paulo', 'Brazil', 'BR', 'LATAM', -23.4356, -46.4731, 2459, 'America/Sao_Paulo', -3, 'OUTSTATION', 2, 3, 42.0, TRUE),
('SYD', 'YSSY', 'Sydney Kingsford Smith', 'Sydney', 'Australia', 'AU', 'APAC', -33.9461, 151.1772, 21, 'Australia/Sydney', 11, 'OUTSTATION', 3, 3, 44.0, TRUE),
('AGP', 'LEMG', 'Malaga Costa del Sol', 'Malaga', 'Spain', 'ES', 'EU', 36.6749, -4.4991, 53, 'Europe/Madrid', 1, 'OUTSTATION', 2, 1, 20.0, TRUE),
('PMI', 'LEPA', 'Palma de Mallorca', 'Palma', 'Spain', 'ES', 'EU', 39.5517, 2.7388, 27, 'Europe/Madrid', 1, 'OUTSTATION', 2, 1, 29.0, TRUE);

-- =============================================================================
-- DIM_AIRCRAFT — SkyPulse Fleet (30 aircraft)
-- =============================================================================

INSERT INTO DIM_AIRCRAFT (registration, aircraft_type, aircraft_family, manufacturer, model_variant, seat_capacity_total, seats_first, seats_business, seats_premium_eco, seats_economy, max_range_nm, delivery_date, aircraft_age_years, engine_type, engine_count, is_widebody, status, last_heavy_check, next_heavy_check)
VALUES
('G-SPAA', 'A320', 'A320neo Family', 'Airbus', 'A320-271N', 180, 0, 12, 0, 168, 3400, '2022-03-15', 4.3, 'CFM LEAP-1A', 2, FALSE, 'ACTIVE', '2025-06-01', '2026-12-01'),
('G-SPAB', 'A320', 'A320neo Family', 'Airbus', 'A320-271N', 180, 0, 12, 0, 168, 3400, '2022-06-20', 4.0, 'CFM LEAP-1A', 2, FALSE, 'ACTIVE', '2025-08-15', '2027-02-15'),
('G-SPAC', 'A320', 'A320neo Family', 'Airbus', 'A320-271N', 180, 0, 12, 0, 168, 3400, '2023-01-10', 3.5, 'CFM LEAP-1A', 2, FALSE, 'ACTIVE', '2025-11-01', '2027-05-01'),
('G-SPAD', 'A321', 'A320neo Family', 'Airbus', 'A321-271NX', 220, 0, 20, 0, 200, 4000, '2023-04-05', 3.2, 'CFM LEAP-1A', 2, FALSE, 'ACTIVE', '2026-01-15', '2027-07-15'),
('G-SPAE', 'A321', 'A320neo Family', 'Airbus', 'A321-271NX', 220, 0, 20, 0, 200, 4000, '2023-08-18', 2.9, 'CFM LEAP-1A', 2, FALSE, 'ACTIVE', '2026-03-01', '2027-09-01'),
('G-SPAF', 'A319', 'A320neo Family', 'Airbus', 'A319-171N', 140, 0, 8, 0, 132, 3400, '2021-11-22', 4.6, 'CFM LEAP-1A', 2, FALSE, 'ACTIVE', '2025-04-01', '2026-10-01'),
('G-SPBA', 'B738', '737 MAX Family', 'Boeing', '737 MAX 8', 189, 0, 16, 0, 173, 3550, '2022-09-01', 3.8, 'CFM LEAP-1B', 2, FALSE, 'ACTIVE', '2025-09-01', '2027-03-01'),
('G-SPBB', 'B738', '737 MAX Family', 'Boeing', '737 MAX 8', 189, 0, 16, 0, 173, 3550, '2023-02-14', 3.4, 'CFM LEAP-1B', 2, FALSE, 'ACTIVE', '2026-02-01', '2027-08-01'),
('G-SPBC', 'B739', '737 MAX Family', 'Boeing', '737 MAX 9', 210, 0, 16, 0, 194, 3550, '2024-01-20', 2.4, 'CFM LEAP-1B', 2, FALSE, 'ACTIVE', '2026-07-01', '2028-01-01'),
('G-SPCA', 'A350', 'A350 XWB', 'Airbus', 'A350-941', 315, 8, 42, 28, 237, 8100, '2023-06-01', 3.1, 'Rolls-Royce Trent XWB', 2, TRUE, 'ACTIVE', '2026-04-01', '2027-10-01');


-- More widebody aircraft for long-haul
INSERT INTO DIM_AIRCRAFT (registration, aircraft_type, aircraft_family, manufacturer, model_variant, seat_capacity_total, seats_first, seats_business, seats_premium_eco, seats_economy, max_range_nm, delivery_date, aircraft_age_years, engine_type, engine_count, is_widebody, status, last_heavy_check, next_heavy_check)
VALUES
('G-SPCB', 'A350', 'A350 XWB', 'Airbus', 'A350-941', 315, 8, 42, 28, 237, 8100, '2023-11-15', 2.6, 'Rolls-Royce Trent XWB', 2, TRUE, 'ACTIVE', '2026-06-01', '2027-12-01'),
('G-SPCC', 'A350', 'A350 XWB', 'Airbus', 'A350-1041', 369, 12, 52, 36, 269, 8700, '2024-03-01', 2.3, 'Rolls-Royce Trent XWB-97', 2, TRUE, 'ACTIVE', '2026-09-01', '2028-03-01'),
('G-SPDA', 'B787', '787 Dreamliner', 'Boeing', '787-9', 290, 8, 36, 21, 225, 7635, '2022-01-20', 4.4, 'Rolls-Royce Trent 1000', 2, TRUE, 'ACTIVE', '2025-07-01', '2027-01-01'),
('G-SPDB', 'B787', '787 Dreamliner', 'Boeing', '787-9', 290, 8, 36, 21, 225, 7635, '2022-07-10', 3.9, 'Rolls-Royce Trent 1000', 2, TRUE, 'ACTIVE', '2025-10-01', '2027-04-01'),
('G-SPDC', 'B787', '787 Dreamliner', 'Boeing', '787-10', 330, 8, 44, 28, 250, 6430, '2024-06-01', 2.1, 'GEnx-1B', 2, TRUE, 'ACTIVE', '2026-12-01', '2028-06-01'),
('G-SPAM', 'A320', 'A320neo Family', 'Airbus', 'A320-271N', 180, 0, 12, 0, 168, 3400, '2021-05-10', 5.1, 'CFM LEAP-1A', 2, FALSE, 'MAINTENANCE', '2026-05-01', '2027-11-01');

-- =============================================================================
-- DIM_ROUTE — SkyPulse route network
-- =============================================================================

INSERT INTO DIM_ROUTE (route_code, origin_iata, destination_iata, distance_km, distance_nm, flight_time_mins, route_type, market_type, competition_level, is_seasonal, is_active)
VALUES
-- From LHR Hub
('LHR-JFK', 'LHR', 'JFK', 5555, 3000, 480, 'LONG_HAUL', 'BUSINESS', 'HIGH', FALSE, TRUE),
('LHR-LAX', 'LHR', 'LAX', 8780, 4742, 660, 'LONG_HAUL', 'MIXED', 'HIGH', FALSE, TRUE),
('LHR-DXB', 'LHR', 'DXB', 5488, 2963, 420, 'LONG_HAUL', 'BUSINESS', 'HIGH', FALSE, TRUE),
('LHR-SIN', 'LHR', 'SIN', 10870, 5870, 780, 'ULTRA_LONG_HAUL', 'BUSINESS', 'MEDIUM', FALSE, TRUE),
('LHR-CDG', 'LHR', 'CDG', 341, 184, 75, 'SHORT_HAUL', 'BUSINESS', 'HIGH', FALSE, TRUE),
('LHR-FRA', 'LHR', 'FRA', 654, 353, 100, 'SHORT_HAUL', 'BUSINESS', 'HIGH', FALSE, TRUE),
('LHR-AMS', 'LHR', 'AMS', 370, 200, 75, 'SHORT_HAUL', 'BUSINESS', 'HIGH', FALSE, TRUE),
('LHR-BCN', 'LHR', 'BCN', 1139, 615, 140, 'SHORT_HAUL', 'LEISURE', 'HIGH', FALSE, TRUE),
('LHR-IST', 'LHR', 'IST', 2500, 1350, 240, 'MEDIUM_HAUL', 'MIXED', 'MEDIUM', FALSE, TRUE),
('LHR-HND', 'LHR', 'HND', 9571, 5168, 720, 'ULTRA_LONG_HAUL', 'BUSINESS', 'MEDIUM', FALSE, TRUE),
('LHR-BOM', 'LHR', 'BOM', 7196, 3886, 540, 'LONG_HAUL', 'VFR', 'MEDIUM', FALSE, TRUE),
('LHR-CPT', 'LHR', 'CPT', 9664, 5218, 690, 'LONG_HAUL', 'LEISURE', 'LOW', FALSE, TRUE),
('LHR-SYD', 'LHR', 'SYD', 17020, 9191, 1320, 'ULTRA_LONG_HAUL', 'LEISURE', 'LOW', FALSE, TRUE),
-- From LGW Hub
('LGW-AGP', 'LGW', 'AGP', 1650, 891, 170, 'SHORT_HAUL', 'LEISURE', 'HIGH', TRUE, TRUE),
('LGW-PMI', 'LGW', 'PMI', 1346, 727, 150, 'SHORT_HAUL', 'LEISURE', 'HIGH', TRUE, TRUE),
('LGW-BCN', 'LGW', 'BCN', 1082, 584, 135, 'SHORT_HAUL', 'LEISURE', 'HIGH', FALSE, TRUE),
-- From MAN
('MAN-DXB', 'MAN', 'DXB', 5484, 2961, 430, 'LONG_HAUL', 'MIXED', 'MEDIUM', FALSE, TRUE),
('MAN-JFK', 'MAN', 'JFK', 5386, 2909, 470, 'LONG_HAUL', 'MIXED', 'MEDIUM', FALSE, TRUE),
-- From EDI
('EDI-LHR', 'EDI', 'LHR', 534, 288, 80, 'DOMESTIC', 'BUSINESS', 'HIGH', FALSE, TRUE),
('EDI-AMS', 'EDI', 'AMS', 745, 402, 95, 'SHORT_HAUL', 'BUSINESS', 'MEDIUM', FALSE, TRUE);


-- =============================================================================
-- DIM_DELAY_REASON — IATA standard delay codes
-- =============================================================================

INSERT INTO DIM_DELAY_REASON (iata_delay_code, delay_category, delay_subcategory, description, is_airline_fault, is_controllable)
VALUES
('11', 'PASSENGER', 'Late check-in', 'Passenger checked in late at counter', TRUE, TRUE),
('12', 'PASSENGER', 'Late boarding', 'Passenger arrived late at gate', TRUE, TRUE),
('13', 'PASSENGER', 'Denied boarding', 'Involuntary denied boarding oversale', TRUE, TRUE),
('15', 'PASSENGER', 'Baggage processing', 'Passenger baggage loading/offloading', TRUE, TRUE),
('19', 'PASSENGER', 'Reduced mobility', 'PRM assistance causing delay', TRUE, TRUE),
('21', 'CARGO', 'Cargo documentation', 'Cargo/mail documentation issues', TRUE, TRUE),
('31', 'AIRPORT', 'Gate unavailability', 'Gate/stand not available', FALSE, FALSE),
('32', 'AIRPORT', 'Parking position', 'Parking stand change', FALSE, FALSE),
('33', 'AIRPORT', 'Airport congestion', 'Congestion in terminal or apron', FALSE, FALSE),
('34', 'AIRPORT', 'Runway/taxiway', 'Runway or taxiway closure', FALSE, FALSE),
('35', 'AIRPORT', 'Airport facilities', 'Airport facility malfunction (bridges, belts)', FALSE, FALSE),
('41', 'TECHNICAL', 'Aircraft defect', 'Aircraft technical defect requiring maintenance', TRUE, TRUE),
('42', 'TECHNICAL', 'Scheduled maintenance', 'Scheduled maintenance overrun', TRUE, TRUE),
('43', 'TECHNICAL', 'Unscheduled maintenance', 'Unscheduled maintenance requirement', TRUE, TRUE),
('44', 'TECHNICAL', 'Spare parts', 'Awaiting spare parts or equipment', TRUE, TRUE),
('51', 'CREW', 'Captain unavailable', 'Captain not available or duty time exceeded', TRUE, TRUE),
('52', 'CREW', 'FO unavailable', 'First Officer not available', TRUE, TRUE),
('55', 'CREW', 'Cabin crew', 'Cabin crew not available', TRUE, TRUE),
('56', 'CREW', 'Duty time limits', 'Crew exceeded max duty time', TRUE, TRUE),
('61', 'REACTIONARY', 'Late arrival aircraft', 'Aircraft arrived late from previous flight', TRUE, FALSE),
('62', 'REACTIONARY', 'Late crew connection', 'Crew connection from delayed flight', TRUE, FALSE),
('63', 'REACTIONARY', 'Passenger connections', 'Waiting for connecting passengers', TRUE, TRUE),
('71', 'WEATHER', 'Departure weather', 'Adverse weather at departure station', FALSE, FALSE),
('72', 'WEATHER', 'Destination weather', 'Adverse weather at destination', FALSE, FALSE),
('73', 'WEATHER', 'En-route weather', 'Weather en-route causing reroute', FALSE, FALSE),
('75', 'WEATHER', 'De-icing', 'De-icing/anti-icing operations', FALSE, FALSE),
('81', 'ATC', 'ATC flow control', 'ATC/CFMU flow control restrictions', FALSE, FALSE),
('82', 'ATC', 'ATC staffing', 'ATC staffing shortage', FALSE, FALSE),
('83', 'ATC', 'ATC strike', 'ATC industrial action', FALSE, FALSE),
('84', 'ATC', 'Airspace closure', 'Airspace closure or restriction', FALSE, FALSE),
('91', 'SECURITY', 'Security screening', 'Security screening delays', FALSE, FALSE),
('93', 'SECURITY', 'Bomb threat', 'Security threat / evacuation', FALSE, FALSE),
('96', 'SECURITY', 'Immigration', 'Immigration or customs delays', FALSE, FALSE);

SELECT 'DIM_AIRPORT loaded: ' || COUNT(*) || ' rows' FROM DIM_AIRPORT;
SELECT 'DIM_AIRCRAFT loaded: ' || COUNT(*) || ' rows' FROM DIM_AIRCRAFT;
SELECT 'DIM_ROUTE loaded: ' || COUNT(*) || ' rows' FROM DIM_ROUTE;
SELECT 'DIM_DELAY_REASON loaded: ' || COUNT(*) || ' rows' FROM DIM_DELAY_REASON;
