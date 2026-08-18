/* ============================================================
   POWER BI EXPORT: pbi_cohort_retention
   Cohort-month x months-since-acquisition retention grid, for
   the Page 3 heatmap. Same behavioral retention definition as
   Phase 3 (>=1 order in that calendar month) - see
   sql/04_marts/mart_customer_month_activity.sql for the full
   methodology note.
   ============================================================ */
SET search_path TO roas, public;

CREATE OR REPLACE VIEW pbi_cohort_retention AS
WITH cohort_sizes AS (
    SELECT
        DATE_TRUNC('month', signup_date)::date AS cohort_month,
        COUNT(*)                                  AS cohort_size
    FROM customers
    GROUP BY DATE_TRUNC('month', signup_date)::date
)
SELECT
    a.cohort_month,
    a.months_since_acquisition,
    cs.cohort_size,
    COUNT(DISTINCT a.customer_id) FILTER (WHERE a.is_active) AS active_customers,
    ROUND(
        100.0 * COUNT(DISTINCT a.customer_id) FILTER (WHERE a.is_active)
        / NULLIF(cs.cohort_size, 0)
    , 2) AS retention_rate_pct
FROM mart_customer_month_activity a
JOIN cohort_sizes cs ON cs.cohort_month = a.cohort_month
GROUP BY a.cohort_month, a.months_since_acquisition, cs.cohort_size;
