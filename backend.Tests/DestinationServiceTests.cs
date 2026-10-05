using Microsoft.EntityFrameworkCore;
using backend.Data;
using backend.DTOs;
using backend.Models;
using backend.Services;

namespace backend.Tests;

public class DestinationServiceTests
{
    private static AppDbContext CreateContext() => new(
        new DbContextOptionsBuilder<AppDbContext>()
            .UseInMemoryDatabase(Guid.NewGuid().ToString())
            .Options);

    private static CreateDestinationDto Destination(string name = "Ella") => new()
    {
        Name = name,
        Country = "Sri Lanka",
        Description = "A real destination description.",
        Latitude = 6.8667,
        Longitude = 81.0466
    };

    [Fact]
    public async Task CreateAsync_PersistsAndReturnsDestination()
    {
        using var context = CreateContext();
        var created = await new DestinationService(context).CreateAsync(Destination());

        Assert.Equal("Ella", created.Name);
        Assert.Single(await context.Destinations.ToListAsync());
    }

    [Fact]
    public async Task CreateAsync_RejectsCaseInsensitiveDuplicate()
    {
        using var context = CreateContext();
        var service = new DestinationService(context);
        await service.CreateAsync(Destination("Ella"));

        await Assert.ThrowsAsync<DestinationConflictException>(() => service.CreateAsync(Destination(" ella ")));
    }

    [Fact]
    public async Task CreateAsync_RejectsInvalidCoordinates()
    {
        using var context = CreateContext();
        var dto = Destination();
        dto.Latitude = 91;

        await Assert.ThrowsAsync<ArgumentException>(() => new DestinationService(context).CreateAsync(dto));
    }

    [Fact]
    public async Task GetAllAsync_ReturnsRealDependencyCounts()
    {
        using var context = CreateContext();
        var destination = new Destination { Id = 1, Name = "Ella", Country = "Sri Lanka" };
        context.Destinations.Add(destination);
        context.Tours.Add(new Tour { Id = 1, DestinationId = 1, Destination = destination, Name = "Tour", Category = "Scenic" });
        context.Hotels.Add(new Hotel { Id = 1, DestinationId = 1, Destination = destination, Name = "Hotel" });
        await context.SaveChangesAsync();

        var result = await new DestinationService(context).GetAllAsync();

        Assert.Equal(1, result[0].TourCount);
        Assert.Equal(1, result[0].HotelCount);
    }

    [Fact]
    public async Task DeleteAsync_RejectsReferencedDestination()
    {
        using var context = CreateContext();
        var destination = new Destination { Id = 1, Name = "Ella", Country = "Sri Lanka" };
        context.Destinations.Add(destination);
        context.Tours.Add(new Tour { Id = 1, DestinationId = 1, Destination = destination, Name = "Tour", Category = "Scenic" });
        await context.SaveChangesAsync();

        var error = await Assert.ThrowsAsync<DestinationConflictException>(() => new DestinationService(context).DeleteAsync(1));

        Assert.Contains("referenced", error.Message);
        Assert.NotNull(await context.Destinations.FindAsync(1));
    }
}
