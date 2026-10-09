-- ============================================================================
-- 06_INTELLIGENCE.SQL - search, anomaly detection, semantic view, agent,
-- live-trip alert and on-demand refresh DAG.
-- Run with snowflake/run_intelligence.py (substitutes checked __DEMO_DB__ /
-- __DEMO_WH__ / __ALERT_EMAIL__). Requires 00-05, plus 08 (Snowflake only) or
-- aws/setup_aws.py (AWS build) for RAW.LIVE_TRIPS.
-- Alerts and tasks are created SUSPENDED; run them with EXECUTE ALERT / EXECUTE TASK.
-- ============================================================================
USE DATABASE __DEMO_DB__;
CREATE SCHEMA IF NOT EXISTS SEARCH;
CREATE SCHEMA IF NOT EXISTS APP;

-- ---------- Synthetic supply-shortage playbooks (clearly synthetic SOPs) ----------
CREATE OR REPLACE TABLE SEARCH.PLAYBOOK_DOCS AS
WITH causes AS (
  SELECT DISTINCT r.SHORTAGE_CAUSE, z.CATEGORY
  FROM RAW.ZONE_DAILY r JOIN RAW.ZONES z ON z.ID = r.ENTITY_ID
  WHERE r.SHORTAGE_HOURS > 0
)
SELECT
  'PLB-' || LPAD(ROW_NUMBER() OVER (ORDER BY CATEGORY, SHORTAGE_CAUSE)::VARCHAR, 3, '0') AS DOC_ID,
  'SOP' AS DOC_TYPE,
  CATEGORY,
  SHORTAGE_CAUSE,
  CATEGORY || ' - ' || SHORTAGE_CAUSE || ' supply shortage playbook' AS TITLE,
  'Synthetic demo SOP. Service: ' || CATEGORY || '. Shortage cause: ' || SHORTAGE_CAUSE || '. '
  || 'Step 1: open a supply incident for the zone, and cap surge at 1.5x until the incident is triaged. '
  || 'Step 2: ' || CASE
       WHEN SHORTAGE_CAUSE = 'Peak commute' THEN 'send a targeted online-hours bonus to drivers within 5 km of the zone for the next two peak windows, and widen the dispatch radius by one ring.'
       WHEN SHORTAGE_CAUSE = 'Heavy rain' THEN 'switch on the rain incentive for active drivers, shift bike demand to car and courier where available, and show riders a longer ETA before booking.'
       WHEN SHORTAGE_CAUSE = 'Driver payout delay' THEN 'escalate the late incentive payout to driver finance, confirm the settlement date to affected drivers in the app, and pause new incentive campaigns in the zone until it is paid.'
       WHEN SHORTAGE_CAUSE = 'Road closure' THEN 'update the routing map with the closure, move pickup points outside the closed area, and notify drivers of the detour.'
       WHEN SHORTAGE_CAUSE = 'Event surge' THEN 'set up a designated pickup point at the venue, pre-position drivers from neighbouring zones 30 minutes before the event ends, and stagger pickups.'
       WHEN SHORTAGE_CAUSE = 'Meal-time peak' THEN 'batch nearby food orders to one driver where the merchants are within 1 km, and extend preparation-time estimates shown to customers.'
       WHEN SHORTAGE_CAUSE = 'Airport surge' THEN 'release drivers from the airport queue to the arrivals pickup lane in order, and pull car drivers from adjacent zones for large-vehicle requests.'
       WHEN SHORTAGE_CAUSE = 'City-wide flooding' THEN 'suspend bike services in flooded areas, keep car services on safe routes only, and post the safety notice to drivers and riders.'
       ELSE 'review the shortage against the zone profile and escalate if unexplained.'
     END
  || ' Step 3: if the average pickup ETA in the zone stays above 10 minutes or unfulfilled requests stay above 10% after two hours, keep the incident open and request a zone supply review. '
  || 'Step 4: record the resolution; if driver payouts were late, log it for the weekly driver finance report.' AS CONTENT
FROM causes;

CREATE OR REPLACE CORTEX SEARCH SERVICE SEARCH.PLAYBOOK_SEARCH
  ON CONTENT
  ATTRIBUTES CATEGORY, SHORTAGE_CAUSE
  WAREHOUSE = __DEMO_WH__
  TARGET_LAG = '7 days'
AS (SELECT DOC_ID, TITLE, CATEGORY, SHORTAGE_CAUSE, CONTENT FROM SEARCH.PLAYBOOK_DOCS);

-- ---------- Pickup ETA anomaly detection (train first 75 days, detect last 15) ----------
CREATE OR REPLACE VIEW ML.PICKUP_ETA_SERIES AS
SELECT ENTITY_ID, EVENT_DATE::TIMESTAMP_NTZ AS TS, AVG_PICKUP_ETA_MIN::FLOAT AS PICKUP_ETA
FROM RAW.ZONE_DAILY;
CREATE OR REPLACE VIEW ML.PICKUP_ETA_TRAIN AS
SELECT * FROM ML.PICKUP_ETA_SERIES WHERE TS < (SELECT DATEADD(day, -15, MAX(TS)) FROM ML.PICKUP_ETA_SERIES);
CREATE OR REPLACE VIEW ML.PICKUP_ETA_DETECT AS
SELECT * FROM ML.PICKUP_ETA_SERIES WHERE TS >= (SELECT DATEADD(day, -15, MAX(TS)) FROM ML.PICKUP_ETA_SERIES);

CREATE OR REPLACE SNOWFLAKE.ML.ANOMALY_DETECTION ML.PICKUP_ETA_ANOMALY_MODEL(
  INPUT_DATA => SYSTEM$REFERENCE('VIEW', 'ML.PICKUP_ETA_TRAIN'),
  SERIES_COLNAME => 'ENTITY_ID', TIMESTAMP_COLNAME => 'TS', TARGET_COLNAME => 'PICKUP_ETA',
  LABEL_COLNAME => '');

CREATE OR REPLACE TABLE ML.PICKUP_ETA_ANOMALIES AS
SELECT SERIES::VARCHAR AS ENTITY_ID, TS::DATE AS EVENT_DATE, Y AS PICKUP_ETA, FORECAST AS EXPECTED,
       LOWER_BOUND, UPPER_BOUND, IS_ANOMALY, PERCENTILE
FROM TABLE(ML.PICKUP_ETA_ANOMALY_MODEL!DETECT_ANOMALIES(
  INPUT_DATA => SYSTEM$REFERENCE('VIEW', 'ML.PICKUP_ETA_DETECT'),
  SERIES_COLNAME => 'ENTITY_ID', TIMESTAMP_COLNAME => 'TS', TARGET_COLNAME => 'PICKUP_ETA'));

-- ---------- Semantic view ----------
CREATE OR REPLACE SEMANTIC VIEW APP.RIDE_HAILING_ANALYTICS
  TABLES (
    zones AS CURATED.PERFORMANCE_SUMMARY PRIMARY KEY (ENTITY_ID)
      COMMENT = 'One row per service zone (one service in one Indonesian city), 90-day totals',
    risk AS ML.SHORTAGE_RISK_SCORES PRIMARY KEY (ENTITY_ID)
      COMMENT = 'Latest next-7-day supply-shortage probability per zone',
    causes AS CURATED.CAUSE_SUMMARY PRIMARY KEY (SHORTAGE_CAUSE)
      COMMENT = 'Shortage zone-days, shortage hours and unfulfilled requests by shortage cause, 90 days',
    daily AS CURATED.TREND_ANALYSIS PRIMARY KEY (METRIC_DATE)
      COMMENT = 'Marketplace-wide totals per day'
  )
  RELATIONSHIPS (risk_zone AS risk (ENTITY_ID) REFERENCES zones)
  FACTS (
    zones.requests_f AS REQUEST_COUNT,
    zones.trips_f AS TRIP_COUNT,
    zones.unfulfilled_f AS UNFULFILLED_COUNT,
    zones.cancelled_f AS CANCELLED_COUNT,
    zones.gmv_f AS GMV_IDR,
    zones.shortage_hours_f AS SHORTAGE_HOURS,
    zones.shortage_days_f AS SHORTAGE_DAYS,
    zones.payout_due_f AS PAYOUT_DUE,
    zones.payout_settled_f AS PAYOUT_SETTLED,
    zones.surge_f AS AVG_SURGE_MULT,
    zones.eta_f AS AVG_PICKUP_ETA_MIN,
    risk.shortage_prob_f AS SHORTAGE_PROB_7D,
    causes.cause_days_f AS SHORTAGE_DAYS,
    causes.cause_hours_f AS SHORTAGE_HOURS,
    causes.cause_unfulfilled_f AS UNFULFILLED_COUNT,
    causes.cause_requests_f AS REQUEST_COUNT,
    daily.day_requests_f AS REQUEST_COUNT,
    daily.day_trips_f AS TRIP_COUNT,
    daily.day_unfulfilled_f AS UNFULFILLED_COUNT,
    daily.day_gmv_f AS GMV_IDR
  )
  DIMENSIONS (
    zones.zone_id AS ENTITY_ID WITH SYNONYMS = ('zone', 'service zone', 'service area'),
    zones.zone_name AS ENTITY_NAME,
    zones.city AS REGION WITH SYNONYMS = ('city', 'region', 'metro area')
      COMMENT = 'Indonesian city: Jakarta, Surabaya, Bandung, Medan or Denpasar',
    zones.service AS CATEGORY WITH SYNONYMS = ('service', 'service type', 'product')
      COMMENT = 'Bike ride, Car ride, Food delivery, Courier or Car XL',
    zones.congestion_tier AS CONGESTION_TIER COMMENT = 'Traffic congestion tier 1 (low) to 3 (high)',
    risk.risk_band AS RISK_BAND COMMENT = 'High >= 0.5, Medium >= 0.25, else Low',
    risk.scored_as_of AS SCORED_AS_OF,
    causes.shortage_cause AS SHORTAGE_CAUSE WITH SYNONYMS = ('cause', 'shortage reason', 'reason'),
    daily.metric_date AS METRIC_DATE
  )
  METRICS (
    zones.zone_count AS COUNT(zones.zone_id) WITH SYNONYMS = ('number of zones', 'zones monitored', 'entities'),
    zones.fulfillment_pct AS 100 * SUM(zones.trips_f) / NULLIF(SUM(zones.requests_f), 0)
      WITH SYNONYMS = ('fulfillment rate', 'completion rate')
      COMMENT = 'Completed trips / ride and delivery requests',
    zones.cancellation_pct AS 100 * SUM(zones.cancelled_f) / NULLIF(SUM(zones.requests_f), 0)
      COMMENT = 'Rider cancellations / requests',
    zones.total_requests AS SUM(zones.requests_f) WITH SYNONYMS = ('requests', 'demand'),
    zones.trips_completed AS SUM(zones.trips_f) WITH SYNONYMS = ('trips', 'completed trips'),
    zones.unfulfilled_requests AS SUM(zones.unfulfilled_f) WITH SYNONYMS = ('unmatched requests', 'no driver found'),
    zones.total_shortage_hours AS SUM(zones.shortage_hours_f) WITH SYNONYMS = ('shortage hours', 'driver shortage'),
    zones.total_shortage_days AS SUM(zones.shortage_days_f),
    zones.total_gmv_idr AS SUM(zones.gmv_f) WITH SYNONYMS = ('GMV', 'gross merchandise value', 'value in IDR'),
    zones.payout_on_time_pct AS 100 * SUM(zones.payout_settled_f) / NULLIF(SUM(zones.payout_due_f), 0)
      COMMENT = 'Driver incentive payouts settled on time / payouts due',
    zones.mean_surge AS AVG(zones.surge_f),
    zones.mean_pickup_eta AS AVG(zones.eta_f),
    risk.avg_shortage_prob AS AVG(risk.shortage_prob_f),
    causes.cause_shortage_days AS SUM(causes.cause_days_f),
    causes.cause_shortage_hours AS SUM(causes.cause_hours_f),
    causes.cause_unfulfilled AS SUM(causes.cause_unfulfilled_f),
    causes.cause_unfulfilled_pct AS 100 * SUM(causes.cause_unfulfilled_f) / NULLIF(SUM(causes.cause_requests_f), 0),
    daily.daily_requests AS SUM(daily.day_requests_f),
    daily.daily_trips AS SUM(daily.day_trips_f),
    daily.daily_unfulfilled AS SUM(daily.day_unfulfilled_f),
    daily.daily_gmv_idr AS SUM(daily.day_gmv_f)
  )
  COMMENT = 'Synthetic Indonesia ride-hailing marketplace operations analytics (demo)';

-- ---------- Cortex Agent ----------
CREATE OR REPLACE AGENT APP.MARKETPLACE_AGENT
  COMMENT = 'Marketplace operations assistant over a synthetic Indonesian ride-hailing and delivery marketplace'
  FROM SPECIFICATION
$$
models:
  orchestration: claude-sonnet-4-5
instructions:
  response: "Answer only from tool results. State that data is synthetic. Give zone IDs and numbers with units (IDR, %, hours, minutes)."
  orchestration: "Use marketplace_analyst for requests, trips, fulfillment rate, unfulfilled requests, cancellations, shortage hours, GMV, driver payouts, zones, cities, services, shortage causes and shortage risk. Use playbook_search for supply-shortage procedures."
tools:
  - tool_spec:
      type: cortex_analyst_text_to_sql
      name: marketplace_analyst
      description: "Ride and delivery requests, completed trips, fulfillment rate, unfulfilled requests, rider cancellations, supply shortage hours, GMV in IDR, driver payout on-time rate, shortage causes and supply-shortage risk scores by zone, city and service"
  - tool_spec:
      type: cortex_search
      name: playbook_search
      description: "Synthetic supply-shortage playbooks by service and shortage cause"
tool_resources:
  marketplace_analyst:
    semantic_view: __DEMO_DB__.APP.RIDE_HAILING_ANALYTICS
    execution_environment:
      type: warehouse
      warehouse: __DEMO_WH__
  playbook_search:
    name: __DEMO_DB__.SEARCH.PLAYBOOK_SEARCH
    max_results: 3
    id_column: DOC_ID
    title_column: TITLE
$$;

-- ---------- Live-trip alert ----------
CREATE TABLE IF NOT EXISTS APP.ALERT_LOG (
  ALERTED_AT TIMESTAMP_LTZ DEFAULT CURRENT_TIMESTAMP(), ZONE_ID VARCHAR,
  EVENT_TS TIMESTAMP_NTZ, FARE_IDR FLOAT, WAIT_SECONDS FLOAT, PLAYBOOK_HINT VARCHAR);

CREATE OR REPLACE NOTIFICATION INTEGRATION ID_RIDE_EMAIL_INT
  TYPE = EMAIL ENABLED = TRUE ALLOWED_RECIPIENTS = ('__ALERT_EMAIL__');

CREATE OR REPLACE PROCEDURE APP.LOG_LIVE_ALERTS()
RETURNS NUMBER
LANGUAGE SQL
EXECUTE AS OWNER
AS
$$
DECLARE
  n NUMBER;
BEGIN
  INSERT INTO APP.ALERT_LOG (ZONE_ID, EVENT_TS, FARE_IDR, WAIT_SECONDS, PLAYBOOK_HINT)
    SELECT t.ZONE_ID, t.EVENT_TS, t.FARE_IDR, t.WAIT_SECONDS,
           'Check ' || z.CATEGORY || ' supply-shortage playbooks; current risk band ' || COALESCE(s.RISK_BAND, 'n/a')
    FROM RAW.LIVE_TRIPS t
    JOIN RAW.ZONES z ON z.ID = t.ZONE_ID
    LEFT JOIN ML.SHORTAGE_RISK_SCORES s ON s.ENTITY_ID = t.ZONE_ID
    WHERE t.STATUS = 'UNFULFILLED'
      AND NOT EXISTS (SELECT 1 FROM APP.ALERT_LOG l WHERE l.ZONE_ID = t.ZONE_ID AND l.EVENT_TS = t.EVENT_TS);
  n := SQLROWCOUNT;
  IF (n > 0) THEN
    CALL SYSTEM$SEND_EMAIL('ID_RIDE_EMAIL_INT', '__ALERT_EMAIL__',
      '[Demo] Unfulfilled trip request alert',
      'New unfulfilled trip requests logged in APP.ALERT_LOG: ' || :n || '. Data is synthetic.');
  END IF;
  RETURN n;
END;
$$;

CREATE OR REPLACE ALERT APP.LIVE_TRIP_ALERT
  WAREHOUSE = __DEMO_WH__
  SCHEDULE = '5 MINUTE'
  IF (EXISTS (
    SELECT 1 FROM RAW.LIVE_TRIPS t
    WHERE t.STATUS = 'UNFULFILLED'
      AND NOT EXISTS (SELECT 1 FROM APP.ALERT_LOG l WHERE l.ZONE_ID = t.ZONE_ID AND l.EVENT_TS = t.EVENT_TS)))
  THEN CALL APP.LOG_LIVE_ALERTS();

-- ---------- On-demand refresh DAG (suspended; run with EXECUTE TASK APP.TASK_REFRESH_CURATED) ----------
CREATE OR REPLACE PROCEDURE APP.REFRESH_CURATED()
RETURNS VARCHAR
LANGUAGE SQL
EXECUTE AS OWNER
AS
$$
BEGIN
  ALTER DYNAMIC TABLE CURATED.PERFORMANCE_SUMMARY REFRESH;
  ALTER DYNAMIC TABLE CURATED.TREND_ANALYSIS REFRESH;
  ALTER DYNAMIC TABLE CURATED.CAUSE_SUMMARY REFRESH;
  ALTER DYNAMIC TABLE CURATED.KPI_SUMMARY REFRESH;
  RETURN 'refreshed';
END;
$$;

CREATE OR REPLACE TASK APP.TASK_REFRESH_CURATED
  WAREHOUSE = __DEMO_WH__
AS
  CALL APP.REFRESH_CURATED();

CREATE OR REPLACE TASK APP.TASK_RESCORE_RISK
  WAREHOUSE = __DEMO_WH__
  AFTER APP.TASK_REFRESH_CURATED
AS
  CREATE OR REPLACE TABLE ML.SHORTAGE_RISK_SCORES COPY GRANTS AS
  WITH latest AS (
    SELECT * FROM ML.SHORTAGE_FEATURES QUALIFY ROW_NUMBER() OVER (PARTITION BY ENTITY_ID ORDER BY EVENT_DATE DESC) = 1
  ), p AS (
    SELECT ENTITY_ID, EVENT_DATE,
           ML.SHORTAGE_RISK_MODEL!PREDICT(INPUT_DATA => OBJECT_CONSTRUCT(
             'CATEGORY', CATEGORY, 'CONGESTION_TIER', CONGESTION_TIER, 'ZONE_AGE_YEARS', ZONE_AGE_YEARS,
             'AVG_SURGE_MULT', AVG_SURGE_MULT, 'AVG_PICKUP_ETA_MIN', AVG_PICKUP_ETA_MIN,
             'PICKUP_ETA_7D', PICKUP_ETA_7D, 'SHORTAGE_HOURS_30D', SHORTAGE_HOURS_30D)) AS PRED
    FROM latest
  )
  SELECT ENTITY_ID, EVENT_DATE AS SCORED_AS_OF, ROUND(PRED:probability:SHORTAGE::FLOAT, 4) AS SHORTAGE_PROB_7D,
         CASE WHEN PRED:probability:SHORTAGE::FLOAT >= 0.5 THEN 'High'
              WHEN PRED:probability:SHORTAGE::FLOAT >= 0.25 THEN 'Medium' ELSE 'Low' END AS RISK_BAND,
         CURRENT_TIMESTAMP() AS SCORED_AT
  FROM p;
