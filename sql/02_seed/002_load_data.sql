/* ============================================================
   LOAD SYNTHETIC DATA
   Loads the CSVs produced by generate_data.py via server-side
   COPY (the "sql" directory is bind-mounted into the container
   by docker-compose, so the Postgres server process can read the
   generated CSV files directly under sql/02_seed/data).
   Load order respects foreign-key dependencies.
   ============================================================ */

SET search_path TO roas, public;

TRUNCATE TABLE orders, leads, customers, daily_campaign_spend, campaigns, channels
    RESTART IDENTITY CASCADE;

COPY channels (channel_id, channel_name)
    FROM '/sql/02_seed/data/channels.csv' WITH (FORMAT csv, HEADER true);

COPY campaigns (campaign_id, channel_id, campaign_name, start_date, end_date, objective)
    FROM '/sql/02_seed/data/campaigns.csv' WITH (FORMAT csv, HEADER true);

COPY daily_campaign_spend (campaign_id, spend_date, spend_amount, impressions, clicks)
    FROM '/sql/02_seed/data/daily_campaign_spend.csv' WITH (FORMAT csv, HEADER true);

COPY customers (customer_id, first_campaign_id, signup_date, region)
    FROM '/sql/02_seed/data/customers.csv' WITH (FORMAT csv, HEADER true);

COPY leads (lead_id, campaign_id, lead_date, converted_flag, converted_customer_id)
    FROM '/sql/02_seed/data/leads.csv' WITH (FORMAT csv, HEADER true, NULL '');

COPY orders (order_id, customer_id, order_date, order_amount)
    FROM '/sql/02_seed/data/orders.csv' WITH (FORMAT csv, HEADER true);

-- Realign SERIAL sequences with the explicitly-loaded IDs.
SELECT setval('channels_channel_id_seq', (SELECT MAX(channel_id) FROM channels));
SELECT setval('campaigns_campaign_id_seq', (SELECT MAX(campaign_id) FROM campaigns));
SELECT setval('customers_customer_id_seq', (SELECT MAX(customer_id) FROM customers));
SELECT setval('leads_lead_id_seq', (SELECT MAX(lead_id) FROM leads));
SELECT setval('orders_order_id_seq', (SELECT MAX(order_id) FROM orders));
