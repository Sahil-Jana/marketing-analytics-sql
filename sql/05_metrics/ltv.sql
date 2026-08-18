/* ============================================================
   METRIC: OBSERVED LTV
   Business question: how much revenue has each customer/channel/
   campaign actually generated - and, comparing fairly across
   campaigns that ran at different times, how much do they
   generate in their first 90 days?

   Two deliberately different numbers, both observed (no
   predictive/statistical model):
     - LIFETIME LTV: all revenue to date. Grows over time and is
       NOT comparable across campaigns/cohorts of different ages
       - a campaign from month 1 will always show higher lifetime
       LTV than one from month 16 purely because it has had more
       time, regardless of true customer quality.
     - 90-DAY LTV: revenue in the first 90 days after signup,
       computed only for customers whose 90-day window has fully
       elapsed (mart_ltv_90d.window_complete). This is the fairer
       number for comparing campaigns/channels against each other.
   ============================================================ */
SET search_path TO roas, public;

-- 1. Customer-level lifetime LTV (reuses the Phase 2 foundation).
SELECT
    customer_id,
    acquisition_channel_name,
    signup_date,
    order_count,
    lifetime_revenue_to_date AS lifetime_ltv
FROM mart_customer_revenue
ORDER BY lifetime_ltv DESC;

-- 2. Lifetime LTV by acquisition channel: mean AND median, since
--    a handful of very high-spend customers can pull the mean up
--    - PERCENTILE_CONT gives the typical customer's number too.
SELECT
    acquisition_channel_name,
    COUNT(*)                                                     AS customers,
    ROUND(AVG(lifetime_revenue_to_date), 2)                        AS avg_lifetime_ltv,
    ROUND(PERCENTILE_CONT(0.5) WITHIN GROUP (
        ORDER BY lifetime_revenue_to_date
    )::numeric, 2)                                                    AS median_lifetime_ltv
FROM mart_customer_revenue
GROUP BY acquisition_channel_name
ORDER BY avg_lifetime_ltv DESC;

-- 3. Lifetime LTV by campaign.
SELECT
    sc.channel_name,
    sc.campaign_id,
    sc.campaign_name,
    COUNT(mcr.customer_id)                    AS customers,
    ROUND(AVG(mcr.lifetime_revenue_to_date), 2) AS avg_lifetime_ltv
FROM stg_campaigns sc
JOIN mart_customer_revenue mcr ON mcr.first_campaign_id = sc.campaign_id
GROUP BY sc.channel_name, sc.campaign_id, sc.campaign_name
ORDER BY avg_lifetime_ltv DESC;

-- 4. 90-day LTV by channel (fair, apples-to-apples comparison) -
--    only customers with a fully elapsed 90-day window are
--    included; excluded_incomplete_window shows how many were
--    dropped and why, so the number is never silently biased by
--    very recently acquired customers.
SELECT
    channel_name,
    COUNT(*) FILTER (WHERE window_complete)                              AS customers_with_complete_window,
    COUNT(*) FILTER (WHERE NOT window_complete)                            AS excluded_incomplete_window,
    ROUND(AVG(ltv_90d) FILTER (WHERE window_complete), 2)                    AS avg_ltv_90d
FROM mart_ltv_90d
GROUP BY channel_name
ORDER BY avg_ltv_90d DESC NULLS LAST;

-- 5. Cumulative cohort-level LTV at fixed checkpoints (draws on
--    the running-total window function built in cohort_retention.sql).
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
        SUM(revenue) AS monthly_revenue
    FROM mart_customer_month_activity
    GROUP BY cohort_month, months_since_acquisition
),
cumulative AS (
    SELECT
        m.cohort_month,
        m.months_since_acquisition,
        cs.cohort_size,
        SUM(m.monthly_revenue) OVER (
            PARTITION BY m.cohort_month ORDER BY m.months_since_acquisition
        ) AS cumulative_revenue
    FROM monthly m
    JOIN cohort_sizes cs ON cs.cohort_month = m.cohort_month
)
SELECT
    cohort_month,
    months_since_acquisition,
    cohort_size,
    ROUND(cumulative_revenue / NULLIF(cohort_size, 0), 2) AS cumulative_ltv_per_customer
FROM cumulative
WHERE months_since_acquisition IN (0, 1, 3, 6)
ORDER BY cohort_month, months_since_acquisition;
