/* ============================================================
   MART: mart_channel_retention
   Retention by acquisition channel at each months-since-
   acquisition checkpoint. "customers_in_scope" is every customer
   whose cohort is old enough to have reached that checkpoint by
   the reference month (not a shrinking "still active" pool) -
   that keeps the denominator equal to the true original cohort
   size for every channel/month combination, which is what a
   correct retention-rate denominator requires.
   Reused by both the retention metric query and the budget
   allocation framework (Phase 3 item 7).
   ============================================================ */
SET search_path TO roas, public;

CREATE OR REPLACE VIEW mart_channel_retention AS
SELECT
    channel_id,
    channel_name,
    months_since_acquisition,
    COUNT(DISTINCT customer_id)                                    AS customers_in_scope,
    COUNT(DISTINCT customer_id) FILTER (WHERE is_active)             AS active_customers,
    ROUND(
        100.0 * COUNT(DISTINCT customer_id) FILTER (WHERE is_active)
        / NULLIF(COUNT(DISTINCT customer_id), 0)
    , 2) AS retention_rate_pct
FROM mart_customer_month_activity
GROUP BY channel_id, channel_name, months_since_acquisition;
