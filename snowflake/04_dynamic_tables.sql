-- ============================================================================
-- 04_DYNAMIC_TABLES.SQL — Curated layer for Ride-Hailing & Super-App Analytics
-- ============================================================================
USE DATABASE RIDE_HAILING_ANALYTICS;
USE SCHEMA CURATED;

-- DEMAND_SUPPLY_BALANCE: Real-time demand-supply ratio by zone, service type, and 15-minute interval
-- Source: DEMAND_EVENTS, DRIVERS
CREATE OR REPLACE DYNAMIC TABLE CURATED.DEMAND_SUPPLY_BALANCE
  TARGET_LAG = '5 minutes'
  WAREHOUSE = RIDEHAIL_WH
AS
SELECT * FROM RAW.DEMAND_EVENTS;
-- TODO: Replace with actual join/aggregation logic per demo

-- FULFILLMENT_METRICS: Trip fulfillment rate, cancellation reasons, and service reliability
-- Source: TRIPS, DEMAND_EVENTS
CREATE OR REPLACE DYNAMIC TABLE CURATED.FULFILLMENT_METRICS
  TARGET_LAG = '5 minutes'
  WAREHOUSE = RIDEHAIL_WH
AS
SELECT * FROM RAW.TRIPS;
-- TODO: Replace with actual join/aggregation logic per demo

-- DRIVER_ECONOMICS: Driver earnings, utilization, and incentive effectiveness per zone
-- Source: TRIPS, DRIVERS, INCENTIVES
CREATE OR REPLACE DYNAMIC TABLE CURATED.DRIVER_ECONOMICS
  TARGET_LAG = '5 minutes'
  WAREHOUSE = RIDEHAIL_WH
AS
SELECT * FROM RAW.TRIPS;
-- TODO: Replace with actual join/aggregation logic per demo

-- PRICING_EFFECTIVENESS: Surge pricing impact on demand, supply, and revenue per zone
-- Source: PRICING_LOGS, TRIPS, DEMAND_EVENTS
CREATE OR REPLACE DYNAMIC TABLE CURATED.PRICING_EFFECTIVENESS
  TARGET_LAG = '5 minutes'
  WAREHOUSE = RIDEHAIL_WH
AS
SELECT * FROM RAW.PRICING_LOGS;
-- TODO: Replace with actual join/aggregation logic per demo

