# Ride-Hailing & Super-App Analytics

**Indonesia - Digital Economy & E-Commerce**
Use case: Ride-Hailing & On-Demand Services

> Real-time demand-supply matching intelligence for Indonesia's super-app economy — ML.FORECAST predicts ride demand, Dynamic Tables build driver allocation dashboards, and Cortex AI generates surge pricing recommendations.

## Why Snowflake

Snowflake powers super-app intelligence — Dynamic Tables maintain real-time demand-supply balance, ML.FORECAST projects demand by zone, and Cortex AI optimizes pricing and driver allocation across transport, food, and payments

- **ML.FORECAST for 30-minute demand prediction by zone** - Only demo using ML.FORECAST for ride-hailing demand forecasting at zone level
- **Real-time demand-supply balance via Dynamic Tables** - 5-minute refresh of 500M monthly demand events for operational decisions
- **AI-generated pricing and allocation recommendations** - Cortex AI produces zone-level surge and driver allocation strategies
- **Indonesian super-app context** - 100M trips/month, 2M drivers, Gojek/Grab competitive dynamics, Rupiah economics

## What is deployed

| | |
|---|---|
| Database | `ID_DIGITAL_ECONOMY_RIDE_HAILING` |
| Service | `ID_DIGITAL_ECONOMY_RIDE_HAILING_APP` |
| Compute pool | `SEA_DEMOS_INDONESIA_POOL` |
| Dimension table | `RAW.ZONE_CONFIG` (20 rows) |
| Fact table | `RAW.DEMAND_EVENTS` (250,000 rows, 90 days) |
| Curated layer | `CURATED.PERFORMANCE_SUMMARY`, `CURATED.TREND_ANALYSIS`, `CURATED.KPI_SUMMARY` |
| Currency | IDR (Rp) |

Regions in play: Jakarta, North Sumatra, Riau, East Kalimantan, Sulawesi
Segments: Motorbike, Car Economy, Car Premium, Food Delivery

Dynamic tables are created suspended and refreshed on demand:

```bash
./refresh_demo_data.sh ID_DIGITAL_ECONOMY_RIDE_HAILING
```

## KPI cards

Every card below is served live from `CURATED.KPI_SUMMARY`. The app keeps the
original literal as a fallback, so it still renders if Snowflake is unreachable.

| Card | Value | Backed by |
|---|---|---|
| Rides (MTD) | `42M` | total across Zone Config |
| Driver Utilization | `68%` | average per event |
| Avg Wait Time | `4.2 min` | average per event |
| Active Drivers | `412K` | total across Zone Config |
| Surge Pricing Active | `12%` | total across Zone Config |
| ETA Accuracy | `94%` | average per event |
| Cancellation Rate | `8.4%` | average per event |


## Demo flow

1. Command Center
2. Demand & Supply
3. Driver Economics
4. Ask AI
5. Architecture & Data

## Talking points

- **100M trips/month** - across ride, food, and courier services
- **89% fulfillment** - trip completion rate (target: 93%)
- **2M drivers** - active driver-partners on platform
- **500M events/month** - demand events processed in real-time
- **Rp 45B/week** - incentive spend on driver and rider campaigns

## Business impact

- Indonesia's ride-hailing and on-demand services market valued at US$7.5B in 2023 (Google-Temasek-Bain SEA Report)
- Gojek and Grab combined serve 38 million MAU in Indonesia across transport, food, and payments (App Annie)
- 1% improvement in fulfillment rate = US$50-75M additional annual revenue at Indonesian scale (McKinsey Mobility)
- ML-optimized pricing increases marketplace revenue by 8-15% while maintaining demand (MIT Operations Research)

---
Generated from `generator/demo_specs/aws-indonesia-digital-economy-ride-hailing.json`. Do not hand-edit: run
`python3 generator/gen_repo_docs.py aws-indonesia-digital-economy-ride-hailing` instead.
