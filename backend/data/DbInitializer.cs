using backend.Models;
using backend.Models.Enums;
using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;

namespace backend.Data
{
    /// <summary>
    /// Seeds comprehensive, realistic sample data for the Serendib Trails platform:
    /// - Roles and Staff accounts (Admin & Travel Agents)
    /// - Diverse Customer profiles with travel preferences
    /// - Sri Lankan Destinations & Sellable Tours
    /// - Boutique Hotels, Room tiers, and Transport options
    /// - AI Trip Requests with Agent reasoning audit logs
    /// - Day-by-day Itineraries and Itinerary Items
    /// - Real Bookings with Approval decisions and Payment transactions
    /// - Multi-channel customer notifications
    /// </summary>
    public static class DbInitializer
    {
        /// <summary>
        /// Fully clears all application and identity tables, then re-seeds fresh default data.
        /// </summary>
        public static async Task ResetAndSeedAsync(IServiceProvider serviceProvider)
        {
            using var scope = serviceProvider.CreateScope();
            var context = scope.ServiceProvider.GetRequiredService<AppDbContext>();

            if (context.Database.ProviderName?.Contains("Npgsql", StringComparison.OrdinalIgnoreCase) == true)
            {
                await context.Database.ExecuteSqlRawAsync(@"
                    TRUNCATE TABLE 
                        ""AgentLogs"",
                        ""AspNetRoleClaims"",
                        ""AspNetRoles"",
                        ""AspNetUserClaims"",
                        ""AspNetUserLogins"",
                        ""AspNetUserRoles"",
                        ""AspNetUserTokens"",
                        ""AspNetUsers"",
                        ""BookingApprovals"",
                        ""BookingItems"",
                        ""Bookings"",
                        ""Customers"",
                        ""Destinations"",
                        ""Hotels"",
                        ""Itineraries"",
                        ""ItineraryItems"",
                        ""Notifications"",
                        ""Payments"",
                        ""Preferences"",
                        ""Rooms"",
                        ""Tours"",
                        ""TransportOptions"",
                        ""TravelAgents"",
                        ""TripRequests""
                    CASCADE;
                ");
            }

            await SeedAsync(serviceProvider);
        }

        public static async Task SeedAsync(IServiceProvider serviceProvider)
        {
            using var scope = serviceProvider.CreateScope();
            var context = scope.ServiceProvider.GetRequiredService<AppDbContext>();
            // SQLite is used only by automated tests. The seed script contains
            // PostgreSQL-specific SQL and production demo data; test fixtures
            // own their data and must start from a clean schema.
            if (context.Database.ProviderName?.Contains("Sqlite", StringComparison.OrdinalIgnoreCase) == true)
                return;

            var userManager = scope.ServiceProvider.GetRequiredService<UserManager<IdentityUser>>();
            var roleManager = scope.ServiceProvider.GetRequiredService<RoleManager<IdentityRole>>();

            // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
            // 0. Ensure Catalog ImageUrl columns exist & seed defaults
            // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
            try
            {
                await context.Database.ExecuteSqlRawAsync(@"
                    ALTER TABLE ""Hotels"" ADD COLUMN IF NOT EXISTS ""ImageUrl"" character varying(500) NULL;
                    ALTER TABLE ""TransportOptions"" ADD COLUMN IF NOT EXISTS ""ImageUrl"" character varying(500) NULL;
                ");
            }
            catch (Exception ex)
            {
                Console.WriteLine($"[DbInitializer] ALTER TABLE notice: {ex.Message}");
            }

            try
            {
                await context.Database.ExecuteSqlRawAsync(@"
                    UPDATE ""Hotels"" SET ""ImageUrl"" = 'https://images.unsplash.com/photo-1566073771259-6a8506099945?auto=format&fit=crop&w=1200&q=80' WHERE ""ImageUrl"" IS NULL AND ""Name"" ILIKE '%Vil Uyana%';
                    UPDATE ""Hotels"" SET ""ImageUrl"" = 'https://images.unsplash.com/photo-1582719478250-c89cae4dc85b?auto=format&fit=crop&w=1200&q=80' WHERE ""ImageUrl"" IS NULL AND ""Name"" ILIKE '%Santani%';
                    UPDATE ""Hotels"" SET ""ImageUrl"" = 'https://images.unsplash.com/photo-1542314831-068cd1dbfeeb?auto=format&fit=crop&w=1200&q=80' WHERE ""ImageUrl"" IS NULL AND ""Name"" ILIKE '%98 Acres%';
                    UPDATE ""Hotels"" SET ""ImageUrl"" = 'https://images.unsplash.com/photo-1571896349842-33c89424de2d?auto=format&fit=crop&w=1200&q=80' WHERE ""ImageUrl"" IS NULL AND ""Name"" ILIKE '%Amangalla%';
                    UPDATE ""Hotels"" SET ""ImageUrl"" = 'https://images.unsplash.com/photo-1520250497591-112f2f40a3f4?auto=format&fit=crop&w=1200&q=80' WHERE ""ImageUrl"" IS NULL AND ""Name"" ILIKE '%Cinnamon Wild%';

                    UPDATE ""TransportOptions"" SET ""ImageUrl"" = 'https://images.unsplash.com/photo-1544620347-c4fd4a3d5957?auto=format&fit=crop&w=1200&q=80' WHERE ""ImageUrl"" IS NULL AND (""Type"" = 'Train' OR ""Type"" = '0');
                    UPDATE ""TransportOptions"" SET ""ImageUrl"" = 'https://images.unsplash.com/photo-1549399542-7e3f8b79c341?auto=format&fit=crop&w=1200&q=80' WHERE ""ImageUrl"" IS NULL AND (""Type"" = 'Car' OR ""Type"" = '2');
                    UPDATE ""TransportOptions"" SET ""ImageUrl"" = 'https://images.unsplash.com/photo-1540959733332-eab4deabeeaf?auto=format&fit=crop&w=1200&q=80' WHERE ""ImageUrl"" IS NULL AND (""Type"" = 'Flight' OR ""Type"" = '1');
                ");
            }
            catch (Exception ex)
            {
                Console.WriteLine($"[DbInitializer] UPDATE ImageUrl notice: {ex.Message}");
            }

            // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
            // 1. Roles
            // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
            string[] roles = ["Customer", "TravelAgent", "Admin"];
            foreach (var role in roles)
            {
                if (!await roleManager.RoleExistsAsync(role))
                {
                    await roleManager.CreateAsync(new IdentityRole(role));
                }
            }

            // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
            // 2. Staff Accounts (Admins & Travel Agents)
            // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
            var staffAccounts = new[]
            {
                (Email: "n.kapoor@serendib.lk", Name: "Nadeesha Kapoor", Role: "Admin", Phone: "+94 11 999 8888", Dept: "Executive Management"),
                (Email: "s.perera@serendib.lk", Name: "Sahan Perera", Role: "TravelAgent", Phone: "+94 77 345 6789", Dept: "Bespoke Tours"),
                (Email: "agent@colombo.lk", Name: "Colombo Travel Agent", Role: "TravelAgent", Phone: "+94 11 234 5678", Dept: "Central Operations"),
                (Email: "agent@serendibtrails.lk", Name: "Serendib Operations Agent", Role: "TravelAgent", Phone: "+94 11 765 4321", Dept: "Tour Operations"),
                (Email: "admin@serendibtrails.lk", Name: "System Administrator", Role: "Admin", Phone: "+94 11 888 7777", Dept: "IT & Systems")
            };

            var staffUsers = new Dictionary<string, IdentityUser>();

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
                    staffUsers[staff.Email] = staffUser;

                    // Ensure role in Identity
                    if (!await userManager.IsInRoleAsync(staffUser, staff.Role))
                    {
                        await userManager.AddToRoleAsync(staffUser, staff.Role);
                    }

                    // Keep Customers table in sync so staff appear in directory
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
                        cust.Phone = staff.Phone;
                        cust.LastActiveAt = DateTime.UtcNow;
                    }

                    // Ensure TravelAgent record exists for travel agents & admins
                    var agentRecord = await context.TravelAgents.FindAsync(staffUser.Id);
                    if (agentRecord == null)
                    {
                        context.TravelAgents.Add(new TravelAgent
                        {
                            Id = staffUser.Id,
                            FullName = staff.Name,
                            Department = staff.Dept
                        });
                    }
                    else
                    {
                        agentRecord.FullName = staff.Name;
                        agentRecord.Department = staff.Dept;
                    }
                }
            }

            await context.SaveChangesAsync();

            // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
            // 3. Realistic Demo Customers with Travel Preferences
            // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
            var demoCustomers = new[]
            {
                (
                    Email: "amelia.t@example.com",
                    Name: "Amelia Thompson",
                    Phone: "+44 7911 234567",
                    BudgetMin: 2500m,
                    BudgetMax: 4500m,
                    Activities: "Heritage, Tea Trails, Cultural Walks",
                    Dietary: "Vegetarian",
                    Accessibility: "Ground floor preferred"
                ),
                (
                    Email: "ravi.mehta@example.in",
                    Name: "Ravi Mehta",
                    Phone: "+91 98200 12345",
                    BudgetMin: 3000m,
                    BudgetMax: 6000m,
                    Activities: "Wildlife, Safari, Photography",
                    Dietary: "Halal",
                    Accessibility: "None"
                ),
                (
                    Email: "hannah.lee@example.com",
                    Name: "Hannah Lee",
                    Phone: "+61 412 345 678",
                    BudgetMin: 1500m,
                    BudgetMax: 3000m,
                    Activities: "Surfing, Snorkeling, Coastal Treks",
                    Dietary: "Pescatarian",
                    Accessibility: "None"
                ),
                (
                    Email: "kavinda.silva@gmail.com",
                    Name: "Kavinda Silva",
                    Phone: "+94 77 123 4567",
                    BudgetMin: 1000m,
                    BudgetMax: 2500m,
                    Activities: "Hiking, Camping, Scenic Rail",
                    Dietary: "No restrictions",
                    Accessibility: "None"
                ),
                (
                    Email: "priya.raghavan@gmail.com",
                    Name: "Priya Raghavan",
                    Phone: "+94 71 987 6543",
                    BudgetMin: 2000m,
                    BudgetMax: 4000m,
                    Activities: "Ayurveda, Yoga, Tea Country",
                    Dietary: "Vegan",
                    Accessibility: "Low-step vehicle"
                ),
                (
                    Email: "tom.whitfield@outlook.com",
                    Name: "Tom Whitfield",
                    Phone: "+44 7911 123456",
                    BudgetMin: 3500m,
                    BudgetMax: 7000m,
                    Activities: "Ancient Ruins, Architecture, Fine Dining",
                    Dietary: "Nut allergy",
                    Accessibility: "None"
                ),
                (
                    Email: "user@gmail.com",
                    Name: "user",
                    Phone: "0776543876",
                    BudgetMin: 25000m,
                    BudgetMax: 75000m,
                    Activities: "Scenic, Cultural Walks, Heritage",
                    Dietary: "No restrictions",
                    Accessibility: "None"
                )
            };

            var customerUsers = new Dictionary<string, IdentityUser>();

            foreach (var c in demoCustomers)
            {
                var user = await userManager.FindByEmailAsync(c.Email);
                if (user == null)
                {
                    user = new IdentityUser { UserName = c.Email, Email = c.Email, EmailConfirmed = true };
                    var res = await userManager.CreateAsync(user, "Customer@123");
                    if (res.Succeeded)
                    {
                        await userManager.AddToRoleAsync(user, "Customer");
                    }
                }

                if (user != null)
                {
                    customerUsers[c.Email] = user;

                    var custRecord = await context.Customers.FindAsync(user.Id);
                    if (custRecord == null)
                    {
                        custRecord = new Customer
                        {
                            Id = user.Id,
                            FullName = c.Name,
                            Phone = c.Phone,
                            Role = "Customer",
                            JoinedAt = DateTime.UtcNow,
                            LastActiveAt = DateTime.UtcNow.AddHours(-1)
                        };
                        context.Customers.Add(custRecord);
                    }
                    else
                    {
                        custRecord.FullName = c.Name;
                        custRecord.Phone = c.Phone;
                        custRecord.Role = "Customer";
                    }

                    // Travel Preference
                    var pref = await context.Preferences.FirstOrDefaultAsync(p => p.CustomerId == user.Id);
                    if (pref == null)
                    {
                        context.Preferences.Add(new Preference
                        {
                            CustomerId = user.Id,
                            BudgetMin = c.BudgetMin,
                            BudgetMax = c.BudgetMax,
                            Currency = "USD",
                            PreferredActivities = c.Activities,
                            DietaryNotes = c.Dietary,
                            AccessibilityNotes = c.Accessibility,
                            UpdatedAt = DateTime.UtcNow.AddDays(-5)
                        });
                    }
                }
            }

            await context.SaveChangesAsync();

            // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â…7594 tokens truncated…€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
            var amelia = customerUsers.GetValueOrDefault("amelia.t@example.com");
            var kavinda = customerUsers.GetValueOrDefault("kavinda.silva@gmail.com");
            var priya = customerUsers.GetValueOrDefault("priya.raghavan@gmail.com");
            var tom = customerUsers.GetValueOrDefault("tom.whitfield@outlook.com");

            // Trip requests, agent logs, itineraries, bookings, approvals, and payments
            // are created only by the real customer/agent workflows. The initializer
            // must not create production business records or fabricated audit trails.

            // 11. Multi-Channel Notifications
            // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
            if (!await context.Notifications.AnyAsync())
            {
                var notifyCustomer = amelia ?? primaryCustomer(customerUsers);
                if (notifyCustomer != null)
                {
                    context.Notifications.AddRange(
                        new Notification
                        {
                            CustomerId = notifyCustomer.Id,
                            Channel = NotificationChannel.Email,
                            MessageType = MessageType.BookingConfirmation,
                            Content = "Your reservation has been confirmed by our operations team. View the full voucher in your portal.",
                            Status = NotificationStatus.Sent,
                            SentAt = DateTime.UtcNow.AddDays(-1)
                        },
                        new Notification
                        {
                            CustomerId = notifyCustomer.Id,
                            Channel = NotificationChannel.Push,
                            MessageType = MessageType.TripUpdate,
                            Content = "Ella Odyssey Train tickets for Day 3 have been issued and attached to your itinerary.",
                            Status = NotificationStatus.Sent,
                            SentAt = DateTime.UtcNow.AddHours(-12)
                        },
                        new Notification
                        {
                            CustomerId = notifyCustomer.Id,
                            Channel = NotificationChannel.SMS,
                            MessageType = MessageType.Reminder,
                            Content = "Serendib Trails: Your private chauffeur Mr. Bandara will meet you at CMB Airport arrivals hall at 10:00 AM.",
                            Status = NotificationStatus.Sent,
                            SentAt = DateTime.UtcNow.AddHours(-2)
                        },
                        new Notification
                        {
                            CustomerId = notifyCustomer.Id,
                            Channel = NotificationChannel.InApp,
                            MessageType = MessageType.PaymentReceipt,
                            Content = "Payment receipt of $3,200.00 received. Transaction reference: ch_live_demo_1003.",
                            Status = NotificationStatus.Read,
                            ReadAt = DateTime.UtcNow.AddHours(-5),
                            SentAt = DateTime.UtcNow.AddDays(-1)
                        }
                    );

                    if (kavinda != null)
                    {
                        context.Notifications.Add(new Notification
                        {
                            CustomerId = kavinda.Id,
                            Channel = NotificationChannel.Email,
                            MessageType = MessageType.TripUpdate,
                            Content = "AI Planning Agents have drafted a customized 5-day route through Sigiriya and Ella. Review and approve your plan.",
                            Status = NotificationStatus.Sent,
                            SentAt = DateTime.UtcNow.AddHours(-6)
                        });
                    }

                    await context.SaveChangesAsync();
                }
            }

            // Ensure all registered customer profiles have multi-channel notifications
            var allCustProfiles = await context.Customers
                .Where(c => c.Role == "Customer" || string.IsNullOrEmpty(c.Role))
                .ToListAsync();

            foreach (var cust in allCustProfiles)
            {
                var count = await context.Notifications.CountAsync(n => n.CustomerId == cust.Id);
                if (count == 0)
                {
                    var fName = (cust.FullName ?? "Customer").Split(' ')[0];
                    context.Notifications.AddRange(
                        new Notification
                        {
                            CustomerId = cust.Id,
                            Channel = NotificationChannel.Email,
                            MessageType = MessageType.BookingConfirmation,
                            Content = $"Dear {fName}, your bespoke Sri Lanka travel booking has been confirmed by Serendib Trails. Full travel documents are ready.",
                            Status = NotificationStatus.Sent,
                            SentAt = DateTime.UtcNow.AddDays(-2)
                        },
                        new Notification
                        {
                            CustomerId = cust.Id,
                            Channel = NotificationChannel.SMS,
                            MessageType = MessageType.Reminder,
                            Content = $"Serendib Trails: Chauffeur guide pickup confirmed for {fName}. Contact: +94 77 123 4567.",
                            Status = NotificationStatus.Sent,
                            SentAt = DateTime.UtcNow.AddHours(-8)
                        },
                        new Notification
                        {
                            CustomerId = cust.Id,
                            Channel = NotificationChannel.InApp,
                            MessageType = MessageType.TripUpdate,
                            Content = $"Day-by-day itinerary excursion details updated for {cust.FullName}.",
                            Status = NotificationStatus.Read,
                            ReadAt = DateTime.UtcNow.AddHours(-2),
                            SentAt = DateTime.UtcNow.AddHours(-15)
                        }
                    );
                }
            }
            await context.SaveChangesAsync();
        }

        private static IdentityUser? primaryCustomer(Dictionary<string, IdentityUser> dict)
        {
            return dict.Values.FirstOrDefault();
        }
    }
}
