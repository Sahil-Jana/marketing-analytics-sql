/* ============================================================
   DATA QUALITY VALIDATION SUITE
   Each check returns a row with a PASS/FAIL status and the
   count of offending rows. Every check is expected to PASS
   against a correctly generated/loaded dataset - a FAIL here
   means either the generator or the load step has a bug.
   ============================================================ */
SET search_path TO roas, public;

WITH checks AS (

    -- Primary key uniqueness (PKs already enforce this, but the
    -- check makes the guarantee explicit and would catch a
    -- reload gone wrong).
    SELECT 'PK uniqueness: channels' AS check_name,
           COUNT(*) - COUNT(DISTINCT channel_id) AS failing_rows FROM channels
    UNION ALL
    SELECT 'PK uniqueness: campaigns',
           COUNT(*) - COUNT(DISTINCT campaign_id) FROM campaigns
    UNION ALL
    SELECT 'PK uniqueness: customers',
           COUNT(*) - COUNT(DISTINCT customer_id) FROM customers
    UNION ALL
    SELECT 'PK uniqueness: leads',
           COUNT(*) - COUNT(DISTINCT lead_id) FROM leads
    UNION ALL
    SELECT 'PK uniqueness: orders',
           COUNT(*) - COUNT(DISTINCT order_id) FROM orders

    -- Required-field nulls
    UNION ALL
    SELECT 'Required fields: campaigns (channel_id/dates)',
           COUNT(*) FILTER (WHERE channel_id IS NULL OR start_date IS NULL OR end_date IS NULL)
    FROM campaigns
    UNION ALL
    SELECT 'Required fields: customers (first_campaign_id/signup_date)',
           COUNT(*) FILTER (WHERE first_campaign_id IS NULL OR signup_date IS NULL)
    FROM customers
    UNION ALL
    SELECT 'Required fields: orders (customer_id/order_date/order_amount)',
           COUNT(*) FILTER (WHERE customer_id IS NULL OR order_date IS NULL OR order_amount IS NULL)
    FROM orders

    -- Foreign key / orphan checks (belt-and-suspenders on top of
    -- the DB-level FK constraints - would only fail on a raw
    -- load that bypassed constraints).
    UNION ALL
    SELECT 'Orphans: campaigns.channel_id -> channels',
           COUNT(*) FROM campaigns cam
           LEFT JOIN channels ch ON ch.channel_id = cam.channel_id
           WHERE ch.channel_id IS NULL
    UNION ALL
    SELECT 'Orphans: customers.first_campaign_id -> campaigns',
           COUNT(*) FROM customers c
           LEFT JOIN campaigns cam ON cam.campaign_id = c.first_campaign_id
           WHERE cam.campaign_id IS NULL
    UNION ALL
    SELECT 'Orphans: leads.campaign_id -> campaigns',
           COUNT(*) FROM leads l
           LEFT JOIN campaigns cam ON cam.campaign_id = l.campaign_id
           WHERE cam.campaign_id IS NULL
    UNION ALL
    SELECT 'Orphans: orders.customer_id -> customers',
           COUNT(*) FROM orders o
           LEFT JOIN customers c ON c.customer_id = o.customer_id
           WHERE c.customer_id IS NULL

    -- Non-negative / positive value checks
    UNION ALL
    SELECT 'Non-negative spend', COUNT(*) FROM daily_campaign_spend WHERE spend_amount < 0
    UNION ALL
    SELECT 'Positive order amounts', COUNT(*) FROM orders WHERE order_amount <= 0

    -- Sensible campaign dates
    UNION ALL
    SELECT 'Campaign dates: end >= start', COUNT(*) FROM campaigns WHERE end_date < start_date
    UNION ALL
    SELECT 'Spend dates within campaign window',
           COUNT(*) FROM daily_campaign_spend s
           JOIN campaigns cam ON cam.campaign_id = s.campaign_id
           WHERE s.spend_date < cam.start_date OR s.spend_date > cam.end_date

    -- Lead/conversion consistency
    UNION ALL
    SELECT 'Lead conversion flag consistency',
           COUNT(*) FROM leads
           WHERE (converted_flag = TRUE AND converted_customer_id IS NULL)
              OR (converted_flag = FALSE AND converted_customer_id IS NOT NULL)
    UNION ALL
    SELECT 'Converted leads map to exactly one customer each (no duplicate customer reuse)',
           COUNT(*) FROM (
               SELECT converted_customer_id
               FROM leads
               WHERE converted_customer_id IS NOT NULL
               GROUP BY converted_customer_id
               HAVING COUNT(*) > 1
           ) dup
    UNION ALL
    SELECT 'Converted lead campaign matches customer first_campaign_id',
           COUNT(*) FROM leads l
           JOIN customers c ON c.customer_id = l.converted_customer_id
           WHERE l.converted_flag = TRUE AND l.campaign_id <> c.first_campaign_id
    UNION ALL
    SELECT 'Converted lead date matches customer signup_date',
           COUNT(*) FROM leads l
           JOIN customers c ON c.customer_id = l.converted_customer_id
           WHERE l.converted_flag = TRUE AND l.lead_date <> c.signup_date

    -- Order timing vs. signup
    UNION ALL
    SELECT 'Order date >= customer signup_date',
           COUNT(*) FROM orders o
           JOIN customers c ON c.customer_id = o.customer_id
           WHERE o.order_date < c.signup_date

    -- Cross-level reconciliation
    UNION ALL
    SELECT 'Reconciliation: campaign-level leads sum = table total',
           ABS((SELECT SUM(lead_count) FROM mart_campaign_funnel) - (SELECT COUNT(*) FROM leads))
    UNION ALL
    SELECT 'Reconciliation: campaign-level acquired customers sum = customers table total',
           ABS((SELECT SUM(acquired_customer_count) FROM mart_campaign_funnel) - (SELECT COUNT(*) FROM customers))
    UNION ALL
    SELECT 'Reconciliation: campaign-level spend sum = daily_campaign_spend total',
           ABS((SELECT SUM(total_spend) FROM mart_campaign_spend) - (SELECT SUM(spend_amount) FROM daily_campaign_spend))
    UNION ALL
    SELECT 'Reconciliation: customer-level revenue sum = orders total',
           ABS((SELECT SUM(lifetime_revenue_to_date) FROM mart_customer_revenue) - (SELECT SUM(order_amount) FROM orders))
)
SELECT
    check_name,
    failing_rows,
    CASE WHEN failing_rows = 0 THEN 'PASS' ELSE 'FAIL' END AS status
FROM checks
ORDER BY status DESC, check_name;
