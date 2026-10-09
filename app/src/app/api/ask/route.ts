import { NextResponse } from 'next/server';
import { executeQuery } from '@/lib/snowflake';
import { demoPlatform } from '@/lib/platform';

export const dynamic = 'force-dynamic';

// Only these fixed, read-only queries can run. The model never writes SQL; it
// only summarises rows returned here, so every answer is traceable to data.
const INTENTS: Record<string, { match: RegExp; sql: string }> = {
  zones: {
    match: /zone|shortage|unfulfil|worst|highest|city|service/i,
    sql: `SELECT ENTITY_ID, ENTITY_NAME, REGION, CATEGORY, SHORTAGE_HOURS, SHORTAGE_DAYS, UNFULFILLED_COUNT, ROUND(FULFILLMENT_PCT, 1) AS FULFILLMENT_PCT
FROM CURATED.PERFORMANCE_SUMMARY
QUALIFY DENSE_RANK() OVER (ORDER BY SHORTAGE_HOURS DESC) <= 3
ORDER BY SHORTAGE_HOURS DESC, UNFULFILLED_COUNT DESC`,
  },
  causes: {
    match: /cause|reason|why|rain|flood|peak/i,
    sql: `SELECT SHORTAGE_CAUSE, SHORTAGE_DAYS, SHORTAGE_HOURS, UNFULFILLED_COUNT, ROUND(UNFULFILLED_PCT, 1) AS UNFULFILLED_PCT
FROM CURATED.CAUSE_SUMMARY ORDER BY SHORTAGE_HOURS DESC LIMIT 8`,
  },
  kpis: {
    match: /.*/,
    sql: `SELECT TITLE, DISPLAY, SOURCE_WATERMARK FROM CURATED.KPI_SUMMARY ORDER BY SORT_ORDER`,
  },
};

const DEFINITIONS =
  'Fulfillment rate = completed trips / ride and delivery requests. Unfulfilled requests found no driver; rider cancellations are counted separately. ' +
  'A shortage hour is an hour in a zone where requests outran available drivers. City-wide flooding hits every zone in a city at once and is not zone-driven. ' +
  'GMV is in IDR. Zones are one service in one Indonesian city. All data is synthetic demo data.';

// provider 'cortex' = Snowflake AI_COMPLETE; 'bedrock' = Amazon Bedrock Claude
// via the external-access UDF APP.BEDROCK_GENERATE (aws/setup_aws.py).
async function summarise(question: string, rows: unknown[], provider: 'cortex' | 'bedrock' = 'cortex'): Promise<string> {
  const prompt =
    'You are a marketplace operations analyst at an Indonesian ride-hailing and delivery super-app. Answer ONLY from the JSON rows and definitions below. ' +
    'If the rows do not answer the question, say so. Do not invent numbers. Keep it under 120 words.\n' +
    `Definitions: ${DEFINITIONS}\nRows: ${JSON.stringify(rows)}\nQuestion: ${question}`;
  const out = await executeQuery<{ R: string }>(
    provider === 'bedrock' ? 'SELECT APP.BEDROCK_GENERATE(?) AS R' : `SELECT AI_COMPLETE('claude-sonnet-4-5', ?) AS R`,
    [prompt],
  );
  const raw = String(out[0]?.R ?? '').trim();
  // AI_COMPLETE returns a JSON string literal; decode it when present.
  try {
    const parsed = JSON.parse(raw);
    return typeof parsed === 'string' ? parsed : raw;
  } catch {
    return raw;
  }
}

export async function POST(req: Request) {
  let body: any;
  try {
    body = await req.json();
  } catch {
    return NextResponse.json({ error: 'Invalid JSON' }, { status: 400 });
  }
  const question = typeof body?.question === 'string' ? body.question.trim().slice(0, 2000) : '';
  const memo = body?.mode === 'memo';
  if (!memo && !question) return NextResponse.json({ error: 'Question required' }, { status: 400 });

  try {
    if (memo) {
      const provider = demoPlatform() === 'aws' ? 'bedrock' : 'cortex';
      const [kpis, zones, causes, risk, bands] = await Promise.all([
        executeQuery(INTENTS.kpis.sql),
        executeQuery(INTENTS.zones.sql),
        executeQuery(INTENTS.causes.sql),
        executeQuery(`SELECT ENTITY_ID, ROUND(SHORTAGE_PROB_7D, 2) AS SHORTAGE_PROB_7D, RISK_BAND
FROM ML.SHORTAGE_RISK_SCORES ORDER BY SHORTAGE_PROB_7D DESC LIMIT 5`),
        executeQuery(`SELECT RISK_BAND, COUNT(*) AS ZONES FROM ML.SHORTAGE_RISK_SCORES GROUP BY RISK_BAND`),
      ]);
      const rows = { kpis, topShortageZones: zones, shortageCauses: causes, top5ByRisk: risk, zonesPerRiskBand: bands };
      const answer = await summarise(
        'Draft a short action memo for the VP Marketplace Operations with 3 prioritised actions, citing the figures.',
        [rows],
        provider,
      );
      return NextResponse.json({ answer, sources: rows, provider: provider === 'bedrock' ? 'Amazon Bedrock (Claude Sonnet 4.5)' : 'Snowflake Cortex AI_COMPLETE (claude-sonnet-4-5)', draft: true, synthetic: true });
    }
    const key = Object.keys(INTENTS).find((k) => INTENTS[k].match.test(question))!;
    const rows = await executeQuery(INTENTS[key].sql);
    const answer = await summarise(question, rows);
    return NextResponse.json({ answer, sql: INTENTS[key].sql, sources: rows, synthetic: true });
  } catch (err) {
    console.error('ask route failed', err);
    return NextResponse.json({ error: 'AI service unavailable' }, { status: 503 });
  }
}
