/* ============================================================
   MART: mart_customer_rfm
   Behavioral RFM (Recency/Frequency/Monetary) scoring, computed
   entirely from observed orders - no pre-existing churn/quality
   label is used anywhere in this project.

   Reference date: mart_reference_date.reference_date (the latest
   observed order date in the dataset), NOT the real current
   date, so recency and the resulting segments are reproducible
   on every re-run.

   Scoring: NTILE(5) splits customers into equal-sized quintiles
   per dimension, which is why it's used instead of fixed dollar/
   day cutoffs - fixed cutoffs would need re-tuning any time the
   dataset's scale changes, quintiles adapt automatically. Score
   5 always means "best" on that dimension:
     - recency_score:   5 = ordered most recently
     - frequency_score: 5 = most orders
     - monetary_score:  5 = highest total spend
   ============================================================ */
SET search_path TO roas, public;

CREATE OR REPLACE VIEW mart_customer_rfm AS
WITH customer_orders AS (
    SELECT
        customer_id,
        COUNT(*)                       AS frequency,
        SUM(order_amount)                AS monetary,
        MAX(order_date)                    AS last_order_date
    FROM orders
    GROUP BY customer_id
),
rfm_base AS (
    SELECT
        sc.customer_id,
        sc.acquisition_channel_id   AS channel_id,
        sc.acquisition_channel_name AS channel_name,
        sc.signup_date,
        co.frequency,
        co.monetary,
        co.last_order_date,
        (rd.reference_date - co.last_order_date) AS recency_days
    FROM stg_customers sc
    JOIN customer_orders co ON co.customer_id = sc.customer_id
    CROSS JOIN mart_reference_date rd
),
scored AS (
    SELECT
        *,
        -- DESC: smallest recency_days (most recent order) must land in
        -- the LAST bucket (score 5 = best), so rows have to be fed to
        -- NTILE in descending recency_days order, not ascending.
        -- customer_id is appended as a tiebreaker in all three: with
        -- thousands of customers sharing the same recency_days/
        -- frequency/monetary value, NTILE's bucket assignment for tied
        -- rows is otherwise unspecified and can vary between identical
        -- reloads of the same data (observed in practice - segment
        -- counts shifted by ~1% across two loads of byte-identical
        -- CSVs before this fix). customer_id makes it deterministic.
        NTILE(5) OVER (ORDER BY recency_days DESC, customer_id) AS recency_score,
        NTILE(5) OVER (ORDER BY frequency ASC, customer_id)       AS frequency_score,
        NTILE(5) OVER (ORDER BY monetary ASC, customer_id)          AS monetary_score
    FROM rfm_base
)
SELECT
    customer_id,
    channel_id,
    channel_name,
    signup_date,
    recency_days,
    frequency,
    monetary,
    recency_score,
    frequency_score,
    monetary_score,
    -- Segment assignment: evaluated top-to-bottom, first match wins,
    -- so every customer lands in exactly one segment.
    CASE
        WHEN recency_score >= 4 AND frequency_score >= 4 AND monetary_score >= 4
            THEN 'Champions'          -- recent, frequent, high spend: the core base
        WHEN frequency = 1 AND recency_score >= 4
            THEN 'New'                -- exactly one order on record, placed recently
                                       -- (raw frequency, not the quintile score, so
                                       -- "New" always means literally one order)
        WHEN recency_score <= 2 AND frequency_score <= 2 AND monetary_score <= 2
            THEN 'Lapsed'             -- low on every dimension: effectively gone
        WHEN recency_score <= 2 AND (frequency_score >= 3 OR monetary_score >= 3)
            THEN 'At Risk'            -- used to be valuable, hasn't ordered recently
        WHEN frequency_score >= 3 AND monetary_score >= 3
            THEN 'Loyal'              -- consistently buys, healthy spend, not top-tier recency
        ELSE 'Needs Attention'        -- mixed signals: doesn't cleanly fit the above
    END AS segment
FROM scored;
