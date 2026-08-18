/* ============================================================
   METRIC: BUDGET ALLOCATION / RECOMMENDATION FRAMEWORK
   Business question: which channels look strongest or weakest
   for future marketing investment, based on what this (synthetic)
   dataset shows so far?

   IMPORTANT: this is a DIRECTIONAL, historical-data framework,
   not a proof of an optimal allocation and not a forecast. It
   says what the data suggests about the past, not what will
   definitely happen if budget is moved.

   Classification logic (every cutoff labeled by its source):
     - LTV:CAC >= 3x and >= 1x are commonly cited external SaaS/
       DTC heuristics (not discovered from this data - see
       ltv_cac.sql).
     - "cac_vs_avg" compares each channel's CAC to the spend-
       weighted average CAC ACROSS THIS DATASET - that part IS
       data-driven, not an external assumption.
     - marketing_contribution > 0 is a hard requirement for
       "Scale candidate" - a channel cannot be a scale candidate
       if it hasn't even earned back its own spend yet.
     - retention_month_3_pct is shown for context on every row but
       does not independently drive the label - it is too data-
       thin for some newer campaigns to be a safe primary signal
       here (see README limitations).
   ============================================================ */
SET search_path TO roas, public;

WITH channel_metrics AS (
    SELECT
        sc.channel_name,
        SUM(s.total_spend)                    AS total_spend,
        SUM(f.acquired_customer_count)           AS customers_acquired,
        ROUND(SUM(s.total_spend) / NULLIF(SUM(f.acquired_customer_count), 0), 2) AS cac,
        SUM(r.revenue_lifetime_to_date)            AS revenue_lifetime_to_date,
        ROUND(SUM(r.revenue_lifetime_to_date) / NULLIF(SUM(s.total_spend), 0), 2)   AS roas_lifetime,
        ROUND(SUM(r.revenue_lifetime_to_date) - SUM(s.total_spend), 2)                AS marketing_contribution
    FROM stg_campaigns sc
    JOIN mart_campaign_spend s   ON s.campaign_id = sc.campaign_id
    JOIN mart_campaign_funnel f  ON f.campaign_id = sc.campaign_id
    JOIN mart_campaign_revenue r ON r.campaign_id = sc.campaign_id
    GROUP BY sc.channel_name
),
channel_ltv AS (
    SELECT acquisition_channel_name AS channel_name,
           ROUND(AVG(lifetime_revenue_to_date), 2) AS avg_ltv_lifetime
    FROM mart_customer_revenue
    GROUP BY acquisition_channel_name
),
channel_retention_m3 AS (
    SELECT channel_name, retention_rate_pct AS retention_month_3_pct
    FROM mart_channel_retention
    WHERE months_since_acquisition = 3
),
overall_avg_cac AS (
    SELECT ROUND(SUM(total_spend) / NULLIF(SUM(customers_acquired), 0), 2) AS avg_cac
    FROM channel_metrics
),
combined AS (
    SELECT
        cm.channel_name,
        cm.total_spend,
        cm.customers_acquired,
        cm.cac,
        cm.roas_lifetime,
        cl.avg_ltv_lifetime,
        ROUND(cl.avg_ltv_lifetime / NULLIF(cm.cac, 0), 2) AS ltv_cac_lifetime,
        cm.marketing_contribution,
        crm.retention_month_3_pct,
        oac.avg_cac                                          AS dataset_avg_cac,
        ROUND(cm.cac / NULLIF(oac.avg_cac, 0), 2)              AS cac_vs_avg_ratio
    FROM channel_metrics cm
    JOIN channel_ltv cl ON cl.channel_name = cm.channel_name
    LEFT JOIN channel_retention_m3 crm ON crm.channel_name = cm.channel_name
    CROSS JOIN overall_avg_cac oac
)
SELECT
    channel_name,
    total_spend,
    customers_acquired,
    cac,
    cac_vs_avg_ratio,
    roas_lifetime,
    ltv_cac_lifetime,
    marketing_contribution,
    retention_month_3_pct,
    CASE
        WHEN marketing_contribution > 0 AND ltv_cac_lifetime >= 3 AND cac_vs_avg_ratio <= 1
            THEN 'Scale candidate'          -- profitable, above the 3x heuristic, cheaper than average
        WHEN marketing_contribution > 0 AND ltv_cac_lifetime >= 1.5
            THEN 'Maintain / monitor'       -- solidly profitable, not a standout
        WHEN marketing_contribution > 0 AND ltv_cac_lifetime >= 1
            THEN 'Review'                   -- barely profitable or costlier than average
        ELSE 'Reduce / investigate'         -- unprofitable or LTV:CAC below 1x
    END AS recommendation,
    CASE
        WHEN marketing_contribution > 0 AND ltv_cac_lifetime >= 3 AND cac_vs_avg_ratio <= 1
            THEN 'Contribution positive, LTV:CAC >= 3x heuristic, CAC at or below dataset average'
        WHEN marketing_contribution > 0 AND ltv_cac_lifetime >= 1.5
            THEN 'Contribution positive, LTV:CAC >= 1.5x - healthy but not exceptional'
        WHEN marketing_contribution > 0 AND ltv_cac_lifetime >= 1
            THEN 'Contribution positive but LTV:CAC below 1.5x, or CAC well above average'
        ELSE 'Contribution negative or LTV:CAC below 1x - spend is not being recovered'
    END AS rationale
FROM combined
ORDER BY marketing_contribution DESC;
