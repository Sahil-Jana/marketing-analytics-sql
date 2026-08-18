/* ============================================================
   METRIC: ACQUISITION FUNNEL
   Business question: how many leads does each campaign/channel
   generate, what share convert, and how many customers does
   that actually produce?
   Logic: leads and converted_lead_count come straight from
   leads-table row counts (real numerator/denominator), not an
   assumed rate.
   ============================================================ */
SET search_path TO roas, public;

-- 1. Campaign-level funnel, ranked within its channel by
--    conversion rate (window function: RANK OVER PARTITION).
WITH campaign_funnel AS (
    SELECT
        sc.campaign_id,
        sc.channel_name,
        sc.campaign_name,
        f.lead_count,
        f.converted_lead_count,
        f.acquired_customer_count,
        ROUND(100.0 * f.converted_lead_count / NULLIF(f.lead_count, 0), 2) AS conversion_rate_pct
    FROM stg_campaigns sc
    JOIN mart_campaign_funnel f ON f.campaign_id = sc.campaign_id
)
SELECT
    *,
    RANK() OVER (PARTITION BY channel_name ORDER BY conversion_rate_pct DESC) AS conv_rate_rank_in_channel
FROM campaign_funnel
ORDER BY channel_name, conv_rate_rank_in_channel;

-- 2. Channel-level funnel (rolls up the campaign grain above -
--    used to sanity-check that campaign-level sums reconcile).
SELECT
    sc.channel_name,
    SUM(f.lead_count)                 AS lead_count,
    SUM(f.converted_lead_count)         AS converted_lead_count,
    SUM(f.acquired_customer_count)        AS acquired_customer_count,
    ROUND(100.0 * SUM(f.converted_lead_count) / NULLIF(SUM(f.lead_count), 0), 2) AS conversion_rate_pct
FROM stg_campaigns sc
JOIN mart_campaign_funnel f ON f.campaign_id = sc.campaign_id
GROUP BY sc.channel_name
ORDER BY conversion_rate_pct DESC;

-- 3. Account-wide totals.
SELECT
    SUM(lead_count)              AS total_leads,
    SUM(converted_lead_count)      AS total_conversions,
    ROUND(100.0 * SUM(converted_lead_count) / NULLIF(SUM(lead_count), 0), 2) AS overall_conversion_rate_pct,
    SUM(acquired_customer_count)      AS total_customers_acquired
FROM mart_campaign_funnel;
