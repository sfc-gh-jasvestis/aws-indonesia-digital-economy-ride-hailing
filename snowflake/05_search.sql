-- ============================================================================
-- 05_SEARCH.SQL — Cortex Search for Ride-Hailing & Super-App Analytics
-- ============================================================================
USE DATABASE RIDE_HAILING_ANALYTICS;
USE SCHEMA SEARCH;

CREATE OR REPLACE CORTEX SEARCH SERVICE SEARCH.ZONE_DOCS_SEARCH
  ON DESCRIPTION
  ATTRIBUTES ZONE_ID, SERVICE_TYPE
  WAREHOUSE = RIDEHAIL_WH
  TARGET_LAG = '1 hour'
AS (
  SELECT * FROM RAW.ZONE_CONFIG
);
