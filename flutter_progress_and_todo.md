# Flutter App: Progress & Remaining Work

Folder: `mobile_flutter/` · Branch: `fix/flutter-audit-phase1`

Only things that still need action are listed. Items with no problem are left out on purpose.

---

## 1. Done so far (Phase 1, finished by Codex)

- [x] Profile avatar route fixed (`/profile`)
- [x] API base URL now configurable (`API_BASE_URL`)
- [x] Central 401 handling, AuthGuard goes to Login
- [x] Fake success removed: Trip Request, My Itinerary, Notifications, Trip History, Profile save
- [x] Profile name/phone validation, safe budget slider
- [x] `flutter analyze`: no issues · `flutter test`: 44 passed

---

## 2. Things YOU must do now

- [ ] `git add -A` then `git commit -m "Flutter phase 1"`
- [ ] Run the quick app checks in section 4A
- [ ] Give Codex **Prompt 2** (Booking, Payment, QR)
- [ ] Get a Stripe **test publishable key** (starts with `pk_test_`). Never use the secret key in the app.

---

## 3. Still to build

### 3A. Phase 2 (Prompt 2): completed

| # | Work | Screen / file | Status |
|---|---|---|---|
| 1 | Pass a real `bookingId` to Checkout, Status and Confirmation (not itinerary or vehicle maps) | my_itinerary, transport_options, checkout | [x] Completed |
| 2 | Keep selected hotel + transport in one shared holder | accommodation, transport, map, TripSelectionService | [x] Completed |
| 3 | Booking Status: real timeline Draft → AwaitingApproval → Confirmed, QR only when Confirmed/Completed | booking_status_screen | [x] Completed |
| 4 | Remove sample "Confirmed" booking fallback | booking_status_screen | [x] Completed |
| 5 | Real Stripe sandbox payment (card form actually used, `tok_visa` vs `tok_chargeDeclined`), block until Confirmed, stay on Checkout when payment fails | checkout_payment_screen | [x] Completed |
| 6 | Remove fake wallet selector / save-card toggle | checkout_payment_screen | [x] Completed |
| 7 | Trip Confirmation: real recap data + real PDF ticket download (pure-Dart PDF 1.4) | trip_confirmation_screen, TicketPdfService | [x] Completed |
| 8 | Remove false claims: forgot-password email, fake cancel/refund, fake Share Trip | login, booking_status, trip_confirmation | [x] Completed |
| 9 | Tests: Booking Status, Checkout failure, Confirmation, Login, Register (54 tests passing) | test/phase_two_workflow_test.dart | [x] Completed |

### 3B. After Phase 2: important

- [ ] Tour Search: destination, date and budget filters; "Top Rated" sort actually sorts
- [ ] Tour Details: included activities, price breakdown, photo gallery
- [ ] Accommodation: real rating and distance from the API (not fixed 4.8)
- [ ] Transport: show the real API options with real departure/arrival times
- [ ] Trip Map: pins from the real selected hotel, tour and transport (not guessed by name)
- [ ] Loaders in Accommodation / Transport / Profile: real error and empty states
- [ ] Decide about external requests (Unsplash images, OpenStreetMap/ArcGIS tiles). Spec says only the ASP.NET API, so either proxy through the API, bundle assets, or note it in your ADR.

### 3C. Nice to have / release

- [ ] Android: set a real application ID (not `com.example...`) and release signing
- [ ] Android: HTTP cleartext is on, fine for dev, switch to HTTPS for deployment
- [ ] App name consistent (`Travel Planner` vs `Serendib Trails`)
- [ ] Remove unused `cupertino_icons`
- [ ] Keep tab state when switching bottom tabs
- [ ] Build the APK (Week 8 deliverable)

### 3D. Backend gaps (not fixable in Flutter, tell the backend owners)

- [ ] No customer endpoint to approve an itinerary (status endpoint rejects it)
- [ ] Customer "request changes" is not saved by the backend
- [ ] Booking creation endpoint: confirm it exists and what it expects (Prompt 2 will report this)

---

## 4. What to test in the app (only what is not tested yet)

### 4A. Phase 1 checks (do now, 5 minutes)

- [ ] Tap the avatar on Home → Profile & Preferences opens
- [ ] Turn the backend OFF → submit a Trip Request → you see an error and stay on the form
- [ ] Notifications and Trip History show an empty state (no fake sample data) when there is no real data
- [ ] Profile: empty name or bad phone number → validation error; save with backend off → error, not "saved"

### 4B. After Phase 2

- [ ] Booking with status AwaitingApproval → no QR, no Pay button
- [ ] Booking approved in React (Confirmed) → QR appears and Pay now is enabled
- [ ] Pay with Stripe test card `4242 4242 4242 4242` (any future date, any CVC) → goes to Confirmation
- [ ] Pay with a declined test card `4000 0000 0000 0002` → stays on Checkout with an error
- [ ] Trip Confirmation shows the real booking data, PDF ticket downloads and opens
- [ ] Wrong/expired token → app returns to Login

### 4C. Full cross-platform run (Week 8)

- [ ] Flutter: submit Trip Request → agents run → booking AwaitingApproval
- [ ] React: staff approves the booking
- [ ] Flutter: status turns Confirmed → pay → QR ticket visible

---

## 5. Run commands

```bash
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:5000 --dart-define=STRIPE_PUBLISHABLE_KEY=pk_test_xxx
```

`10.0.2.2` is for the Android emulator. On a real phone use your PC's LAN IP. Use the real backend port.
