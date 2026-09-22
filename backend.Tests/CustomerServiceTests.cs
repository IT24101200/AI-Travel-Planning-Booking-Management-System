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
    }
}
