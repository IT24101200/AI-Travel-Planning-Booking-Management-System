using backend.Data;
using backend.Models;
using backend.Models.Enums;
using Microsoft.EntityFrameworkCore;

namespace DemoTravelCatalogueImporter;

public sealed record ApplyResult(
    int DestinationsInserted,
    int HotelsInserted,
    int RoomsInserted,
    int ToursInserted,
    int TransportInserted,
    int FailedBatches,
    IReadOnlyList<string> Failures);

public static class ImportExecutor
{
    public static async Task<ApplyResult> ApplyAsync(
        AppDbContext db,
        ImportPlan plan,
        CancellationToken cancellationToken)
    {
        var destinationsInserted = 0;
        var hotelsInserted = 0;
        var roomsInserted = 0;
        var toursInserted = 0;
        var transportInserted = 0;
        var failures = new List<string>();

        var destinationKeys = plan.DestinationsToInsert
            .Select(d => d.Name)
            .Concat(plan.HotelsToInsert.Select(h => h.Destination))
            .Concat(plan.ToursToInsert.Select(t => t.Destination))
            .Distinct(StringComparer.OrdinalIgnoreCase)
            .ToList();

        foreach (var destinationName in destinationKeys)
        {
            var destinationBatchInserted = 0;
            var hotelBatchInserted = 0;
            var roomBatchInserted = 0;
            var tourBatchInserted = 0;
            await using var transaction = await db.Database.BeginTransactionAsync(cancellationToken);
            try
            {
                var destination = await db.Destinations
                    .FirstOrDefaultAsync(d => d.Name.ToUpper() == destinationName.Trim().ToUpper(), cancellationToken);

                if (destination is null)
                {
                    var seed = plan.DestinationsToInsert.FirstOrDefault(d =>
                        Normalizers.Name(d.Name) == Normalizers.Name(destinationName));
                    if (seed is null)
                    {
                        throw new InvalidOperationException($"Destination '{destinationName}' was not available during apply.");
                    }

                    destination = new Destination
                    {
                        Name = seed.Name,
                        NormalizedName = Normalizers.Name(seed.Name),
                        Country = seed.Country,
                        Description = seed.Description,
                        Latitude = seed.Latitude,
                        Longitude = seed.Longitude
                    };
                    db.Destinations.Add(destination);
                    await db.SaveChangesAsync(cancellationToken);
                    destinationBatchInserted++;
                }

                var hotelsForDestination = plan.HotelsToInsert
                    .Where(h => Normalizers.Name(h.Destination) == Normalizers.Name(destinationName))
                    .ToList();
                foreach (var hotelSeed in hotelsForDestination)
                {
                    var hotel = await db.Hotels.FirstOrDefaultAsync(
                        h => h.DestinationId == destination.Id && h.Name.ToUpper() == hotelSeed.Name.Trim().ToUpper(),
                        cancellationToken);
                    if (hotel is not null)
                    {
                        continue;
                    }

                    if (hotelSeed.Latitude is null || hotelSeed.Longitude is null)
                    {
                        throw new InvalidOperationException($"Hotel '{hotelSeed.Name}' reached apply without verified coordinates.");
                    }

                    hotel = new Hotel
                    {
                        DestinationId = destination.Id,
                        Name = hotelSeed.Name.Trim(),
                        Address = hotelSeed.Address,
                        ContactPhone = hotelSeed.ContactPhone,
                        ContactEmail = hotelSeed.ContactEmail,
                        Latitude = hotelSeed.Latitude.Value,
                        Longitude = hotelSeed.Longitude.Value,
                        StarRating = Math.Clamp(hotelSeed.StarRating, 0, 5),
                        Status = HotelStatus.Active
                    };
                    db.Hotels.Add(hotel);
                    await db.SaveChangesAsync(cancellationToken);
                    hotelBatchInserted++;

                    foreach (var roomSeed in plan.RoomsToInsert.Where(r =>
                                 Normalizers.Name(r.Hotel) == Normalizers.Name(hotelSeed.Name)))
                    {
                        var duplicateRoom = await db.Rooms.AnyAsync(
                            r => r.HotelId == hotel.Id && r.RoomType.ToUpper() == roomSeed.RoomType.Trim().ToUpper(),
                            cancellationToken);
                        if (duplicateRoom)
                        {
                            continue;
                        }

                        db.Rooms.Add(new Room
                        {
                            HotelId = hotel.Id,
                            RoomType = roomSeed.RoomType,
                            Capacity = roomSeed.Capacity,
                            TotalRooms = roomSeed.TotalRooms,
                            PricePerNight = roomSeed.PricePerNight,
                            Currency = roomSeed.Currency,
                            Status = RoomStatus.Active,
                            RateNotes = roomSeed.RateNotes
                        });
                        roomBatchInserted++;
                    }
                }

                foreach (var tourSeed in plan.ToursToInsert
                             .Where(t => Normalizers.Name(t.Destination) == Normalizers.Name(destinationName)))
                {
                    var duplicateTour = await db.Tours.AnyAsync(
                        t => t.DestinationId == destination.Id && t.Name.ToUpper() == tourSeed.Name.Trim().ToUpper(),
                        cancellationToken);
                    if (duplicateTour)
                    {
                        continue;
                    }

                    db.Tours.Add(new Tour
                    {
                        DestinationId = destination.Id,
                        Name = tourSeed.Name,
                        Category = tourSeed.Category,
                        Description = tourSeed.Description,
                        ImageUrl = tourSeed.ImageUrl,
                        Price = tourSeed.Price,
                        Currency = tourSeed.Currency,
                        DurationHours = tourSeed.DurationHours,
                        DefaultStartTime = new TimeSpan(8, 0, 0),
                        Status = "Active",
                        CreatedAt = DateTime.UtcNow,
                        UpdatedAt = DateTime.UtcNow
                    });
                    tourBatchInserted++;
                }

                await db.SaveChangesAsync(cancellationToken);
                await transaction.CommitAsync(cancellationToken);
                destinationsInserted += destinationBatchInserted;
                hotelsInserted += hotelBatchInserted;
                roomsInserted += roomBatchInserted;
                toursInserted += tourBatchInserted;
            }
            catch (Exception ex)
            {
                await transaction.RollbackAsync(cancellationToken);
                db.ChangeTracker.Clear();
                failures.Add($"Destination batch '{destinationName}': {ex.Message}");
            }
        }

        var routeGroups = plan.TransportToInsert
            .GroupBy(t => Normalizers.Route(t.RouteFrom, t.RouteTo), StringComparer.OrdinalIgnoreCase)
            .ToList();

        foreach (var routeGroup in routeGroups)
        {
            var transportBatchInserted = 0;
            await using var transaction = await db.Database.BeginTransactionAsync(cancellationToken);
            try
            {
                foreach (var transportSeed in routeGroup)
                {
                    var duplicate = await db.TransportOptions.AnyAsync(t =>
                        t.Provider.ToUpper() == transportSeed.Provider.ToUpper() &&
                        t.RouteFrom.ToUpper() == transportSeed.RouteFrom.ToUpper() &&
                        t.RouteTo.ToUpper() == transportSeed.RouteTo.ToUpper() &&
                        t.DepartureTime == transportSeed.DepartureTime, cancellationToken);
                    if (duplicate)
                    {
                        continue;
                    }

                    db.TransportOptions.Add(new TransportOption
                    {
                        Type = Enum.Parse<TransportType>(transportSeed.Type, ignoreCase: true),
                        Provider = transportSeed.Provider,
                        RouteFrom = transportSeed.RouteFrom,
                        RouteTo = transportSeed.RouteTo,
                        DepartureTime = DateTime.SpecifyKind(transportSeed.DepartureTime, DateTimeKind.Unspecified),
                        ArrivalTime = DateTime.SpecifyKind(transportSeed.ArrivalTime, DateTimeKind.Unspecified),
                        Capacity = transportSeed.Capacity,
                        Price = transportSeed.Price,
                        Currency = transportSeed.Currency,
                        Status = TransportStatus.Active
                    });
                    transportBatchInserted++;
                }

                await db.SaveChangesAsync(cancellationToken);
                await transaction.CommitAsync(cancellationToken);
                transportInserted += transportBatchInserted;
            }
            catch (Exception ex)
            {
                await transaction.RollbackAsync(cancellationToken);
                db.ChangeTracker.Clear();
                failures.Add($"Transport batch '{routeGroup.Key}': {ex.Message}");
            }
        }

        return new ApplyResult(
            destinationsInserted,
            hotelsInserted,
            roomsInserted,
            toursInserted,
            transportInserted,
            failures.Count,
            failures);
    }
}
