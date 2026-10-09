'use client';

import { useEffect, useState } from 'react';
import { AppLayout } from '@/components/AppLayout';
import { KPICard } from '@/components/KPICard';
import { Chart } from '@/components/Chart';
import { DataTable } from '@/components/DataTable';
import { AskAI } from '@/components/AskAI';
import { ActionMemo } from '@/components/ActionMemo';

interface MarketplaceData {
  platform: 'snowflake' | 'aws';
  kpiCards: { title: string; value: string }[];
  timeseries: { period: string; unfulfilled: number | null; shortageHours: number | null }[];
  categories: { category: string; days: number | null; hours: number | null }[];
  entities: Record<string, string | number | null>[];
  payoutRisk: { name: string; payout: number; shortageHours: number }[];
  sourceWatermark: string | null;
  rawWatermark: string | null;
  requestedAt: string;
  stale: boolean;
  pipelineBehind: boolean;
  risk: Record<string, string | number | null>[];
  holdout: { n: number | null; baseRate: number | null; precision: number | null; recall: number | null } | null;
  forecast: { period: string; value: number | null; lower: number | null; upper: number | null }[];
  live: Record<string, string | number | null>[];
  liveSummary: { n: number | null; unfulfilled: number | null; lastLoaded: string | null; medianLagSeconds: number | null };
  anomalies: Record<string, string | number | null>[];
  alerts: Record<string, string | number | null>[];
}

const pct = (value: number | null) => (value === null ? 'n/a' : `${(value * 100).toFixed(0)}%`);

export default function HomePage() {
  const [data, setData] = useState<MarketplaceData | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [attempt, setAttempt] = useState(0);

  useEffect(() => {
    const controller = new AbortController();
    setLoading(true);
    setError(null);
    setData(null);
    fetch('/api/data', { cache: 'no-store', signal: controller.signal })
      .then(async (response) => {
        if (!response.ok) throw new Error('Data request failed');
        const payload = await response.json();
        if (!Array.isArray(payload.kpiCards) || !Array.isArray(payload.entities)) throw new Error('Invalid contract');
        return payload;
      })
      .then(setData)
      .catch(() => {
        if (!controller.signal.aborted) setError('Snowflake data is unavailable. No fallback values are displayed.');
      })
      .finally(() => { if (!controller.signal.aborted) setLoading(false); });
    return () => controller.abort();
  }, [attempt]);

  const isAws = (data?.platform ?? 'aws') === 'aws';
  const awsDiagram = { key: 'aws', title: 'AWS + Snowflake', src: '/architecture-aws.html' };
  const sfDiagram = { key: 'snowflake', title: 'Snowflake Only', src: '/architecture-snowflake.html' };
  const diagrams = isAws ? [awsDiagram, sfDiagram] : [sfDiagram, awsDiagram];
  const kpiVal = (title: string) => data?.kpiCards.find((card) => card.title === title)?.value ?? 'Unavailable';
  const executive = (
    <div className="space-y-6">
      <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-4">
        {['Fulfillment Rate', 'Unfulfilled Requests', 'Supply Shortage Hours', 'GMV (IDR B)'].map((title) => (
          <KPICard key={title} title={title} value={kpiVal(title)} status="neutral" />
        ))}
      </div>
      <p className="text-sm text-slate-600">Fulfillment rate = completed trips / ride and delivery requests. Unfulfilled requests found no driver. A shortage hour is an hour in a zone where requests outran available drivers. GMV is the IDR value of completed trips and orders in the snapshot.</p>
      <div className="grid grid-cols-1 gap-4 lg:grid-cols-2">
        <Chart data={data?.timeseries ?? []} type="line" xKey="period"
          yKeys={[{ key: 'unfulfilled', name: 'Unfulfilled requests' }]} title="Daily Unfulfilled Requests" />
        <Chart data={data?.categories ?? []} type="bar" xKey="category"
          yKeys={[{ key: 'hours', name: 'Shortage hours' }, { key: 'days', name: 'Shortage zone-days' }]} title="Supply Shortage by Cause" />
      </div>
      <DataTable columns={[
        { key: 'id', header: 'Zone' }, { key: 'region', header: 'City' }, { key: 'category', header: 'Service' },
        { key: 'tier', header: 'Congestion tier' }, { key: 'requests', header: 'Requests' }, { key: 'trips', header: 'Trips' },
        { key: 'unfulfilled', header: 'Unfulfilled' }, { key: 'shortageHours', header: 'Shortage hours' }, { key: 'fulfillment', header: 'Fulfillment (%)' },
        { key: 'gmv', header: 'GMV (IDR B)' },
      ]} data={data?.entities ?? []} title="Zone observations (one service in one city)" />
    </div>
  );
  const predictive = (
    <div className="space-y-4">
      <h2 className="font-semibold">7-day supply-shortage risk and unfulfilled-request forecast</h2>
      <p className="text-sm text-slate-600">
        Snowflake ML classification predicts the probability that a zone has a supply shortage in the next 7 days,
        from average surge, pickup ETA, recent shortage hours, congestion tier, zone age and service.
      </p>
      {data?.holdout ? (
        <p role="status" className="text-sm text-slate-700">
          Out-of-time holdout ({data.holdout.n} zone-days): precision {pct(data.holdout.precision)} and recall{' '}
          {pct(data.holdout.recall)} at a 0.5 threshold, versus a {pct(data.holdout.baseRate)} base rate.
        </p>
      ) : (
        <p role="status">Model outputs are not deployed. Run snowflake/05_ml.sql.</p>
      )}
      <DataTable columns={[
        { key: 'id', header: 'Zone' }, { key: 'band', header: 'Risk band' },
        { key: 'probability', header: 'P(supply shortage in 7 days)' }, { key: 'scoredAsOf', header: 'Scored as of' },
      ]} data={data?.risk ?? []} title="Supply-shortage risk by zone" />
      <Chart data={data?.forecast ?? []} type="line" xKey="period"
        yKeys={[{ key: 'value', name: 'Forecast' }, { key: 'lower', name: 'Lower' }, { key: 'upper', name: 'Upper' }]}
        title="Marketplace-wide unfulfilled-request forecast, next 14 days (requests per day)" />
      <DataTable columns={[
        { key: 'id', header: 'Zone' }, { key: 'date', header: 'Date' }, { key: 'eta', header: 'Pickup ETA (min)' },
        { key: 'expected', header: 'Expected' }, { key: 'upper', header: 'Upper bound' },
      ]} data={data?.anomalies ?? []} title="Pickup ETA anomalies, last 15 days (Snowflake ML anomaly detection, trained on the prior 75 days)" />
    </div>
  );
  const liveTab = (
    <div className="space-y-4">
      <h2 className="font-semibold">{isAws ? 'Live trips: Amazon Data Firehose to S3 to Snowpipe' : 'Live trips: Snowflake-native simulator'}</h2>
      <p className="text-sm text-slate-600">
        {isAws
          ? 'Simulated trip request events are sent to the Firehose stream id-ride-trips (aws/publish_trips.py). Firehose writes batches to S3, and Snowpipe auto-ingest loads them into RAW.LIVE_TRIPS.'
          : 'CALL APP.SIMULATE_TRIPS(n) inserts simulated trip request events directly into RAW.LIVE_TRIPS (or resume APP.TASK_SIMULATE_TRIPS for a feed every minute). This simulates a trip feed; it is not Snowpipe Streaming.'}
        {' '}The alert APP.LIVE_TRIP_ALERT logs UNFULFILLED requests and emails the on-call marketplace analyst.
      </p>
      <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-4">
        <KPICard title="Trip events loaded" value={String(data?.liveSummary?.n ?? 'n/a')} />
        <KPICard title="UNFULFILLED requests" value={String(data?.liveSummary?.unfulfilled ?? 'n/a')} />
        <KPICard title={isAws ? 'Median send to table lag (s)' : 'Median generated to table lag (s)'} value={String(data?.liveSummary?.medianLagSeconds ?? 'n/a')} />
        <KPICard title="Last load" value={data?.liveSummary?.lastLoaded ?? 'none'} />
      </div>
      <DataTable columns={[
        { key: 'id', header: 'Zone' }, { key: 'eventTs', header: 'Event (UTC)' }, { key: 'fare', header: 'Fare (IDR)' },
        { key: 'wait', header: 'Rider wait (s)' }, { key: 'status', header: 'Status' }, { key: 'loadedAt', header: 'Loaded' },
      ]} data={data?.live ?? []} title="Latest 25 trip request events" />
      <DataTable columns={[
        { key: 'id', header: 'Zone' }, { key: 'eventTs', header: 'Event (UTC)' }, { key: 'fare', header: 'Fare (IDR)' },
        { key: 'wait', header: 'Rider wait (s)' }, { key: 'hint', header: 'Action hint' },
      ]} data={data?.alerts ?? []} title="Alert log" />
    </div>
  );
  const planning = (
    <div className="space-y-6">
      <div className="grid grid-cols-1 gap-4 sm:grid-cols-3">
        <KPICard title="Driver Payout On-Time Rate" value={kpiVal('Driver Payout On-Time Rate')} />
        <KPICard title="Driver Document Coverage" value={kpiVal('Driver Document Coverage')} />
        <KPICard title="Driver Documents Pending" value={kpiVal('Driver Documents Pending')} />
      </div>
      <Chart data={data?.payoutRisk ?? []} type="scatter" xKey="payout" xName="Payout on-time rate"
        yKeys={[{ key: 'shortageHours', name: 'Shortage hours' }]} yDomain={[0, 'auto']}
        title="Driver payout on-time rate (%) vs supply shortage hours by zone" />
      <p className="text-sm text-slate-600">Synthetic associations are not evidence that on-time payouts prevented supply shortages.</p>
      <ActionMemo persona={{ name: 'Bimo Prasetyo', role: 'VP Marketplace Operations (fictional persona)' }} context={{}}
        onGenerate={async () => {
          const r = await fetch('/api/ask', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ mode: 'memo' }) });
          if (!r.ok) throw new Error('memo failed');
          const j = await r.json();
          return { subject: 'Draft marketplace operations actions (synthetic data, human review required)', body: j.answer, urgency: 'review', actions: [] };
        }} />
      <p role="status" className="text-sm text-slate-600">{isAws ? 'Draft generated by Amazon Bedrock (Claude) through a Snowflake external-access function' : 'Draft generated by Snowflake Cortex AI_COMPLETE (Claude Sonnet 4.5)'}, from the KPI, zone, shortage-cause and risk tables only. No notification is sent.</p>
    </div>
  );
  const ai = (
    <div className="space-y-4">
      <p role="status">Answers come from the Cortex Agent APP.MARKETPLACE_AGENT. It uses Cortex Analyst over the semantic view APP.RIDE_HAILING_ANALYTICS for metrics, and Cortex Search over synthetic supply-shortage playbooks for procedures. The generated SQL is shown with each answer.</p>
      <div className="h-[500px]">
        <AskAI title="Ask the marketplace operations agent" mode="advisor" sampleQuestions={['Which 3 zones have the most supply shortage hours?', 'Which zones are high risk this week and what playbook applies?', 'What is the fulfillment rate by city?']}
          onSubmit={async (question) => {
            const r = await fetch('/api/agent', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ question }) });
            if (!r.ok) throw new Error('agent failed');
            const j = await r.json();
            const cites = j.sops?.length ? `\n\nPlaybooks: ${j.sops.join(', ')}` : '';
            return { answer: `${j.answer}${cites}`, sql: j.sql ?? undefined };
          }} />
      </div>
    </div>
  );
  const architecture = (
    <div className="space-y-4">
      {diagrams.map((d, i) => (
        <div key={d.key} className="space-y-2">
          <h2 className="font-semibold">Architecture: {d.title}{i === 0 ? ' (this deployment)' : ''}</h2>
          <iframe src={d.src} title={`${d.title} architecture diagram`} className="h-[620px] w-full rounded border border-slate-200" />
          <p className="text-sm text-slate-600">Hover a component for details. <a className="underline" href={d.src} target="_blank" rel="noreferrer">Open full screen</a></p>
        </div>
      ))}
      <h2 className="font-semibold">Implementation status</h2>
      <p>Core source: synthetic service zones (one service in one of 5 Indonesian cities), daily zone observations and driver compliance documents. Curated dynamic tables compute numerator/denominator metrics and are suspended after on-demand initialization.</p>
      <p>Application: Next.js server queries the explicit curated contract. Request time and source observation watermark are separate.</p>
      <p>ML: SNOWFLAKE.ML.CLASSIFICATION supply-shortage risk model evaluated on a time-based holdout, plus a 14-day unfulfilled-request FORECAST with prediction intervals.</p>
      <p>ML: ANOMALY_DETECTION flags pickup ETA outliers per zone over the last 15 days.</p>
      <p>AI: Cortex Agent (Cortex Analyst over a semantic view, plus Cortex Search over playbooks) answers questions. The action memo uses {isAws ? 'Amazon Bedrock Claude through an external-access UDF' : 'Cortex AI_COMPLETE (Claude Sonnet 4.5)'}.</p>
      {isAws ? (
        <>
          <p>AWS ingestion: Amazon Data Firehose to S3 to Snowpipe auto-ingest (SQS) into RAW.LIVE_TRIPS, with a Snowflake alert and email on UNFULFILLED requests.</p>
          <p>QuickSight: Snowflake DIRECT_QUERY dashboard (daily unfulfilled requests, shortage hours by zone, supply-shortage risk) through a PAT-only service user, with a Q topic.</p>
        </>
      ) : (
        <>
          <p>Ingestion: APP.SIMULATE_TRIPS inserts simulated trip request events into RAW.LIVE_TRIPS, with a Snowflake alert and email on UNFULFILLED requests. No AWS account is used.</p>
          <p>BI: this SPCS app is the dashboard; natural-language questions go to the Cortex Agent.</p>
        </>
      )}
      <p>Orchestration: the task graph APP.TASK_REFRESH_CURATED, then TASK_RESCORE_RISK, runs on demand. Alerts and tasks stay suspended between demos.</p>
    </div>
  );
  const tabs = [
    { id: 'executive-cockpit', label: 'Executive Cockpit', icon: '', content: executive },
    { id: 'predictive', label: 'Predictive', icon: '', content: predictive },
    { id: 'planning', label: 'Controls', icon: '', content: planning },
    { id: 'live', label: 'Live Trips', icon: '', content: liveTab },
    { id: 'ask-ai', label: 'Ask AI', icon: '', content: ai },
    { id: 'architecture', label: 'Architecture & Data', icon: '', content: architecture },
  ].map((tab) => ({ ...tab, content: tab.id === 'architecture' ? tab.content : (
    <div className="space-y-4">
      <p className="text-sm text-slate-600">Synthetic demo data for a fictional Indonesian ride-hailing and delivery super-app. On-demand snapshots are not live customer operations.</p>
      {loading ? <p role="status">Loading Snowflake data...</p> : error ? (
        <div role="alert" className="rounded border border-red-200 p-4">
          <p>{error}</p>
          <button className="mt-3 rounded border px-3 py-2" onClick={() => setAttempt((value) => value + 1)}>Retry data connection</button>
        </div>
      ) : !data?.entities.length ? <p role="status">No zone observations are available in this snapshot.</p> : (
        <>
          <p className="text-sm">Observation watermark: {data.sourceWatermark ?? 'Unavailable'}. Request time: {data.requestedAt}.</p>
          {(data.stale || data.pipelineBehind) && <p role="status" className="text-amber-700">Stale or lagging snapshot. Refresh the on-demand pipeline before presenting current results.</p>}
          {tab.content}
        </>
      )}
    </div>
  ) }));
  return <AppLayout title="Indonesia Ride-Hailing Marketplace" tabs={tabs} />;
}
