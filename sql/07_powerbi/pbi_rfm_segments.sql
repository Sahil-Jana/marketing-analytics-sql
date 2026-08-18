/* ============================================================
   POWER BI EXPORT: pbi_rfm_segments
   Segment-level counts/revenue share for Page 3. Same
   methodology as sql/04_marts/mart_customer_rfm.sql - no
   re-derivation of R/F/M or segment logic here.
   ============================================================ */
SET search_path TO roas, public;

CREATE OR REPLACE VIEW pbi_rfm_segments AS
WITH totals AS (
    SELECT SUM(monetary) AS total_revenue, COUNT(*) AS total_customers FROM mart_customer_rfm
)
SELECT
    r.segment,
    COUNT(*)                                                                             AS customers,
    ROUND(100.0 * COUNT(*) / NULLIF((SELECT total_customers FROM totals), 0), 2)             AS pct_of_customers,
    ROUND(AVG(r.recency_days), 1)                                                               AS avg_recency_days,
    ROUND(AVG(r.frequency), 2)                                                                    AS avg_frequency,
    ROUND(AVG(r.monetary), 2)                                                                       AS avg_monetary,
    ROUND(SUM(r.monetary), 2)                                                                        AS segment_revenue,
    ROUND(100.0 * SUM(r.monetary) / NULLIF((SELECT total_revenue FROM totals), 0), 2)                  AS pct_of_revenue
FROM mart_customer_rfm r
GROUP BY r.segment;
