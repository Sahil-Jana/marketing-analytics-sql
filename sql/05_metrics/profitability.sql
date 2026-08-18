/* ============================================================
   METRIC: CAMPAIGN / CHANNEL PROFITABILITY (extended)
   Business question: the single consolidated view a marketing
   lead needs to judge a channel/campaign - spend, funnel,
   revenue, ROAS, LTV, and LTV:CAC together, with the acquisition-
   window and observed-lifetime numbers clearly separated so
   neither gets silently compared against the wrong window.

   marketing_contribution = revenue_lifetime_to_date - total_spend.
   This is NOT company profit (see roas.sql / README) - it
   excludes COGS, fulfillment, payroll, and all other operating
   costs.
   ============================================================ */
SET search_path TO roas, public;

-- 1. Campaign-level profitability
WITH campaign_ltv AS (
    SELECT first_campaign_id, ROUND(AVG(lifetime_revenue_to_date), 2) AS avg_ltv_lifetime
    FROM mart_customer_revenue
    GROUP BY first_campaign_id
)
SELECT
    sc.channel_name,
    sc.campaign_id,
    sc.campaign_name,
    s.total_spend,
    f.lead_count,
    f.converted_lead_count,
    f.acquired_customer_count,
    ROUND(100.0 * f.converted_lead_count / NULLIF(f.lead_count, 0), 2) AS conversion_rate_pct,
    ROUND(s.total_spend / NULLIF(f.acquired_customer_count, 0), 2)      AS cac,
    r.revenue_in_campaign_window,
    r.revenue_lifetime_to_date,
    ROUND(r.revenue_in_campaign_window / NULLIF(s.total_spend, 0), 2)     AS roas_in_window,
    ROUND(r.revenue_lifetime_to_date / NULLIF(s.total_spend, 0), 2)         AS roas_lifetime,
    cl.avg_ltv_lifetime,
    ROUND(cl.avg_ltv_lifetime / NULLIF(s.total_spend / NULLIF(f.acquired_customer_count, 0), 0), 2) AS ltv_cac_lifetime,
    ROUND(r.revenue_lifetime_to_date - s.total_spend, 2)                      AS marketing_contribution
FROM stg_campaigns sc
JOIN mart_campaign_spend s   ON s.campaign_id = sc.campaign_id
JOIN mart_campaign_funnel f  ON f.campaign_id = sc.campaign_id
JOIN mart_campaign_revenue r ON r.campaign_id = sc.campaign_id
JOIN campaign_ltv cl         ON cl.first_campaign_id = sc.campaign_id
ORDER BY marketing_contribution DESC;

-- 2. Channel-level profitability (reconciles with the sums of
--    the campaign-level rows above)
WITH channel_ltv AS (
    SELECT acquisition_channel_name AS channel_name,
           ROUND(AVG(lifetime_revenue_to_date), 2) AS avg_ltv_lifetime
    FROM mart_customer_revenue
    GROUP BY acquisition_channel_name
)
SELECT
    sc.channel_name,
    SUM(s.total_spend)                       AS total_spend,
    SUM(f.lead_count)                          AS lead_count,
    SUM(f.converted_lead_count)                  AS converted_lead_count,
    SUM(f.acquired_customer_count)                 AS acquired_customer_count,
    ROUND(100.0 * SUM(f.converted_lead_count) / NULLIF(SUM(f.lead_count), 0), 2) AS conversion_rate_pct,
    ROUND(SUM(s.total_spend) / NULLIF(SUM(f.acquired_customer_count), 0), 2)      AS cac,
    SUM(r.revenue_lifetime_to_date)                                                AS revenue_lifetime_to_date,
    ROUND(SUM(r.revenue_lifetime_to_date) / NULLIF(SUM(s.total_spend), 0), 2)        AS roas_lifetime,
    cl.avg_ltv_lifetime,
    ROUND(cl.avg_ltv_lifetime / NULLIF(SUM(s.total_spend) / NULLIF(SUM(f.acquired_customer_count), 0), 0), 2) AS ltv_cac_lifetime,
    ROUND(SUM(r.revenue_lifetime_to_date) - SUM(s.total_spend), 2)                     AS marketing_contribution
FROM stg_campaigns sc
JOIN mart_campaign_spend s   ON s.campaign_id = sc.campaign_id
JOIN mart_campaign_funnel f  ON f.campaign_id = sc.campaign_id
JOIN mart_campaign_revenue r ON r.campaign_id = sc.campaign_id
JOIN channel_ltv cl          ON cl.channel_name = sc.channel_name
GROUP BY sc.channel_name, cl.avg_ltv_lifetime
ORDER BY marketing_contribution DESC;
