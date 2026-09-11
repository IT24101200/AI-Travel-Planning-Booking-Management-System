BACKEND STATUS: ❌ NOT COMPLETE — 21 items remaining

1. Role seeding for Customer, TravelAgent, and Admin roles is missing in Identity configuration, migrations, and seeder.
2. CORS policy in Program.cs uses AllowAnyOrigin() instead of scoping to specific React and Flutter client origins.
3. Database connection string with plaintext password ("7552632") is committed in appsettings.json and hardcoded in Program.cs.
4. Global exception handling middleware or filter is missing, allowing unhandled exceptions to leak stack traces.
5. EF Core migrations and snapshot are missing 10 of 17 database tables (only Component A, Destination, and Tour are migrated).
6. AgentLog entity schema deviates from requirements (missing StepType, ToolName, DurationMs; fields renamed).
7. BookingItem lacks validation ensuring exactly one of TourId, RoomId, or TransportOptionId is set matching ItemType.
8. Five domain models (ItineraryItem, Hotel, Room, TransportOption, BookingItem) are completely unconfigured in OnModelCreating.
9. BookingController is missing booking creation, cancellation, and status transition endpoints.
10. Booking status transition guard is missing; ApprovalController transitions to Confirmed without checking if status was AwaitingApproval.
11. Stripe payment integration is missing (no Stripe package, no charge endpoint, no API keys, and PaymentService is empty).
12. PaymentController is missing the GET /api/payment/booking/{bookingId} endpoint.
13. ApprovalController, ItineraryController, HotelController, and TransportController completely lack [Authorize] attributes.
14. BookingController and CustomerController (GetById) have IDOR vulnerabilities with no ownership or role checks.
15. Itinerary assembly logic with time-slot conflict checking on the same day is missing (ItineraryService is empty).
16. Staff registration endpoint requiring a secret verification code is missing from AuthController.
17. Hotel and Transport controllers execute hard database deletes rather than soft-deleting or deactivating records.
18. HotelController lacks nested room listing and management endpoints.
19. TransportController is missing a GET by ID endpoint.
20. Destination, Hotel, TransportOption, Itinerary, Notification, and Tour list endpoints lack required pagination, filter, or sort parameters.
21. Request DTOs for Hotel, Transport, Approval, Itinerary, and Tour lack model validation annotations and ModelState verification.

---

## Audit History

- **2026-09-09**: Initial comprehensive static code audit across all 10 evaluation categories. Result: ❌ NOT COMPLETE (21 blocking items identified across configuration, database schema, controllers, security, business logic, and migrations).

---

## Detailed Findings

### 1. Project Setup & Configuration

- **JWT Authentication Registered & Configured**: **PASS**
  - *Evidence*: `backend/Program.cs` lines 43–63. `AddAuthentication(JwtBearerDefaults.AuthenticationScheme)` and `AddJwtBearer` validate issuer, audience, lifetime, and signing key read from configuration via `builder.Configuration.GetSection("Jwt")`.
- **ASP.NET Core Identity & Role Seeding**: **PARTIAL**
  - *Evidence*: `backend/Program.cs` lines 30–40 registers `AddIdentity<IdentityUser, IdentityRole>()` with Entity Framework stores. However, role seeding for `Customer`, `TravelAgent`, and `Admin` was **NOT FOUND** in `Program.cs`, `AppDbContext.cs`, or any migration/seeder file.
- **CORS Policy Scoping**: **FAIL**
  - *Evidence*: `backend/Program.cs` lines 115–123. The CORS policy `"AllowAll"` uses `policy.AllowAnyOrigin().AllowAnyMethod().AllowAnyHeader();` which is an unscoped wildcard policy rather than restricting to React (`http://localhost:5173`) and Flutter client origins.
- **Swagger / OpenAPI Bearer Token Support**: **PASS**
  - *Evidence*: `backend/Program.cs` lines 78–112. Configured with `AddSecurityDefinition("Bearer", new OpenApiSecurityScheme { Type = SecuritySchemeType.Http, Scheme = "bearer", BearerFormat = "JWT" })` and `AddSecurityRequirement`.
- **PostgreSQL Connection String Hygiene**: **FAIL**
  - *Evidence*: `backend/appsettings.json` line 10 contains committed plaintext credentials `"Default": "Host=localhost;Port=5432;Database=travel_booking_db;Username=postgres;Password=7552632"`. Additionally, `backend/Program.cs` line 21 contains hardcoded fallback credentials with the same plaintext password.
- **Global Exception Handling Middleware**: **FAIL**
  - *Evidence*: `backend/Program.cs` lines 133–147. No `app.UseExceptionHandler()` or custom error-handling middleware/filter is registered in the middleware pipeline; only `if (app.Environment.IsDevelopment())` swagger blocks exist.

---

### 2. Database Schema — All 17 Tables

- **Customer**: **PASS**
  - *Evidence*: `backend/Models/Customer.cs` lines 14–26. Fields: `Id` (PK/FK to AspNetUsers string), `FullName` (string, required, max 150), `Phone` (string?, max 20), `JoinedAt` (DateTime), `LastActiveAt` (DateTime).
- **TravelAgent**: **PASS**
  - *Evidence*: `backend/Models/TravelAgent.cs` lines 11–21. Fields: `Id` (PK/FK to AspNetUsers string), `FullName` (string, required, max 150), `Department` (string, max 100), `HireDate` (DateTime).
- **Preference**: **PASS**
  - *Evidence*: `backend/Models/Preference.cs` lines 13–42 and `backend/data/AppDbContext.cs` lines 57–70. Fields: `Id` (Guid PK), `CustomerId` (string FK, unique index on line 59 of AppDbContext), `BudgetMin` (decimal), `BudgetMax` (decimal), `Currency` (string), `PreferredActivities` (string?), `DietaryNotes` (string?), `AccessibilityNotes` (string?), `UpdatedAt` (DateTime).
- **Notification**: **PASS**
  - *Evidence*: `backend/Models/Notification.cs` lines 14–34. Fields: `Id` (Guid PK), `CustomerId` (string FK), `Channel` (NotificationChannel enum), `MessageType` (MessageType enum), `Content` (string, max 2000), `Status` (NotificationStatus enum), `ReadAt` (DateTime?, nullable), `SentAt` (DateTime).
- **TripRequest**: **PASS**
  - *Evidence*: `backend/Models/TripRequest.cs` lines 14–60. Fields: `Id` (int PK), `CustomerId` (string FK), `DestinationId` (int? FK, nullable), `RawRequestText` (string, max 2000), `StartDate` (DateTime), `EndDate` (DateTime), `TravellerCount` (int), `BudgetCeiling` (decimal), `Currency` (string), `Status` (TripRequestStatus enum), `RetryCount` (int, default 0), `PlanJson` (string?, jsonb, nullable), `FailureReason` (string?, max 1000), `CreatedAt` (DateTime).
- **Destination**: **PASS**
  - *Evidence*: `backend/Models/Destination.cs` lines 8–25. Fields: `Id` (int PK), `Name` (string, max 100), `Country` (string, max 100), `Description` (string?, max 1000), `ImageUrl` (string?), `Latitude` (double), `Longitude` (double).
- **Tour**: **PASS**
  - *Evidence*: `backend/Models/Tour.cs` lines 9–47. Fields: `Id` (int PK), `DestinationId` (int FK), `Name` (string, max 150), `Category` (string, max 50), `Description` (string?, max 1000), `Price` (decimal), `Currency` (string, max 10), `DurationHours` (double), `DefaultStartTime` (TimeSpan), `Latitude` (double?, nullable), `Longitude` (double?, nullable), `Status` (string, max 20), `CreatedAt` (DateTime), `UpdatedAt` (DateTime).
- **Itinerary**: **PASS**
  - *Evidence*: `backend/Models/Itinerary.cs` lines 12–37. Fields: `Id` (int PK), `CustomerId` (string FK), `TripRequestId` (int FK), `StartDate` (DateTime), `EndDate` (DateTime), `Status` (string, max 30), `TotalEstimatedCost` (decimal), `Currency` (string, max 10), `CreatedAt` (DateTime).
- **ItineraryItem**: **PASS**
  - *Evidence*: `backend/Models/ItineraryItem.cs` lines 12–32. Fields: `Id` (int PK), `ItineraryId` (int FK), `TourId` (int FK), `DayNumber` (int), `SequenceOrder` (int), `StartTime` (TimeSpan), `EndTime` (TimeSpan), `PriceAtSelection` (decimal).
- **Hotel**: **PASS**
  - *Evidence*: `backend/Models/Hotel.cs` lines 12–36. Fields: `Id` (int PK), `DestinationId` (int FK), `Name` (string, max 150), `Address` (string, max 250), `Latitude` (double?, nullable), `Longitude` (double?, nullable), `StarRating` (int), `Status` (string, max 20). Verified: NO price field exists on Hotel; pricing lives exclusively on Room.
- **Room**: **PASS**
  - *Evidence*: `backend/Models/Room.cs` lines 12–32. Fields: `Id` (int PK), `HotelId` (int FK), `RoomType` (string, max 80), `Capacity` (int), `TotalRooms` (int), `PricePerNight` (decimal), `Currency` (string, max 10).
- **TransportOption**: **PASS**
  - *Evidence*: `backend/Models/TransportOption.cs` lines 12–46. Fields: `Id` (int PK), `Type` (string, max 30), `Provider` (string, max 120), `RouteFrom` (string, max 100), `RouteTo` (string, max 100), `DepartureTime` (TimeSpan), `ArrivalTime` (TimeSpan), `Capacity` (int), `Price` (decimal), `Currency` (string, max 10), `Status` (string, max 20).
- **Booking**: **PASS**
  - *Evidence*: `backend/Models/Booking.cs` lines 12–39 and `backend/data/AppDbContext.cs` line 150. Fields: `Id` (int PK), `BookingReference` (string, unique index via `AppDbContext.cs:150`), `CustomerId` (string FK), `ItineraryId` (int FK), `Status` (string, max 30), `TotalCost` (decimal), `Currency` (string, max 10), `CreatedAt` (DateTime), `UpdatedAt` (DateTime).
- **BookingItem**: **PARTIAL**
  - *Evidence*: `backend/Models/BookingItem.cs` lines 12–44. Fields: `Id` (int PK), `BookingId` (int FK), `ItemType` (string), `TourId` (int?, nullable FK), `RoomId` (int?, nullable FK), `TransportOptionId` (int?, nullable FK), `CheckInDate` (DateTime?, nullable), `CheckOutDate` (DateTime?, nullable), `Quantity` (int), `UnitPrice` (decimal), `Subtotal` (decimal).
  - *Discrepancy*: Validation/check ensuring exactly one of `TourId`/`RoomId`/`TransportOptionId` is set matching `ItemType` is **NOT FOUND** in model, Fluent API, or controller.
- **BookingApproval**: **PASS**
  - *Evidence*: `backend/Models/BookingApproval.cs` lines 12–29. Fields: `Id` (int PK), `BookingId` (int FK), `TravelAgentId` (string FK), `Decision` (string, max 30), `Comment` (string?, max 1000), `DecidedAt` (DateTime).
- **Payment**: **PASS**
  - *Evidence*: `backend/Models/Payment.cs` lines 12–33. Fields: `Id` (int PK), `BookingId` (int FK), `Amount` (decimal), `Currency` (string, max 10), `Status` (string, max 30), `StripeReference` (string?, max 120), `PaymentDate` (DateTime).
- **AgentLog**: **FAIL**
  - *Evidence*: `backend/Models/AgentLog.cs` lines 12–37.
  - *Discrepancy*: Required fields `StepType`, `ToolName`, and `DurationMs` are **NOT FOUND**. The field `StepDescription` is named `StepName`, `InputJson` is named `Input`, `OutputJson` is named `Output`, and `CreatedAt` is named `Timestamp`.
- **Database Constraints & OnModelCreating Configurations**: **FAIL**
  - *Evidence*: `backend/data/AppDbContext.cs` lines 42–203. Uniqueness on `BookingReference` is configured (`line 150`). However, entity mappings for `ItineraryItem`, `Hotel`, `Room`, `TransportOption`, and `BookingItem` are completely missing from `OnModelCreating`, leaving cascade and restrict foreign key rules unconfigured in EF Core metadata.

---

### 3. Controllers — Endpoints & Actions

- **CustomerController**: **PARTIAL**
  - `GET /api/Customer/me` [Authorize] — returns current customer profile (`CustomerController.cs:27`).
  - `PUT /api/Customer/me` [Authorize] — updates current customer profile (`CustomerController.cs:46`).
  - `GET /api/Customer/{id}` [Authorize] — returns customer profile by ID (`CustomerController.cs:66`). Flag: Lacks role check.
  - `GET /api/Customer` [Authorize] — returns paginated, sorted, filtered customer directory (`CustomerController.cs:81`).
  - *Missing*: Delete action not implemented.
- **NotificationController**: **PASS**
  - `GET /api/Notification` [Authorize] — lists notifications with status and date filtering + pagination (`NotificationController.cs:26`).
  - `PATCH /api/Notification/{id}/read` [Authorize] — marks as read (`NotificationController.cs:57`).
  - `PATCH /api/Notification/{id}/unread` [Authorize] — marks as unread (`NotificationController.cs:74`).
  - `POST /api/Notification/mark-all-read` [Authorize] — marks all read (`NotificationController.cs:90`).
  - `POST /api/Notification/{id}/resend` [Authorize] — resends failed notification (`NotificationController.cs:105`).
- **TripRequestController**: **PASS**
  - `POST /api/TripRequest` [Authorize] — creates request (`TripRequestController.cs:29`).
  - `GET /api/TripRequest` [Authorize] — lists caller's requests with pagination (`TripRequestController.cs:56`).
  - `GET /api/TripRequest/{id}` [Authorize] — gets request by ID with ownership check (`TripRequestController.cs:84`).
  - `GET /api/TripRequest/{id}/status` [Authorize] — status check (`TripRequestController.cs:101`).
  - `PATCH /api/TripRequest/{id}/cancel` [Authorize] — cancellation (`TripRequestController.cs:126`).
  - `GET /api/TripRequest/{id}/logs` [Authorize] — gets agent execution logs (`TripRequestController.cs:151`).
- **TourController**: **PASS**
  - `GET /api/Tour` [Authorize] — search with category, destination, price range, and pagination (`TourController.cs:22`).
  - `GET /api/Tour/{id}` [Authorize] — gets tour by ID (`TourController.cs:39`).
  - `POST /api/Tour` [Authorize(Roles = "TravelAgent,Admin")] — creates tour (`TourController.cs:49`).
  - `PUT /api/Tour/{id}` [Authorize(Roles = "TravelAgent,Admin")] — updates tour (`TourController.cs:58`).
  - `DELETE /api/Tour/{id}` [Authorize(Roles = "TravelAgent,Admin")] — soft-deletes tour (`TourController.cs:68`).
- **ItineraryController**: **FAIL**
  - `GET /api/Itinerary/review` — gets proposed itineraries for staff review (`ItineraryController.cs:26`).
  - `PATCH /api/Itinerary/{id}/status` — updates itinerary status (`ItineraryController.cs:67`).
  - *Missing*: No `[Authorize]` attribute on controller or any action (`ItineraryController.cs:14`). No `GET /api/Itinerary/{id}` endpoint. No ownership filtering. No conflict checking assembly endpoint.
- **HotelController**: **FAIL**
  - `GET /api/Hotel` — lists hotels with destination and name filter (`HotelController.cs:27`).
  - `GET /api/Hotel/{id}` — gets hotel with rooms (`HotelController.cs:63`).
  - `POST /api/Hotel` — creates hotel with default room tier (`HotelController.cs:80`).
  - `PUT /api/Hotel/{id}` — updates hotel and default room tier (`HotelController.cs:115`).
  - `DELETE /api/Hotel/{id}` — hard delete (`HotelController.cs:141`).
  - *Missing*: No `[Authorize]` attribute on controller or actions. No dedicated room listing/management endpoints (e.g. `GET /api/Hotel/{id}/rooms`, `POST /api/Hotel/{id}/rooms`). Uses hard delete instead of status soft delete.
- **TransportController**: **FAIL**
  - `GET /api/Transport` — lists transport options (`TransportController.cs:27`).
  - `POST /api/Transport` — creates transport option (`TransportController.cs:65`).
  - `PUT /api/Transport/{id}` — updates transport option (`TransportController.cs:91`).
  - `DELETE /api/Transport/{id}` — hard delete (`TransportController.cs:115`).
  - *Missing*: No `[Authorize]` attribute on controller or actions. Missing `GET /api/Transport/{id}` endpoint. Uses hard delete.
- **BookingController**: **FAIL**
  - `GET /api/Booking` — lists bookings (`BookingController.cs:27`).
  - `GET /api/Booking/{id}` — gets booking by ID (`BookingController.cs:67`).
  - *Missing*: No `[Authorize]` attribute. Missing create booking endpoint (`POST /api/Booking`). Missing status transition / cancellation endpoints. Missing customer ownership check on `GetById`. Returns raw entity with all navigation properties.
- **ApprovalController**: **PARTIAL**
  - `GET /api/Approval/pending` — lists pending approvals (`ApprovalController.cs:29`).
  - `POST /api/Approval/{bookingId}/decide` — records decision (`ApprovalController.cs:76`).
  - *Missing*: No `[Authorize]` attribute on controller or actions. Falls back to `"agent-system"` if unauthenticated (`ApprovalController.cs:82`).
- **PaymentController**: **PARTIAL**
  - `GET /api/Payment` [Authorize] — lists payments with customer IDOR filtering (`PaymentController.cs:32`).
  - `GET /api/Payment/{id}` [Authorize] — gets payment by ID with customer ownership check (`PaymentController.cs:76`).
  - `GET /api/Payment/revenue-summary` [Authorize] — staff-only revenue summary (`PaymentController.cs:111`).
  - *Missing*: Missing `GET /api/Payment/booking/{bookingId}` endpoint. Missing payment creation / Stripe charge trigger endpoint (`POST /api/Payment`).

---

### 4. Ownership / IDOR Checks (Security)

- **TripRequest**: **PASS**
  - *Evidence*: `backend/Services/TripRequestService.cs` line 107 in `GetStatusAsync`:
    `FirstOrDefaultAsync(t => t.Id == tripRequestId && t.CustomerId == customerId)`
  - Direct comparison to claims user ID confirms ownership.
- **Itinerary**: **FAIL**
  - *Evidence*: `backend/Controllers/ItineraryController.cs` lines 26–61.
  - Verdict: **NO OWNERSHIP CHECK FOUND**. Endpoint has no authentication and does not filter by `CustomerId`.
- **Booking**: **FAIL**
  - *Evidence*: `backend/Controllers/BookingController.cs` lines 67–81.
  - Verdict: **NO OWNERSHIP CHECK FOUND**. `GetById(int id)` fetches record by primary key with no comparison to `User.FindFirstValue(ClaimTypes.NameIdentifier)`.
- **Payment (`GET /api/payment/{id}`)**: **PASS**
  - *Evidence*: `backend/Controllers/PaymentController.cs` line 90:
    `if (!isStaff && payment.Booking.CustomerId != userId) return Forbid();`
  - Exact check compares parent `Booking.CustomerId` against authenticated `userId`.
- **Payment (`GET /api/payment/booking/{bookingId}`)**: **FAIL**
  - *Evidence*: `backend/Controllers/PaymentController.cs` lines 1–148.
  - Verdict: **NOT FOUND** (Endpoint does not exist).
- **Notification**: **PASS**
  - *Evidence*: `backend/Services/NotificationService.cs` line 22:
    `query = _db.Notifications.Where(n => n.CustomerId == customerId)`
  - Exact check scopes queries to logged-in user.
- **Preference**: **PASS**
  - *Evidence*: `backend/Services/PreferenceService.cs` line 20:
    `FirstOrDefaultAsync(p => p.CustomerId == customerId)`
  - Exact check compares `p.CustomerId` to claims ID.
- **Customer Profile (`GET /api/customer/{id}`)**: **FAIL**
  - *Evidence*: `backend/Controllers/CustomerController.cs` lines 63–74:
    `var customer = await _customerService.GetByIdAsync(id);`
  - Verdict: **NO OWNERSHIP CHECK FOUND**. Any authenticated user can retrieve any other customer's full record by providing their ID; no role verification (`Admin`/`TravelAgent`) is performed.

---

### 5. Business Logic per Component

#### Component A (Profile / Preferences / Notifications / TripRequest)
- **Preference Validation**: **PASS**
  - *Evidence*: `backend/Services/PreferenceService.cs` lines 28–31:
    `if (dto.BudgetMax < dto.BudgetMin) throw new ArgumentException("BudgetMax must be greater than or equal to BudgetMin.");`
- **TripRequest Date & Parameter Validation**: **PASS**
  - *Evidence*: `backend/Services/TripRequestService.cs` lines 21–29 enforces `dto.StartDate.Date >= DateTime.UtcNow.Date` and `dto.EndDate > dto.StartDate`.
- **TripRequest Initialization**: **PASS**
  - *Evidence*: `backend/Services/TripRequestService.cs` lines 61–62 initializes `Status = TripRequestStatus.Pending` and `RetryCount = 0`.
- **Notification Status Tracking**: **PARTIAL**
  - *Evidence*: `backend/Services/NotificationService.cs` lines 81, 95, 110, 131 updates status on Read, Unread, and Resend. However, actual background delivery logging or dispatcher logic is **NOT FOUND**.

#### Component B (Tours / Itineraries)
- **Itinerary Item Overlap Conflict Prevention**: **FAIL**
  - *Evidence*: `backend/Controllers/ItineraryController.cs` and `backend/Services/ItineraryService.cs`.
  - Verdict: **NOT FOUND**. `ItineraryService.cs` is an empty 0-byte file. No code exists to prevent overlapping `StartTime`/`EndTime` on the same `DayNumber` for an itinerary.
- **Tour Search Filtering**: **PASS**
  - *Evidence*: `backend/Services/TourService.cs` lines 29–44 uses real EF Core `.Where()` clauses for `DestinationId`, `Category`, `Price >= minPrice`, `Price <= maxPrice`, and `Status == statusFilter`.

#### Component C (Accommodation / Transport)
- **AvailabilityService Overlap Logic**: **PASS (REAL)**
  - *Evidence*: `backend/Services/AvailabilityService.cs` lines 26–41 (`GetAvailableRoomCount`) queries `BookingItems` with overlap condition `bi.CheckInDate < checkOut && bi.CheckOutDate > checkIn` where status is not `Cancelled` or `Rejected`, subtracting from `room.TotalRooms`.
  - Lines 46–61 (`GetAvailableTransportSeats`) performs seat counting against `transport.Capacity`.
  - Verdict: **REAL** (not a stub).
- **Concurrency & Transaction Safety**: **PASS**
  - *Evidence*: `backend/Services/AvailabilityService.cs` lines 71–72 and lines 114–115 wraps reservations in `await _db.Database.BeginTransactionAsync(System.Data.IsolationLevel.Serializable)` to prevent double-booking the last inventory unit.

#### Component D (Booking / Approval / Payments)
- **Booking Status Transition Guard (`AwaitingApproval` -> `Confirmed`)**: **FAIL**
  - *Evidence*: `backend/Controllers/ApprovalController.cs` lines 110–124. When `dto.Decision == "Approved"`, `booking.Status` is unconditionally updated to `"Confirmed"` without checking that the booking is currently in `"AwaitingApproval"`.
- **Payment Creation Guard (`Booking.Status == Confirmed`)**: **FAIL**
  - *Evidence*: Payment creation/charge endpoint does not exist. No guard checking `booking.Status == "Confirmed"` exists in code.
- **BookingApproval Audit Row Generation**: **PASS**
  - *Evidence*: `backend/Controllers/ApprovalController.cs` lines 98–107. A `BookingApproval` row is instantiated with `BookingId`, `TravelAgentId`, `Decision`, `Comment`, and `DecidedAt = DateTime.UtcNow`, and persisted via `_db.BookingApprovals.Add(approval)`.
- **Timestamp Updates on Status Transition**: **PASS**
  - *Evidence*: `backend/Controllers/ApprovalController.cs` line 123 sets `booking.UpdatedAt = DateTime.UtcNow;`.

---

### 6. Third-Party Integration (Stripe)

- **Stripe Sandbox Keys in Configuration**: **FAIL**
  - *Evidence*: `backend/appsettings.json`, `backend/appsettings.Development.json`, and `backend/Program.cs`.
  - Verdict: **NOT FOUND**. No Stripe configuration keys (`PublishableKey`, `SecretKey`, `WebhookSecret`) exist in any configuration file.
- **Synchronous Payment Execution**: **FAIL**
  - *Evidence*: `backend/backend.csproj` has no reference to `Stripe.net`. `backend/Services/PaymentService.cs` is a 0-byte file. No Stripe API invocation exists anywhere in the codebase.
- **StripeReference Persistence**: **PARTIAL**
  - *Evidence*: `backend/Models/Payment.cs` line 30 defines `public string? StripeReference { get; set; }`. However, since no payment processing action exists, real Stripe transaction references are never populated.

---

### 7. Secrets & Config Hygiene

- **Sensitive Strings Inspection**:
  - `password`: **FAIL** — `backend/Program.cs` line 21 contains hardcoded `"Password=7552632"`. `backend/appsettings.json` line 10 contains committed `"Password=7552632"`.
  - `Jwt:Key`: **PASS** — `backend/appsettings.json` line 13 uses placeholder `"CHANGE-ME-in-appsettings.Development.json-or-env-var-32chars!!"`. Real development key is located in `backend/appsettings.Development.json`.
  - `Staff:RegistrationCode`: **PASS** — `backend/appsettings.json` line 19 uses placeholder. Real development code is in `backend/appsettings.Development.json`.
  - `sk_test` / `sk_live`: **PASS** (No raw Stripe keys committed).
- **.gitignore Exclusions**: **PASS**
  - *Evidence*: `/.gitignore` line 5 includes `backend/appsettings.Development.json`, and lines 23–24 include `.env` and `.env.local`.
- **Staff Registration Endpoint & Secret Verification**: **FAIL**
  - *Evidence*: `backend/Controllers/AuthController.cs` lines 1–180. Only `register` and `login` are defined. A `register-staff` endpoint verifying `StaffSecretCode` is **NOT FOUND**.

---

### 8. CRUD + Search / Filter / Sort / Pagination Coverage

| Entity | Pagination | Filter Parameter(s) | Sort Parameter | Verdict | Evidence / Signature |
| :--- | :---: | :---: | :---: | :---: | :--- |
| **Customer** | ✅ | ✅ | ✅ | **PASS** | `CustomerController.cs:81` — `GetAll([FromQuery] string? search, [FromQuery] string? sortBy, [FromQuery] bool descending, int page, int pageSize)` |
| **Preference** | ❌ | ❌ | ❌ | **FAIL** | `PreferenceController.cs:29` — `GetMyPreferences()` (1:1 retrieval only, no collection query) |
| **Notification** | ✅ | ✅ | ❌ | **PARTIAL** | `NotificationController.cs:26` — `GetMyNotifications(string? status, DateTime? from, DateTime? to, int page, int pageSize)` (Sort is hardcoded) |
| **TripRequest** | ✅ | ❌ | ❌ | **PARTIAL** | `TripRequestController.cs:56` — `GetMyTripRequests(int page, int pageSize)` (No filter, sort is hardcoded) |
| **Destination** | ❌ | ❌ | ❌ | **FAIL** | `DestinationController.cs:22` — `GetAll()` (Plain return all rows, no parameters) |
| **Tour** | ✅ | ✅ | ❌ | **PARTIAL** | `TourController.cs:22` — `Search(int? destinationId, string? category, decimal? minPrice, decimal? maxPrice, string? status, int page, int pageSize)` (Sort is hardcoded) |
| **Itinerary** | ❌ | ✅ | ❌ | **PARTIAL** | `ItineraryController.cs:26` — `GetForReview([FromQuery] string? status)` (No pagination, sort is hardcoded) |
| **Hotel** | ❌ | ✅ | ❌ | **PARTIAL** | `HotelController.cs:27` — `GetAll([FromQuery] int? destinationId, [FromQuery] string? search)` (No pagination, sort is hardcoded) |
| **Room** | ❌ | ❌ | ❌ | **FAIL** | Endpoint **NOT FOUND**. Rooms only retrieved as children of Hotel. |
| **TransportOption** | ❌ | ✅ | ❌ | **PARTIAL** | `TransportController.cs:27` — `GetAll([FromQuery] string? type, [FromQuery] string? search)` (No pagination, sort is hardcoded) |

---

### 9. Migrations

- **Migration Files Present**:
  1. `backend/Migrations/20260811172021_AddDestination.cs`
  2. `backend/Migrations/20260812163420_AddTour.cs`
  3. `backend/Migrations/20260819145626_AddStudentATables.cs`
  4. `backend/Migrations/AppDbContextModelSnapshot.cs`
- **Model vs Migration Snapshot Parity**: **FAIL**
  - *Evidence*: `backend/Migrations/AppDbContextModelSnapshot.cs` lines 1–695.
  - The latest migration snapshot contains only Identity tables, `Customer`, `Preference`, `Notification`, `TripRequest`, `AgentLog`, `Destination`, and `Tour`.
  - **10 of 17 models are completely missing from migrations and snapshot**:
    1. `TravelAgent`
    2. `Itinerary`
    3. `ItineraryItem`
    4. `Hotel`
    5. `Room`
    6. `TransportOption`
    7. `Booking`
    8. `BookingItem`
    9. `BookingApproval`
    10. `Payment`

---

### 10. Error Handling & Validation Quality

- **DTO Usage vs Raw EF Entity Exposure**: **FAIL**
  - *Evidence*: `backend/Controllers/BookingController.cs` line 80 (`GetById`) returns the raw `Booking` entity including all nested EF navigation entities (`Customer`, `Itinerary`, `Items`, `Approvals`, `Payment`). `backend/Controllers/HotelController.cs` lines 73, 108, 134 returns raw `Hotel` entities.
- **Data Annotation Validation on Request DTOs**: **FAIL**
  - *Evidence*:
    - `CustomerUpdateDto`: Validated with `[Required]`, `[MaxLength]`, `[Phone]` (`CustomerUpdateDto.cs`).
    - `PreferenceUpdateDto`: Validated with `[Range]`, `[MaxLength]` (`PreferenceUpdateDto.cs`).
    - `TripRequestCreateDto`: Validated with `[Required]`, `[Range]` (`TripRequestCreateDto.cs`).
    - `CreateTourDto`: **FAIL** — No validation attributes on any field (`TourDto.cs:21–34`).
    - `CreateHotelDto`: **FAIL** — No validation attributes on any field (`HotelController.cs:154–163`).
    - `CreateTransportDto`: **FAIL** — No validation attributes on any field (`TransportController.cs:128–139`).
    - `ApprovalDecisionDto`: **FAIL** — No validation attributes (`ApprovalController.cs:139–143`).
    - `UpdateItineraryStatusDto`: **FAIL** — No validation attributes (`ItineraryController.cs:80–83`).
- **Foreign Key Existence Pre-Validation**: **PARTIAL**
  - *Evidence*: `TripRequestController.cs` line 37 and `TripRequestService.cs` line 44 validate existence of `CustomerId` and `DestinationId` returning 404/400.
  - However, `TourService.CreateAsync` does not check if `dto.DestinationId` exists prior to `SaveChangesAsync()`, leading to unhandled database exceptions (`PostgresException 23503`) when an invalid ID is provided. `HotelController.Create` defaults missing `DestinationId` to `1` without verifying existence.

---

## Remaining Action Items

1. **Create and Apply Complete EF Core Migration**:
   - Generate an EF Core migration encompassing `TravelAgent`, `Itinerary`, `ItineraryItem`, `Hotel`, `Room`, `TransportOption`, `Booking`, `BookingItem`, `BookingApproval`, and `Payment`.
   - Add Fluent API configurations in `AppDbContext.OnModelCreating` for `ItineraryItem`, `Hotel`, `Room`, `TransportOption`, and `BookingItem`.
2. **Remove Plaintext Database Credentials**:
   - Remove hardcoded password `"7552632"` from `backend/Program.cs` line 21 and replace `backend/appsettings.json` line 10 with a clean placeholder.
3. **Register Global Exception Handling Middleware**:
   - Add `app.UseExceptionHandler()` or a custom exception middleware in `backend/Program.cs` to return clean RFC 7807 Problem Details and prevent stack trace leakage.
4. **Scope CORS Configuration**:
   - Update `Program.cs` line 119 to specify explicit allowed origins (e.g. `http://localhost:5173`) instead of `AllowAnyOrigin()`.
5. **Implement Identity Role Seeding & Staff Registration**:
   - Implement role seeding for `"Customer"`, `"TravelAgent"`, and `"Admin"` during application startup.
   - Add `POST /api/auth/register-staff` in `AuthController.cs` validating `StaffSecretCode` against `IConfiguration["Staff:RegistrationCode"]`.
6. **Secure Endpoints with [Authorize] & Fix IDOR Vulnerabilities**:
   - Add `[Authorize]` to `BookingController`, `ItineraryController`, `HotelController`, and `TransportController`.
   - Add customer ownership check to `BookingController.GetById(int id)`.
   - Restrict `CustomerController.GetById(string id)` to `Admin` and `TravelAgent` roles.
7. **Implement Missing Booking Controller Endpoints**:
   - Implement `POST /api/booking` (create booking with line items).
   - Implement `PATCH /api/booking/{id}/cancel`.
   - Enforce status guards ensuring status cannot transition directly to `Confirmed` without passing through `AwaitingApproval`.
8. **Implement Stripe Payment Integration**:
   - Install `Stripe.net` NuGet package.
   - Implement synchronous payment capture in `PaymentService.cs` storing the returned `StripeReference`.
   - Implement `POST /api/payment/charge` requiring `Booking.Status == "Confirmed"`.
   - Implement `GET /api/payment/booking/{bookingId}` with customer ownership checks.
9. **Align AgentLog Schema**:
   - Update `backend/Models/AgentLog.cs` to include `StepType`, `ToolName`, `DurationMs`, `StepDescription`, `InputJson`, `OutputJson`, and `CreatedAt`.
10. **Implement Itinerary Assembly & Overlap Checking**:
    - Implement `ItineraryService.cs` with validation logic that rejects any itinerary with overlapping `StartTime` and `EndTime` intervals on the same `DayNumber`.
11. **Add Missing Endpoints & Soft Deletes on Vendor Controllers**:
    - Add `GET /api/transport/{id}` to `TransportController`.
    - Add nested room management (`GET /api/hotel/{id}/rooms`, `POST /api/hotel/{id}/rooms`) to `HotelController`.
    - Change hard delete operations in `HotelController` and `TransportController` to soft deletes (`Status = "Inactive"`).
12. **Complete Query Capabilities (Pagination, Filtering, Sorting)**:
    - Add pagination, filtering, and sorting to `DestinationController.GetAll()`.
    - Add sort parameters to `TourController`, `NotificationController`, `HotelController`, `TransportController`, and `ItineraryController`.
    - Add pagination to `HotelController`, `TransportController`, and `ItineraryController`.
13. **Strengthen Request Validation & Eliminate Entity Leaks**:
    - Add `[Required]`, `[Range]`, and `[MaxLength]` validation attributes to `CreateHotelDto`, `CreateTransportDto`, `ApprovalDecisionDto`, `UpdateItineraryStatusDto`, and `CreateTourDto`.
    - Replace raw entity returns in `BookingController` and `HotelController` with strongly typed response DTOs.
    - Add polymorphic validation on `BookingItem` ensuring exactly one of `TourId`, `RoomId`, or `TransportOptionId` is provided matching `ItemType`.
