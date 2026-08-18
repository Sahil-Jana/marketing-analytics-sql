/* ============================================================
   POWER BI EXPORT: pbi_monthly_trend
   Calendar-month spend vs. revenue, for the Page 1 trend line.
   Not a new analytical concept - it's the same spend/revenue
   totals already validated in Phase 2/3, just grouped by month
   instead of by channel/campaign. Revenue here is ALL observed
   order revenue in that month (not first-touch-attributed to a
   campaign's own window), since a trend chart is meant to show
   overall business rhythm, not campaign-level attribution -
   attribution is handled by the channel/campaign views instead.
   ============================================================ */
SET search_path TO roas, public;

CREATE OR REPLACE VIEW pbi_monthly_trend AS
WITH monthly_spend AS (
    SELECT DATE_TRUNC('month', spend_date)::date AS month, SUM(spend_amount) AS total_spend
    FROM daily_campaign_spend
    GROUP BY DATE_TRUNC('month', spend_date)::date
),
monthly_revenue AS (
    SELECT DATE_TRUNC('month', order_date)::date AS month, SUM(order_amount) AS total_revenue
    FROM orders
    GROUP BY DATE_TRUNC('month', order_date)::date
)
SELECT
    COALESCE(s.month, r.month)          AS month,
    COALESCE(s.total_spend, 0)            AS total_spend,
    COALESCE(r.total_revenue, 0)            AS total_revenue
FROM monthly_spend s
FULL OUTER JOIN monthly_revenue r ON r.month = s.month
ORDER BY 1;
