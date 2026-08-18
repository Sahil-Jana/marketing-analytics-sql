/* ============================================================
   MART: mart_campaign_spend
   Campaign-level rollup of daily spend. Reused by CAC, ROAS,
   and campaign performance so the spend total isn't re-summed
   with slightly different logic in each metric query.
   ============================================================ */
SET search_path TO roas, public;

CREATE OR REPLACE VIEW mart_campaign_spend AS
SELECT
    campaign_id,
    SUM(spend_amount)  AS total_spend,
    SUM(impressions)   AS total_impressions,
    SUM(clicks)         AS total_clicks,
    MIN(spend_date)     AS first_spend_date,
    MAX(spend_date)     AS last_spend_date
FROM daily_campaign_spend
GROUP BY campaign_id;
