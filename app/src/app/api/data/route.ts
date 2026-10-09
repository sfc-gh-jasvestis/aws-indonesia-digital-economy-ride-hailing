import { NextResponse } from 'next/server';
import { demoPlatform } from '@/lib/platform';
import { executeQuery } from '@/lib/snowflake';

export const dynamic = 'force-dynamic';
export const revalidate = 0;

export async function GET() {
  try {
    const [kpis, trend, causes, zones, freshness, risk, holdout, forecast, live, liveSummary, anomalies, alerts] = await Promise.all([
      executeQuery<{ TITLE: string; DISPLAY: string; STATUS: string }>(
        'SELECT TITLE, DISPLAY, STATUS FROM CURATED.KPI_SUMMARY ORDER BY SORT_ORDER'),
      executeQuery<{ PERIOD: string; UNFULFILLED: number | null; SHORTAGE_HOURS: number | null }>(`
        SELECT TO_CHAR(METRIC_DATE, 'YYYY-MM-DD') AS PERIOD,
               UNFULFILLED_COUNT AS UNFULFILLED, SHORTAGE_HOURS
        FROM CURATED.TREND_ANALYSIS ORDER BY METRIC_DATE`),
      executeQuery<{ SHORTAGE_CAUSE: string; SHORTAGE_DAYS: number; SHORTAGE_HOURS: number }>(`
        SELECT SHORTAGE_CAUSE, SHORTAGE_DAYS, SHORTAGE_HOURS
        FROM CURATED.CAUSE_SUMMARY ORDER BY SHORTAGE_HOURS DESC, SHORTAGE_DAYS DESC`),
      executeQuery<Record<string, string | number | null>>(`
        SELECT ENTITY_ID, ENTITY_NAME, REGION, CATEGORY, CONGESTION_TIER, EVENT_COUNT, REQUEST_COUNT, TRIP_COUNT,
               UNFULFILLED_COUNT, SHORTAGE_HOURS, ROUND(FULFILLMENT_PCT, 1) AS FULFILLMENT_PCT,
               PAYOUT_ON_TIME_PCT, ROUND(GMV_IDR / 1e9, 2) AS GMV_IDR_B
        FROM CURATED.PERFORMANCE_SUMMARY ORDER BY ENTITY_ID LIMIT 200`),
      executeQuery<{ RAW_WATERMARK: string | null; CURATED_WATERMARK: string | null }>(`
        SELECT (SELECT TO_CHAR(MAX(EVENT_DATE), 'YYYY-MM-DD') FROM RAW.ZONE_DAILY) AS RAW_WATERMARK,
               (SELECT TO_CHAR(MAX(METRIC_DATE), 'YYYY-MM-DD') FROM CURATED.TREND_ANALYSIS) AS CURATED_WATERMARK`),
      executeQuery<Record<string, string | number | null>>(`
        SELECT ENTITY_ID, TO_CHAR(SCORED_AS_OF, 'YYYY-MM-DD') AS SCORED_AS_OF, SHORTAGE_PROB_7D, RISK_BAND
        FROM ML.SHORTAGE_RISK_SCORES ORDER BY SHORTAGE_PROB_7D DESC`),
      executeQuery<Record<string, string | number | null>>(
        'SELECT N, BASE_RATE, PRECISION_AT_50, RECALL_AT_50 FROM ML.SHORTAGE_RISK_HOLDOUT_METRICS'),
      executeQuery<Record<string, string | number | null>>(`
        SELECT TO_CHAR(FORECAST_DATE, 'YYYY-MM-DD') AS PERIOD, UNFULFILLED_COUNT, LOWER_BOUND, UPPER_BOUND
        FROM ML.UNFULFILLED_FORECAST ORDER BY FORECAST_DATE`),
      executeQuery<Record<string, string | number | null>>(`
        SELECT ZONE_ID, TO_CHAR(EVENT_TS, 'YYYY-MM-DD HH24:MI:SS') AS EVENT_TS, ROUND(FARE_IDR, 0) AS FARE_IDR,
               WAIT_SECONDS, STATUS, TO_CHAR(LOADED_AT, 'YYYY-MM-DD HH24:MI:SS TZH:TZM') AS LOADED_AT
        FROM RAW.LIVE_TRIPS ORDER BY EVENT_TS DESC LIMIT 25`),
      executeQuery<Record<string, string | number | null>>(`
        SELECT COUNT(*) AS N, COUNT_IF(STATUS = 'UNFULFILLED') AS UNFULFILLED,
               TO_CHAR(MAX(LOADED_AT), 'YYYY-MM-DD HH24:MI:SS TZH:TZM') AS LAST_LOADED,
               ROUND(MEDIAN(DATEDIFF('second', SENT_TS, CONVERT_TIMEZONE('UTC', LOADED_AT)::TIMESTAMP_NTZ)), 0) AS MEDIAN_LAG_S
        FROM RAW.LIVE_TRIPS`),
      executeQuery<Record<string, string | number | null>>(`
        SELECT ENTITY_ID, TO_CHAR(EVENT_DATE, 'YYYY-MM-DD') AS EVENT_DATE, ROUND(PICKUP_ETA, 1) AS PICKUP_ETA,
               ROUND(EXPECTED, 1) AS EXPECTED, ROUND(UPPER_BOUND, 1) AS UPPER_BOUND
        FROM ML.PICKUP_ETA_ANOMALIES WHERE IS_ANOMALY ORDER BY EVENT_DATE DESC, ENTITY_ID LIMIT 50`),
      executeQuery<Record<string, string | number | null>>(`
        SELECT ZONE_ID, TO_CHAR(EVENT_TS, 'YYYY-MM-DD HH24:MI:SS') AS EVENT_TS, ROUND(FARE_IDR, 0) AS FARE_IDR,
               WAIT_SECONDS, PLAYBOOK_HINT
        FROM APP.ALERT_LOG ORDER BY ALERTED_AT DESC, EVENT_TS DESC LIMIT 25`),
    ]);
    const numberOrNull = (value: unknown): number | null => {
      if (value === null || value === undefined) return null;
      const numeric = Number(value);
      if (!Number.isFinite(numeric)) throw new Error('Non-numeric measure in curated contract');
      return numeric;
    };
    const watermark = freshness[0]?.CURATED_WATERMARK ?? null;
    const ageDays = watermark ? (Date.now() - Date.parse(`${watermark}T00:00:00Z`)) / 86400000 : null;
    return NextResponse.json({
      platform: demoPlatform(),
      kpiCards: kpis.map((row) => ({ title: row.TITLE, value: row.DISPLAY, status: row.STATUS })),
      timeseries: trend.map((row) => ({ period: row.PERIOD, unfulfilled: numberOrNull(row.UNFULFILLED), shortageHours: numberOrNull(row.SHORTAGE_HOURS) })),
      categories: causes.map((row) => ({ category: row.SHORTAGE_CAUSE, days: numberOrNull(row.SHORTAGE_DAYS), hours: numberOrNull(row.SHORTAGE_HOURS) })),
      entities: zones.map((row) => ({
        id: row.ENTITY_ID, name: row.ENTITY_NAME, region: row.REGION, category: row.CATEGORY, tier: row.CONGESTION_TIER,
        requests: numberOrNull(row.REQUEST_COUNT), trips: numberOrNull(row.TRIP_COUNT), unfulfilled: numberOrNull(row.UNFULFILLED_COUNT),
        shortageHours: numberOrNull(row.SHORTAGE_HOURS), fulfillment: numberOrNull(row.FULFILLMENT_PCT),
        gmv: numberOrNull(row.GMV_IDR_B), payout: numberOrNull(row.PAYOUT_ON_TIME_PCT), events: numberOrNull(row.EVENT_COUNT),
      })),
      payoutRisk: zones.map((row) => ({
        name: row.ENTITY_NAME, payout: numberOrNull(row.PAYOUT_ON_TIME_PCT), shortageHours: numberOrNull(row.SHORTAGE_HOURS),
      })).filter((row) => row.payout !== null && row.shortageHours !== null),
      sourceWatermark: watermark,
      rawWatermark: freshness[0]?.RAW_WATERMARK ?? null,
      stale: ageDays === null || ageDays > 2,
      pipelineBehind: freshness[0]?.RAW_WATERMARK !== watermark,
      requestedAt: new Date().toISOString(),
      synthetic: true,
      risk: risk.map((row) => ({
        id: row.ENTITY_ID, scoredAsOf: row.SCORED_AS_OF,
        probability: numberOrNull(row.SHORTAGE_PROB_7D), band: row.RISK_BAND,
      })),
      holdout: holdout[0] ? {
        n: numberOrNull(holdout[0].N), baseRate: numberOrNull(holdout[0].BASE_RATE),
        precision: numberOrNull(holdout[0].PRECISION_AT_50), recall: numberOrNull(holdout[0].RECALL_AT_50),
      } : null,
      forecast: forecast.map((row) => ({
        period: row.PERIOD, value: numberOrNull(row.UNFULFILLED_COUNT),
        lower: numberOrNull(row.LOWER_BOUND), upper: numberOrNull(row.UPPER_BOUND),
      })),
      modelStatus: holdout[0] ? 'holdout_evaluated' : 'missing',
      live: live.map((row) => ({
        id: row.ZONE_ID, eventTs: row.EVENT_TS, fare: numberOrNull(row.FARE_IDR),
        wait: numberOrNull(row.WAIT_SECONDS), status: row.STATUS, loadedAt: row.LOADED_AT,
      })),
      liveSummary: {
        n: numberOrNull(liveSummary[0]?.N), unfulfilled: numberOrNull(liveSummary[0]?.UNFULFILLED),
        lastLoaded: liveSummary[0]?.LAST_LOADED ?? null, medianLagSeconds: numberOrNull(liveSummary[0]?.MEDIAN_LAG_S),
      },
      anomalies: anomalies.map((row) => ({
        id: row.ENTITY_ID, date: row.EVENT_DATE, eta: numberOrNull(row.PICKUP_ETA),
        expected: numberOrNull(row.EXPECTED), upper: numberOrNull(row.UPPER_BOUND),
      })),
      alerts: alerts.map((row) => ({
        id: row.ZONE_ID, eventTs: row.EVENT_TS, fare: numberOrNull(row.FARE_IDR),
        wait: numberOrNull(row.WAIT_SECONDS), hint: row.PLAYBOOK_HINT,
      })),
    }, { headers: { 'Cache-Control': 'no-store' } });
  } catch {
    return NextResponse.json({ error: 'Marketplace data is unavailable. Verify the core deployment and application role.' },
      { status: 503, headers: { 'Cache-Control': 'no-store' } });
  }
}
