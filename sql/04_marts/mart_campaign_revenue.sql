/* ============================================================
   MART: mart_campaign_revenue
   First-touch attributed revenue per campaign, split into two
   explicitly labeled windows so ROAS never silently mixes them:
     - revenue_in_campaign_window: orders placed while the
       campaign was actively running (start_date..end_date)
     - revenue_lifetime_to_date: ALL orders ever placed by
       customers first acquired through this campaign
   Attribution rule: a customer's revenue is attributed entirely
   to customers.first_campaign_id (first-touch). See README for
   why first-touch was chosen.
   ============================================================ */
SET search_path TO roas, public;

CREATE OR REPLACE VIEW mart_campaign_revenue AS
SELECT
    cam.campaign_id,
    cam.channel_id,
    COALESCE(SUM(o.order_amount) FILTER (
        WHERE o.order_date BETWEEN cam.start_date AND cam.end_date
    ), 0) AS revenue_in_campaign_window,
    COALESCE(SUM(o.order_amount), 0) AS revenue_lifetime_to_date
FROM campaigns cam
JOIN customers c ON c.first_campaign_id = cam.campaign_id
LEFT JOIN orders o ON o.customer_id = c.customer_id
GROUP BY cam.campaign_id, cam.channel_id;
