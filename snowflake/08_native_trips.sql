-- ============================================================================
-- 08_native_trips.sql - Snowflake-only build: live trip feed without AWS.
-- Creates RAW.LIVE_TRIPS (same columns as the Snowpipe target created by
-- aws/setup_aws.py) and APP.SIMULATE_TRIPS(N), which inserts synthetic trip
-- request events with the same value ranges and ~10% UNFULFILLED rate as
-- aws/publish_trips.py. Rows are inserted directly; this simulates a trip
-- feed and is not Snowpipe Streaming.
-- Run before 06_intelligence.sql (the alert reads RAW.LIVE_TRIPS).
-- Idempotent: safe to run in the AWS build too.
-- ============================================================================
CREATE SCHEMA IF NOT EXISTS RAW;
CREATE SCHEMA IF NOT EXISTS APP;

CREATE TABLE IF NOT EXISTS RAW.LIVE_TRIPS (
  ZONE_ID VARCHAR, EVENT_TS TIMESTAMP_NTZ, FARE_IDR FLOAT, WAIT_SECONDS FLOAT,
  STATUS VARCHAR, SENT_TS TIMESTAMP_NTZ, SOURCE_FILE VARCHAR,
  LOADED_AT TIMESTAMP_LTZ DEFAULT CURRENT_TIMESTAMP());

CREATE OR REPLACE PROCEDURE APP.SIMULATE_TRIPS(N NUMBER)
RETURNS NUMBER
LANGUAGE SQL
EXECUTE AS OWNER
AS
$$
BEGIN
  IF (N < 1 OR N > 1000) THEN
    RETURN 0;
  END IF;
  INSERT INTO RAW.LIVE_TRIPS (ZONE_ID, EVENT_TS, FARE_IDR, WAIT_SECONDS, STATUS, SENT_TS, SOURCE_FILE)
    WITH g AS (
      SELECT 'ZON-' || LPAD(UNIFORM(0, 39, RANDOM())::VARCHAR, 4, '0') AS ZONE_ID,
             UNIFORM(0::FLOAT, 1::FLOAT, RANDOM()) < 0.1 AS IS_UNFULFILLED,
             SYSDATE() AS TS, SEQ4() AS I
      FROM TABLE(GENERATOR(ROWCOUNT => 1000))
    )
    -- NORMAL() needs constant arguments, so the status offset is applied outside it.
    SELECT ZONE_ID, TS,
           IFF(IS_UNFULFILLED, 0, ROUND(32000 * EXP(NORMAL(0, 0.5, RANDOM())), -2)),
           ROUND(IFF(IS_UNFULFILLED, 600, 240) * EXP(NORMAL(0, 0.4, RANDOM())), 0),
           IFF(IS_UNFULFILLED, 'UNFULFILLED', 'MATCHED'), TS, 'APP.SIMULATE_TRIPS'
    FROM g
    WHERE I < :N;
  RETURN SQLROWCOUNT;
END;
$$;

-- Optional continuous feed for longer demos (suspended; RESUME to start, SUSPEND after).
CREATE OR REPLACE TASK APP.TASK_SIMULATE_TRIPS
  WAREHOUSE = __DEMO_WH__
  SCHEDULE = '1 MINUTE'
AS
  CALL APP.SIMULATE_TRIPS(5);
