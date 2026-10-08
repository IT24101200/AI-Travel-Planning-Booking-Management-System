namespace backend.Tests;

using DemoTravelCatalogueImporter;

public sealed class DemoTravelCatalogueImporterTests
{
    [Theory]
    [InlineData("UNKNOWN", "false", false)]
    [InlineData("UNKNOWN", "true", false)]
    [InlineData("DEMO", "false", false)]
    [InlineData("DEMO", "true", true)]
    [InlineData("DEVELOPMENT", "true", true)]
    [InlineData("TEST", "true", true)]
    [InlineData("PRODUCTION", "true", false)]
    [InlineData("SHARED", "true", false)]
    public void Environment_gate_requires_allowed_classification_and_explicit_write_approval(
        string environment,
        string writeEnabled,
        bool expectedApproval)
    {
        var target = DescribeTarget(
            ("DEMO_CATALOGUE_ENVIRONMENT", environment),
            ("DEMO_CATALOGUE_WRITE_ENABLED", writeEnabled));

        Assert.Equal(expectedApproval, target.WriteApproved);
        Assert.Equal(environment is "DEMO" or "DEVELOPMENT" or "TEST", target.EnvironmentAllowed);
    }

    [Fact]
    public void Environment_gate_blocks_conflicting_production_signal()
    {
        var target = DescribeTarget(
            ("DEMO_CATALOGUE_ENVIRONMENT", "DEMO"),
            ("ASPNETCORE_ENVIRONMENT", "Production"),
            ("DEMO_CATALOGUE_WRITE_ENABLED", "true"));

        Assert.True(target.ProductionConflict);
        Assert.Equal("PRODUCTION/SHARED", target.EnvironmentClassification);
        Assert.False(target.WriteApproved);
    }

    [Fact]
    public void Environment_gate_blocks_missing_configuration()
    {
        var target = DescribeTarget();

        Assert.Equal("UNKNOWN", target.EnvironmentClassification);
        Assert.False(target.EnvironmentAllowed);
        Assert.False(target.WriteApprovalEnabled);
        Assert.False(target.WriteApproved);
    }

    private static DatabaseTargetInfo DescribeTarget(params (string Key, string Value)[] entries)
    {
        var environment = new EnvironmentValues
        {
            ConnectionSource = "test",
            Values = entries.ToDictionary(
                entry => entry.Key,
                entry => entry.Value,
                StringComparer.OrdinalIgnoreCase)
        };

        return EnvironmentLoader.Describe(
            environment,
            "Host=localhost;Port=5432;Database=test;Username=test;SSL Mode=Require");
    }

    [Fact]
    public void Planner_does_not_mutate_the_read_only_snapshot()
    {
        var snapshot = new CatalogueSnapshot
        {
            Destinations =
            [
                new ExistingDestination(1, "Colombo", "COLOMBO")
            ],
            Hotels = [],
            Rooms = [],
            Tours = [],
            TransportOptions = []
        };
        var document = new CatalogueDocument
        {
            Destinations =
            [
                new DestinationSeed
                {
                    Name = "Negombo",
                    Country = "Sri Lanka",
                    Latitude = 7.2083,
                    Longitude = 79.8358,
                    Verified = true
                }
            ]
        };

        var plan = CataloguePlanner.Build(snapshot, document, new DateOnly(2026, 10, 8));

        Assert.Single(plan.DestinationsToInsert);
        Assert.Single(snapshot.Destinations);
        Assert.Empty(snapshot.Hotels);
    }

    [Fact]
    public void Planner_skips_normalized_duplicate_hotels_and_rooms_are_deterministic()
    {
        var snapshot = new CatalogueSnapshot
        {
            Destinations =
            [
                new ExistingDestination(1, "Colombo", "COLOMBO")
            ],
            Hotels =
            [
                new ExistingHotel(10, 1, "Cinnamon Grand Colombo", "Active")
            ],
            Rooms = [],
            Tours = [],
            TransportOptions = []
        };
        var document = new CatalogueDocument
        {
            Hotels =
            [
                new HotelSeed
                {
                    Name = " cinnamon   grand colombo ",
                    Destination = "Colombo",
                    Tier = "Budget",
                    IdentityVerified = true,
                    CoordinatesVerified = true,
                    Latitude = 6.9271,
                    Longitude = 79.8612
                },
                new HotelSeed
                {
                    Name = "New Demo Hotel",
                    Destination = "Colombo",
                    Tier = "Premium",
                    IdentityVerified = true,
                    CoordinatesVerified = true,
                    Latitude = 6.93,
                    Longitude = 79.86
                }
            ]
        };

        var plan = CataloguePlanner.Build(snapshot, document, new DateOnly(2026, 10, 8));

        Assert.Single(plan.HotelsToInsert);
        Assert.Equal(3, plan.RoomsToInsert.Count);
        Assert.Contains(plan.Issues, issue => issue.Code == "SKIP_EXISTING");
        Assert.Equal(new[] { 8, 5, 2 }, plan.RoomsToInsert.Select(room => room.TotalRooms));
        Assert.Equal(new[] { 25000m, 40000m, 65000m }, plan.RoomsToInsert.Select(room => room.PricePerNight));
    }

    [Fact]
    public void Planner_generates_bidirectional_local_schedules_inside_the_sixty_day_window()
    {
        var snapshot = new CatalogueSnapshot
        {
            Destinations =
            [
                new ExistingDestination(1, "Colombo", "COLOMBO"),
                new ExistingDestination(2, "Ella", "ELLA"),
                new ExistingDestination(3, "Batticaloa", "BATTICALOA")
            ],
            Hotels = [],
            Rooms = [],
            Tours = [],
            TransportOptions = []
        };

        var plan = CataloguePlanner.Build(snapshot, new CatalogueDocument(), new DateOnly(2026, 10, 8));

        var relevant = plan.TransportToInsert.Where(t =>
            (t.RouteFrom == "Colombo" && t.RouteTo == "Ella") ||
            (t.RouteFrom == "Ella" && t.RouteTo == "Colombo") ||
            (t.RouteFrom == "Batticaloa" && t.RouteTo == "Colombo") ||
            (t.RouteFrom == "Colombo" && t.RouteTo == "Batticaloa")).ToList();

        Assert.NotEmpty(relevant);
        Assert.Contains(relevant, option => option.RouteFrom == "Colombo" && option.RouteTo == "Ella");
        Assert.Contains(relevant, option => option.RouteFrom == "Ella" && option.RouteTo == "Colombo");
        Assert.Contains(relevant, option => option.RouteFrom == "Batticaloa" && option.RouteTo == "Colombo");
        Assert.Contains(relevant, option => option.RouteFrom == "Colombo" && option.RouteTo == "Batticaloa");
        Assert.All(relevant, option =>
        {
            Assert.Equal(DateTimeKind.Unspecified, option.DepartureTime.Kind);
            Assert.True(option.ArrivalTime > option.DepartureTime);
            Assert.InRange(DateOnly.FromDateTime(option.DepartureTime), new DateOnly(2026, 10, 9), new DateOnly(2026, 12, 7));
        });
    }

    [Fact]
    public void Planner_generates_both_directions_for_the_bentota_multi_leg_demo_route()
    {
        var snapshot = new CatalogueSnapshot
        {
            Destinations =
            [
                new ExistingDestination(51, "Colombo", "COLOMBO"),
                new ExistingDestination(53, "Bentota", "BENTOTA"),
                new ExistingDestination(56, "Arugam Bay", "ARUGAM BAY")
            ],
            Hotels = [],
            Rooms = [],
            Tours = [],
            TransportOptions = []
        };

        var plan = CataloguePlanner.Build(snapshot, new CatalogueDocument(), new DateOnly(2026, 10, 9));

        var relevant = plan.TransportToInsert.Where(option =>
            (option.RouteFrom == "Colombo" && option.RouteTo == "Bentota") ||
            (option.RouteFrom == "Bentota" && option.RouteTo == "Colombo") ||
            (option.RouteFrom == "Bentota" && option.RouteTo == "Arugam Bay") ||
            (option.RouteFrom == "Arugam Bay" && option.RouteTo == "Bentota")).ToList();

        Assert.Contains(relevant, option => option.RouteFrom == "Colombo" && option.RouteTo == "Bentota");
        Assert.Contains(relevant, option => option.RouteFrom == "Bentota" && option.RouteTo == "Colombo");
        Assert.Contains(relevant, option => option.RouteFrom == "Bentota" && option.RouteTo == "Arugam Bay");
        Assert.Contains(relevant, option => option.RouteFrom == "Arugam Bay" && option.RouteTo == "Bentota");
        Assert.All(relevant, option =>
        {
            Assert.Equal("Demo Private Transfer", option.Provider);
            Assert.Equal("LKR", option.Currency);
            Assert.Equal(DateTimeKind.Unspecified, option.DepartureTime.Kind);
            Assert.True(option.ArrivalTime > option.DepartureTime);
            Assert.InRange(DateOnly.FromDateTime(option.DepartureTime), new DateOnly(2026, 10, 10), new DateOnly(2026, 12, 8));
        });
    }

    [Fact]
    public void Planner_generates_one_daily_departure_for_every_ordered_destination_pair()
    {
        var snapshot = new CatalogueSnapshot
        {
            Destinations =
            [
                new ExistingDestination(1, "Colombo", "COLOMBO", 6.9271, 79.8612),
                new ExistingDestination(2, "Bentota", "BENTOTA", 6.4215, 79.9979),
                new ExistingDestination(3, "Ella", "ELLA", 6.8667, 81.0466),
                new ExistingDestination(4, "Jaffna", "JAFFNA", 9.6615, 80.0255)
            ],
            Hotels = [],
            Rooms = [],
            Tours = [],
            TransportOptions = []
        };

        var plan = CataloguePlanner.Build(snapshot, new CatalogueDocument(), new DateOnly(2026, 10, 8));
        var expectedRoutes = snapshot.Destinations.Count * (snapshot.Destinations.Count - 1);
        var expectedDepartures = expectedRoutes * CataloguePlanner.TransportScheduleHorizonDays;

        Assert.Equal(expectedDepartures, plan.TransportToInsert.Count);
        Assert.Equal(expectedRoutes, plan.TransportToInsert
            .Select(option => (option.RouteFrom, option.RouteTo))
            .Distinct()
            .Count());
        Assert.DoesNotContain(plan.TransportToInsert, option => option.RouteFrom == option.RouteTo);
        Assert.All(plan.TransportToInsert.GroupBy(option => (option.RouteFrom, option.RouteTo)), group =>
        {
            Assert.Equal(CataloguePlanner.TransportScheduleHorizonDays, group.Count());
            Assert.Equal(7, group.Select(option => DateOnly.FromDateTime(option.DepartureTime).DayOfWeek).Distinct().Count());
            Assert.All(group, option =>
            {
                Assert.Equal(new TimeSpan(7, 0, 0), option.DepartureTime.TimeOfDay);
                Assert.True(option.ArrivalTime > option.DepartureTime);
                Assert.True(option.Price >= 2500m);
                Assert.Equal(8, option.Capacity);
                Assert.Equal("LKR", option.Currency);
            });
        });
    }

    [Fact]
    public void Planner_blocks_unverified_destination_and_hotel_coordinates()
    {
        var snapshot = new CatalogueSnapshot();
        var document = new CatalogueDocument
        {
            Destinations =
            [
                new DestinationSeed
                {
                    Name = "Arugam Bay",
                    Latitude = 6.84,
                    Longitude = 81.84,
                    Verified = false,
                    VerificationNote = "point review pending"
                }
            ],
            Hotels =
            [
                new HotelSeed
                {
                    Name = "Candidate Hotel",
                    Destination = "Arugam Bay",
                    IdentityVerified = true,
                    CoordinatesVerified = false
                }
            ]
        };

        var plan = CataloguePlanner.Build(snapshot, document, new DateOnly(2026, 10, 8));

        Assert.Empty(plan.DestinationsToInsert);
        Assert.Empty(plan.HotelsToInsert);
        Assert.Contains(plan.Issues, issue => issue.Code == "DESTINATION_VERIFICATION_PENDING");
        Assert.Contains(plan.Issues, issue => issue.Code == "DESTINATION_NOT_IMPORTABLE");
    }
}
