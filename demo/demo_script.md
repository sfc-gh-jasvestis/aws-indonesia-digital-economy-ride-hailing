# Demo Script: Ride-Hailing & Super-App Analytics
## ~4-Minute Recorded Walkthrough
**Format**: Screen recording with voiceover
**Target**: Customer meeting / booth loop / social share
**Narrative**: "Snowflake powers super-app intelligence — Dynamic Tables maintain real-time demand-supply balance, ML.FORECAST projects demand by zone, and Cortex AI optimizes pricing and driver allocation across transport, food, and payments"
**Demo Mode**: Open app with `?demo=true` for presenter notes

---

## Two Personas

| Persona | Role | Tool | What they care about |
|---|---|---|---|
| **Bimo Prasetyo** | VP Marketplace Operations | React App (SPCS) | Supply-demand balance, driver earnings, surge management, service reliability |
| **Citra Handayani** | Pricing & Incentives Lead | Amazon QuickSight | Dynamic pricing effectiveness, driver incentive ROI, demand elasticity, competitor pricing |

---

## What's Built

| Layer | Component | Detail |
|---|---|---|
| **RAW** | 6 tables | TRIPS (100000000), DRIVERS (2000000), DEMAND_EVENTS (500000000), PRICING_LOGS (50000000), INCENTIVES (5000000), ZONE_CONFIG (5000) |
| **CURATED** | 4 Dynamic Tables | DEMAND_SUPPLY_BALANCE, FULFILLMENT_METRICS, DRIVER_ECONOMICS, PRICING_EFFECTIVENESS |
| **ML** | ML.FORECAST | Forecasting + anomaly detection |
| **AI** | COMPLETE, AI_CLASSIFY, SUMMARIZE | Classification + extraction |
| **Search** | Cortex Search | 5000 documents indexed |
| **Agent** | MARKETPLACE_OPS_AGENT | Semantic View + Search tools |


---

## The Story

Indonesia's super-app market processes 100 million monthly trips, but fulfillment rates are slipping as driver supply struggles to match peak demand. With surge pricing effectiveness declining and driver churn at 8% monthly, the VP Marketplace needs real-time demand-supply intelligence and ML-powered allocation — not post-hoc analysis of yesterday's failures.

---

## Script

### [0:00–0:45] COMMAND CENTER

**Show**: Command Center tab

> "100 million trips per month across ride, food, and courier — fulfillment at 89%."

**Action**: Point at 100M trips and 89% fulfillment

### [0:45–1:30] DEMAND & SUPPLY

**Show**: Demand & Supply tab

> "ML.FORECAST predicts demand 30 minutes ahead per zone — enables proactive driver allocation."

**Action**: Show demand forecast vs actual by zone

### [1:30–2:15] DRIVER ECONOMICS

**Show**: Driver Economics tab

> "Average driver earning Rp 180K/day — 15% below 6-month ago (competition effect)."

**Action**: Show driver earnings distribution

### [2:15–3:00] ASK AI

**Show**: Ask AI tab

> "Bimo asks: 'What's the current fulfillment rate across all services?'"

**Action**: Type fulfillment question

### [3:00–3:45] ARCHITECTURE & DATA

**Show**: Architecture & Data tab

> "Six Snowflake capabilities, six AWS services."

**Action**: Walk through architecture diagram


---

## Key Demo Differentiators

1. **ML.FORECAST for 30-minute demand prediction by zone** — Only demo using ML.FORECAST for ride-hailing demand forecasting at zone level
2. **Real-time demand-supply balance via Dynamic Tables** — 5-minute refresh of 500M monthly demand events for operational decisions
3. **AI-generated pricing and allocation recommendations** — Cortex AI produces zone-level surge and driver allocation strategies
4. **Indonesian super-app context** — 100M trips/month, 2M drivers, Gojek/Grab competitive dynamics, Rupiah economics


---

## Demo Prep Checklist

### Data Verification
- [ ] `SELECT COUNT(*) FROM RIDE_HAILING_ANALYTICS.RAW.TRIPS` → 100000000
- [ ] `SELECT COUNT(*) FROM RIDE_HAILING_ANALYTICS.RAW.DRIVERS` → 2000000
- [ ] `SELECT COUNT(*) FROM RIDE_HAILING_ANALYTICS.RAW.DEMAND_EVENTS` → 500000000

### ML Model Verification
- [ ] `SELECT COUNT(*) FROM RIDE_HAILING_ANALYTICS.ML.DEMAND_FORECAST_RESULTS` → >0

### AI/Agent Verification
- [ ] `SELECT COUNT(*) FROM RIDE_HAILING_ANALYTICS.AI.CANCELLATION_CLASSIFICATION` → >0

