/* ============================================================
   MART: mart_customer_cohort_spine
   One row per customer per calendar month, from that customer's
   acquisition (cohort) month through the dataset's reference
   month. This is the "customer x month" spine cohort/retention
   analysis needs.

   Why bounded, not a blind customer x all-18-months cartesian
   product: each customer's series starts at THEIR OWN cohort
   month (LATERAL generate_series), so a customer acquired in
   month 15 gets ~3 rows, not 18. That keeps row count close to
   the sum of each cohort's actual remaining observation window
   (~225K rows for ~25K customers) instead of 25K x 18 = 450K+
   rows of mostly meaningless pre-acquisition months.
   ============================================================ */
SET search_path TO roas, public;

CREATE OR REPLACE VIEW mart_customer_cohort_spine AS
SELECT
    sc.customer_id,
    DATE_TRUNC('month', sc.signup_date)::date AS cohort_month,
    sc.acquisition_channel_id                   AS channel_id,
    sc.acquisition_channel_name                   AS channel_name,
    gs.activity_month,
    -- months_since_acquisition via calendar-month arithmetic (not
    -- day subtraction) so "month 1" always means "the next
    -- calendar month", regardless of which day of the month the
    -- customer signed up on.
    (EXTRACT(YEAR FROM gs.activity_month) * 12 + EXTRACT(MONTH FROM gs.activity_month))
      - (EXTRACT(YEAR FROM DATE_TRUNC('month', sc.signup_date)) * 12
         + EXTRACT(MONTH FROM DATE_TRUNC('month', sc.signup_date))) AS months_since_acquisition
FROM stg_customers sc
CROSS JOIN mart_reference_date rd
CROSS JOIN LATERAL generate_series(
    DATE_TRUNC('month', sc.signup_date)::date,
    rd.reference_month,
    interval '1 month'
) AS gs(activity_month);
