/* ============================================================
   METRIC: CUSTOMER REVENUE FOUNDATION
   Business question: what has each customer actually spent
   with us to date, and how does that break down by acquisition
   channel? This is a FOUNDATION query only - Phase 3 builds
   cohort-aware LTV and RFM segmentation on top of it. Nothing
   here should be read as final LTV.
   ============================================================ */
SET search_path TO roas, public;

-- 1. Per-customer observed revenue, ranked by value within
--    their acquisition channel (window function).
SELECT
    customer_id,
    acquisition_channel_name,
    signup_date,
    order_count,
    lifetime_revenue_to_date,
    first_order_date,
    last_order_date,
    RANK() OVER (PARTITION BY acquisition_channel_name ORDER BY lifetime_revenue_to_date DESC) AS revenue_rank_in_channel
FROM mart_customer_revenue
ORDER BY lifetime_revenue_to_date DESC;

-- 2. Channel-level summary: average observed revenue and orders
--    per acquired customer (directional signal only, not LTV).
SELECT
    acquisition_channel_name,
    COUNT(*)                                    AS customers_acquired,
    ROUND(AVG(order_count), 2)                     AS avg_orders_per_customer,
    ROUND(AVG(lifetime_revenue_to_date), 2)           AS avg_revenue_per_customer,
    ROUND(SUM(lifetime_revenue_to_date), 2)              AS total_revenue_to_date
FROM mart_customer_revenue
GROUP BY acquisition_channel_name
ORDER BY avg_revenue_per_customer DESC;
