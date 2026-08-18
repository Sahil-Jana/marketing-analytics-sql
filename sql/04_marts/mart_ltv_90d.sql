/* ============================================================
   MART: mart_ltv_90d
   Fixed 90-day-since-signup observed revenue per customer, plus
   a flag for whether that 90-day window has actually fully
   elapsed as of the reference date.

   WHY THIS EXISTS: comparing raw lifetime LTV across campaigns
   is misleading when campaigns acquired customers at very
   different points in time - a campaign that ran in month 1 has
   had 17 months for its customers to accumulate revenue, one
   that ran in month 16 has had almost none, regardless of true
   customer quality. A fixed 90-day window is comparable across
   every campaign because it measures the same length of time
   for everyone. window_complete=false customers are excluded
   from 90-day averages (see ltv.sql) rather than silently
   included with an artificially truncated number.
   ============================================================ */
SET search_path TO roas, public;

CREATE OR REPLACE VIEW mart_ltv_90d AS
SELECT
    sc.customer_id,
    sc.first_campaign_id,
    sc.acquisition_channel_id   AS channel_id,
    sc.acquisition_channel_name AS channel_name,
    sc.signup_date,
    COALESCE(SUM(o.order_amount) FILTER (
        WHERE o.order_date <= sc.signup_date + INTERVAL '90 days'
    ), 0) AS ltv_90d,
    (sc.signup_date + INTERVAL '90 days')::date <= rd.reference_date AS window_complete
FROM stg_customers sc
CROSS JOIN mart_reference_date rd
LEFT JOIN orders o ON o.customer_id = sc.customer_id
GROUP BY
    sc.customer_id, sc.first_campaign_id, sc.acquisition_channel_id,
    sc.acquisition_channel_name, sc.signup_date, rd.reference_date;
