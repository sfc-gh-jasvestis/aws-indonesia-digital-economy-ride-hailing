-- Synthetic zone-day observations for a fictional Indonesian super-app's
-- ride-hailing and delivery marketplace. A zone is one service (bike ride, car
-- ride, food delivery, courier, car XL) in one city service area.
-- Nothing is seeded as a prediction. Randomness is HASH-seeded, so every rebuild
-- is reproducible: per-zone shortage propensity, supply drift between driver
-- incentive payouts, late payouts, service-weighted shortage causes, and two
-- city-wide flooding days.
USE DATABASE IDENTIFIER($DEMO_DB);
USE SCHEMA RAW;
USE WAREHOUSE IDENTIFIER($DEMO_WH);

CREATE TABLE RAW.ZONES AS
WITH zones AS (
  SELECT ROW_NUMBER() OVER (ORDER BY SEQ4()) - 1 AS ZONE_INDEX
  FROM TABLE(GENERATOR(ROWCOUNT => 40))
), draws AS (
  SELECT ZONE_INDEX,
         MOD(ABS(HASH(ZONE_INDEX, 'age')), 1000000) / 1e6 AS U_AGE,
         MOD(ABS(HASH(ZONE_INDEX, 'rate')), 1000000) / 1e6 AS U_RATE,
         MOD(ABS(HASH(ZONE_INDEX, 'payout')), 1000000) / 1e6 AS U_PAYOUT,
         MOD(ABS(HASH(ZONE_INDEX, 'discipline')), 1000000) / 1e6 AS U_DISCIPLINE,
         MOD(ABS(HASH(ZONE_INDEX, 'tier')), 1000000) / 1e6 AS U_TIER
  FROM zones
), labelled AS (
  SELECT *,
         -- Deterministic spread (5 and 8 are coprime): every city and service is present.
         CASE MOD(ZONE_INDEX, 5) WHEN 0 THEN 'Jakarta' WHEN 1 THEN 'Surabaya'
              WHEN 2 THEN 'Bandung' WHEN 3 THEN 'Medan' ELSE 'Denpasar' END AS CITY,
         CASE MOD(ZONE_INDEX, 8) WHEN 0 THEN 'Bike ride' WHEN 1 THEN 'Bike ride'
              WHEN 2 THEN 'Bike ride' WHEN 3 THEN 'Car ride' WHEN 4 THEN 'Car ride'
              WHEN 5 THEN 'Food delivery' WHEN 6 THEN 'Courier' ELSE 'Car XL' END AS SERVICE
  FROM draws
)
SELECT 'ZON-' || LPAD(ZONE_INDEX::VARCHAR, 4, '0') AS ID,
       CITY || ' ' || SERVICE || ' zone ' || LPAD(ZONE_INDEX::VARCHAR, 4, '0') AS NAME,
       CITY AS REGION, SERVICE AS CATEGORY, ZONE_INDEX,
       1 + FLOOR(U_TIER * 3) AS CONGESTION_TIER,
       ROUND(0.2 + U_AGE * 5.8, 1) AS ZONE_AGE_YEARS,
       -- Base daily probability of a supply shortage 0.4%-3%; ~15% of zones are
       -- chronically undersupplied (x3).
       (0.004 + U_RATE * 0.026) * IFF(U_RATE > 0.85, 3, 1) AS BASE_SHORTAGE_RATE,
       7 * (1 + FLOOR(U_PAYOUT * 3)) AS PAYOUT_INTERVAL_DAYS,
       0.55 + U_DISCIPLINE * 0.45 AS PAYOUT_ON_TIME_PROB,
       'Active' AS STATUS
FROM labelled;

CREATE TABLE RAW.ZONE_DAILY AS
WITH days AS (
  SELECT ROW_NUMBER() OVER (ORDER BY SEQ4()) - 1 AS DAY_INDEX
  FROM TABLE(GENERATOR(ROWCOUNT => 90))
), city_events AS (
  -- Two city-wide flooding days; every zone in the city loses supply for 4 hours.
  SELECT * FROM VALUES (27, 'Jakarta'), (64, 'Surabaya') AS o(DAY_INDEX, REGION)
), base AS (
  SELECT z.ID AS ENTITY_ID, z.ZONE_INDEX, z.CATEGORY, z.REGION, z.ZONE_AGE_YEARS,
         z.BASE_SHORTAGE_RATE, z.PAYOUT_INTERVAL_DAYS, z.PAYOUT_ON_TIME_PROB,
         d.DAY_INDEX,
         DATEADD('day', d.DAY_INDEX - 89, CURRENT_DATE()) AS EVENT_DATE,
         MOD(d.DAY_INDEX + z.ZONE_INDEX * 5, z.PAYOUT_INTERVAL_DAYS) AS DAYS_SINCE_PAYOUT,
         MOD(ABS(HASH(z.ID, d.DAY_INDEX, 'short')), 1000000) / 1e6 AS U_SHORT,
         MOD(ABS(HASH(z.ID, d.DAY_INDEX, 'detect')), 1000000) / 1e6 AS U_DETECT,
         MOD(ABS(HASH(z.ID, d.DAY_INDEX, 'hours')), 1000000) / 1e6 AS U_HOURS,
         MOD(ABS(HASH(z.ID, d.DAY_INDEX, 'cause')), 1000000) / 1e6 AS U_CAUSE,
         MOD(ABS(HASH(z.ID, d.DAY_INDEX, 'done')), 1000000) / 1e6 AS U_DONE,
         MOD(ABS(HASH(z.ID, d.DAY_INDEX, 'volume')), 1000000) / 1e6 AS U_VOLUME,
         MOD(ABS(HASH(z.ID, d.DAY_INDEX, 'noise')), 1000000) / 1e6 AS U_NOISE,
         e.REGION IS NOT NULL AS CITY_EVENT
  FROM RAW.ZONES z CROSS JOIN days d
  LEFT JOIN city_events e ON e.DAY_INDEX = d.DAY_INDEX AND e.REGION = z.REGION
), payouts AS (
  SELECT *,
         IFF(DAYS_SINCE_PAYOUT = 0, 1, 0) AS PAYOUT_DUE,
         IFF(DAYS_SINCE_PAYOUT = 0 AND U_DONE < PAYOUT_ON_TIME_PROB, 1, 0) AS PAYOUT_SETTLED,
         -- Driver supply drifts down between incentive payouts; late payouts
         -- carry the drift over.
         DAYS_SINCE_PAYOUT / PAYOUT_INTERVAL_DAYS + (1 - PAYOUT_ON_TIME_PROB) AS DRIFT
  FROM base
), risk AS (
  SELECT *,
         CASE WHEN U_SHORT < LEAST(0.5, BASE_SHORTAGE_RATE * (0.4 + 1.6 * DRIFT) * (1 + 1 / (1 + ZONE_AGE_YEARS))) / 4 THEN 2
              WHEN U_SHORT < LEAST(0.5, BASE_SHORTAGE_RATE * (0.4 + 1.6 * DRIFT) * (1 + 1 / (1 + ZONE_AGE_YEARS))) THEN 1
              ELSE 0 END AS SHORTAGE_RISK
  FROM payouts
), shortages AS (
  SELECT *,
         -- About 85% of at-risk days turn into measured shortage hours; surge
         -- pricing absorbs the rest.
         IFF(CITY_EVENT, 4, IFF(U_DETECT < 0.85, SHORTAGE_RISK * (1 + FLOOR(U_HOURS * 3)), 0)) AS SHORTAGE_HOURS
  FROM risk
), measured AS (
  SELECT *,
         ROUND(CASE CATEGORY WHEN 'Bike ride' THEN 4200 WHEN 'Car ride' THEN 1600
                             WHEN 'Food delivery' THEN 2600 WHEN 'Courier' THEN 650 ELSE 220 END
               * (0.7 + 0.6 * U_VOLUME) * (1 + 0.15 * SHORTAGE_RISK)) AS REQUEST_COUNT,
         CASE CATEGORY WHEN 'Bike ride' THEN 14000 WHEN 'Car ride' THEN 42000
                       WHEN 'Food delivery' THEN 58000 WHEN 'Courier' THEN 26000 ELSE 88000 END
           * (0.8 + 0.4 * U_NOISE) * (1 + 0.05 * SHORTAGE_HOURS) AS AVG_FARE_IDR
  FROM shortages
), outcomes AS (
  SELECT *,
         ROUND(REQUEST_COUNT * (0.015 + 0.01 * DRIFT + 0.025 * SHORTAGE_HOURS)) AS UNFULFILLED_COUNT,
         ROUND(REQUEST_COUNT * (0.03 + 0.02 * U_NOISE + 0.006 * SHORTAGE_HOURS)) AS CANCELLED_COUNT
  FROM measured
)
SELECT ENTITY_ID || '-' || TO_CHAR(EVENT_DATE, 'YYYYMMDD') AS EVENT_ID,
       ENTITY_ID, EVENT_DATE,
       REQUEST_COUNT,
       REQUEST_COUNT - UNFULFILLED_COUNT - CANCELLED_COUNT AS TRIP_COUNT,
       UNFULFILLED_COUNT, CANCELLED_COUNT,
       ROUND((REQUEST_COUNT - UNFULFILLED_COUNT - CANCELLED_COUNT) * AVG_FARE_IDR) AS GMV_IDR,
       SHORTAGE_HOURS,
       CASE WHEN SHORTAGE_HOURS = 0 THEN 'None'
            WHEN CITY_EVENT THEN 'City-wide flooding'
            WHEN CATEGORY = 'Bike ride' THEN IFF(U_CAUSE < 0.5, 'Peak commute', IFF(U_CAUSE < 0.8, 'Heavy rain', 'Driver payout delay'))
            WHEN CATEGORY = 'Car ride' THEN IFF(U_CAUSE < 0.45, 'Peak commute', IFF(U_CAUSE < 0.8, 'Road closure', 'Event surge'))
            WHEN CATEGORY = 'Food delivery' THEN IFF(U_CAUSE < 0.55, 'Meal-time peak', 'Heavy rain')
            WHEN CATEGORY = 'Courier' THEN IFF(U_CAUSE < 0.5, 'Driver payout delay', 'Road closure')
            ELSE IFF(U_CAUSE < 0.5, 'Airport surge', IFF(U_CAUSE < 0.75, 'Event surge', 'Driver payout delay')) END AS SHORTAGE_CAUSE,
       PAYOUT_DUE, PAYOUT_SETTLED,
       ROUND(1 + 0.08 * DRIFT + 0.12 * SHORTAGE_RISK + 0.05 * U_NOISE, 2) AS AVG_SURGE_MULT,
       ROUND(4 + 2.5 * DRIFT + 3 * SHORTAGE_RISK + U_NOISE * 1.5, 1) AS AVG_PICKUP_ETA_MIN,
       CURRENT_TIMESTAMP() AS LOADED_AT
FROM outcomes;

-- Driver compliance document checks per zone (snapshot).
CREATE TABLE RAW.DRIVER_DOCUMENTS AS
SELECT ID AS ENTITY_ID,
       CASE CATEGORY WHEN 'Bike ride' THEN 'SIM C licence check'
                     WHEN 'Car ride' THEN 'SIM A licence check'
                     WHEN 'Food delivery' THEN 'Food handling certificate'
                     WHEN 'Courier' THEN 'Vehicle registration (STNK) check'
                     ELSE 'Police clearance (SKCK) check' END AS DOC_TYPE,
       1 + MOD(ABS(HASH(ID, 'req')), 4) AS REQUIRED_QTY,
       MOD(ABS(HASH(ID, 'file')), 5) AS ON_FILE_QTY,
       IFF(MOD(ABS(HASH(ID, 'file')), 5) < 1 + MOD(ABS(HASH(ID, 'req')), 4),
           MOD(ABS(HASH(ID, 'pending')), 3), 0) AS PENDING_QTY,
       CURRENT_DATE() AS SNAPSHOT_DATE
FROM RAW.ZONES;
