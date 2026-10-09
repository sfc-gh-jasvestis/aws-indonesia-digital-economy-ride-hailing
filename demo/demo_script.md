# Ride-Hailing Marketplace Operations

**Indonesia - Ride-Hailing and Delivery Super-App**
Use case: Driver supply shortages, request fulfillment and marketplace operations risk

> Operations monitoring for 40 service zones of a fictional Indonesian super-app across Jakarta, Surabaya, Bandung, Medan and Denpasar: dynamic tables, a holdout-evaluated supply-shortage classifier, an unfulfilled-request forecast and grounded AI answers.

## Why Snowflake

- **Dynamic tables** reconcile requests, completed trips, unfulfilled requests, cancellations, shortage hours and driver payout timeliness from RAW zone data, with checks in `run_core.py`
- **Supply-shortage classification** gives a holdout-evaluated next-7-day probability per zone
- **Unfulfilled-request forecast** projects 14 days of marketplace-wide unfulfilled requests with prediction intervals, for driver incentive planning
- **Grounded AI**: the Cortex Agent (Analyst over a semantic view, plus Search over playbooks) shows its SQL and playbook citations
- **Live trips**: a native simulator (Snowflake only) or Firehose, S3 and Snowpipe (AWS build), then an alert and email

## What is built

| | |
|---|---|
| Dimension table | `RAW.ZONES` (40 rows) |
| Fact table | `RAW.ZONE_DAILY` (3,600 zone-days, 90 days) |
| Curated layer | `CURATED.KPI_SUMMARY`, `PERFORMANCE_SUMMARY`, `CAUSE_SUMMARY`, `TREND_ANALYSIS` |
| ML | `ML.SHORTAGE_RISK_SCORES`, `ML.SHORTAGE_RISK_HOLDOUT_METRICS`, `ML.UNFULFILLED_FORECAST`, `ML.PICKUP_ETA_ANOMALIES` |

Cities: Jakarta, Surabaya, Bandung, Medan, Denpasar. Services: Bike ride, Car ride, Food delivery, Courier, Car XL.
The super-app is fictional; values are in IDR.

## KPI cards (live from `CURATED.KPI_SUMMARY`; no fallback values)

| Card | Value from the seeded data |
|---|---|
| Fulfillment Rate | 93.4% |
| Unfulfilled Requests | 220,569 |
| Supply Shortage Hours | 387 |
| Rider Cancellation Rate | 4.1% |
| Shortage Zone-Days | 146 |
| GMV (IDR B) | 213 |
| Trips Completed | 8,221,526 |
| Driver Payout On-Time Rate | 79.4% |
| Zones Monitored | 40 |
| Driver Document Coverage | 66.7% |
| Driver Documents Pending | 20 |

Values are synthetic. A rebuild reproduces them because the data is HASH-seeded; dates are relative to the build day.

## Demo flow

1. Executive Cockpit: KPIs, daily unfulfilled requests, supply shortage by cause, zone table
2. Predictive: holdout metrics, risk bands, 14-day unfulfilled-request forecast, pickup ETA anomalies
3. Controls: driver payout on-time rate, driver document coverage and pending checks, payout on-time rate against shortage hours, then generate the action memo
4. Live Trips: run `CALL APP.SIMULATE_TRIPS(20)` (Snowflake only) or `python aws/publish_trips.py --count 20` (AWS build). Then run `EXECUTE ALERT APP.LIVE_TRIP_ALERT` and show the alert log and email.
5. Ask AI: the Cortex Agent answers metric questions through the semantic view and cites playbooks from Cortex Search. The SQL is shown.
6. QuickSight (AWS build): the same Snowflake tables through DIRECT_QUERY
7. Architecture: both builds side by side

## Talking points

- 93.4% of requests end as completed trips; the 220,569 unfulfilled requests are where marketplace operations time goes.
- Peak commute causes the most shortage hours (96 of 387). The two city-wide flooding days hit every zone in Jakarta or Surabaya at once.
- The risk model is evaluated on a time-based holdout: precision 0.32 and recall 0.18 at 0.5, against a 0.24 base rate. Present it as triage, not a verdict.
- City-wide flooding days are excluded from model training, because they are not zone-driven.

## Business impact

Use only the sourced references in `README.md` (Business Impact).
