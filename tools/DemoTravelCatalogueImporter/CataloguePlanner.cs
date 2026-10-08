namespace DemoTravelCatalogueImporter;

public static class CataloguePlanner
{
    private const string DemoProvider = "Demo Private Transfer";
    public const int TransportScheduleHorizonDays = 60;
    private const double RoadDistanceFactor = 1.30d;
    private const double AverageRoadSpeedKmh = 45d;
    private const decimal DemoTransferBaseFare = 2500m;
    private const decimal DemoTransferFarePerRoadKm = 35m;
    private const decimal DemoTransferFareIncrement = 500m;
    private static readonly TimeSpan DemoDepartureTime = new(7, 0, 0);
    private static readonly DayOfWeek[] DailySchedule = Enum.GetValues<DayOfWeek>();
    private const string DemoRateNote =
        "Demo catalogue rate - not live booking price; confirm dates, taxes, meal plan, and availability with the property.";

    // Test fixtures and older local snapshots may not carry destination
    // coordinates. These are the same verified point coordinates used by the
    // current demo destination catalogue; live snapshots take precedence.
    private static readonly IReadOnlyDictionary<string, (double Latitude, double Longitude)> VerifiedCoordinateFallbacks =
        new Dictionary<string, (double Latitude, double Longitude)>(StringComparer.OrdinalIgnoreCase)
        {
            ["ELLA"] = (6.8667, 81.0466),
            ["GALLE"] = (6.0329, 80.2168),
            ["MIRISSA"] = (5.9483, 80.4716),
            ["YALA"] = (6.3728, 81.5185),
            ["KANDY"] = (7.2906, 80.6337),
            ["NUWARA ELIYA"] = (6.9497, 80.7891),
            ["SIGIRIYA"] = (7.9570, 80.7603),
            ["ANURADHAPURA"] = (8.3114, 80.4037),
            ["TRINCOMALEE"] = (8.5874, 81.2152),
            ["JAFFNA"] = (9.6615, 80.0255),
            ["BATTICALOA"] = (7.7310, 81.6747),
            ["COLOMBO"] = (6.9271, 79.8612),
            ["NEGOMBO"] = (7.2083, 79.8358),
            ["BENTOTA"] = (6.4215, 79.9979),
            ["DAMBULLA"] = (7.8742, 80.6511),
            ["POLONNARUWA"] = (7.9395, 81.0003),
            ["ARUGAM BAY"] = (6.8468506, 81.8306961),
            ["HIKKADUWA"] = (6.1407, 80.1012)
        };
    private static readonly IReadOnlyDictionary<string, string> VerifiedCoordinateFallbackNames =
        new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase)
        {
            ["ELLA"] = "Ella",
            ["GALLE"] = "Galle",
            ["MIRISSA"] = "Mirissa",
            ["YALA"] = "Yala",
            ["KANDY"] = "Kandy",
            ["NUWARA ELIYA"] = "Nuwara Eliya",
            ["SIGIRIYA"] = "Sigiriya",
            ["ANURADHAPURA"] = "Anuradhapura",
            ["TRINCOMALEE"] = "Trincomalee",
            ["JAFFNA"] = "Jaffna",
            ["BATTICALOA"] = "Batticaloa",
            ["COLOMBO"] = "Colombo",
            ["NEGOMBO"] = "Negombo",
            ["BENTOTA"] = "Bentota",
            ["DAMBULLA"] = "Dambulla",
            ["POLONNARUWA"] = "Polonnaruwa",
            ["ARUGAM BAY"] = "Arugam Bay",
            ["HIKKADUWA"] = "Hikkaduwa"
        };

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

        var selectableDestinations = BuildSelectableDestinations(snapshot.Destinations, destinationInserts);

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
        var routePairs = RouteCatalog(selectableDestinations);
        var windowStart = businessToday.AddDays(1);
        var windowEnd = businessToday.AddDays(TransportScheduleHorizonDays);

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
                    Type = "Van",
                    RouteFromLatitude = route.FromLatitude,
                    RouteFromLongitude = route.FromLongitude,
                    RouteToLatitude = route.ToLatitude,
                    RouteToLongitude = route.ToLongitude
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
        var destinations = VerifiedCoordinateFallbacks
            .OrderBy(pair => pair.Key, StringComparer.OrdinalIgnoreCase)
            .Select(pair => new SelectableDestination(
                VerifiedCoordinateFallbackNames[pair.Key],
                pair.Value.Latitude,
                pair.Value.Longitude));
        return RouteCatalog(destinations).Select(route => (route.From, route.To)).ToList();
    }

    public static IReadOnlyList<(string From, string To)> RequiredRoutes(
        CatalogueSnapshot snapshot,
        IEnumerable<DestinationSeed>? plannedDestinations = null)
    {
        var destinations = BuildSelectableDestinations(snapshot.Destinations, plannedDestinations ?? []);
        return RouteCatalog(destinations).Select(route => (route.From, route.To)).ToList();
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

    private static IReadOnlyList<SelectableDestination> BuildSelectableDestinations(
        IEnumerable<ExistingDestination> existingDestinations,
        IEnumerable<DestinationSeed> plannedDestinations)
    {
        var result = new Dictionary<string, SelectableDestination>(StringComparer.OrdinalIgnoreCase);
        foreach (var destination in existingDestinations)
        {
            if (TryResolveCoordinates(destination.NormalizedName, destination.Latitude, destination.Longitude, out var coordinates))
            {
                result[Normalizers.Name(destination.Name)] = new SelectableDestination(
                    destination.Name,
                    coordinates.Latitude,
                    coordinates.Longitude);
            }
        }

        foreach (var destination in plannedDestinations)
        {
            if (destination.Verified && CoordinatesAreValid(destination.Latitude, destination.Longitude))
            {
                result[Normalizers.Name(destination.Name)] = new SelectableDestination(
                    destination.Name,
                    destination.Latitude,
                    destination.Longitude);
            }
        }

        return result.Values
            .OrderBy(destination => destination.Name, StringComparer.OrdinalIgnoreCase)
            .ToList();
    }

    private static IReadOnlyList<RouteSpec> RouteCatalog(IEnumerable<SelectableDestination> destinations)
    {
        var ordered = destinations
            .GroupBy(destination => Normalizers.Name(destination.Name), StringComparer.OrdinalIgnoreCase)
            .Select(group => group.First())
            .OrderBy(destination => destination.Name, StringComparer.OrdinalIgnoreCase)
            .ToList();
        var routes = new List<RouteSpec>(ordered.Count * Math.Max(0, ordered.Count - 1));

        foreach (var from in ordered)
        {
            foreach (var to in ordered)
            {
                if (ReferenceEquals(from, to) ||
                    string.Equals(Normalizers.Name(from.Name), Normalizers.Name(to.Name), StringComparison.OrdinalIgnoreCase))
                {
                    continue;
                }

                var straightLineKm = HaversineKilometres(
                    from.Latitude,
                    from.Longitude,
                    to.Latitude,
                    to.Longitude);
                var roadDistanceKm = straightLineKm * RoadDistanceFactor;
                var durationMinutes = RoundUpToThirtyMinutes(roadDistanceKm / AverageRoadSpeedKmh * 60d);
                var fare = RoundUpToIncrement(
                    DemoTransferBaseFare + (decimal)roadDistanceKm * DemoTransferFarePerRoadKm,
                    DemoTransferFareIncrement);

                routes.Add(new RouteSpec(
                    from.Name,
                    to.Name,
                    durationMinutes,
                    fare,
                    DailySchedule,
                    DemoDepartureTime,
                    from.Latitude,
                    from.Longitude,
                    to.Latitude,
                    to.Longitude));
            }
        }

        return routes;
    }

    private sealed record RouteSpec(
        string From,
        string To,
        int DurationMinutes,
        decimal DemoFare,
        IReadOnlyCollection<DayOfWeek> Weekdays,
        TimeSpan DepartureTime,
        double FromLatitude,
        double FromLongitude,
        double ToLatitude,
        double ToLongitude);

    private static bool TryResolveCoordinates(
        string normalizedName,
        double? latitude,
        double? longitude,
        out (double Latitude, double Longitude) coordinates)
    {
        if (CoordinatesAreValid(latitude, longitude))
        {
            coordinates = (latitude!.Value, longitude!.Value);
            return true;
        }

        return VerifiedCoordinateFallbacks.TryGetValue(normalizedName, out coordinates);
    }

    private static double HaversineKilometres(double latitude1, double longitude1, double latitude2, double longitude2)
    {
        const double earthRadiusKilometres = 6371d;
        var latitudeDelta = DegreesToRadians(latitude2 - latitude1);
        var longitudeDelta = DegreesToRadians(longitude2 - longitude1);
        var a = Math.Pow(Math.Sin(latitudeDelta / 2d), 2d) +
                Math.Cos(DegreesToRadians(latitude1)) *
                Math.Cos(DegreesToRadians(latitude2)) *
                Math.Pow(Math.Sin(longitudeDelta / 2d), 2d);
        return earthRadiusKilometres * 2d * Math.Asin(Math.Sqrt(a));
    }

    private static double DegreesToRadians(double degrees) => degrees * Math.PI / 180d;

    private static int RoundUpToThirtyMinutes(double minutes) =>
        Math.Max(60, (int)(Math.Ceiling(minutes / 30d) * 30d));

    private static decimal RoundUpToIncrement(decimal value, decimal increment) =>
        Math.Ceiling(value / increment) * increment;
}
