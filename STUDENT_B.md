# Student B — Component & Architecture Documentation
## Component B: Tours & Itineraries Management + AI Itinerary Domain Analysis Agent

> **Course:** SE3090 — Software Engineering Frameworks  
> **Student Ownership:** Student B  
> **Stack:** ASP.NET Core Web API (.NET 8) · PostgreSQL (EF Core) · React (Staff Dashboard) · Flutter (Mobile Customer App) · Python / LangGraph (AI Agent)

---

## 1. Executive Summary & Component Scope

Student B owns **Component B: Tours & Itineraries**, which serves as the experience-planning core of the system. This component manages destination data, the catalog of available tours and activities, and the day-by-day scheduling engine that builds conflict-free trip itineraries.

### Key Responsibilities
1. **Catalog Management:** Full administrative CRUD for Destinations and Tours (with multi-part image uploads, magic-byte MIME validation, and soft-delete capabilities).
2. **Itinerary Scheduling Engine:** Dynamic assembly of day-by-day itineraries with deterministic business rules (time-overlap validation, price snapshotting, and automatic total cost recalculation).
3. **Multi-Platform UI:**
   - **React (Staff/Admin):** Tour Catalog Management, Destination Management, and Itinerary Review Console.
   - **Flutter (Customer):** Tour Search & Browse, Tour Details, and "My Itinerary" day-by-day timeline view.
4. **Agentic AI Workflow (Itinerary Agent):** An autonomous domain-analysis agent powered by LangGraph that searches matching tours based on customer preferences and builds an initial conflict-free schedule.

---

## 2. Progress Summary: Completed vs. Pending Tasks

### 2.1 Overall Status Dashboard

| Subsystem / Layer | Component / Scope | Status | Completion |
|---|---|:---:|:---:|
| **Database & Models** | 4 Tables (`Destination`, `Tour`, `Itinerary`, `ItineraryItem`) + EF Core Mappings | ✅ Completed | 100% |
| **Backend API** | `TourController`, `ItineraryController`, `DestinationController` + DTOs | ✅ Completed | 100% |
| **Business Logic** | Overlap Conflict Engine, Total Cost Recalculation, Image Magic Bytes | ✅ Completed | 100% |
| **Testing Suite** | `TourServiceTests.cs`, `ItineraryServiceTests.cs` (XUnit + InMemory) | ✅ Completed | 100% |
| **React Staff UI** | Tour Catalog, Destination Management, Itinerary Review | ✅ Completed | 100% |
| **Flutter Mobile UI** | Tour Search & Browse, Tour Details, My Itinerary, API Services | ✅ Completed | 100% |
| **Agentic AI** | Python Itinerary Agent (`agentic-ai/agents/itinerary_agent.py`) | ⏳ Pending | 15% (Architecture Ready) |
| **Overall Readiness** | **Component B Overall Readiness Score** | 🟢 **Near Complete** | **~90%** (All Backend, React, Flutter & Tests 100% Complete) |

---

### 2.2 What is COMPLETED (Done & Verified)

1. **Backend Database Models & DbSets (`backend/Models/`, `backend/Data/AppDbContext.cs`):**
   - [x] `Destination` model with latitude/longitude and foreign relationships.
   - [x] `Tour` model with category, price, duration, default start time, and soft-delete (`Status = "Active"/"Inactive"`).
   - [x] `Itinerary` model with `ItineraryStatus` enum (`Draft`, `Proposed`, `Accepted`, `Discarded`).
   - [x] `ItineraryItem` model with `PriceAtSelection` price snapshotting.
   - [x] `AppDbContext` DbSets and Fluent API foreign key constraints configured.

2. **Backend Controllers, Services & DI (`backend/Controllers/`, `backend/Services/`):**
   - [x] `TourController` & `TourService`:
     - Multi-filter search: free-text `search` (case-insensitive name/description), `category`, `minPrice`, `maxPrice`, `status`, `sortBy`, and pagination.
     - Multipart form data image upload with 5MB max limit and binary magic-byte inspection (JPEG, PNG, WebP).
     - Soft delete endpoint setting `Status = "Inactive"`.
   - [x] `ItineraryController` & `ItineraryService`:
     - Mathematical time-overlap validation rule on the same day (`newStart < existingEnd && newEnd > existingStart`).
     - Automated `TotalEstimatedCost` recalculation on adding and removing items.
     - Customer ownership check (ensuring customers only view/edit their own itineraries).
     - Status transition workflow (`Draft` → `Proposed` → `Accepted`).
   - [x] `DestinationController` & `DestinationService`: Full CRUD.
   - [x] Dependency injection registered in `Program.cs` (`IItineraryService`, `TourService`, `DestinationService`).

3. **Frontend — Staff Portal (`frontend-react/src/pages/tours/`):**
   - [x] `TourCatalogManagement.jsx`: Full table with search, category filtering, sort, add/edit modal, image upload, and soft-delete toggle.
   - [x] `ItineraryReview.jsx`: Staff review queue for AI-proposed itineraries, day-by-day item timeline, and approve/reject actions.
   - [x] `DestinationManagement.jsx`: Destination CRUD with image previews and coordinates.

4. **Frontend — Customer Mobile App (`mobile_flutter/lib/screens/tours/`):**
   - [x] `tour_search_browse_screen.dart`: Free-text search bar with debounce, category filter chips, tour cards.
   - [x] `tour_details_screen.dart`: Activity description, duration, default start time, hero image, and "Add to Itinerary".
   - [x] `my_itinerary_screen.dart`: Day-by-day scheduled activities timeline, start/end time badges, total cost summary pill.
   - [x] `api_service.dart`: Synchronized API calls with backend routes.

5. **Unit Tests (`backend.Tests/`):**
   - [x] `TourServiceTests.cs`: Search filter test verified and updated with `search: null`.
   - [x] `ItineraryServiceTests.cs`: 3 brand-new automated test cases passing:
     - `AddItemToItineraryAsync_NoOverlap_Succeeds`
     - `AddItemToItineraryAsync_OverlappingTimeOnSameDay_IsRejected`
     - `AddItemToItineraryAsync_SameTimeDifferentDay_Succeeds`

6. **Recent Critical Bug Fixes:**
   - [x] Fixed Flutter 404 route mismatch (`itinerary/my` → `itinerary/customer/$userId`).
   - [x] Added missing `search` free-text query parameter to `TourController` and `TourService`.
   - [x] Resolved test build error in `TourServiceTests.cs`.

7. **Edit-Before-Release & Change Request Features:**
   - [x] React `ItineraryReview.jsx`: Added a "Remove" button on each itinerary item in the day-by-day timeline, visible when the itinerary is not yet `Accepted`/`Discarded`. Calls the existing backend endpoint `DELETE /api/itinerary/{itineraryId}/items/{itemId}` via a new `removeItineraryItem()` helper in `apiClient.js`. Satisfies the spec's "edit-before-release" requirement.
   - [x] Flutter `my_itinerary_screen.dart`: Added a "Request Changes" button in the itinerary detail view, with a confirmation dialog. Calls a new `requestItineraryChanges()` method in `api_service.dart`, which PATCHes the existing `/api/itinerary/{id}/status` endpoint to set status to `Discarded`. Required adding a generic `patch()` HTTP helper to `api_service.dart` (previously only `get`/`post`/`put` existed).

---

### 2.3 What STILL NEEDS TO BE DONE (Pending Tasks)

1. **Python AI Agent Implementation (`agentic-ai/agents/itinerary_agent.py`):**
   - [ ] Currently, `itinerary_agent.py` is an empty file (0 bytes).
   - [ ] Implement the LangGraph node for the Itinerary Agent.
   - [ ] Define the `search_tours` tool (under `agentic-ai/tools/tour_tools.py`) to query the ASP.NET Core API (`GET /api/tour`).
   - [ ] Implement the prompt template that accepts:
     - Destination, Date range, Budget ceiling, Traveller count, Preferred activity tags.
   - [ ] Write the scheduling logic that arranges selected tours into a conflict-free day-by-day JSON schedule without time overlaps.
   - [ ] Hook into `logger.py` to persist duration, tool calls, and step descriptions into the `AgentLog` table.

2. **Cross-Agent Graph Integration (`agentic-ai/graph.py`):**
   - [ ] Connect the output of the Coordinator Agent (Student A) to the Itinerary Agent (Student B).
   - [ ] Route the output of the Itinerary Agent to the Booking Agent (Student C) to check hotel/transport availability.

3. **End-to-End Workflow Verification:**
   - [ ] Perform a full cross-platform test:
     1. Customer submits a Trip Request in Flutter.
     2. Python multi-agent system runs (`Coordinator` → `Itinerary` → `Booking` → `Validation`).
     3. Itinerary row & items are persisted in PostgreSQL.
     4. Travel Agent reviews and approves in React.
     5. Customer views the confirmed day-by-day schedule in Flutter.

4. **Rich Seed Data Enhancement (Optional Viva Polish):**
   - [ ] Ensure `DatabaseSeeder.cs` has 10+ realistic Sri Lankan tours across multiple categories (Sigiriya, Kandy, Galle, Ella, Yala) with high-quality images and coordinates so the demo looks visually stunning.

---

## 3. Database Schema & Data Models (4 Tables Owned)

Student B owns and maintains 4 relational database tables within PostgreSQL via Entity Framework Core:

```mermaid
erDiagram
    DESTINATION ||--o{ TOUR : "contains"
    DESTINATION ||--o{ TRIP_REQUEST : "requested in"
    ITINERARY ||--|{ ITINERARY_ITEM : "contains"
    TOUR ||--o{ ITINERARY_ITEM : "scheduled as"
    CUSTOMER ||--o{ ITINERARY : "owns"
    TRIP_REQUEST ||--o{ ITINERARY : "originates from"
    ITINERARY ||--o| BOOKING : "booked as"

    DESTINATION {
        int Id PK
        string Name
        string Country
        string Description
        string ImageUrl
        double Latitude
        double Longitude
    }

    TOUR {
        int Id PK
        int DestinationId FK
        string Name
        string Category
        string Description
        string ImageUrl
        decimal Price
        string Currency
        double DurationHours
        TimeSpan DefaultStartTime
        double Latitude
        double Longitude
        string Status "Active / Inactive"
        DateTime CreatedAt
        DateTime UpdatedAt
    }

    ITINERARY {
        int Id PK
        string CustomerId FK
        int TripRequestId FK
        DateTime StartDate
        DateTime EndDate
        int Status "Draft / Proposed / Accepted / Discarded"
        decimal TotalEstimatedCost
        string Currency
        DateTime CreatedAt
    }

    ITINERARY_ITEM {
        int Id PK
        int ItineraryId FK
        int TourId FK
        int DayNumber
        int SequenceOrder
        TimeSpan StartTime
        TimeSpan EndTime
        decimal PriceAtSelection
    }
```

### Table Specifications

#### 1. `Destination` (`backend/Models/Destination.cs`)
* Stores geographical target areas (e.g., Kandy, Sigiriya, Mirissa).
* Fields: `Id`, `Name` (max 100), `Country` (max 100), `Description` (max 1000), `ImageUrl`, `Latitude`, `Longitude`.
* Foreign relationship: 1-to-Many with `Tour`.

#### 2. `Tour` (`backend/Models/Tour.cs`)
* Individual bookable activities or excursions.
* Fields: `Id`, `DestinationId` (FK), `Name`, `Category` (e.g., Sightseeing, Adventure, Safari), `Description`, `ImageUrl`, `Price`, `Currency`, `DurationHours`, `DefaultStartTime`, `Status` (Active/Inactive), `CreatedAt`, `UpdatedAt`.
* **Soft Delete:** Status is changed to `"Inactive"` instead of physically removing database rows, ensuring historical bookings and itineraries maintain relational integrity.

#### 3. `Itinerary` (`backend/Models/Itinerary.cs`)
* Represents a full trip package structure linking customer requests to scheduled activities.
* Fields: `Id`, `CustomerId` (FK), `TripRequestId` (FK), `StartDate`, `EndDate`, `Status` (`ItineraryStatus` Enum: `Draft`, `Proposed`, `Accepted`, `Discarded`), `TotalEstimatedCost`, `Currency`, `CreatedAt`.
* Foreign relationships: Belongs to `Customer` and `TripRequest`; has many `ItineraryItems`.

#### 4. `ItineraryItem` (`backend/Models/ItineraryItem.cs`)
* Specific scheduled tour instance assigned to a particular day and time range within an itinerary.
* Fields: `Id`, `ItineraryId` (FK), `TourId` (FK), `DayNumber`, `SequenceOrder`, `StartTime`, `EndTime`, `PriceAtSelection`.
* **Price Snapshot Pattern:** `PriceAtSelection` captures the exact tour price at the moment of adding it. If the tour base price changes later, historical itineraries remain unmodified.

---

## 4. Backend Architecture & Business Logic (ASP.NET Core)

### 4.1 Controllers

| Controller | Route | HTTP Method | Authorization | Purpose |
|---|---|---|---|---|
| `TourController` | `/api/tour` | `GET` | `[AllowAnonymous]` | Search, filter (search, category, price, destination), sort, paginate tours |
| `TourController` | `/api/tour/{id}` | `GET` | `[AllowAnonymous]` | Get full tour details by ID |
| `TourController` | `/api/tour` | `POST` | `[Authorize(Roles="TravelAgent,Admin")]` | Create tour with image file upload (`multipart/form-data`) |
| `TourController` | `/api/tour/{id}` | `PUT` | `[Authorize(Roles="TravelAgent,Admin")]` | Update tour details |
| `TourController` | `/api/tour/{id}` | `DELETE` | `[Authorize(Roles="TravelAgent,Admin")]` | Soft-delete tour (`Status = "Inactive"`) |
| `ItineraryController` | `/api/itinerary` | `POST` | `[Authorize]` | Create initial empty Itinerary in `Draft` state |
| `ItineraryController` | `/api/itinerary/{id}` | `GET` | `[Authorize]` | Get itinerary with items and tour navigation (Ownership-guarded) |
| `ItineraryController` | `/api/itinerary/customer/{customerId}` | `GET` | `[Authorize]` | List all itineraries for logged-in customer |
| `ItineraryController` | `/api/itinerary/review` | `GET` | `[Authorize(Roles="TravelAgent,Admin")]` | Review queue of all itineraries for staff |
| `ItineraryController` | `/api/itinerary/{id}/items` | `POST` | `[Authorize]` | Add scheduled tour to itinerary (Runs overlap validation) |
| `ItineraryController` | `/api/itinerary/{id}/items/{itemId}` | `DELETE` | `[Authorize]` | Remove item and automatically recalculate total cost |
| `ItineraryController` | `/api/itinerary/{id}/status` | `PATCH` | `[Authorize]` | Update itinerary status (`Draft` → `Proposed` → `Accepted`) |
| `DestinationController`| `/api/destinations` | `GET`, `POST` | Mixed | Full Destination catalog CRUD |
| `DestinationController`| `/api/destinations/{id}`| `GET`, `PUT`, `DELETE`| Mixed | Destination individual record CRUD |

---

### 4.2 Core Service Business Logic

#### A. Overlap Conflict Detection Engine (`ItineraryService.cs`)
To guarantee conflict-free schedules, before an item is inserted, the engine validates all existing items for that itinerary on the same `DayNumber`:

$$\text{Overlap Condition: } (\text{newStart} < \text{existingEnd}) \land (\text{newEnd} > \text{existingStart})$$

```csharp
// Excerpt from ItineraryService.cs:
var sameDayItems = await _context.ItineraryItems
    .Where(item => item.ItineraryId == itineraryId && item.DayNumber == dto.DayNumber)
    .ToListAsync();

var conflicting = sameDayItems.FirstOrDefault(existing =>
    dto.StartTime < existing.EndTime && dto.EndTime > existing.StartTime);

if (conflicting is not null)
{
    return (false,
        $"Time conflict on Day {dto.DayNumber}: requested range {dto.StartTime}–{dto.EndTime} " +
        $"overlaps with existing item ({conflicting.StartTime}–{conflicting.EndTime}).",
        null);
}
```

#### B. Dynamic Cost Recalculation
- When an item is added: `Itinerary.TotalEstimatedCost = existingItemsTotal + newItem.PriceAtSelection`.
- When an item is deleted: `Itinerary.TotalEstimatedCost = remainingItems.Sum(i => i.PriceAtSelection)`.

#### C. Secure File Uploads (`TourController.cs`)
- Enforces strict 5MB maximum file limit.
- Whitelists file extensions: `.jpg`, `.jpeg`, `.png`, `.webp`.
- **Magic Byte Verification:** Inspects binary headers to prevent malicious files disguised with legitimate extensions (JPEG `FF D8 FF`, PNG `89 50 4E 47`, WebP `RIFF....WEBP`).

---

## 5. Frontend Integration

### 5.1 Staff Management Dashboard (React — `frontend-react`)

| File | Screen / View | Features |
|---|---|---|
| `src/pages/tours/TourCatalogManagement.jsx` | Tour Catalog Admin Console | Table with search, category filtering, price sorting, pagination; modal for adding/editing tours; image upload handler; soft-delete toggle. |
| `src/pages/tours/ItineraryReview.jsx` | Itinerary Review Queue | View AI-generated / customer draft itineraries, inspect day-by-day item timeline, approve/reject proposal, inline adjustments; supports removing individual items before approval (edit-before-release). |
| `src/pages/tours/DestinationManagement.jsx` | Destinations Management | Create and edit destination locations, lat/long coordinates, and photo previews. |

### 5.2 Customer Mobile Application (Flutter — `mobile_flutter`)

| File | Screen / View | Features |
|---|---|---|
| `lib/screens/tours/tour_search_browse_screen.dart` | Tour Search & Browse | Search bar sending query to backend `?search=xxx`, category filter chips, tour price badges, photo thumbnails, empty/loading/error states. |
| `lib/screens/tours/tour_detail_screen.dart` | Tour Details | High-resolution hero image, activity description, duration, default start time, price tag, destination info, "Add to Itinerary" action. |
| `lib/screens/tours/my_itinerary_screen.dart` | My Itinerary Screen | Displays day-by-day cards, sequenced activities with start/end time chips, total cost calculation, and status progression pill; includes a 'Request Changes' action that marks the itinerary as Discarded. |
| `lib/services/api_service.dart` | Client API Service | Contains `getTours(search, sortBy)`, `getTour(id)`, `getMyItineraries()`, and `getItinerary(id)`. |

---

## 6. Summary of Bug Fixes & Code Improvements Completed

During quality assurance and static code tracing, 4 critical issues were identified and resolved:

1. **Flutter Route Mismatch Fixed (`mobile_flutter/lib/services/api_service.dart`):**
   - *Issue:* `getMyItineraries()` was calling `GET itinerary/my`, which returned `404 Not Found` because the backend route was `GET itinerary/customer/{customerId}`.
   - *Fix:* Updated `getMyItineraries()` to retrieve the logged-in customer's `userId` from secure storage and call `GET itinerary/customer/$userId`.

2. **Backend Search Parameter Added (`TourController.cs` & `TourService.cs`):**
   - *Issue:* The mobile app sent `GET /api/tour?search=xxx`, but the backend ignored the query because `TourController.Search()` and `TourService.SearchAsync()` lacked the `search` parameter.
   - *Fix:* Added `[FromQuery] string? search` to the controller and implemented case-insensitive filtering on both `Name` and `Description` in `TourService.cs`:
     ```csharp
     if (!string.IsNullOrWhiteSpace(search))
     {
         var term = search.Trim().ToLower();
         query = query.Where(t =>
             t.Name.ToLower().Contains(term) ||
             (t.Description != null && t.Description.ToLower().Contains(term)));
     }
     ```

3. **Test Compilation Failure Fixed (`backend.Tests/TourServiceTests.cs`):**
   - *Issue:* Named parameter call to `service.SearchAsync(...)` lacked the newly added required `search` argument, causing a build failure.
   - *Fix:* Added `search: null,` as the first named parameter.

4. **Automated Unit Tests Created (`backend.Tests/ItineraryServiceTests.cs`):**
   - Created comprehensive unit tests using `Microsoft.EntityFrameworkCore.InMemory`:
     - `AddItemToItineraryAsync_NoOverlap_Succeeds`: Verifies successful item addition and single item count.
     - `AddItemToItineraryAsync_OverlappingTimeOnSameDay_IsRejected`: Verifies time conflict rejection with descriptive error message.
     - `AddItemToItineraryAsync_SameTimeDifferentDay_Succeeds`: Verifies identical time ranges on different days do not conflict.

5. **Edit-Before-Release Added (`ItineraryReview.jsx` & `apiClient.js`):**
   - *Gap:* The Itinerary Review page was read-only — travel agents could approve/reject but not remove an unwanted item first.
   - *Fix:* Added `removeItineraryItem(itineraryId, itemId)` in `apiClient.js` calling the existing `DELETE /api/itinerary/{id}/items/{itemId}` endpoint, plus a "Remove" button per item, guarded by a `canEdit` check on itinerary status.

6. **Request Changes Added (`my_itinerary_screen.dart` & `api_service.dart`):**
   - *Gap:* Customers had no way to signal dissatisfaction with an AI-proposed itinerary from the Flutter app.
   - *Fix:* Added a generic `patch()` helper and a `requestItineraryChanges(itineraryId)` method calling the existing `PATCH /api/itinerary/{id}/status` endpoint with `{"status": "Discarded"}`, wired to a new confirmation-gated "Request Changes" button.

---

## 7. AI Agent Design: Itinerary / Domain Analysis Agent

> **File:** `agentic-ai/agents/itinerary_agent.py`  
> **Framework:** Python 3.11 + LangGraph + LangChain  
> **Status:** Architecture Designed (Ready for implementation)

### 7.1 Role in Multi-Agent Pipeline
The Itinerary Agent is **Agent 2** in the 4-agent sequential workflow:
```
[TripRequest] ──► Agent 1: Coordinator (Student A)
                        │
                        ▼ (Structured Plan + Destination/Dates/Budget/Preferences)
                  Agent 2: Itinerary Agent (Student B)
                        │
                        ▼ (Day-by-Day Conflict-Free Itinerary)
                  Agent 3: Booking Agent (Student C)
                        │
                        ▼ (Priced Package with Room/Transport Availability)
                  Agent 4: Validation Agent (Student D)
                        │
                        ▼
                  [Human-in-the-Loop Approval Gate]
```

### 7.2 Agent Specifications
* **Agent Name:** `Itinerary / Domain Analysis Agent`
* **Input Contract:**
  ```json
  {
    "trip_request_id": 101,
    "destination_id": 2,
    "destination_name": "Kandy",
    "start_date": "2026-10-01",
    "end_date": "2026-10-05",
    "traveller_count": 2,
    "budget_ceiling": 150000.00,
    "preferred_activities": ["Culture", "Nature", "Walking Tours"]
  }
  ```
* **Tools Owned:**
  * `search_tours(destination_id, category, max_price)`: Queries the ASP.NET Core `GET /api/tour` endpoint to retrieve candidate tours.
* **Deterministic Rules Enforced by the Agent:**
  1. Only select tours with `Status == "Active"`.
  2. Total tour costs must remain within the allocated activity budget portion.
  3. Ensure no schedule collision: for any day, $\text{StartTime}_B \ge \text{EndTime}_A$.
  4. Balance the schedule: distribute activities across available days (typically 1-2 major tours per day).
* **Output Contract:**
  ```json
  {
    "itinerary_id": null,
    "total_estimated_cost": 48000.00,
    "currency": "LKR",
    "schedule": [
      {
        "day_number": 1,
        "items": [
          { "tour_id": 1, "tour_name": "Temple of the Tooth Tour", "start_time": "09:00:00", "end_time": "11:30:00", "price": 12000.00 },
          { "tour_id": 3, "tour_name": "Kandy Lake Sunset Walk", "start_time": "16:00:00", "end_time": "18:00:00", "price": 6000.00 }
        ]
      }
    ]
  }
  ```
* **Audit Trail:** Writes execution details to the `AgentLog` table (Duration, Step Description, Input JSON, Output JSON).

---

## 8. Viva & Marking Defense Guide for Student B

When defending your component in the viva examination, focus on these key highlights:

1. **Why soft delete instead of hard delete on Tours?**
   - *Answer:* Hard deleting a tour breaks foreign keys in historical `ItineraryItems` and completed `Bookings`. By setting `Status = "Inactive"`, we preserve historical financial and operational records while preventing future scheduling.
2. **How do you prevent scheduling collisions?**
   - *Answer:* In `ItineraryService.AddItemToItineraryAsync()`, we query existing items on the same `DayNumber` and test the mathematical interval overlap condition: `newStart < existingEnd && newEnd > existingStart`. If true, we abort and return a 400 Bad Request with a descriptive conflict message.
3. **How do you handle price changes over time?**
   - *Answer:* We use the **Price Snapshot Pattern** (`PriceAtSelection` on `ItineraryItem`). Even if the tour manager raises the tour price from \$50 to \$70 later, the customer's draft and booked itineraries retain the exact price active at the moment of selection.
4. **How do your security and file uploads work?**
   - *Answer:* In `TourController.Create()`, image files are checked for 5MB limits and binary magic bytes (JPEG/PNG/WebP headers), preventing extension-spoofing attacks.
5. **How does your component integrate with other students?**
   - *With Student A:* Consumes `TripRequest` and `Customer` IDs to generate the `Itinerary`.
   - *With Student C:* The Itinerary created by Student B is passed to Student C to attach Hotel and Transport choices for the same dates.
   - *With Student D:* The final Itinerary and its items are converted into `Booking` and `BookingItem` records, which pass through Student D's human approval gate.
