/* ============================================================
   POWER BI EXPORT: pbi_campaign_performance
   Campaign-grain version of pbi_channel_performance, for the
   Page 2 table/scatter when a reviewer drills below channel
   level. Same marts, same definitions - just a finer grain.
   ============================================================ */
SET search_path TO roas, public;

CREATE OR REPLACE VIEW pbi_campaign_performance AS
WITH campaign_ltv AS (
    SELECT first_campaign_id, ROUND(AVG(lifetime_revenue_to_date), 2) AS avg_ltv_lifetime
    FROM mart_customer_revenue
    GROUP BY first_campaign_id
)
SELECT
    sc.channel_name,
    sc.campaign_id,
    sc.campaign_name,
    sc.objective,
    sc.start_date,
    sc.end_date,
    s.total_spend,
    f.lead_count                                                                AS leads,
    f.converted_lead_count                                                        AS conversions,
    f.acquired_customer_count                                                       AS customers_acquired,
    ROUND(100.0 * f.converted_lead_count / NULLIF(f.lead_count, 0), 2)               AS conversion_rate_pct,
    ROUND(s.total_spend / NULLIF(f.acquired_customer_count, 0), 2)                      AS cac,
    r.revenue_lifetime_to_date                                                            AS revenue_lifetime,
    ROUND(r.revenue_lifetime_to_date / NULLIF(s.total_spend, 0), 2)                          AS roas_lifetime,
    cl.avg_ltv_lifetime,
    ROUND(cl.avg_ltv_lifetime / NULLIF(s.total_spend / NULLIF(f.acquired_customer_count, 0), 0), 2) AS ltv_cac_lifetime,
    ROUND(r.revenue_lifetime_to_date - s.total_spend, 2)                                       AS marketing_contribution
FROM stg_campaigns sc
JOIN mart_campaign_spend s   ON s.campaign_id = sc.campaign_id
JOIN mart_campaign_funnel f  ON f.campaign_id = sc.campaign_id
JOIN mart_campaign_revenue r ON r.campaign_id = sc.campaign_id
JOIN campaign_ltv cl         ON cl.first_campaign_id = sc.campaign_id;
