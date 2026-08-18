# Power BI Dashboard — Build Guide

This is a build-ready spec for the 3-page dashboard described in the
project. Every number and definition here comes from the validated SQL
in `sql/05_metrics/` and `sql/07_powerbi/` — nothing below asks you to
compute or redefine a metric in Power BI. Follow it top to bottom in
Power BI Desktop; it should take about 20-30 minutes.

**Why this is a guide and not a finished `.pbix`/`.pbip` file:** a
hand-authored Power BI project file was attempted first. Power BI
Desktop's project-file format (`.pbip`) turned out to require internal
manifest files that aren't part of any documentation available here, and
the first attempt failed to open (`Cannot find file 'version.json'`,
confirmed by actually launching Power BI Desktop against it). Rather than
ship a broken file or keep guessing at an undocumented format through
more trial and error, the SQL/data-model design work is handed off here
in a form that's guaranteed to work: you build it in the GUI, which does
this correctly by construction.

## 1. Start the database

```bash
./setup.sh
```

Confirms Postgres is running on `localhost:5432` with the `roas` schema
loaded and validated (36/36 checks passing).

## 2. Connect Power BI to Postgres

`Get Data` → `PostgreSQL database`
- Server: `localhost:5432`
- Database: `roas`
- Data Connectivity mode: **Import**
- Credentials: username `roas`, password `roas` (from `docker-compose.yml`)

In the Navigator, under schema `roas`, select these 7 objects and click
**Transform Data** (not Load directly — so you can rename appropriately
if you want, though no transforms are required):

| Object | Used on |
|---|---|
| `pbi_executive_summary` | Page 1 |
| `pbi_channel_performance` | Page 1, Page 2 |
| `pbi_campaign_performance` | Page 2 |
| `pbi_monthly_trend` | Page 1 |
| `pbi_cohort_retention` | Page 3 |
| `mart_channel_retention` | Page 3 |
| `pbi_rfm_segments` | Page 3 |

No Power Query transforms needed — every view already has exactly the
shape/grain the visuals need. Click **Close & Apply**.

## 3. DAX measures (5 total — all one-liners)

These exist only so slicers/cross-filtering aggregate correctly (a plain
column `SUM` of a ratio like CAC would be wrong across a multi-channel
selection). Everything else on the dashboard binds directly to a column.

On **`pbi_executive_summary`**:
```dax
Total Revenue = SUM(pbi_executive_summary[total_revenue])
Total Spend = SUM(pbi_executive_summary[total_spend])
Marketing Contribution = SUM(pbi_executive_summary[marketing_contribution])
```

On **`pbi_channel_performance`**:
```dax
Blended CAC = DIVIDE(SUM(pbi_channel_performance[total_spend]), SUM(pbi_channel_performance[customers_acquired]))
Blended ROAS (Lifetime) = DIVIDE(SUM(pbi_channel_performance[revenue_lifetime]), SUM(pbi_channel_performance[total_spend]))
```

(`pbi_executive_summary` is a single unfiltered row, so its own columns
like `roas_lifetime`, `blended_cac`, `avg_ltv_lifetime` can be used
directly on cards with no measure needed — they're already the correct
account-wide numbers.)

## 4. Page 1 — Executive Overview

*Answers: "How is marketing performing overall?"*

**6 KPI cards** in a row across the top, each a `Card` visual bound to
`pbi_executive_summary`:
1. Total Revenue (Lifetime) → measure `Total Revenue`
2. Total Marketing Spend → measure `Total Spend`
3. ROAS (Lifetime) → column `roas_lifetime`
4. Blended CAC → column `blended_cac`
5. Observed LTV (Lifetime, avg) → column `avg_ltv_lifetime`
6. Marketing Contribution → measure `Marketing Contribution`

Note: LTV:CAC is deliberately **not** a 7th card — at this blended grain
it's mathematically identical to ROAS (see `sql/05_metrics/ltv_cac.sql`),
so showing both would just duplicate one ratio under two names.
Marketing Contribution covers the "different signal" slot instead.

**Line chart** (bottom-left, ~half width): `pbi_monthly_trend`
- X axis: `month`
- Y values: `total_spend`, `total_revenue`
- Title: "Revenue vs. Spend by Month"

**Clustered column chart** (bottom-right, ~half width): `pbi_channel_performance`
- X axis: `channel_name`
- Y value: `marketing_contribution`
- Title: "Marketing Contribution by Channel"

## 5. Page 2 — Channel & Campaign Performance

*Answers: "Which channels/campaigns deserve attention or budget?"*

**Table** (full width, top): `pbi_channel_performance`, columns in order:
`channel_name, total_spend, conversion_rate_pct, cac, revenue_lifetime,
roas_lifetime, avg_ltv_lifetime, ltv_cac_lifetime,
marketing_contribution, recommendation`

The `recommendation` column already contains the Scale/Maintain/Review/
Reduce labels from `sql/05_metrics/budget_allocation.sql` — this table
alone answers the page's core question. Only 6 rows (one per channel),
so it stays scannable.

**Scatter chart** (bottom-left): `pbi_channel_performance`
- X axis: `cac`
- Y axis: `avg_ltv_lifetime`
- Size: `customers_acquired`
- Legend/Category: `channel_name`
- Title: "CAC vs. Observed LTV by Channel (bubble size = customers acquired)"

**Table** (bottom-right): `pbi_campaign_performance`, columns:
`channel_name, campaign_name, total_spend, cac, roas_lifetime,
ltv_cac_lifetime, marketing_contribution` — 40 rows, sortable, gives
campaign-level drill-down under the channel summary above.

(Acquisition funnel visual intentionally omitted — the channel table
already carries conversion rate, and a 6-channel funnel adds clutter
without much extra insight; skip unless you want a 4th visual.)

## 6. Page 3 — Customer Cohorts & Segmentation

*Answers: "Are customers being retained, and which segments matter?"*

**Matrix** (top, full width): `pbi_cohort_retention`
- Rows: `cohort_month`
- Columns: `months_since_acquisition`
- Values: `retention_rate_pct`
- Title: "Cohort Retention Heatmap"
- **To get the actual heatmap look**: select the matrix → Format pane →
  `Cell elements` → turn on background color for `retention_rate_pct`,
  set the color scale (e.g. red at 0%, yellow midpoint, green at 100%).
  This is a ~30-second GUI step, not a new calculation.

**Line chart** (bottom-left): `mart_channel_retention`
- X axis: `months_since_acquisition`
- Y value: `retention_rate_pct`
- Legend/Series: `channel_name`
- Title: "Retention by Months Since Acquisition, by Channel"

**Two clustered column charts** (bottom-right, side by side): both from `pbi_rfm_segments`
- Chart A — X: `segment`, Y: `customers` — "Customers by RFM Segment"
- Chart B — X: `segment`, Y: `pct_of_revenue` — "Revenue Share by RFM Segment"

## 7. General formatting

- Report theme: any built-in Power BI theme is fine; keep it consistent
  across all 3 pages.
- Turn off the default "Total" row on the two performance tables for
  ratio columns (CAC, ROAS, LTV:CAC, conversion rate) if Power BI adds
  one automatically — a summed ratio is meaningless (this is exactly why
  those columns were set to non-additive `summarizeBy: none` semantics
  in the SQL views; Power BI's table visual may still show a sum unless
  you turn the totals row off in the table's Format pane).
- No slicers are required for the dashboard to make sense as-is; if you
  want one, a single `channel_name` slicer on Page 2 is the most useful
  addition (cross-filters the table, scatter, and campaign table
  together since they're all on the same page).
- Add a footer text box on Page 1: *"Synthetic dataset — seed=42,
  deterministically generated. Not real business data."*

## 8. Save

`File → Save As → Power BI project (.pbip)` (or plain `.pbix` if you
prefer a single file) into this `powerbi/` folder. Either way, once
saved by Power BI Desktop itself the file will be correctly formed —
today's failure was specific to a hand-authored project skipping
internal files Power BI's own save process includes automatically.
