#!/usr/bin/env bash
# ============================================================
# End-to-end reproducible setup for the marketing analytics project.
#   1. start Postgres via docker-compose
#   2. create the schema
#   3. generate the deterministic synthetic dataset
#   4. load it
#   5. build staging/mart views
#   6. run data-quality validation
# ============================================================
set -euo pipefail

PSQL="docker compose exec -T db psql -U roas -d roas -v ON_ERROR_STOP=1"

echo "==> Starting Postgres..."
docker compose up -d

echo "==> Waiting for Postgres to accept connections..."
until docker compose exec -T db pg_isready -U roas -d roas >/dev/null 2>&1; do
  sleep 1
done

echo "==> Creating schema..."
$PSQL -f /sql/01_schema/001_schema.sql

echo "==> Generating synthetic data (seed=42)..."
python "sql/02_seed/generate_data.py"

echo "==> Loading data..."
$PSQL -f /sql/02_seed/002_load_data.sql

echo "==> Building staging views..."
$PSQL -f /sql/03_staging/stg_campaigns.sql
$PSQL -f /sql/03_staging/stg_customers.sql

echo "==> Building mart views (Phase 2)..."
$PSQL -f /sql/04_marts/mart_campaign_spend.sql
$PSQL -f /sql/04_marts/mart_campaign_funnel.sql
$PSQL -f /sql/04_marts/mart_campaign_revenue.sql
$PSQL -f /sql/04_marts/mart_customer_revenue.sql

echo "==> Building mart views (Phase 3)..."
$PSQL -f /sql/04_marts/mart_reference_date.sql
$PSQL -f /sql/04_marts/mart_customer_cohort_spine.sql
$PSQL -f /sql/04_marts/mart_customer_month_activity.sql
$PSQL -f /sql/04_marts/mart_channel_retention.sql
$PSQL -f /sql/04_marts/mart_customer_rfm.sql
$PSQL -f /sql/04_marts/mart_ltv_90d.sql

echo "==> Building Power BI export views..."
$PSQL -f /sql/07_powerbi/pbi_channel_performance.sql
$PSQL -f /sql/07_powerbi/pbi_campaign_performance.sql
$PSQL -f /sql/07_powerbi/pbi_monthly_trend.sql
$PSQL -f /sql/07_powerbi/pbi_cohort_retention.sql
$PSQL -f /sql/07_powerbi/pbi_rfm_segments.sql
$PSQL -f /sql/07_powerbi/pbi_executive_summary.sql

echo "==> Running data-quality validation..."
$PSQL -f /sql/06_validation/001_data_quality_checks.sql
$PSQL -f /sql/06_validation/002_phase3_validation.sql

echo "==> Setup complete."
