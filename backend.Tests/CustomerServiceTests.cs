using backend.Data;
using backend.DTOs;
using backend.Models;
using backend.Services;
using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using Moq;
using Xunit;

namespace backend.Tests
{
    public class CustomerServiceTests
    {
        private static AppDbContext CreateContext()
        {
            var options = new DbContextOptionsBuilder<AppDbContext>()
                .UseInMemoryDatabase(Guid.NewGuid().ToString())
                .Options;

            return new AppDbContext(options);
        }

        private static Mock<UserManager<IdentityUser>> CreateMockUserManager()
        {
            var store = new Mock<IUserStore<IdentityUser>>();
            return new Mock<UserManager<IdentityUser>>(store.Object, null!, null!, null!, null!, null!, null!, null!, null!);
        }

        [Fact]
        public async Task ExistsAsync_ExistingCustomer_ReturnsTrue()
        {
            var context = CreateContext();
            var userManager = CreateMockUserManager();
            var service = new CustomerService(context, userManager.Object);

            context.Customers.Add(new Customer
            {
                Id = "cust-1",
                FullName = "Alice Smith"
            });
            await context.SaveChangesAsync();

            var exists = await service.ExistsAsync("cust-1");
            Assert.True(exists);
        }

        [Fact]
        public async Task ExistsAsync_NonExistingCustomer_ReturnsFalse()
        {
            var context = CreateContext();
            var userManager = CreateMockUserManager();
            var service = new CustomerService(context, userManager.Object);

            var exists = await service.ExistsAsync("non-existent");
            Assert.False(exists);
        }

        [Fact]
        public async Task UpdateAsync_ValidUpdate_UpdatesCustomerDetails()
        {
            var context = CreateContext();
            var userManager = CreateMockUserManager();
            var service = new CustomerService(context, userManager.Object);

            var customer = new Customer
            {
                Id = "cust-1",
                FullName = "Alice Old",
                Phone = "1234567890"
            };
            context.Customers.Add(customer);
            await context.SaveChangesAsync();

            var updateDto = new CustomerUpdateDto
            {
                FullName = "Alice New",
                Phone = "0987654321"
            };

            var updated = await service.UpdateAsync("cust-1", updateDto);

            Assert.NotNull(updated);
            Assert.Equal("Alice New", updated.FullName);
            Assert.Equal("0987654321", updated.Phone);
        }

        [Fact]
        public async Task GetAllAsync_SearchesIdentityEmailWithoutNameOrPhoneMatch()
        {
            var context = CreateContext();
            var userManager = CreateMockUserManager();
            var service = new CustomerService(context, userManager.Object);
            var user = new IdentityUser
            {
                Id = "cust-email",
                Email = "traveller@example.test",
                UserName = "traveller@example.test"
            };
            context.Users.Add(user);
            context.Customers.Add(new Customer
            {
                Id = user.Id,
                FullName = "Directory Person",
                Phone = "0771234567",
                Role = "Customer"
            });
            await context.SaveChangesAsync();

            var result = await service.GetAllAsync("  EXAMPLE.TEST  ", "name", false, 1, 10);

            var match = Assert.Single(result);
            Assert.Equal(user.Id, match.Id);
            Assert.Equal(user.Email, match.Email);
        }

        [Fact]
        public async Task DeleteAsync_DeletesCustomerWithoutProtectedHistory()
        {
            var context = CreateContext();
            var userManager = CreateMockUserManager();
            var service = new CustomerService(context, userManager.Object);
            context.Customers.Add(new Customer { Id = "safe-customer", FullName = "Disposable Fixture" });
            await context.SaveChangesAsync();

            var deleted = await service.DeleteAsync("safe-customer");

            Assert.True(deleted);
            Assert.False(await context.Customers.AnyAsync(c => c.Id == "safe-customer"));
        }

        [Fact]
        public async Task DeleteAsync_BlocksCustomerWithTripHistoryBeforeMutation()
        {
            var context = CreateContext();
            var userManager = CreateMockUserManager();
            var service = new CustomerService(context, userManager.Object);
            context.Customers.Add(new Customer { Id = "history-customer", FullName = "Retained History" });
            context.TripRequests.Add(new TripRequest
            {
                CustomerId = "history-customer",
                RawRequestText = "Historical request"
            });
            await context.SaveChangesAsync();

            var error = await Assert.ThrowsAsync<CustomerDeletionConflictException>(() => service.DeleteAsync("history-customer"));

            Assert.Contains("history", error.Message, StringComparison.OrdinalIgnoreCase);
            Assert.Equal(1, error.Details["tripRequests"]);
            Assert.True(await context.Customers.AnyAsync(c => c.Id == "history-customer"));
        }

        [Fact]
        public async Task DeleteAsync_BlocksTheLastAdministrator()
        {
            var context = CreateContext();
            var userManager = CreateMockUserManager();
            userManager.Setup(manager => manager.GetUsersInRoleAsync("Admin"))
                .ReturnsAsync(new List<IdentityUser> { new() { Id = "only-admin" } });
            var service = new CustomerService(context, userManager.Object);
            context.Customers.Add(new Customer { Id = "only-admin", FullName = "Only Admin", Role = "Admin" });
            await context.SaveChangesAsync();

            var error = await Assert.ThrowsAsync<CustomerDeletionConflictException>(() => service.DeleteAsync("only-admin"));

            Assert.Contains("last administrator", error.Message, StringComparison.OrdinalIgnoreCase);
            Assert.True(await context.Customers.AnyAsync(c => c.Id == "only-admin"));
        }
    }
}
