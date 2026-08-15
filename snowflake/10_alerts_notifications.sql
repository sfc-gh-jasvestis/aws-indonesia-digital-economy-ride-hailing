-- ============================================================================
-- 10_ALERTS_NOTIFICATIONS.SQL — Alerts for Ride-Hailing & Super-App Analytics
-- ============================================================================
USE DATABASE RIDE_HAILING_ANALYTICS;
USE SCHEMA APP;

-- Notification integration (email)
CREATE OR REPLACE NOTIFICATION INTEGRATION aws_indonesia_digital_economy_ride_hailing_EMAIL_INT
  TYPE = EMAIL
  ENABLED = TRUE
  ALLOWED_RECIPIENTS = ('jonathan.asvestis@snowflake.com');

-- Alert: FULFILLMENT_DROP_ALERT
CREATE OR REPLACE ALERT APP.FULFILLMENT_DROP_ALERT
  WAREHOUSE = RIDEHAIL_WH
  SCHEDULE = '5 MINUTE'
  COMMENT = 'Critical supply shortage — zone fulfillment below 80%'
IF (EXISTS (
  SELECT 1 FROM CURATED.DEMAND_SUPPLY_BALANCE
  WHERE 1=1 -- Condition: Zone fulfillment rate drops below 80% for 30 minutes
))
THEN
  CALL SYSTEM$SEND_EMAIL(
    'aws_indonesia_digital_economy_ride_hailing_EMAIL_INT',
    'jonathan.asvestis@snowflake.com',
    '[ALERT] Ride-Hailing & Super-App Analytics: Critical supply shortage — zone fulfillment below 80%',
    'Critical supply shortage — zone fulfillment below 80%'
  );

ALTER ALERT APP.FULFILLMENT_DROP_ALERT RESUME;

-- Alert: SURGE_ANOMALY_ALERT
CREATE OR REPLACE ALERT APP.SURGE_ANOMALY_ALERT
  WAREHOUSE = RIDEHAIL_WH
  SCHEDULE = '5 MINUTE'
  COMMENT = 'Extended high surge — review driver allocation and incentives'
IF (EXISTS (
  SELECT 1 FROM CURATED.DEMAND_SUPPLY_BALANCE
  WHERE 1=1 -- Condition: Surge multiplier exceeds 3.0x for more than 15 minutes
))
THEN
  CALL SYSTEM$SEND_EMAIL(
    'aws_indonesia_digital_economy_ride_hailing_EMAIL_INT',
    'jonathan.asvestis@snowflake.com',
    '[ALERT] Ride-Hailing & Super-App Analytics: Extended high surge — review driver allocation and incentives',
    'Extended high surge — review driver allocation and incentives'
  );

ALTER ALERT APP.SURGE_ANOMALY_ALERT RESUME;

