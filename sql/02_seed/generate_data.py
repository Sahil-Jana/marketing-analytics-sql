"""
Deterministic synthetic data generator for the marketing analytics schema.

Everything here is FAKE data produced by a seeded random-number generator.
No real customers, campaigns, or spend are represented. Re-running this
script with the same seed always produces byte-identical output, which is
what makes the project reproducible end to end.

Only the Python standard library is used (random, csv, datetime) to keep
setup dependencies at zero beyond Python itself.

Modeling approach:
  - Each channel has a base cost-per-lead, conversion rate, average order
    value, and repeat-purchase gap, so channels are believably different
    from each other rather than randomly interchangeable.
  - Each campaign inherits its channel's profile with a per-campaign
    multiplier (+/-20%) so campaigns within a channel still vary.
  - Daily spend drives daily lead volume (spend / cost-per-lead), so CAC
    and lead volume are internally consistent by construction.
  - Repeat orders are generated as a Poisson-like process (exponential
    inter-arrival gaps) per customer, so repeat-purchase behavior differs
    by acquisition channel.
"""

import csv
import os
import random
from datetime import date, timedelta

SEED = 42
rng = random.Random(SEED)

OUT_DIR = os.path.join(os.path.dirname(__file__), "data")
os.makedirs(OUT_DIR, exist_ok=True)

WINDOW_START = date(2025, 1, 1)
WINDOW_END = date(2026, 6, 30)  # ~18 months

REGIONS = ["North America", "Europe", "APAC", "LATAM"]
OBJECTIVES = ["Lead Generation", "Conversions", "Brand Awareness", "Retargeting"]

# channel_name: (num_campaigns, daily_budget_min, daily_budget_max,
#                cost_per_lead_mean, cost_per_lead_sd, conversion_rate,
#                cpm, ctr, aov_mean, aov_sd, repeat_gap_days)
CHANNELS = {
    "Paid Search":    (8, 150, 400, 9.0, 1.5, 0.220, 18, 0.030, 68, 15, 190),
    "Paid Social":    (8, 120, 350, 6.0, 1.2, 0.154, 12, 0.025, 52, 12, 240),
    "Email":          (6, 20,  60,  1.6, 0.4, 0.352, 4,  0.050, 57, 13, 130),
    "Organic Search": (6, 10,  30,  0.6, 0.2, 0.297, 2,  0.060, 61, 14, 150),
    "Referral":       (6, 15,  45,  2.2, 0.5, 0.396, 3,  0.055, 71, 16, 140),
    "Affiliate":      (6, 80,  220, 6.5, 1.3, 0.132, 10, 0.020, 46, 10, 280),
}

MIN_CAMPAIGN_DAYS = 30
MAX_CAMPAIGN_DAYS = 150


def clamp(value, low, high):
    return max(low, min(high, value))


def days_between(d1, d2):
    return (d2 - d1).days


# ---------------------------------------------------------------
# 1. channels
# ---------------------------------------------------------------
channels_rows = []
channel_id_by_name = {}
for i, name in enumerate(CHANNELS.keys(), start=1):
    channel_id_by_name[name] = i
    channels_rows.append((i, name))

# ---------------------------------------------------------------
# 2. campaigns
# ---------------------------------------------------------------
campaigns_rows = []
campaign_meta = {}  # campaign_id -> dict of effective params
campaign_id = 0
for name, cfg in CHANNELS.items():
    (num_campaigns, budget_min, budget_max, cpl_mean, cpl_sd, conv_rate,
     cpm, ctr, aov_mean, aov_sd, repeat_gap) = cfg
    for n in range(num_campaigns):
        campaign_id += 1
        mult = rng.uniform(0.8, 1.2)
        duration = rng.randint(MIN_CAMPAIGN_DAYS, MAX_CAMPAIGN_DAYS)
        latest_start = WINDOW_END - timedelta(days=duration)
        span_days = days_between(WINDOW_START, latest_start)
        start_offset = rng.randint(0, max(span_days, 0))
        start_date = WINDOW_START + timedelta(days=start_offset)
        end_date = start_date + timedelta(days=duration)
        objective = rng.choice(OBJECTIVES)
        campaign_name = f"{name} - {objective} - {n + 1:02d}"

        campaign_meta[campaign_id] = dict(
            channel_id=channel_id_by_name[name],
            channel_name=name,
            start_date=start_date,
            end_date=end_date,
            daily_budget=(budget_min * mult, budget_max * mult),
            cost_per_lead=max(0.2, rng.gauss(cpl_mean, cpl_sd) * mult),
            conversion_rate=clamp(conv_rate * rng.uniform(0.85, 1.15), 0.02, 0.75),
            cpm=cpm,
            ctr=clamp(ctr * rng.uniform(0.8, 1.2), 0.005, 0.2),
            aov_mean=aov_mean * mult,
            aov_sd=aov_sd,
            repeat_gap_days=max(20, repeat_gap * rng.uniform(0.85, 1.15)),
        )
        campaigns_rows.append((
            campaign_id, channel_id_by_name[name], campaign_name,
            start_date.isoformat(), end_date.isoformat(), objective,
        ))

# ---------------------------------------------------------------
# 3. daily_campaign_spend + 4. leads + 5. customers (generated together
#    since lead volume is driven day-by-day from spend)
# ---------------------------------------------------------------
spend_rows = []
leads_rows = []
customers_rows = []

lead_id = 0
customer_id = 0

for cid, meta in campaign_meta.items():
    d = meta["start_date"]
    budget_min, budget_max = meta["daily_budget"]
    while d <= meta["end_date"]:
        base_budget = rng.uniform(budget_min, budget_max)
        daily_mult = clamp(rng.gauss(1.0, 0.25), 0.3, 2.0)
        spend_amount = round(base_budget * daily_mult, 2)

        impressions = max(0, round((spend_amount / meta["cpm"]) * 1000 * rng.gauss(1.0, 0.1)))
        clicks = max(0, round(impressions * meta["ctr"] * rng.gauss(1.0, 0.15)))

        spend_rows.append((cid, d.isoformat(), spend_amount, impressions, clicks))

        expected_leads = spend_amount / meta["cost_per_lead"]
        lead_count = max(0, round(rng.gauss(expected_leads, max(expected_leads, 1) ** 0.5)))

        for _ in range(lead_count):
            lead_id += 1
            converted = rng.random() < meta["conversion_rate"]
            if converted:
                customer_id += 1
                region = rng.choice(REGIONS)
                customers_rows.append((customer_id, cid, d.isoformat(), region))
                leads_rows.append((lead_id, cid, d.isoformat(), "true", customer_id))
            else:
                leads_rows.append((lead_id, cid, d.isoformat(), "false", ""))

        d += timedelta(days=1)

# ---------------------------------------------------------------
# 6. orders: first purchase shortly after signup, then a Poisson-like
#    repeat-purchase process with channel-specific gaps until the end
#    of the observation window.
# ---------------------------------------------------------------
orders_rows = []
order_id = 0

for cust_id, camp_id, signup_iso, region in customers_rows:
    meta = campaign_meta[camp_id]
    signup_dt = date.fromisoformat(signup_iso)

    first_order_dt = signup_dt + timedelta(days=rng.randint(0, 3))
    if first_order_dt > WINDOW_END:
        first_order_dt = WINDOW_END

    order_id += 1
    amount = max(5.0, round(rng.gauss(meta["aov_mean"], meta["aov_sd"]), 2))
    orders_rows.append((order_id, cust_id, first_order_dt.isoformat(), amount))

    current_dt = first_order_dt
    gap_mean = meta["repeat_gap_days"]
    while True:
        gap = rng.expovariate(1.0 / gap_mean)
        next_dt = current_dt + timedelta(days=gap)
        if next_dt > WINDOW_END:
            break
        order_id += 1
        amount = max(5.0, round(rng.gauss(meta["aov_mean"], meta["aov_sd"]), 2))
        orders_rows.append((order_id, cust_id, next_dt.isoformat(), amount))
        current_dt = next_dt

# ---------------------------------------------------------------
# Write CSVs
# ---------------------------------------------------------------
def write_csv(filename, header, rows):
    path = os.path.join(OUT_DIR, filename)
    with open(path, "w", newline="", encoding="utf-8") as f:
        writer = csv.writer(f)
        writer.writerow(header)
        writer.writerows(rows)
    print(f"  {filename}: {len(rows):,} rows")


print("Generating synthetic marketing analytics dataset (seed=%d)..." % SEED)
write_csv("channels.csv", ["channel_id", "channel_name"], channels_rows)
write_csv("campaigns.csv",
          ["campaign_id", "channel_id", "campaign_name", "start_date", "end_date", "objective"],
          campaigns_rows)
write_csv("daily_campaign_spend.csv",
          ["campaign_id", "spend_date", "spend_amount", "impressions", "clicks"],
          spend_rows)
write_csv("customers.csv",
          ["customer_id", "first_campaign_id", "signup_date", "region"],
          customers_rows)
write_csv("leads.csv",
          ["lead_id", "campaign_id", "lead_date", "converted_flag", "converted_customer_id"],
          leads_rows)
write_csv("orders.csv",
          ["order_id", "customer_id", "order_date", "order_amount"],
          orders_rows)

print("Done. CSVs written to:", OUT_DIR)
