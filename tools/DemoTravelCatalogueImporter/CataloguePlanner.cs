namespace DemoTravelCatalogueImporter;

public static class CataloguePlanner
{
    private const string DemoProvider = "Demo Private Transfer";
    private const string DemoRateNote =
        "Demo catalogue rate - not live booking price; confirm dates, taxes, meal plan, and availability with the property.";

    public static ImportPlan Build(
        CatalogueSnapshot snapshot,
        CatalogueDocument document,
        DateOnly businessToday)
    {
        var issues = new List<PlanIssue>();
        var destinationInserts = new List<DestinationSeed>();
        var hotelInserts = new List<HotelSeed>();
        var roomInserts = new List<PlannedRoom>();
        var tourInserts = new List<TourSeed>();
        var transportInserts = new List<PlannedTransport>();

        var existingDestinations = snapshot.Destinations
            .GroupBy(d => d.NormalizedName, StringComparer.OrdinalIgnoreCase)
            .ToDictionary(g => g.Key, g => g.First(), StringComparer.OrdinalIgnoreCase);
        var availableDestinations = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);

        foreach (var destination in snapshot.Destinations)
        {
            availableDestinations[Normalizers.Name(destination.Name)] = destination.Name;
        }

        var candidateDestinationKeys = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
        foreach (var destination in document.Destinations)
        {
            var key = Normalizers.Name(destination.Name);
            if (!candidateDestinationKeys.Add(key))
            {
                issues.Add(new("Destination", destination.Name, "DUPLICATE_CANDIDATE", "Repeated normalized candidate name."));
                continue;
            }

            if (existingDestinations.ContainsKey(key))
            {
                issues.Add(new("Destination", destination.Name, "SKIP_EXISTING", "Canonical destination already exists."));
                continue;
            }

            if (!destination.Verified || !CoordinatesAreValid(destination.Latitude, destination.Longitude))
            {
                issues.Add(new(
                    "Destination",
                    destination.Name,
                    "DESTINATION_VERIFICATION_PENDING",
                    destination.VerificationNote));
                continue;
            }

            destinationInserts.Add(destination);
            availableDestinations[key] = destination.Name;
        }

        var existingHotels = snapshot.Hotels
            .Select(h => Normalizers.Hotel(
                snapshot.Destinations.FirstOrDefault(d => d.Id == h.DestinationId)?.Name ?? string.Empty,
                h.Name))
            .ToHashSet(StringComparer.OrdinalIgnoreCase);
        var plannedHotelKeys = new HashSet<string>(StringComparer.OrdinalIgnoreCase);

        foreach (var hotel in document.Hotels)
        {
            var destinationKey = Normalizers.Name(hotel.Destination);
            if (!availableDestinations.ContainsKey(destinationKey))
            {
                issues.Add(new("Hotel", hotel.Name, "DESTINATION_NOT_IMPORTABLE", $"Destination '{hotel.Destination}' is not verified/importable."));
                continue;
            }

            var key = Normalizers.Hotel(hotel.Destination, hotel.Name);
            if (existingHotels.Contains(key))
            {
                issues.Add(new("Hotel", hotel.Name, "SKIP_EXISTING", "Destination and normalized hotel name already exist."));
                continue;
            }

            if (!plannedHotelKeys.Add(key))
            {
                issues.Add(new("Hotel", hotel.Name, "DUPLICATE_CANDIDATE", "Repeated destination and normalized hotel name."));
                continue;
            }

            if (!hotel.IdentityVerified)
            {
                issues.Add(new("Hotel", hotel.Name, "HOTEL_IDENTITY_VERIFICATION_FAILED", hotel.VerificationNote));
                continue;
            }

            if (!hotel.CoordinatesVerified || !CoordinatesAreValid(hotel.Latitude, hotel.Longitude))
            {
                issues.Add(new(
                    "Hotel",
                    hotel.Name,
                    "HOTEL_COORDINATE_VERIFICATION_PENDING",
                    "Latitude and longitude must be verified from a point-level source before import. " + hotel.VerificationNote));
                continue;
            }

            hotelInserts.Add(hotel);
            roomInserts.AddRange(BuildRooms(hotel));
        }

        var existingTours = snapshot.Tours
            .Select(t => Normalizers.Tour(
                snapshot.Destinations.FirstOrDefault(d => d.Id == t.DestinationId)?.Name ?? string.Empty,
                t.Name))
            .ToHashSet(StringComparer.OrdinalIgnoreCase);
        var plannedTourKeys = new HashSet<string>(StringComparer.OrdinalIgnoreCase);

        foreach (var tour in document.Tours)
        {
            var destinationKey = Normalizers.Name(tour.Destination);
            if (!availableDestinations.ContainsKey(destinationKey))
            {
                issues.Add(new("Tour", tour.Name, "DESTINATION_NOT_IMPORTABLE", $"Destination '{tour.Destination}' is not verified/importable."));
                continue;
            }

            var key = Normalizers.Tour(tour.Destination, tour.Name);
            if (existingTours.Contains(key))
            {
                issues.Add(new("Tour", tour.Name, "SKIP_EXISTING", "Destination and normalized tour name already exist."));
                continue;
            }

            if (!plannedTourKeys.Add(key))
            {
                issues.Add(new("Tour", tour.Name, "DUPLICATE_CANDIDATE", "Repeated destination and normalized tour name."));
                continue;
            }

            if (!tour.IdentityVerified)
            {
                issues.Add(new("Tour", tour.Name, "TOUR_IDENTITY_VERIFICATION_FAILED", "Attraction identity is not source-verified."));
                continue;
            }

            tourInserts.Add(tour);
        }

        var existingTransportKeys = snapshot.TransportOptions
            .Select(t => Normalizers.Transport(t.Provider, t.RouteFrom, t.RouteTo, t.DepartureTime))
            .ToHashSet(StringComparer.OrdinalIgnoreCase);
        var plannedTransportKeys = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
        var routePairs = RouteCatalog();
        var windowStart = businessToday.AddDays(1);
        var windowEnd = businessToday.AddDays(60);

        foreach (var existingTransport in snapshot.TransportOptions)
        {
            var fromKnown = availableDestinations.ContainsKey(Normalizers.Name(existingTransport.RouteFrom));
            var toKnown = availableDestinations.ContainsKey(Normalizers.Name(existingTransport.RouteTo));
            if (!fromKnown || !toKnown)
            {
                issues.Add(new(
                    "Transport",
                    $"{existingTransport.RouteFrom} -> {existingTransport.RouteTo}",
                    "NON_CANONICAL_EXISTING_ROUTE",
                    "Existing row is preserved; new generated rows use exact canonical Destination.Name values."));
            }
            else if (Normalizers.Name(existingTransport.RouteFrom) == Normalizers.Name(existingTransport.RouteTo))
            {
                issues.Add(new(
                    "Transport",
                    $"{existingTransport.RouteFrom} -> {existingTransport.RouteTo}",
                    "SELF_ROUTE_EXISTING",
                    "Existing row is preserved but excluded from ordered inter-destination coverage."));
            }
        }

        foreach (var route in routePairs)
        {
            if (!availableDestinations.ContainsKey(Normalizers.Name(route.From)) ||
                !availableDestinations.ContainsKey(Normalizers.Name(route.To)))
            {
                issues.Add(new("Transport", $"{route.From} -> {route.To}", "NO_ROUTE_DESTINATION", "One or both canonical destinations are not importable."));
                continue;
            }

            for (var date = windowStart; date <= windowEnd; date = date.AddDays(1))
            {
                if (!route.Weekdays.Contains(date.DayOfWeek))
                {
                    continue;
                }

                var departure = DateTime.SpecifyKind(
                    date.ToDateTime(TimeOnly.FromTimeSpan(route.DepartureTime)),
                    DateTimeKind.Unspecified);
                var arrival = departure.AddMinutes(route.DurationMinutes);
                var key = Normalizers.Transport(DemoProvider, route.From, route.To, departure);

                if (existingTransportKeys.Contains(key))
                {
                    issues.Add(new("Transport", key, "SKIP_EXISTING", "Provider, ordered route, and local departure already exist."));
                    continue;
                }

                if (!plannedTransportKeys.Add(key))
                {
                    issues.Add(new("Transport", key, "DUPLICATE_CANDIDATE", "Generated provider, ordered route, and departure key repeated."));
                    continue;
                }

                transportInserts.Add(new PlannedTransport
                {
                    Provider = DemoProvider,
                    RouteFrom = availableDestinations[Normalizers.Name(route.From)],
                    RouteTo = availableDestinations[Normalizers.Name(route.To)],
                    DepartureTime = departure,
                    ArrivalTime = arrival,
                    Capacity = 8,
                    Price = route.DemoFare,
                    Currency = "LKR",
                    Type = "Van"
                });
            }
        }

        return new ImportPlan
        {
            WindowStart = windowStart,
            WindowEnd = windowEnd,
            DestinationsToInsert = destinationInserts,
            HotelsToInsert = hotelInserts,
            RoomsToInsert = roomInserts,
            ToursToInsert = tourInserts,
            TransportToInsert = transportInserts,
            Issues = issues
        };
    }

    public static IReadOnlyList<(string From, string To)> RequiredRoutes()
    {
        return RouteCatalog().Select(route => (route.From, route.To)).ToList();
    }

    public static IReadOnlyList<(string RoomType, int Capacity, int TotalRooms, decimal Price)> RoomPolicy(HotelSeed hotel)
    {
        return hotel.Tier.Trim().ToUpperInvariant() switch
        {
            "BUDGET" =>
            [
                ("Standard Room", 2, 12, 8000m),
                ("Deluxe Room", 2, 8, 11000m),
                ("Family Room", 4, 3, 16000m)
            ],
            "PREMIUM" =>
            [
                ("Standard Room", 2, 8, 25000m),
                ("Deluxe Room", 2, 5, 40000m),
                ("Suite", 4, 2, 65000m)
            ],
            _ =>
            [
                ("Standard Room", 2, 10, 14000m),
                ("Deluxe Room", 2, 6, 22000m),
                ("Family Room", 4, 3, 35000m)
            ]
        };
    }

    private static IEnumerable<PlannedRoom> BuildRooms(HotelSeed hotel)
    {
        return RoomPolicy(hotel).Select(room => new PlannedRoom
        {
            Hotel = hotel.Name,
            RoomType = room.RoomType,
            Capacity = room.Capacity,
            TotalRooms = room.TotalRooms,
            PricePerNight = room.Price,
            Currency = "LKR",
            RateNotes = DemoRateNote
        });
    }

    private static bool CoordinatesAreValid(double? latitude, double? longitude)
    {
        return latitude is >= -90 and <= 90 && longitude is >= -180 and <= 180 &&
               !(latitude == 0 && longitude == 0);
    }

    private static IReadOnlyList<RouteSpec> RouteCatalog()
    {
        var routes = new List<RouteSpec>();

        AddBoth(routes, "Colombo", "Kandy", 180, 6500m, true);
        AddBoth(routes, "Kandy", "Ella", 240, 8000m, true);
        AddBoth(routes, "Colombo", "Galle", 150, 5500m, true);
        AddBoth(routes, "Galle", "Mirissa", 75, 3500m, true);
        AddBoth(routes, "Colombo", "Anuradhapura", 270, 7500m, true);
        AddBoth(routes, "Anuradhapura", "Sigiriya", 120, 4500m, true);
        AddBoth(routes, "Colombo", "Trincomalee", 360, 9500m, true);
        AddBoth(routes, "Trincomalee", "Batticaloa", 150, 5500m, true);
        AddBoth(routes, "Colombo", "Jaffna", 390, 11000m, true);
        AddBoth(routes, "Jaffna", "Anuradhapura", 300, 8500m, true);

        AddBoth(routes, "Kandy", "Nuwara Eliya", 150, 5000m, false);
        AddBoth(routes, "Kandy", "Sigiriya", 150, 5000m, false);
        AddBoth(routes, "Kandy", "Dambulla", 120, 4500m, false);
        AddBoth(routes, "Ella", "Nuwara Eliya", 150, 5000m, false);
        AddBoth(routes, "Ella", "Yala", 210, 7000m, false);
        AddBoth(routes, "Galle", "Bentota", 90, 3500m, false);
        AddBoth(routes, "Galle", "Hikkaduwa", 45, 3000m, false);
        AddBoth(routes, "Batticaloa", "Arugam Bay", 150, 6000m, false);
        AddBoth(routes, "Anuradhapura", "Polonnaruwa", 120, 4500m, false);
        AddBoth(routes, "Dambulla", "Polonnaruwa", 120, 4500m, false);

        // Explicit coverage for the previously failing multi-destination path.
        AddBoth(routes, "Batticaloa", "Colombo", 420, 11000m, true);
        AddBoth(routes, "Colombo", "Ella", 330, 9500m, true);

        return routes;
    }

    private static void AddBoth(
        ICollection<RouteSpec> routes,
        string from,
        string to,
        int durationMinutes,
        decimal fare,
        bool core)
    {
        var weekdays = core
            ? new[] { DayOfWeek.Tuesday, DayOfWeek.Thursday, DayOfWeek.Saturday }
            : new[] { DayOfWeek.Friday };
        var departure = core ? new TimeSpan(6, 30, 0) : new TimeSpan(7, 0, 0);

        routes.Add(new RouteSpec(from, to, durationMinutes, fare, weekdays, departure));
        routes.Add(new RouteSpec(to, from, durationMinutes, fare, weekdays, departure));
    }

    private sealed record RouteSpec(
        string From,
        string To,
        int DurationMinutes,
        decimal DemoFare,
        IReadOnlyCollection<DayOfWeek> Weekdays,
        TimeSpan DepartureTime);
}
