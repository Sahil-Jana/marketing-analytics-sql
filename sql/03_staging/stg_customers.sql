/* ============================================================
   STAGING: stg_customers
   Attaches the first-touch acquisition channel/campaign onto
   every customer. Reused by CAC, campaign performance, and the
   customer revenue foundation.
   ============================================================ */
SET search_path TO roas, public;

CREATE OR REPLACE VIEW stg_customers AS
SELECT
    c.customer_id,
    c.first_campaign_id,
    cam.channel_id AS acquisition_channel_id,
    cam.channel_name AS acquisition_channel_name,
    c.signup_date,
    c.region
FROM customers c
JOIN stg_campaigns cam ON cam.campaign_id = c.first_campaign_id;
