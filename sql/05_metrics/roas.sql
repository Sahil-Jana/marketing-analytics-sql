/* ============================================================
   METRIC: RETURN ON AD SPEND (ROAS)
   Business question: for every dollar spent on a campaign, how
   many dollars of revenue did the customers it acquired
   generate?

   Formula:
       ROAS = attributed revenue / campaign marketing spend

   Attribution assumption: same first-touch rule as CAC - revenue
   from a customer is attributed to customers.first_campaign_id.

   Revenue window - deliberately reported as TWO separate metrics
   so campaign-period spend is never silently divided into revenue
   from a different time horizon:
     - roas_in_window: revenue from orders placed DURING the
       campaign's own start_date..end_date. Answers "did the
       campaign pay for itself while it was running?"
     - roas_lifetime: ALL revenue to date from customers the
       campaign acquired, divided by the campaign's total spend.
       Answers "has the campaign paid for itself since launch?"
       This number only grows over time and is expected to be
       >= roas_in_window.
   ============================================================ */
SET search_path TO roas, public;

-- 1. ROAS by campaign
SELECT
    sc.channel_name,
    sc.campaign_id,
    sc.campaign_name,
    s.total_spend,
    r.revenue_in_campaign_window,
    r.revenue_lifetime_to_date,
    ROUND(r.revenue_in_campaign_window / NULLIF(s.total_spend, 0), 2) AS roas_in_window,
    ROUND(r.revenue_lifetime_to_date / NULLIF(s.total_spend, 0), 2)   AS roas_lifetime
FROM stg_campaigns sc
JOIN mart_campaign_spend s   ON s.campaign_id = sc.campaign_id
JOIN mart_campaign_revenue r ON r.campaign_id = sc.campaign_id
ORDER BY roas_lifetime DESC NULLS LAST;

-- 2. ROAS by channel (revenue and spend rolled up first, then divided)
SELECT
    sc.channel_name,
    SUM(s.total_spend)                     AS total_spend,
    SUM(r.revenue_in_campaign_window)         AS revenue_in_campaign_window,
    SUM(r.revenue_lifetime_to_date)             AS revenue_lifetime_to_date,
    ROUND(SUM(r.revenue_in_campaign_window) / NULLIF(SUM(s.total_spend), 0), 2) AS roas_in_window,
    ROUND(SUM(r.revenue_lifetime_to_date) / NULLIF(SUM(s.total_spend), 0), 2)   AS roas_lifetime
FROM stg_campaigns sc
JOIN mart_campaign_spend s   ON s.campaign_id = sc.campaign_id
JOIN mart_campaign_revenue r ON r.campaign_id = sc.campaign_id
GROUP BY sc.channel_name
ORDER BY roas_lifetime DESC NULLS LAST;
