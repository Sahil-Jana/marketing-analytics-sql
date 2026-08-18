/* ============================================================
   MART: mart_customer_month_activity
   The cohort spine (mart_customer_cohort_spine) joined against
   actual monthly order activity. This is the single source both
   cohort retention and channel retention are built from, so the
   two can never disagree about whether a given customer-month
   was "active".

   METHODOLOGY / DEFINITION (documented once, reused everywhere):
   A customer is "active" in a given calendar month if they
   placed at least one order with an order_date in that month.
   This is a BEHAVIORAL definition, not contractual churn - there
   is no subscription or cancellation event in this schema. A
   customer who simply hasn't repurchased yet is indistinguishable
   here from one who never will.
   ============================================================ */
SET search_path TO roas, public;

CREATE OR REPLACE VIEW mart_customer_month_activity AS
WITH monthly_orders AS (
    SELECT
        customer_id,
        DATE_TRUNC('month', order_date)::date AS order_month,
        COUNT(*)                                AS orders_count,
        SUM(order_amount)                         AS revenue
    FROM orders
    GROUP BY customer_id, DATE_TRUNC('month', order_date)::date
)
SELECT
    s.customer_id,
    s.cohort_month,
    s.channel_id,
    s.channel_name,
    s.activity_month,
    s.months_since_acquisition,
    COALESCE(mo.orders_count, 0)      AS orders_count,
    COALESCE(mo.revenue, 0)             AS revenue,
    (mo.customer_id IS NOT NULL)           AS is_active
FROM mart_customer_cohort_spine s
LEFT JOIN monthly_orders mo
    ON mo.customer_id = s.customer_id
   AND mo.order_month = s.activity_month;
