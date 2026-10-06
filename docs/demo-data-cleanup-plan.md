# Demo-data cleanup plan (not executed)

This document is a review procedure only. It contains read-only verification
queries and a deletion order for the historical `DbInitializer` demo records.
No query in this document has been executed by the application or this task.

## Read-only verification

Run these queries against a read-only PostgreSQL session after taking a backup.

```sql
SELECT "Id", "BookingReference", "CustomerId", "ItineraryId", "Status", "TotalCost", "Currency"
FROM "Bookings"
WHERE "BookingReference" IN ('ST-BK-1001', 'ST-BK-1002', 'ST-BK-1003', 'ST-BK-1004', 'ST-BK-1005');

SELECT p."Id", p."BookingId", p."StripeReference", p."Amount", p."Currency", p."Status", p."PaymentDate",
       b."BookingReference"
FROM "Payments" p
JOIN "Bookings" b ON b."Id" = p."BookingId"
WHERE p."StripeReference" IN ('ch_live_demo_1003', 'ch_live_demo_1005')
   OR b."BookingReference" IN ('ST-BK-1001', 'ST-BK-1002', 'ST-BK-1003', 'ST-BK-1004', 'ST-BK-1005');

SELECT ba."Id", ba."BookingId", ba."TravelAgentId", ba."Decision", ba."DecidedAt",
       b."BookingReference"
FROM "BookingApprovals" ba
JOIN "Bookings" b ON b."Id" = ba."BookingId"
WHERE b."BookingReference" IN ('ST-BK-1001', 'ST-BK-1002', 'ST-BK-1003', 'ST-BK-1004', 'ST-BK-1005');

SELECT bi."Id", bi."BookingId", b."BookingReference"
FROM "BookingItems" bi
JOIN "Bookings" b ON b."Id" = bi."BookingId"
WHERE b."BookingReference" IN ('ST-BK-1001', 'ST-BK-1002', 'ST-BK-1003', 'ST-BK-1004', 'ST-BK-1005');

SELECT i."Id" AS "ItineraryId", i."CustomerId", i."TripRequestId", i."TotalEstimatedCost", i."Currency",
       tr."Id" AS "TripRequestId"
FROM "Itineraries" i
LEFT JOIN "TripRequests" tr ON tr."Id" = i."TripRequestId"
WHERE i."Id" = 36
   OR EXISTS (
       SELECT 1 FROM "Bookings" b
       WHERE b."ItineraryId" = i."Id"
         AND b."BookingReference" IN ('ST-BK-1001', 'ST-BK-1002', 'ST-BK-1003', 'ST-BK-1004', 'ST-BK-1005')
   );

SELECT al."Id", al."TripRequestId", al."AgentName", al."StepName", al."Status", al."Timestamp"
FROM "AgentLogs" al
WHERE al."AgentName" IN ('CoordinatorAgent', 'ItineraryAgent', 'BookingAgent', 'ValidationAgent');

SELECT "Id", "Email", "UserName"
FROM "AspNetUsers"
WHERE lower("Email") IN (
  'kavinda.silva@gmail.com',
  'priya.raghavan@gmail.com',
  'tom.whitfield@outlook.com'
);

SELECT "Id", "FullName", "Role"
FROM "Customers"
WHERE "FullName" IN ('Kavinda Silva', 'Priya Raghavan', 'Tom Whitfield');
```

## Candidate review rule

Only treat a row as a cleanup candidate when its booking reference or payment
reference matches the historical initializer and its complete relationship
graph is confirmed. Customer names alone are not sufficient evidence for
customer-account deletion.

## FK-safe deletion order (review only)

After explicit approval and a backup, delete only confirmed demo rows in this
child-first order:

1. `BookingApprovals` for confirmed demo `BookingId` values.
2. `Payments` for confirmed demo `BookingId` values.
3. `BookingItems` for confirmed demo `BookingId` values.
4. `Bookings` for confirmed demo booking references.
5. `ItineraryItems` for an itinerary only when no legitimate booking uses it.
6. `Itineraries` only when its customer/trip-request relationship is confirmed
   as demo-only.
7. `AgentLogs` for a demo-only `TripRequestId`.
8. `TripRequests` only when no legitimate itinerary or other workflow uses it.

Do not delete `Customers` or `AspNetUsers` in this procedure unless the exact
seeded identity, email, and absence of legitimate dependent records are proven
separately. This cleanup plan was not executed.
