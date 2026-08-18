/* ============================================================
   METRIC: MARKETING CONTRIBUTION
   Business question: after paying for the marketing that
   acquired them, how much revenue is left over from a
   campaign/channel's customers?

   Formula:
       marketing_contribution = attributed revenue - marketing spend

   This is explicitly NOT company profit. It excludes cost of
   goods sold, fulfillment, payroll, and all other operating
   costs - only the marketing spend side of the ledger is
   subtracted. Treat it as a marketing-efficiency signal, not a
   P&L line.

   Uses revenue_lifetime_to_date (see roas.sql for the two-window
   explanation) since contribution is meant to answer "has this
   campaign earned back more than it cost, to date" rather than
   being capped at the campaign's original run dates.
   ============================================================ */
SET search_path TO roas, public;

-- 1. Marketing contribution by campaign, with a channel-level
--    rank so the best/worst campaign in each channel is obvious
--    at a glance (window function: RANK OVER PARTITION).
WITH campaign_contribution AS (
    SELECT
        sc.channel_name,
        sc.campaign_id,
        sc.campaign_name,
        s.total_spend,
        r.revenue_lifetime_to_date,
        ROUND(r.revenue_lifetime_to_date - s.total_spend, 2) AS marketing_contribution
    FROM stg_campaigns sc
    JOIN mart_campaign_spend s   ON s.campaign_id = sc.campaign_id
    JOIN mart_campaign_revenue r ON r.campaign_id = sc.campaign_id
)
SELECT
    *,
    RANK() OVER (PARTITION BY channel_name ORDER BY marketing_contribution DESC) AS contribution_rank_in_channel
FROM campaign_contribution
ORDER BY marketing_contribution DESC;

-- 2. Marketing contribution by channel
SELECT
    sc.channel_name,
    SUM(s.total_spend)                 AS total_spend,
    SUM(r.revenue_lifetime_to_date)      AS revenue_lifetime_to_date,
    ROUND(SUM(r.revenue_lifetime_to_date) - SUM(s.total_spend), 2) AS marketing_contribution
FROM stg_campaigns sc
JOIN mart_campaign_spend s   ON s.campaign_id = sc.campaign_id
JOIN mart_campaign_revenue r ON r.campaign_id = sc.campaign_id
GROUP BY sc.channel_name
ORDER BY marketing_contribution DESC;
