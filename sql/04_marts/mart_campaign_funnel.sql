/* ============================================================
   MART: mart_campaign_funnel
   Campaign-level acquisition funnel: leads, converted leads,
   and distinct acquired customers. This is the numerator/
   denominator source for conversion rate and CAC.
   ============================================================ */
SET search_path TO roas, public;

CREATE OR REPLACE VIEW mart_campaign_funnel AS
SELECT
    campaign_id,
    COUNT(*)                                             AS lead_count,
    COUNT(*) FILTER (WHERE converted_flag)                 AS converted_lead_count,
    COUNT(DISTINCT converted_customer_id)                    AS acquired_customer_count
FROM leads
GROUP BY campaign_id;
