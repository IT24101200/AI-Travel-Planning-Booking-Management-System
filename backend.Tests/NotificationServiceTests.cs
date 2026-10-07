using backend.Data;
using backend.DTOs;
using backend.Models;
using backend.Models.Enums;
using backend.Services;
using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;

namespace backend.Tests;

public class NotificationServiceTests
{
    private static AppDbContext CreateContext()
    {
        var options = new DbContextOptionsBuilder<AppDbContext>()
            .UseInMemoryDatabase(Guid.NewGuid().ToString())
            .Options;

        return new AppDbContext(options);
    }

    private static Customer Customer(string id, string name = "Test Customer") => new()
    {
        Id = id,
        FullName = name,
        Role = "Customer",
        JoinedAt = DateTime.UtcNow,
        LastActiveAt = DateTime.UtcNow
    };

    private static Notification Notification(
        string customerId,
        NotificationStatus status = NotificationStatus.Sent,
        DateTime? sentAt = null) => new()
    {
        Id = Guid.NewGuid(),
        CustomerId = customerId,
        Channel = NotificationChannel.InApp,
        MessageType = MessageType.SystemAlert,
        Content = "Controlled notification test data.",
        Status = status,
        SentAt = sentAt ?? DateTime.UtcNow
    };

    [Fact]
    public async Task GetByCustomerIdAsync_ReturnsOnlyTheRequestedCustomersNotifications()
    {
        await using var context = CreateContext();
        context.Customers.AddRange(Customer("customer-a", "Customer A"), Customer("customer-b", "Customer B"));
        var owned = Notification("customer-a");
        var other = Notification("customer-b");
        context.Notifications.AddRange(owned, other);
        await context.SaveChangesAsync();

        var result = await new NotificationService(context)
            .GetByCustomerIdAsync("customer-a", null, null, null, 1, 20);

        var item = Assert.Single(result);
        Assert.Equal(owned.Id, item.Id);
        Assert.Equal("customer-a", item.CustomerId);
        Assert.DoesNotContain(result, notification => notification.Id == other.Id);
    }

    [Fact]
    public async Task MarkAsReadAsync_IsOwnershipScoped_AndIsIdempotent()
    {
        await using var context = CreateContext();
        context.Customers.AddRange(Customer("customer-a"), Customer("customer-b"));
        var owned = Notification("customer-a");
        var other = Notification("customer-b");
        context.Notifications.AddRange(owned, other);
        await context.SaveChangesAsync();

        var service = new NotificationService(context);
        Assert.Null(await service.MarkAsReadAsync(other.Id, "customer-a"));

        var first = await service.MarkAsReadAsync(owned.Id, "customer-a");
        var second = await service.MarkAsReadAsync(owned.Id, "customer-a");

        Assert.Equal("Read", first?.Status);
        Assert.Equal("Read", second?.Status);
        Assert.NotNull(second?.ReadAt);
        Assert.Equal(NotificationStatus.Sent, (await context.Notifications.FindAsync(other.Id))?.Status);
    }

    [Fact]
    public async Task MarkAllAsReadAsync_ChangesOnlyTheCurrentCustomersUnreadRecords()
    {
        await using var context = CreateContext();
        context.Customers.AddRange(Customer("customer-a"), Customer("customer-b"));
        var first = Notification("customer-a");
        var second = Notification("customer-a", NotificationStatus.Pending);
        var alreadyRead = Notification("customer-a", NotificationStatus.Read);
        alreadyRead.ReadAt = DateTime.UtcNow.AddMinutes(-1);
        var otherCustomer = Notification("customer-b");
        context.Notifications.AddRange(first, second, alreadyRead, otherCustomer);
        await context.SaveChangesAsync();

        var count = await new NotificationService(context).MarkAllAsReadAsync("customer-a");

        Assert.Equal(2, count);
        Assert.All(
            await context.Notifications.Where(n => n.CustomerId == "customer-a").ToListAsync(),
            notification => Assert.Equal(NotificationStatus.Read, notification.Status));
        Assert.Equal(NotificationStatus.Sent, (await context.Notifications.FindAsync(otherCustomer.Id))?.Status);
        Assert.Equal(0, await context.Notifications.CountAsync(n => n.CustomerId == "customer-a" && n.Status != NotificationStatus.Read));
    }

    [Fact]
    public async Task SendNotificationAsync_PersistsExactlyOneNotificationForTheSelectedCustomer()
    {
        await using var context = CreateContext();
        context.Customers.Add(Customer("customer-a", "Customer A"));
        context.Users.Add(new IdentityUser { Id = "customer-a", UserName = "a@example.test", Email = "a@example.test" });
        await context.SaveChangesAsync();

        var result = await new NotificationService(context).SendNotificationAsync(new SendNotificationDto
        {
            CustomerId = "customer-a",
            Channel = "InApp",
            MessageType = "BookingConfirmation",
            Content = "Controlled send test."
        });

        Assert.Equal("customer-a", result.CustomerId);
        Assert.Equal("InApp", result.Channel);
        Assert.Equal("BookingConfirmation", result.MessageType);
        Assert.Equal("Sent", result.Status);
        Assert.Equal("Controlled send test.", result.Content);
        Assert.Equal(1, await context.Notifications.CountAsync());
    }

    [Fact]
    public async Task ResendFailedAsync_IsOwnershipScoped_AndRequeuesTheExistingRecord()
    {
        await using var context = CreateContext();
        context.Customers.AddRange(Customer("customer-a"), Customer("customer-b"));
        var failed = Notification("customer-a", NotificationStatus.Failed, DateTime.UtcNow.AddHours(-1));
        var other = Notification("customer-b", NotificationStatus.Failed);
        context.Notifications.AddRange(failed, other);
        await context.SaveChangesAsync();

        var before = failed.SentAt;
        var service = new NotificationService(context);
        Assert.Null(await service.ResendFailedAsync(other.Id, "customer-a"));

        var result = await service.ResendFailedAsync(failed.Id, "customer-a");

        Assert.Equal(failed.Id, result?.Id);
        Assert.Equal("Sent", result?.Status);
        Assert.True(result?.SentAt > before);
        Assert.Equal(NotificationStatus.Failed, (await context.Notifications.FindAsync(other.Id))?.Status);
    }
}
