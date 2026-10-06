-- Apply in your DEPLOYED PostgreSQL SQL editor.
-- Checked against the live 61-tour catalog on 6 October 2026.
-- Matches exact tour names plus destination names; generated IDs are not assumed.
-- Existing nonzero GPS pairs are preserved. Only missing/zero coordinates change.
-- Coordinates locate the named attraction or a road-accessible meeting point;
-- routing snaps these points to the nearest drivable road.
BEGIN;

CREATE TEMP TABLE matched_tour_locations (
    tour_name text,
    destination_names text[],
    latitude double precision,
    longitude double precision,
    location_source text
) ON COMMIT DROP;

INSERT INTO matched_tour_locations VALUES
('Bahirawakanda Vihara Buddha Statue', ARRAY['KANDY'], 7.29553, 80.63094,
 'https://mapcarta.com/W573809459'),
('Ceylon Tea Museum Tour', ARRAY['KANDY'], 7.26864, 80.63266,
 'https://mapcarta.com/N3276843504'),
('Kandy Lake Sunset Walk', ARRAY['KANDY'], 7.29115, 80.63772,
 'https://mapcarta.com/N4035870281 (Lake Round roadside starting point)'),
('Royal Botanical Garden Peradeniya', ARRAY['KANDY'], 7.2707, 80.5955,
 'https://www.reiseceylon.com/destinations/royal-botanical-gardens-peradeniya'),
('Temple of the Tooth Tour', ARRAY['KANDY'], 7.2936, 80.6413,
 'Existing GPS coordinates in the deployed tour catalog'),
('Galle Fort History Walk', ARRAY['GALLE'], 6.03047, 80.21692,
 'https://mapcarta.com/N12600751302 (fort information/meeting point)'),
('Sunrise Rock Fortress Walk', ARRAY['SIGIRYA', 'SIGIRIYA'], 7.9571, 80.7573,
 'https://mapcarta.com/Sigiriya (Sigiriya ruins point)');

-- Preview the matches and intended changes.
SELECT t."Id", t."Name", d."Name" AS "Destination",
       t."Latitude" AS "CurrentLatitude", t."Longitude" AS "CurrentLongitude",
       m.latitude AS "MatchedLatitude", m.longitude AS "MatchedLongitude",
       m.location_source AS "Source"
FROM "Tours" t
JOIN "Destinations" d ON d."Id" = t."DestinationId"
JOIN matched_tour_locations m ON t."Name" = m.tour_name
    AND UPPER(BTRIM(d."Name")) = ANY(m.destination_names)
ORDER BY t."Id";

UPDATE "Tours" t
SET "Latitude" = m.latitude,
    "Longitude" = m.longitude,
    "UpdatedAt" = NOW()
FROM matched_tour_locations m, "Destinations" d
WHERE t."Name" = m.tour_name
  AND d."Id" = t."DestinationId"
  AND UPPER(BTRIM(d."Name")) = ANY(m.destination_names)
  AND (t."Latitude" IS NULL OR t."Longitude" IS NULL
       OR (t."Latitude" = 0 AND t."Longitude" = 0))
RETURNING t."Id", t."Name", t."Latitude", t."Longitude";

-- Tours that still need a specific attraction/venue or pickup point.
-- The cultural show could be at several venues: pick its actual venue in admin.
-- Mirissa Coastal Day Trip and Yala Wildlife Safari need actual pickup/entrance GPS.
-- Kandy Cultural Heritage Tour is currently assigned to Ella: verify destination.
SELECT t."Id", t."Name", d."Name" AS "Destination",
       t."Latitude", t."Longitude"
FROM "Tours" t
JOIN "Destinations" d ON d."Id" = t."DestinationId"
WHERE t."Latitude" IS NULL OR t."Longitude" IS NULL
   OR (t."Latitude" = 0 AND t."Longitude" = 0)
ORDER BY d."Name", t."Name";

COMMIT;

-- The 50 original fictional tours were subsequently replaced with real
-- attractions by replace_demo_tours_with_real_attractions.sql.
