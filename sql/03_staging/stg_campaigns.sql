/* ============================================================
   STAGING: stg_campaigns
   Denormalizes channel_name onto campaigns so every downstream
   query can group/filter by channel without repeating the join.
   Reused by nearly every metric in 05_metrics.
   ============================================================ */
SET search_path TO roas, public;

CREATE OR REPLACE VIEW stg_campaigns AS
SELECT
    cam.campaign_id,
    cam.channel_id,
    ch.channel_name,
    cam.campaign_name,
    cam.start_date,
    cam.end_date,
    cam.objective,
    (cam.end_date - cam.start_date) AS campaign_duration_days
FROM campaigns cam
JOIN channels ch ON ch.channel_id = cam.channel_id;
