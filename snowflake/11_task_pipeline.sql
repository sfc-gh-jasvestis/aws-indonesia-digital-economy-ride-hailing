-- ============================================================================
-- 11_TASK_PIPELINE.SQL — Task DAG for Ride-Hailing & Super-App Analytics
-- ============================================================================
USE DATABASE RIDE_HAILING_ANALYTICS;
USE SCHEMA APP;

CREATE OR REPLACE TASK APP.TASK_REFRESH_DEMAND
  WAREHOUSE = RIDEHAIL_WH
  SCHEDULE = 'USING CRON */5 * * * * UTC'
  COMMENT = 'Refresh demand-supply balance metrics every 5 minutes'
AS
  SELECT 1; -- Replace with actual refresh logic

CREATE OR REPLACE TASK APP.TASK_FORECAST_DEMAND
  WAREHOUSE = RIDEHAIL_WH
  AFTER APP.TASK_REFRESH_DEMAND
  COMMENT = 'Run 30-minute demand forecast by zone'
AS
  SELECT 1; -- Replace with actual refresh logic

CREATE OR REPLACE TASK APP.TASK_OPTIMIZE_PRICING
  WAREHOUSE = RIDEHAIL_WH
  AFTER APP.TASK_FORECAST_DEMAND
  COMMENT = 'Generate pricing and allocation recommendations'
AS
  SELECT 1; -- Replace with actual refresh logic

ALTER TASK APP.TASK_OPTIMIZE_PRICING RESUME;
ALTER TASK APP.TASK_FORECAST_DEMAND RESUME;
ALTER TASK APP.TASK_REFRESH_DEMAND RESUME;
