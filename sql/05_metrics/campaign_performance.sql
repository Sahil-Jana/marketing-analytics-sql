/* ============================================================
   METRIC: CAMPAIGN / CHANNEL PERFORMANCE
   Business question: single consolidated view of spend, funnel,
   and revenue per campaign and per channel - the one table a
   marketing lead would actually scan first.
   Aggregation levels are built from the SAME underlying marts
   (mart_campaign_spend, mart_campaign_funnel, mart_campaign_revenue)
   used by cac.sql/roas.sql, so campaign-level rows here sum
   exactly to the channel-level rows below.
   ============================================================ */
SET search_path TO roas, public;

-- 1. Campaign-level performance
SELECT
    sc.channel_name,
    sc.campaign_id,
    sc.campaign_name,
    sc.objective,
    s.total_spend,
    f.lead_count,
    f.converted_lead_count,
    f.acquired_customer_count,
    ROUND(100.0 * f.converted_lead_count / NULLIF(f.lead_count, 0), 2) AS conversion_rate_pct,
    r.revenue_lifetime_to_date,
    ROUND(s.total_spend / NULLIF(f.acquired_customer_count, 0), 2)      AS cac,
    ROUND(r.revenue_lifetime_to_date / NULLIF(s.total_spend, 0), 2)     AS roas_lifetime
FROM stg_campaigns sc
JOIN mart_campaign_spend s   ON s.campaign_id = sc.campaign_id
JOIN mart_campaign_funnel f  ON f.campaign_id = sc.campaign_id
JOIN mart_campaign_revenue r ON r.campaign_id = sc.campaign_id
ORDER BY sc.channel_name, roas_lifetime DESC NULLS LAST;

-- 2. Channel-level performance (reconciles with the sums of the
--    campaign-level rows above)
SELECT
    sc.channel_name,
    SUM(s.total_spend)                    AS total_spend,
    SUM(f.lead_count)                        AS lead_count,
    SUM(f.converted_lead_count)                AS converted_lead_count,
    SUM(f.acquired_customer_count)                AS acquired_customer_count,
    ROUND(100.0 * SUM(f.converted_lead_count) / NULLIF(SUM(f.lead_count), 0), 2) AS conversion_rate_pct,
    SUM(r.revenue_lifetime_to_date)                  AS revenue_lifetime_to_date,
    ROUND(SUM(s.total_spend) / NULLIF(SUM(f.acquired_customer_count), 0), 2)      AS cac,
    ROUND(SUM(r.revenue_lifetime_to_date) / NULLIF(SUM(s.total_spend), 0), 2)     AS roas_lifetime
FROM stg_campaigns sc
JOIN mart_campaign_spend s   ON s.campaign_id = sc.campaign_id
JOIN mart_campaign_funnel f  ON f.campaign_id = sc.campaign_id
JOIN mart_campaign_revenue r ON r.campaign_id = sc.campaign_id
GROUP BY sc.channel_name
ORDER BY roas_lifetime DESC NULLS LAST;
