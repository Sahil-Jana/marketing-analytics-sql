/* ============================================================
   PHASE 3 VALIDATION SUITE
   Same pattern as 001_data_quality_checks.sql: each row is a
   check with a failing-row count and PASS/FAIL. A few checks are
   intentionally reported as INFO rather than PASS/FAIL because
   the "correct" value isn't a hard invariant (e.g. Month 0
   retention, which this dataset's generator does not guarantee
   will be exactly 100% - see cohort_retention.sql for why).
   ============================================================ */
SET search_path TO roas, public;

WITH checks AS (

    -- ---------- COHORTS ----------
    SELECT 'Cohort: every customer maps to exactly one cohort_month' AS check_name,
           COUNT(*) AS failing_rows
    FROM (
        SELECT customer_id FROM mart_customer_cohort_spine
        GROUP BY customer_id
        HAVING COUNT(DISTINCT cohort_month) <> 1
    ) x

    UNION ALL
    SELECT 'Cohort: retention_rate_pct never exceeds 100',
           COUNT(*) FROM mart_channel_retention WHERE retention_rate_pct > 100

    UNION ALL
    SELECT 'Cohort: sum of cohort sizes = total customers',
           ABS(
               (SELECT SUM(cohort_size) FROM (
                   SELECT DATE_TRUNC('month', signup_date)::date AS cohort_month, COUNT(*) AS cohort_size
                   FROM customers GROUP BY DATE_TRUNC('month', signup_date)::date
               ) cs)
               - (SELECT COUNT(*) FROM customers)
           )

    -- ---------- RFM ----------
    UNION ALL
    SELECT 'RFM: every customer appears exactly once',
           COUNT(*) FROM (
               SELECT customer_id FROM mart_customer_rfm
               GROUP BY customer_id HAVING COUNT(*) > 1
           ) x

    UNION ALL
    SELECT 'RFM: no null recency/frequency/monetary values',
           COUNT(*) FROM mart_customer_rfm
           WHERE recency_days IS NULL OR frequency IS NULL OR monetary IS NULL

    UNION ALL
    SELECT 'RFM: segment counts sum to total customers',
           ABS(
               (SELECT COUNT(*) FROM mart_customer_rfm)
               - (SELECT COUNT(*) FROM customers)
           )

    -- ---------- LTV ----------
    UNION ALL
    SELECT 'LTV: sum of customer lifetime LTV = sum of order revenue',
           ROUND(ABS(
               (SELECT SUM(lifetime_revenue_to_date) FROM mart_customer_revenue)
               - (SELECT SUM(order_amount) FROM orders)
           ), 2)

    UNION ALL
    SELECT 'LTV: channel-level revenue (customer mart) = channel-level revenue (campaign mart)',
           ROUND(COALESCE(SUM(ABS(diff)), 0), 2)
           FROM (
               SELECT
                   ch.channel_name,
                   COALESCE(cust.rev, 0) - COALESCE(camp.rev, 0) AS diff
               FROM channels ch
               LEFT JOIN (
                   SELECT acquisition_channel_name AS channel_name, SUM(lifetime_revenue_to_date) AS rev
                   FROM mart_customer_revenue GROUP BY acquisition_channel_name
               ) cust ON cust.channel_name = ch.channel_name
               LEFT JOIN (
                   SELECT channel_id, SUM(revenue_lifetime_to_date) AS rev
                   FROM mart_campaign_revenue GROUP BY channel_id
               ) camp ON camp.channel_id = ch.channel_id
           ) diffs

    -- ---------- LTV:CAC ----------
    UNION ALL
    SELECT 'LTV:CAC: total customers across channels = total customers table',
           ABS(
               (SELECT SUM(f.acquired_customer_count)
                FROM mart_campaign_funnel f)
               - (SELECT COUNT(*) FROM customers)
           )

    -- ---------- PROFITABILITY ----------
    UNION ALL
    SELECT 'Profitability: total revenue_lifetime reconciles with Phase 2 mart',
           ROUND(ABS(
               (SELECT SUM(revenue_lifetime_to_date) FROM mart_campaign_revenue)
               - (SELECT SUM(lifetime_revenue_to_date) FROM mart_customer_revenue)
           ), 2)

    UNION ALL
    SELECT 'Profitability: total spend reconciles with Phase 2 mart',
           ROUND(ABS(
               (SELECT SUM(total_spend) FROM mart_campaign_spend)
               - (SELECT SUM(spend_amount) FROM daily_campaign_spend)
           ), 2)
)
SELECT
    check_name,
    failing_rows,
    CASE WHEN failing_rows = 0 THEN 'PASS' ELSE 'FAIL' END AS status
FROM checks
ORDER BY status DESC, check_name;

-- ------------------------------------------------------------
-- Informational (not strict pass/fail): Month 0 retention and
-- divide-by-zero handling, reported as data rather than a
-- boolean check since "correct" isn't a single fixed number.
-- ------------------------------------------------------------

-- Month 0 retention should be close to 100% (small deviation
-- expected and explained - see cohort_retention.sql).
SELECT 'Month 0 retention (all cohorts, weighted)' AS info,
       ROUND(100.0 * SUM(active_customers) / NULLIF(SUM(customers_in_scope), 0), 2) AS pct
FROM mart_channel_retention
WHERE months_since_acquisition = 0;

-- Confirm campaigns with 0 acquired customers (if any) produce
-- NULL CAC/LTV:CAC rather than an error.
SELECT
    sc.campaign_name,
    f.acquired_customer_count,
    ROUND(s.total_spend / NULLIF(f.acquired_customer_count, 0), 2) AS cac
FROM stg_campaigns sc
JOIN mart_campaign_funnel f ON f.campaign_id = sc.campaign_id
JOIN mart_campaign_spend s  ON s.campaign_id = sc.campaign_id
WHERE f.acquired_customer_count = 0;
