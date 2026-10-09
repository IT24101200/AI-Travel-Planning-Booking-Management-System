# Paid trip confirmations

After a successful Stripe payment, the customer receives one in-app Payment Successful notification containing a snapshot of the paid booking. Checkout shows the same details immediately. The saved notification contains every booked hotel stay and transport leg, available business phone/email contacts, and the daily activities, hotel check-in/check-out dates and planned road routes.

The snapshot is saved in the same database transaction as the paid payment. Retrying a paid booking does not charge again or create another confirmation. Declined and ambiguous payments do not receive a paid trip confirmation. Detailed agent inputs, instructions and diagnostic logs are excluded.

Hotel contacts come from the hotel's existing contact fields. Transport contacts can now be entered in the staff Transport Fleet create/edit form. Missing contacts are displayed as not provided, with instructions to contact the travel desk. A saved transport operator's identity is retained; another operator's contact is never attached to it.

## Deploy

Apply the migration to the configured database before deploying the updated backend:

```powershell
dotnet ef database update --project backend/backend.csproj
```

Alternatively, run `database/add_paid_trip_confirmation_details.sql` against a database already migrated through `20261008205014_AddAirportPickupPlanning`. The script records the migration and can be rerun after successful completion.

Deploy the backend, rebuild the Flutter app, and deploy the React staff frontend. Populate real transport phone/email details in Transport Fleet. New successful payments create detailed confirmations; existing notifications retain their original content. Delivery uses the application's existing in-app Alerts channel.

## Verification

- Backend payment tests cover full plans longer than the notification summary limit, preserved contacts after catalogue edits, complete activities, failed payments, duplicate payments, legacy route data and contact create/update.
- Flutter tests cover the paid checkout confirmation, opening and scrolling a complete notification, multiple hotels/transport legs, missing contacts and narrow layouts in both themes.
- Transport frontend tests cover contact preservation in schedule payloads.
