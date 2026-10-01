using backend.Models;
using backend.Models.Enums;
using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;

namespace backend.Data
{
    /// <summary>
    /// Initializes base system roles, staff accounts, demo customers,
    /// and realistic trip requests, itineraries, and bookings into the database.
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

            // 3. Demo Customers
            var demoCustomers = new[]
            {
                (Email: "kavinda.silva@gmail.com", Name: "Kavinda Silva", Phone: "+94 77 123 4567"),
                (Email: "priya.raghavan@gmail.com", Name: "Priya Raghavan", Phone: "+94 71 987 6543"),
                (Email: "tom.whitfield@outlook.com", Name: "Tom Whitfield", Phone: "+44 7911 123456")
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
                        context.Customers.Add(new Customer
                        {
                            Id = user.Id,
                            FullName = c.Name,
                            Phone = c.Phone,
                            Role = "Customer",
                            JoinedAt = DateTime.UtcNow.AddDays(-14),
                            LastActiveAt = DateTime.UtcNow
                        });
                    }
                }
            }

            await context.SaveChangesAsync();

            // 4. Ensure at least one Destination exists
            var destination = await context.Destinations.FirstOrDefaultAsync();
            if (destination == null)
            {
                destination = new Destination
                {
                    Name = "Cultural Triangle & Highlands",
                    Country = "Sri Lanka",
                    Description = "Ancient rock fortresses, sacred Buddhist temples, and scenic mountain tea trails.",
                    Latitude = 7.9570,
                    Longitude = 80.7603
                };
                context.Destinations.Add(destination);
                await context.SaveChangesAsync();
            }

            // 5. Ensure at least one TripRequest with realistic AI Agent Logs exists
            var primaryCustomer = customerUsers.Values.FirstOrDefault();
            if (primaryCustomer != null)
            {
                var tripRequest = await context.TripRequests
                    .Include(t => t.AgentLogs)
                    .FirstOrDefaultAsync(t => t.CustomerId == primaryCustomer.Id);

                if (tripRequest == null)
                {
                    tripRequest = new TripRequest
                    {
                        CustomerId = primaryCustomer.Id,
                        DestinationId = destination.Id,
                        RawRequestText = "5-day route through Sigiriya, Kandy and Ella for 2 adults with $1,800 ceiling.",
                        StartDate = DateTime.UtcNow.AddDays(7),
                        EndDate = DateTime.UtcNow.AddDays(12),
                        TravellerCount = 2,
                        BudgetCeiling = 1800m,
                        Currency = "USD",
                        Status = TripRequestStatus.Planned,
                        CreatedAt = DateTime.UtcNow.AddDays(-1)
                    };
                    context.TripRequests.Add(tripRequest);
                    await context.SaveChangesAsync();

                    // Seed AI Agent Reasoning Trail
                    context.AgentLogs.AddRange(
                        new AgentLog
                        {
                            TripRequestId = tripRequest.Id,
                            AgentName = "CoordinatorAgent",
                            StepName = "Analyzed traveler intent and seasonality window",
                            Status = "Completed",
                            Input = "Raw trip request: Sigiriya, Kandy, Ella for 2 travellers.",
                            Output = "Seasonality optimal. Selected 5-day route template with $1,800 ceiling.",
                            Timestamp = DateTime.UtcNow.AddHours(-3)
                        },
                        new AgentLog
                        {
                            TripRequestId = tripRequest.Id,
                            AgentName = "ItineraryAgent",
                            StepName = "Drafted 5-day timetable through cultural and hill country hubs",
                            Status = "Completed",
                            Input = "Route stops: Sigiriya -> Kandy -> Ella.",
                            Output = "Scheduled sunrise climb at Sigiriya, Temple of Tooth, and Ella Odyssey train.",
                            Timestamp = DateTime.UtcNow.AddHours(-2)
                        },
                        new AgentLog
                        {
                            TripRequestId = tripRequest.Id,
                            AgentName = "BookingAgent",
                            StepName = "Validated boutique villa availability and express rail passes",
                            Status = "Completed",
                            Input = "Checking room holds and first-class train seats.",
                            Output = "Reserved boutique suites and confirmed driver escort for transit.",
                            Timestamp = DateTime.UtcNow.AddHours(-1)
                        },
                        new AgentLog
                        {
                            TripRequestId = tripRequest.Id,
                            AgentName = "ValidationAgent",
                            StepName = "Calculated total $1,480.00 <= $1,800.00 budget ceiling. Escalated for human sign-off.",
                            Status = "Completed",
                            Input = "Calculating commercial breakdown.",
                            Output = "Total verified at $1,480.00. Ready for Colombo travel agent approval.",
                            Timestamp = DateTime.UtcNow.AddMinutes(-30)
                        }
                    );
                    await context.SaveChangesAsync();
                }

                // 6. Ensure Itinerary exists
                var itinerary = await context.Itineraries.FirstOrDefaultAsync(i => i.CustomerId == primaryCustomer.Id);
                if (itinerary == null)
                {
                    itinerary = new Itinerary
                    {
                        CustomerId = primaryCustomer.Id,
                        TripRequestId = tripRequest.Id,
                        StartDate = DateTime.UtcNow.AddDays(7),
                        EndDate = DateTime.UtcNow.AddDays(12),
                        Status = ItineraryStatus.Proposed,
                        TotalEstimatedCost = 1480m,
                        Currency = "USD",
                        CreatedAt = DateTime.UtcNow.AddDays(-1)
                    };
                    context.Itineraries.Add(itinerary);
                    await context.SaveChangesAsync();
                }

                // 7. Seed Real Database Bookings
                if (!await context.Bookings.AnyAsync())
                {
                    var colomboAgent = staffUsers.GetValueOrDefault("agent@colombo.lk");
                    var kavinda = customerUsers.GetValueOrDefault("kavinda.silva@gmail.com") ?? primaryCustomer;
                    var priya = customerUsers.GetValueOrDefault("priya.raghavan@gmail.com") ?? primaryCustomer;
                    var tom = customerUsers.GetValueOrDefault("tom.whitfield@outlook.com") ?? primaryCustomer;

                    // Booking 1: Pending Approval
                    var b1 = new Booking
                    {
                        BookingReference = "ST-BK-1001",
                        CustomerId = kavinda.Id,
                        ItineraryId = itinerary.Id,
                        Status = BookingStatus.AwaitingApproval,
                        TotalCost = 1480.00m,
                        Currency = "USD",
                        CreatedAt = DateTime.UtcNow.AddHours(-2),
                        UpdatedAt = DateTime.UtcNow.AddHours(-2)
                    };

                    // Booking 2: Pending Approval
                    var b2 = new Booking
                    {
                        BookingReference = "ST-BK-1002",
                        CustomerId = priya.Id,
                        ItineraryId = itinerary.Id,
                        Status = BookingStatus.AwaitingApproval,
                        TotalCost = 1120.00m,
                        Currency = "USD",
                        CreatedAt = DateTime.UtcNow.AddHours(-6),
                        UpdatedAt = DateTime.UtcNow.AddHours(-6)
                    };

                    // Booking 3: Confirmed
                    var b3 = new Booking
                    {
                        BookingReference = "ST-BK-1003",
                        CustomerId = tom.Id,
                        ItineraryId = itinerary.Id,
                        Status = BookingStatus.Confirmed,
                        TotalCost = 860.00m,
                        Currency = "USD",
                        CreatedAt = DateTime.UtcNow.AddDays(-2),
                        UpdatedAt = DateTime.UtcNow.AddDays(-1)
                    };

                    // Booking 4: Rejected
                    var b4 = new Booking
                    {
                        BookingReference = "ST-BK-1004",
                        CustomerId = kavinda.Id,
                        ItineraryId = itinerary.Id,
                        Status = BookingStatus.Rejected,
                        TotalCost = 640.00m,
                        Currency = "USD",
                        CreatedAt = DateTime.UtcNow.AddDays(-4),
                        UpdatedAt = DateTime.UtcNow.AddDays(-3)
                    };

                    context.Bookings.AddRange(b1, b2, b3, b4);
                    await context.SaveChangesAsync();

                    // Seed BookingApprovals for the decided bookings
                    if (colomboAgent != null)
                    {
                        context.BookingApprovals.AddRange(
                            new BookingApproval
                            {
                                BookingId = b3.Id,
                                TravelAgentId = colomboAgent.Id,
                                Decision = ApprovalDecision.Approved,
                                Comment = "Confirmed room allocations and private chauffeur transfers with local partner.",
                                DecidedAt = DateTime.UtcNow.AddDays(-1)
                            },
                            new BookingApproval
                            {
                                BookingId = b4.Id,
                                TravelAgentId = colomboAgent.Id,
                                Decision = ApprovalDecision.Rejected,
                                Comment = "Requested heritage first-class observation carriages unavailable on Poya holiday weekend.",
                                DecidedAt = DateTime.UtcNow.AddDays(-3)
                            }
                        );

                        // Seed Payment for the confirmed booking
                        context.Payments.Add(new Payment
                        {
                            BookingId = b3.Id,
                            Amount = 860.00m,
                            Currency = "USD",
                            Status = PaymentStatus.Paid,
                            PaymentDate = DateTime.UtcNow.AddDays(-1),
                            StripeReference = "ch_live_demo_1003"
                        });

                        await context.SaveChangesAsync();
                    }
                }
            }
        }
    }
}

