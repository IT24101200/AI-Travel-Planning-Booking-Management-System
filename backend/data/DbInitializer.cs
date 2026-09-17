using backend.Models;
using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;

namespace backend.Data
{
    /// <summary>
    /// Initializes base system roles and initial staff travel agent credentials.
    /// Does NOT seed any demo tours, hotels, fleet, or customer data.
    /// </summary>
    public static class DbInitializer
    {
        public static async Task SeedAsync(IServiceProvider serviceProvider)
        {
            using var scope = serviceProvider.CreateScope();
            var context = scope.ServiceProvider.GetRequiredService<AppDbContext>();
            var userManager = scope.ServiceProvider.GetRequiredService<UserManager<IdentityUser>>();
            var roleManager = scope.ServiceProvider.GetRequiredService<RoleManager<IdentityRole>>();

            // 1. Roles
            string[] roles = ["Customer", "TravelAgent", "Admin"];
            foreach (var role in roles)
            {
                if (!await roleManager.RoleExistsAsync(role))
                {
                    await roleManager.CreateAsync(new IdentityRole(role));
                }
            }

            // 2. Default Staff User (TravelAgent)
            const string staffEmail = "agent@colombo.lk";
            var staffUser = await userManager.FindByEmailAsync(staffEmail);
            if (staffUser == null)
            {
                staffUser = new IdentityUser { UserName = staffEmail, Email = staffEmail, EmailConfirmed = true };
                var res = await userManager.CreateAsync(staffUser, "Staff@123");
                if (res.Succeeded)
                {
                    await userManager.AddToRoleAsync(staffUser, "TravelAgent");
                }
            }

            if (staffUser != null)
            {
                // Ensure TravelAgent role in Identity
                if (!await userManager.IsInRoleAsync(staffUser, "TravelAgent"))
                {
                    await userManager.AddToRoleAsync(staffUser, "TravelAgent");
                }

                // Ensure Customer table entry reflects Role = "TravelAgent"
                var cust = await context.Customers.FindAsync(staffUser.Id);
                if (cust == null)
                {
                    context.Customers.Add(new Customer
                    {
                        Id = staffUser.Id,
                        FullName = "Colombo Travel Agent",
                        Phone = "+94 11 234 5678",
                        Role = "TravelAgent",
                        JoinedAt = DateTime.UtcNow,
                        LastActiveAt = DateTime.UtcNow
                    });
                }
                else
                {
                    cust.Role = "TravelAgent";
                    cust.FullName = "Colombo Travel Agent";
                }

                // Ensure TravelAgents table entry
                if (!await context.TravelAgents.AnyAsync(ta => ta.Id == staffUser.Id))
                {
                    context.TravelAgents.Add(new TravelAgent
                    {
                        Id = staffUser.Id,
                        FullName = "Colombo Travel Agent",
                        Department = "Operations"
                    });
                }

                await context.SaveChangesAsync();
            }
        }
    }
}
