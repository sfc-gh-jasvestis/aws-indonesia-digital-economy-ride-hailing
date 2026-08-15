-- ============================================================================
-- Ride-Hailing & Super-App Analytics
-- Real-time demand-supply matching intelligence for Indonesia's super-app economy — ML.FORECAST predicts ride demand, Dynamic Tables build driver allocation dashboards, and Cortex AI generates surge pricing recommendations.
-- ============================================================================
USE ROLE ACCOUNTADMIN;
CREATE DATABASE IF NOT EXISTS RIDE_HAILING_ANALYTICS;
CREATE WAREHOUSE IF NOT EXISTS RIDEHAIL_WH WAREHOUSE_SIZE = 'MEDIUM' AUTO_SUSPEND = 120 AUTO_RESUME = TRUE;
USE DATABASE RIDE_HAILING_ANALYTICS;
CREATE SCHEMA IF NOT EXISTS RAW;
CREATE SCHEMA IF NOT EXISTS CURATED;
CREATE SCHEMA IF NOT EXISTS ML;
CREATE SCHEMA IF NOT EXISTS AI;
CREATE SCHEMA IF NOT EXISTS SEARCH;
CREATE SCHEMA IF NOT EXISTS APP;

USE WAREHOUSE RIDEHAIL_WH;
