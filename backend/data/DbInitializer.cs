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

            // 2. Default Staff Users (TravelAgent & Admin)
            var staffAccounts = new[]
            {
                (Email: "agent@colombo.lk", Name: "Colombo Travel Agent", Role: "TravelAgent", Phone: "+94 11 234 5678", Dept: "Operations"),
                (Email: "agent@serendibtrails.lk", Name: "Serendib Operations Agent", Role: "TravelAgent", Phone: "+94 11 765 4321", Dept: "Tour Operations"),
                (Email: "admin@serendibtrails.lk", Name: "System Administrator", Role: "Admin", Phone: "+94 11 999 8888", Dept: "Management")
            };

            foreach (var staff in staffAccounts)
            {
                var staffUser = await userManager.FindByEmailAsync(staff.Email);
                if (staffUser == null)
                {
                    staffUser = new IdentityUser { UserName = staff.Email, Email = staff.Email, EmailConfirmed = true };
                    var res = await userManager.CreateAsync(staffUser, "Staff@123");
                    if (res.Succeeded)
                    {
                        await userManager.AddToRoleAsync(staffUser, staff.Role);
                    }
                }

                if (staffUser != null)
                {
                    // Ensure appropriate role in Identity
                    if (!await userManager.IsInRoleAsync(staffUser, staff.Role))
                    {
                        await userManager.AddToRoleAsync(staffUser, staff.Role);
                    }

                    // Ensure Customer table entry reflects Role
                    var cust = await context.Customers.FindAsync(staffUser.Id);
                    if (cust == null)
                    {
                        context.Customers.Add(new Customer
                        {
                            Id = staffUser.Id,
                            FullName = staff.Name,
                            Phone = staff.Phone,
                            Role = staff.Role,
                            JoinedAt = DateTime.UtcNow,
                            LastActiveAt = DateTime.UtcNow
                        });
                    }
                    else
                    {
                        cust.Role = staff.Role;
                        cust.FullName = staff.Name;
                    }

                    // Ensure TravelAgents table entry
                    if (!await context.TravelAgents.AnyAsync(ta => ta.Id == staffUser.Id))
                    {
                        context.TravelAgents.Add(new TravelAgent
                        {
                            Id = staffUser.Id,
                            FullName = staff.Name,
                            Department = staff.Dept
                        });
                    }
                }
            }

            await context.SaveChangesAsync();
        }
    }
}
