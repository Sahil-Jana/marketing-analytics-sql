/* ============================================================
   ROAS ANALYTICS - CORE SCHEMA
   Six-table relational model supporting the full funnel:
   channel -> campaign -> lead -> customer -> order
   with daily campaign spend as the cost side of the ledger.
   ============================================================ */

CREATE SCHEMA IF NOT EXISTS roas;
SET search_path TO roas, public;

DROP TABLE IF EXISTS orders CASCADE;
DROP TABLE IF EXISTS leads CASCADE;
DROP TABLE IF EXISTS customers CASCADE;
DROP TABLE IF EXISTS daily_campaign_spend CASCADE;
DROP TABLE IF EXISTS campaigns CASCADE;
DROP TABLE IF EXISTS channels CASCADE;

-- ------------------------------------------------------------
-- channels: dimension so channel names stay consistent across
-- campaigns instead of being repeated as free text.
-- ------------------------------------------------------------
CREATE TABLE channels (
    channel_id      SERIAL PRIMARY KEY,
    channel_name    VARCHAR(50) NOT NULL UNIQUE
);

-- ------------------------------------------------------------
-- campaigns: the attribution grain for spend and acquisition.
-- ------------------------------------------------------------
CREATE TABLE campaigns (
    campaign_id     SERIAL PRIMARY KEY,
    channel_id      INTEGER NOT NULL REFERENCES channels(channel_id),
    campaign_name   VARCHAR(100) NOT NULL,
    start_date      DATE NOT NULL,
    end_date        DATE NOT NULL,
    objective       VARCHAR(50) NOT NULL,
    CHECK (end_date >= start_date)
);

CREATE INDEX idx_campaigns_channel_id ON campaigns(channel_id);

-- ------------------------------------------------------------
-- daily_campaign_spend: daily grain so CAC/ROAS can be computed
-- over arbitrary date windows and spend trends can be analyzed.
-- Composite PK (campaign_id, spend_date) is the natural key -
-- one spend row per campaign per day.
-- ------------------------------------------------------------
CREATE TABLE daily_campaign_spend (
    campaign_id     INTEGER NOT NULL REFERENCES campaigns(campaign_id),
    spend_date      DATE NOT NULL,
    spend_amount    NUMERIC(12,2) NOT NULL CHECK (spend_amount >= 0),
    impressions     INTEGER NOT NULL CHECK (impressions >= 0),
    clicks          INTEGER NOT NULL CHECK (clicks >= 0),
    PRIMARY KEY (campaign_id, spend_date)
);

CREATE INDEX idx_spend_date ON daily_campaign_spend(spend_date);

-- ------------------------------------------------------------
-- customers: anchor entity for revenue/LTV/cohort analysis.
-- first_campaign_id records the acquisition (first-touch)
-- campaign - see README for the attribution assumption.
-- No churn_probability column: Phase 3 segmentation is derived
-- from observed order behavior, not a pre-existing label.
-- ------------------------------------------------------------
CREATE TABLE customers (
    customer_id         SERIAL PRIMARY KEY,
    first_campaign_id   INTEGER NOT NULL REFERENCES campaigns(campaign_id),
    signup_date          DATE NOT NULL,
    region               VARCHAR(50)
);

CREATE INDEX idx_customers_first_campaign_id ON customers(first_campaign_id);

-- ------------------------------------------------------------
-- leads: acquisition-funnel events. Without this table there is
-- no real numerator/denominator for conversion rate - it makes
-- "leads -> conversions -> customers" an actual funnel instead
-- of an assumed one.
-- ------------------------------------------------------------
CREATE TABLE leads (
    lead_id                 SERIAL PRIMARY KEY,
    campaign_id             INTEGER NOT NULL REFERENCES campaigns(campaign_id),
    lead_date                DATE NOT NULL,
    converted_flag            BOOLEAN NOT NULL DEFAULT FALSE,
    converted_customer_id     INTEGER REFERENCES customers(customer_id),
    CHECK (
        (converted_flag = TRUE  AND converted_customer_id IS NOT NULL) OR
        (converted_flag = FALSE AND converted_customer_id IS NULL)
    )
);

CREATE INDEX idx_leads_campaign_id ON leads(campaign_id);
CREATE INDEX idx_leads_converted_customer_id ON leads(converted_customer_id);
CREATE INDEX idx_leads_lead_date ON leads(lead_date);

-- ------------------------------------------------------------
-- orders: dated, multi-row-per-customer revenue events. This is
-- what makes cohort/retention/repeat-purchase analysis possible
-- in Phase 3 (the reference project had one undated revenue row
-- per user, which ruled all of that out).
-- ------------------------------------------------------------
CREATE TABLE orders (
    order_id        SERIAL PRIMARY KEY,
    customer_id     INTEGER NOT NULL REFERENCES customers(customer_id),
    order_date       DATE NOT NULL,
    order_amount      NUMERIC(12,2) NOT NULL CHECK (order_amount > 0)
);

CREATE INDEX idx_orders_customer_id ON orders(customer_id);
CREATE INDEX idx_orders_order_date ON orders(order_date);
