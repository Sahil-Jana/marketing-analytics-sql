/* ============================================================
   METRIC: LTV:CAC
   Business question: does what a channel/campaign's customers
   are worth outweigh what it costs to acquire them?

   Grain: channel and campaign ONLY - never per-customer. CAC is
   a channel/campaign-level cost (total spend / customers
   acquired); no individual customer "incurred" a specific dollar
   amount of marketing spend, so a customer-level CAC would be a
   fabricated number, not an observed one.

   Two ratios are reported, and they answer different questions:
     - ltv_cac_lifetime = avg lifetime LTV per customer / CAC.
       NOTE: at this grain this is mathematically identical to
       roas_lifetime from roas.sql - (revenue/customers) / (spend/
       customers) reduces to revenue/spend. That's not a bug, it's
       what the algebra of "same revenue window, same customer
       denominator" guarantees. It's kept here anyway because
       "LTV:CAC" is the framing marketers actually use, and the
       equivalence is exactly the kind of thing worth being able
       to explain in an interview.
     - ltv_cac_90d = avg 90-day LTV per customer (complete-window
       customers only) / CAC. This one is NOT equivalent to any
       ROAS number - it is the fairer, apples-to-apples ratio for
       comparing campaigns of different ages.

   3x is a commonly cited external SaaS/DTC heuristic for a
   "healthy" LTV:CAC ratio - it is NOT a threshold discovered from
   this data, and is labeled as such, not stated as fact.
   ============================================================ */
SET search_path TO roas, public;

-- 1. LTV:CAC by channel
WITH channel_cac AS (
    SELECT
        sc.channel_name,
        SUM(s.total_spend)                  AS total_spend,
        SUM(f.acquired_customer_count)         AS customers_acquired,
        ROUND(SUM(s.total_spend) / NULLIF(SUM(f.acquired_customer_count), 0), 2) AS cac
    FROM stg_campaigns sc
    JOIN mart_campaign_spend s  ON s.campaign_id = sc.campaign_id
    JOIN mart_campaign_funnel f ON f.campaign_id = sc.campaign_id
    GROUP BY sc.channel_name
),
channel_ltv_lifetime AS (
    SELECT acquisition_channel_name AS channel_name,
           ROUND(AVG(lifetime_revenue_to_date), 2) AS avg_ltv_lifetime
    FROM mart_customer_revenue
    GROUP BY acquisition_channel_name
),
channel_ltv_90d AS (
    SELECT channel_name,
           ROUND(AVG(ltv_90d) FILTER (WHERE window_complete), 2) AS avg_ltv_90d
    FROM mart_ltv_90d
    GROUP BY channel_name
)
SELECT
    cc.channel_name,
    cc.total_spend,
    cc.customers_acquired,
    cc.cac,
    cl.avg_ltv_lifetime,
    ROUND(cl.avg_ltv_lifetime / NULLIF(cc.cac, 0), 2)   AS ltv_cac_lifetime,
    c90.avg_ltv_90d,
    ROUND(c90.avg_ltv_90d / NULLIF(cc.cac, 0), 2)          AS ltv_cac_90d,
    CASE
        WHEN cl.avg_ltv_lifetime / NULLIF(cc.cac, 0) >= 3 THEN 'Above 3x heuristic'
        WHEN cl.avg_ltv_lifetime / NULLIF(cc.cac, 0) >= 1 THEN 'Positive but below 3x heuristic'
        ELSE 'Below 1x (spend exceeds observed lifetime value)'
    END AS heuristic_flag_lifetime
FROM channel_cac cc
JOIN channel_ltv_lifetime cl ON cl.channel_name = cc.channel_name
JOIN channel_ltv_90d c90     ON c90.channel_name = cc.channel_name
ORDER BY ltv_cac_lifetime DESC NULLS LAST;

-- 2. LTV:CAC by campaign
WITH campaign_cac AS (
    SELECT
        sc.campaign_id, sc.channel_name, sc.campaign_name,
        s.total_spend,
        f.acquired_customer_count,
        ROUND(s.total_spend / NULLIF(f.acquired_customer_count, 0), 2) AS cac
    FROM stg_campaigns sc
    JOIN mart_campaign_spend s  ON s.campaign_id = sc.campaign_id
    JOIN mart_campaign_funnel f ON f.campaign_id = sc.campaign_id
),
campaign_ltv_lifetime AS (
    SELECT first_campaign_id, ROUND(AVG(lifetime_revenue_to_date), 2) AS avg_ltv_lifetime
    FROM mart_customer_revenue
    GROUP BY first_campaign_id
),
campaign_ltv_90d AS (
    SELECT first_campaign_id,
           ROUND(AVG(ltv_90d) FILTER (WHERE window_complete), 2) AS avg_ltv_90d
    FROM mart_ltv_90d
    GROUP BY first_campaign_id
)
SELECT
    cc.channel_name,
    cc.campaign_id,
    cc.campaign_name,
    cc.total_spend,
    cc.acquired_customer_count,
    cc.cac,
    cl.avg_ltv_lifetime,
    ROUND(cl.avg_ltv_lifetime / NULLIF(cc.cac, 0), 2) AS ltv_cac_lifetime,
    c90.avg_ltv_90d,
    ROUND(c90.avg_ltv_90d / NULLIF(cc.cac, 0), 2)        AS ltv_cac_90d
FROM campaign_cac cc
JOIN campaign_ltv_lifetime cl ON cl.first_campaign_id = cc.campaign_id
LEFT JOIN campaign_ltv_90d c90 ON c90.first_campaign_id = cc.campaign_id
ORDER BY ltv_cac_lifetime DESC NULLS LAST;
