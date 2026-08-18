/* ============================================================
   METRIC: RFM CUSTOMER SEGMENTATION
   Business question: which behavioral groups do our customers
   fall into, and how much of our revenue does each group
   represent? See mart_customer_rfm.sql for the full scoring and
   segment-assignment methodology.
   ============================================================ */
SET search_path TO roas, public;

-- 1. Segment counts and revenue share.
WITH totals AS (
    SELECT SUM(monetary) AS total_revenue FROM mart_customer_rfm
)
SELECT
    r.segment,
    COUNT(*)                                             AS customers,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2)      AS pct_of_customers,
    ROUND(AVG(r.recency_days), 1)                             AS avg_recency_days,
    ROUND(AVG(r.frequency), 2)                                  AS avg_frequency,
    ROUND(AVG(r.monetary), 2)                                     AS avg_monetary,
    ROUND(SUM(r.monetary), 2)                                       AS segment_revenue,
    ROUND(100.0 * SUM(r.monetary) / NULLIF((SELECT total_revenue FROM totals), 0), 2) AS pct_of_revenue
FROM mart_customer_rfm r
GROUP BY r.segment
ORDER BY segment_revenue DESC;

-- 2. Segment mix by acquisition channel (does one channel skew
--    toward higher-value segments?).
SELECT
    channel_name,
    segment,
    COUNT(*) AS customers
FROM mart_customer_rfm
GROUP BY channel_name, segment
ORDER BY channel_name, customers DESC;

-- 3. Manual validation sample: a handful of customers from each
--    segment with their raw R/F/M inputs, to eyeball that the
--    segment assignment matches the underlying numbers.
SELECT customer_id, channel_name, recency_days, frequency, monetary,
       recency_score, frequency_score, monetary_score, segment
FROM (
    SELECT r.*,
           ROW_NUMBER() OVER (PARTITION BY segment ORDER BY customer_id) AS rn
    FROM mart_customer_rfm r
) sampled
WHERE rn <= 3
ORDER BY segment, customer_id;
