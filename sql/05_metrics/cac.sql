/* ============================================================
   METRIC: CUSTOMER ACQUISITION COST (CAC)
   Business question: how much does it cost, on average, to
   acquire one paying customer through each campaign/channel?

   Formula:
       CAC = total campaign marketing spend / customers acquired

   Attribution assumption (approved in Phase 1):
     FIRST-TOUCH. A customer's acquisition is credited entirely
     to customers.first_campaign_id - the campaign whose lead
     converted them. There is no multi-touch event table, so
     assist/last-touch attribution cannot be reconstructed from
     this data; first-touch is the simplest assumption the
     schema can actually support and defend.

   Date window: total spend is summed over the campaign's own
   active window (daily_campaign_spend rows only exist while
   the campaign ran), matched against customers whose
   first_campaign_id is that campaign - i.e. spend and the
   customers it produced are always from the same campaign.

   What CAC does NOT represent: fully-loaded acquisition cost
   (no creative/agency/tooling cost included, spend only), and
   it says nothing about the quality/LTV of the customers
   acquired - that's covered separately by ROAS and (Phase 3) LTV.
   ============================================================ */
SET search_path TO roas, public;

-- 1. CAC by campaign
SELECT
    sc.channel_name,
    sc.campaign_id,
    sc.campaign_name,
    s.total_spend,
    f.acquired_customer_count,
    ROUND(s.total_spend / NULLIF(f.acquired_customer_count, 0), 2) AS cac
FROM stg_campaigns sc
JOIN mart_campaign_spend s  ON s.campaign_id = sc.campaign_id
JOIN mart_campaign_funnel f ON f.campaign_id = sc.campaign_id
ORDER BY cac ASC NULLS LAST;

-- 2. CAC by channel (spend and customers rolled up first, THEN
--    divided - averaging the campaign-level CAC values directly
--    would incorrectly weight every campaign equally regardless
--    of size).
SELECT
    sc.channel_name,
    SUM(s.total_spend)                   AS total_spend,
    SUM(f.acquired_customer_count)          AS acquired_customer_count,
    ROUND(SUM(s.total_spend) / NULLIF(SUM(f.acquired_customer_count), 0), 2) AS cac
FROM stg_campaigns sc
JOIN mart_campaign_spend s  ON s.campaign_id = sc.campaign_id
JOIN mart_campaign_funnel f ON f.campaign_id = sc.campaign_id
GROUP BY sc.channel_name
ORDER BY cac ASC NULLS LAST;
