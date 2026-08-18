/* ============================================================
   METRIC: COHORT RETENTION
   Business question: once acquired, how well do we keep
   customers ordering month over month, and does that differ by
   acquisition channel?

   Definition (see mart_customer_month_activity for the full
   note): a customer is "retained" in month N if they placed at
   least one order in that calendar month. This is BEHAVIORAL,
   not contractual - there is no cancellation event in this data,
   so "not retained" really means "did not order this month",
   which is not the same claim as "churned for good".

   Month 0 = the customer's signup month itself. It will NOT be
   exactly 100% here: each customer's first order lands 0-3 days
   after signup, so a customer who signs up on the last day or
   two of a month can have their first order land in the
   following calendar month. That is a real edge effect of using
   calendar-month grain and is called out explicitly rather than
   smoothed away.
   ============================================================ */
SET search_path TO roas, public;

-- 1. Cohort x months-since-acquisition retention + cumulative LTV.
--    cumulative_revenue uses a running SUM() window function
--    (needed because "cumulative" is inherently an ordered,
--    running calculation - a plain GROUP BY cannot produce it).
WITH cohort_sizes AS (
    SELECT
        DATE_TRUNC('month', signup_date)::date AS cohort_month,
        COUNT(*)                                  AS cohort_size
    FROM customers
    GROUP BY DATE_TRUNC('month', signup_date)::date
),
monthly AS (
    SELECT
        cohort_month,
        months_since_acquisition,
        COUNT(DISTINCT customer_id) FILTER (WHERE is_active) AS active_customers,
        SUM(revenue)                                            AS monthly_revenue
    FROM mart_customer_month_activity
    GROUP BY cohort_month, months_since_acquisition
)
SELECT
    m.cohort_month,
    m.months_since_acquisition,
    cs.cohort_size,
    m.active_customers,
    ROUND(100.0 * m.active_customers / NULLIF(cs.cohort_size, 0), 2) AS retention_rate_pct,
    m.monthly_revenue,
    SUM(m.monthly_revenue) OVER (
        PARTITION BY m.cohort_month ORDER BY m.months_since_acquisition
    ) AS cumulative_revenue,
    ROUND(
        SUM(m.monthly_revenue) OVER (
            PARTITION BY m.cohort_month ORDER BY m.months_since_acquisition
        ) / NULLIF(cs.cohort_size, 0)
    , 2) AS cumulative_ltv_per_customer
FROM monthly m
JOIN cohort_sizes cs ON cs.cohort_month = m.cohort_month
ORDER BY m.cohort_month, m.months_since_acquisition;

-- 2. Retention by acquisition channel at fixed checkpoints
--    (month 0, 1, 3, 6) - the numbers most useful for a
--    retention heatmap without dumping every possible month.
SELECT
    channel_name,
    months_since_acquisition,
    customers_in_scope,
    active_customers,
    retention_rate_pct
FROM mart_channel_retention
WHERE months_since_acquisition IN (0, 1, 3, 6)
ORDER BY channel_name, months_since_acquisition;

-- 3. Full channel x month retention grid (the raw material for a
--    later retention heatmap visualization).
SELECT
    channel_name,
    months_since_acquisition,
    customers_in_scope,
    active_customers,
    retention_rate_pct
FROM mart_channel_retention
ORDER BY channel_name, months_since_acquisition;
