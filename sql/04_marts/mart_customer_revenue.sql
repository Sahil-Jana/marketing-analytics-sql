/* ============================================================
   MART: mart_customer_revenue
   Observed, cumulative revenue per customer from the orders
   table. This is the FOUNDATION for Phase 3 LTV/cohort work -
   it does not yet build cohort-aware or channel-level LTV.
   ============================================================ */
SET search_path TO roas, public;

CREATE OR REPLACE VIEW mart_customer_revenue AS
SELECT
    sc.customer_id,
    sc.first_campaign_id,
    sc.acquisition_channel_id,
    sc.acquisition_channel_name,
    sc.signup_date,
    sc.region,
    COUNT(o.order_id)                     AS order_count,
    COALESCE(SUM(o.order_amount), 0)        AS lifetime_revenue_to_date,
    MIN(o.order_date)                        AS first_order_date,
    MAX(o.order_date)                        AS last_order_date
FROM stg_customers sc
LEFT JOIN orders o ON o.customer_id = sc.customer_id
GROUP BY
    sc.customer_id, sc.first_campaign_id, sc.acquisition_channel_id,
    sc.acquisition_channel_name, sc.signup_date, sc.region;
