-- ============================================================================
-- 07_SEMANTIC_VIEW.SQL — Semantic View for Ride-Hailing & Super-App Analytics
-- ============================================================================
USE DATABASE RIDE_HAILING_ANALYTICS;
USE SCHEMA APP;

CREATE OR REPLACE SEMANTIC VIEW APP.RIDE_HAILING_ANALYTICS
  COMMENT = 'Ride-hailing demand-supply, pricing, fulfillment, and driver economics analytics'
AS
  TABLES (
    CURATED.DEMAND_SUPPLY_BALANCE AS demand_supply_balance,CURATED.FULFILLMENT_METRICS AS fulfillment_metrics,CURATED.DRIVER_ECONOMICS AS driver_economics,CURATED.PRICING_EFFECTIVENESS AS pricing_effectiveness
  );
