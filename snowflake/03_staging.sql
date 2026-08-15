-- ============================================================================
-- 03_STAGING.SQL — Generate synthetic data for Ride-Hailing & Super-App Analytics
-- Country: INDONESIA | Currency: IDR
-- ============================================================================
USE DATABASE RIDE_HAILING_ANALYTICS;
USE SCHEMA RAW;

-- Data generation scripts are demo-specific.
-- See the handcrafted SQL in the aws-malaysia-semiconductor-yield demo for
-- the full pattern: GENERATOR + UNIFORM + LATERAL for distribution,
-- Cortex Complete for text generation, engineered key demo numbers.

-- Target row counts:
-- TRIPS: 100,000,000 rows — 12 months of completed and cancelled trip records across transport, food, and courier
-- DRIVERS: 2,000,000 rows — Active driver-partners with status, rating, vehicle type, and earnings
-- DEMAND_EVENTS: 500,000,000 rows — Real-time ride requests, searches, and cancellations by zone and time
-- PRICING_LOGS: 50,000,000 rows — Dynamic pricing decisions with surge multiplier and demand-supply ratio
-- INCENTIVES: 5,000,000 rows — Driver and rider incentive campaigns with spend and response data
-- ZONE_CONFIG: 5,000 rows — Geographic zone definitions with demand patterns and service availability
