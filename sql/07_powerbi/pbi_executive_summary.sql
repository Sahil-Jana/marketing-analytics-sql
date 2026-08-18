/* ============================================================
   POWER BI EXPORT: pbi_executive_summary
   Single-row account-wide totals for the Page 1 KPI cards.
   LTV:CAC is deliberately NOT included here: at blended grain
   it is mathematically identical to ROAS-lifetime (see
   sql/05_metrics/ltv_cac.sql), so showing both on the same page
   would just duplicate one ratio under two names. Marketing
   contribution is shown instead - a genuinely different signal
   (absolute dollars, not another ratio).
   ============================================================ */
SET search_path TO roas, public;

CREATE OR REPLACE VIEW pbi_executive_summary AS
SELECT
    (SELECT SUM(total_spend) FROM mart_campaign_spend)                                  AS total_spend,
    (SELECT SUM(revenue_lifetime_to_date) FROM mart_campaign_revenue)                     AS total_revenue,
    ROUND(
        (SELECT SUM(revenue_lifetime_to_date) FROM mart_campaign_revenue)
        / NULLIF((SELECT SUM(total_spend) FROM mart_campaign_spend), 0)
    , 2)                                                                                      AS roas_lifetime,
    ROUND(
        (SELECT SUM(total_spend) FROM mart_campaign_spend)
        / NULLIF((SELECT SUM(acquired_customer_count) FROM mart_campaign_funnel), 0)
    , 2)                                                                                          AS blended_cac,
    (SELECT ROUND(AVG(lifetime_revenue_to_date), 2) FROM mart_customer_revenue)                     AS avg_ltv_lifetime,
    ROUND(
        (SELECT SUM(revenue_lifetime_to_date) FROM mart_campaign_revenue)
        - (SELECT SUM(total_spend) FROM mart_campaign_spend)
    , 2)                                                                                              AS marketing_contribution,
    (SELECT COUNT(*) FROM customers)                                                                    AS total_customers,
    (SELECT reference_date FROM mart_reference_date)                                                       AS data_as_of;
