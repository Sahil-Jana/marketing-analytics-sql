/* ============================================================
   POWER BI EXPORT: pbi_channel_performance
   One row per channel, combining Phase 2 CAC/ROAS/contribution
   with Phase 3 LTV/LTV:CAC/budget-allocation - exactly the
   fields Dashboard Page 1 (exec KPIs) and Page 2 (channel table
   + scatter) need. No logic here that isn't already validated
   in 05_metrics/profitability.sql, ltv_cac.sql, and
   budget_allocation.sql - this view only re-exposes those same
   joins as a single flat, Power-BI-friendly table so no metric
   has to be recomputed in DAX.
   ============================================================ */
SET search_path TO roas, public;

CREATE OR REPLACE VIEW pbi_channel_performance AS
WITH channel_metrics AS (
    SELECT
        sc.channel_name,
        SUM(s.total_spend)                       AS total_spend,
        SUM(f.lead_count)                           AS leads,
        SUM(f.converted_lead_count)                   AS conversions,
        SUM(f.acquired_customer_count)                  AS customers_acquired,
        ROUND(100.0 * SUM(f.converted_lead_count) / NULLIF(SUM(f.lead_count), 0), 2) AS conversion_rate_pct,
        ROUND(SUM(s.total_spend) / NULLIF(SUM(f.acquired_customer_count), 0), 2)      AS cac,
        SUM(r.revenue_in_campaign_window)                                               AS revenue_in_window,
        SUM(r.revenue_lifetime_to_date)                                                   AS revenue_lifetime,
        ROUND(SUM(r.revenue_in_campaign_window) / NULLIF(SUM(s.total_spend), 0), 2)         AS roas_in_window,
        ROUND(SUM(r.revenue_lifetime_to_date) / NULLIF(SUM(s.total_spend), 0), 2)             AS roas_lifetime,
        ROUND(SUM(r.revenue_lifetime_to_date) - SUM(s.total_spend), 2)                          AS marketing_contribution
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
channel_ltv_90d AS (
    SELECT channel_name, ROUND(AVG(ltv_90d) FILTER (WHERE window_complete), 2) AS avg_ltv_90d
    FROM mart_ltv_90d
    GROUP BY channel_name
),
channel_retention_m1 AS (
    SELECT channel_name, retention_rate_pct AS retention_month_1_pct
    FROM mart_channel_retention WHERE months_since_acquisition = 1
),
channel_retention_m3 AS (
    SELECT channel_name, retention_rate_pct AS retention_month_3_pct
    FROM mart_channel_retention WHERE months_since_acquisition = 3
),
overall_avg_cac AS (
    SELECT ROUND(SUM(total_spend) / NULLIF(SUM(customers_acquired), 0), 2) AS avg_cac
    FROM channel_metrics
)
SELECT
    cm.channel_name,
    cm.total_spend,
    cm.leads,
    cm.conversions,
    cm.conversion_rate_pct,
    cm.customers_acquired,
    cm.cac,
    cm.revenue_in_window,
    cm.revenue_lifetime,
    cm.roas_in_window,
    cm.roas_lifetime,
    cl.avg_ltv_lifetime,
    c90.avg_ltv_90d,
    ROUND(cl.avg_ltv_lifetime / NULLIF(cm.cac, 0), 2) AS ltv_cac_lifetime,
    ROUND(c90.avg_ltv_90d / NULLIF(cm.cac, 0), 2)        AS ltv_cac_90d,
    cm.marketing_contribution,
    crm1.retention_month_1_pct,
    crm3.retention_month_3_pct,
    CASE
        WHEN cm.marketing_contribution > 0 AND cl.avg_ltv_lifetime / NULLIF(cm.cac, 0) >= 3
             AND cm.cac <= oac.avg_cac
            THEN 'Scale candidate'
        WHEN cm.marketing_contribution > 0 AND cl.avg_ltv_lifetime / NULLIF(cm.cac, 0) >= 1.5
            THEN 'Maintain / monitor'
        WHEN cm.marketing_contribution > 0 AND cl.avg_ltv_lifetime / NULLIF(cm.cac, 0) >= 1
            THEN 'Review'
        ELSE 'Reduce / investigate'
    END AS recommendation
FROM channel_metrics cm
JOIN channel_ltv cl ON cl.channel_name = cm.channel_name
LEFT JOIN channel_ltv_90d c90 ON c90.channel_name = cm.channel_name
LEFT JOIN channel_retention_m1 crm1 ON crm1.channel_name = cm.channel_name
LEFT JOIN channel_retention_m3 crm3 ON crm3.channel_name = cm.channel_name
CROSS JOIN overall_avg_cac oac;
