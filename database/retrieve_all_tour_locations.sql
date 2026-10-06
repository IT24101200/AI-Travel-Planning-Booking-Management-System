-- Run in your PostgreSQL SQL editor to retrieve all tours, including inactive ones.
SELECT t."Id", t."Name", t."Status", t."DestinationId",
       d."Name" AS "Destination", t."Latitude", t."Longitude",
       CASE
           WHEN t."Latitude" IS NULL OR t."Longitude" IS NULL
                OR (t."Latitude" = 0 AND t."Longitude" = 0)
               THEN 'Missing GPS'
           WHEN t."Name" LIKE 'Demo %'
               THEN 'City-centre placeholder; choose actual venue'
           ELSE 'GPS present'
       END AS "LocationStatus"
FROM "Tours" t
LEFT JOIN "Destinations" d ON d."Id" = t."DestinationId"
ORDER BY d."Name", t."Name";
