/* ============================================================
   MART: mart_reference_date
   Every "as of today" calculation in Phase 3 (recency for RFM,
   how far a cohort's month spine extends, whether a 90-day
   observation window has fully elapsed) needs a single shared
   "today". Using the actual system date would make results
   different every time the project is re-run; using the latest
   observed order date instead makes every number in this
   project reproducible from the dataset alone.
   ============================================================ */
SET search_path TO roas, public;

CREATE OR REPLACE VIEW mart_reference_date AS
SELECT
    MAX(order_date)                              AS reference_date,
    DATE_TRUNC('month', MAX(order_date))::date     AS reference_month
FROM orders;
