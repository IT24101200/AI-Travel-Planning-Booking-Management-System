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
        public static async Task SeedAsync(IServiceProvider serviceProvider)
        {
            using var scope = serviceProvider.CreateScope();
            var context = scope.ServiceProvider.GetRequiredService<AppDbContext>();
            var userManager = scope.ServiceProvider.GetRequiredService<UserManager<IdentityUser>>();
            var roleManager = scope.ServiceProvider.GetRequiredService<RoleManager<IdentityRole>>();

            // ─────────────────────────────────────────────────────────────
            // 0. Ensure Catalog ImageUrl columns exist & seed defaults
            // ─────────────────────────────────────────────────────────────
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

            // ─────────────────────────────────────────────────────────────
            // 1. Roles
            // ─────────────────────────────────────────────────────────────
            string[] roles = ["Customer", "TravelAgent", "Admin"];
            foreach (var role in roles)
            {
                if (!await roleManager.RoleExistsAsync(role))
                {
                    await roleManager.CreateAsync(new IdentityRole(role));
                }
            }

            // ─────────────────────────────────────────────────────────────
            // 2. Staff Accounts (Admins & Travel Agents)
            // ─────────────────────────────────────────────────────────────
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
                            JoinedAt = DateTime.UtcNow.AddMonths(-6),
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

            // ─────────────────────────────────────────────────────────────
            // 3. Realistic Demo Customers with Travel Preferences
            // ─────────────────────────────────────────────────────────────
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
                            JoinedAt = DateTime.UtcNow.AddDays(-28),
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

            // ─────────────────────────────────────────────────────────────
            // 3b. Ensure all existing registered customers have distinct preferences
            // ─────────────────────────────────────────────────────────────
            var registeredCusts = await context.Customers
                .Include(c => c.Preference)
                .Where(c => (c.Role == "Customer" || string.IsNullOrEmpty(c.Role)))
                .ToListAsync();

            foreach (var cust in registeredCusts)
            {
                if (cust.Preference == null)
                {
                    var nameLower = (cust.FullName ?? "").ToLower();
                    decimal minB = 1800m;
                    decimal maxB = 3800m;
                    string activities = "Cultural Heritage · Wildlife Safari · Tea Country";
                    string dietary = "No restrictions";
                    string access = "None";

                    if (nameLower.Contains("pamoda"))
                    {
                        minB = 2200m;
                        maxB = 4200m;
                        activities = "Hill Country Treks · Ancient Temples · Photography";
                        dietary = "Vegetarian";
                        access = "Ground-floor rooms preferred";
                    }
                    else if (nameLower.Contains("pasindu"))
                    {
                        minB = 1600m;
                        maxB = 3200m;
                        activities = "Surfing · Coastal Treks · Seafood Dining";
                        dietary = "No dietary restrictions";
                        access = "None";
                    }
                    else if (nameLower.Contains("chathuranga"))
                    {
                        minB = 1400m;
                        maxB = 2900m;
                        activities = "Scenic Rail · Eco Lodges · Waterfall Trails";
                        dietary = "Vegan-friendly";
                        access = "None";
                    }

                    context.Preferences.Add(new Preference
                    {
                        CustomerId = cust.Id,
                        BudgetMin = minB,
                        BudgetMax = maxB,
                        Currency = "USD",
                        PreferredActivities = activities,
                        DietaryNotes = dietary,
                        AccessibilityNotes = access,
                        UpdatedAt = DateTime.UtcNow
                    });
                }
            }

            await context.SaveChangesAsync();

            // ─────────────────────────────────────────────────────────────
            // 4. Destinations (Curated Sri Lankan Highlights)
            // ─────────────────────────────────────────────────────────────
            var destinationData = new[]
            {
                new Destination
                {
                    Name = "Sigiriya",
                    Country = "Sri Lanka",
                    Description = "Ancient 5th-century rock fortress, Mirror Wall frescoes, and royal water gardens in the Cultural Triangle.",
                    Latitude = 7.9570,
                    Longitude = 80.7603,
                    ImageUrl = "https://images.unsplash.com/photo-1586861635167-e5223aadc9fe?auto=format&fit=crop&w=1200&q=80"
                },
                new Destination
                {
                    Name = "Kandy",
                    Country = "Sri Lanka",
                    Description = "Sacred Hill Capital featuring the Temple of the Tooth Relic, mist-shrouded lake, and Peradeniya Royal Botanic Gardens.",
                    Latitude = 7.2906,
                    Longitude = 80.6337,
                    ImageUrl = "https://images.unsplash.com/photo-1546708973-b339540b5162?auto=format&fit=crop&w=1200&q=80"
                },
                new Destination
                {
                    Name = "Ella",
                    Country = "Sri Lanka",
                    Description = "Misty highland village featuring the Demodara Nine Arches Bridge, Little Adam's Peak, and rolling tea estates.",
                    Latitude = 6.8667,
                    Longitude = 81.0466,
                    ImageUrl = "https://images.unsplash.com/photo-1588258524675-c61917a10786?auto=format&fit=crop&w=1200&q=80"
                },
                new Destination
                {
                    Name = "Galle",
                    Country = "Sri Lanka",
                    Description = "17th-century UNESCO World Heritage Dutch Fort with cobblestone streets, colonial ramparts, and boutique heritage villas.",
                    Latitude = 6.0535,
                    Longitude = 80.2210,
                    ImageUrl = "https://images.unsplash.com/photo-1552465011-b4e21bf6e79a?auto=format&fit=crop&w=1200&q=80"
                },
                new Destination
                {
                    Name = "Yala",
                    Country = "Sri Lanka",
                    Description = "Premier national park celebrated for high leopard density, herds of wild Asian elephants, and coastal scrub lagoons.",
                    Latitude = 6.3725,
                    Longitude = 81.5204,
                    ImageUrl = "https://images.unsplash.com/photo-1561731216-c3a4d99437d5?auto=format&fit=crop&w=1200&q=80"
                },
                new Destination
                {
                    Name = "Mirissa",
                    Country = "Sri Lanka",
                    Description = "Golden crescent bay famous for blue whale watching expeditions, coconut tree hill, surfing breaks, and beach seafood cafes.",
                    Latitude = 5.9483,
                    Longitude = 80.4716,
                    ImageUrl = "https://images.unsplash.com/photo-1507525428034-b723cf961d3e?auto=format&fit=crop&w=1200&q=80"
                },
                new Destination
                {
                    Name = "Nuwara Eliya",
                    Country = "Sri Lanka",
                    Description = "Cool mountain retreat dubbed 'Little England' with British colonial cottages, Gregory Lake, and high-grown tea gardens.",
                    Latitude = 6.9497,
                    Longitude = 80.7891,
                    ImageUrl = "https://images.unsplash.com/photo-1544735716-392fe2489ffa?auto=format&fit=crop&w=1200&q=80"
                },
                new Destination
                {
                    Name = "Trincomalee",
                    Country = "Sri Lanka",
                    Description = "Deep natural harbor on the eastern coast with Pigeon Island coral reefs, marble beach, and clifftop Koneswaram Temple.",
                    Latitude = 8.5874,
                    Longitude = 81.2152,
                    ImageUrl = "https://images.unsplash.com/photo-1506744038136-46273834b3fb?auto=format&fit=crop&w=1200&q=80"
                }
            };

            foreach (var d in destinationData)
            {
                var existingDest = await context.Destinations.FirstOrDefaultAsync(x => x.Name == d.Name);
                if (existingDest == null)
                {
                    context.Destinations.Add(d);
                }
                else
                {
                    existingDest.Description = d.Description;
                    existingDest.ImageUrl = d.ImageUrl;
                    existingDest.Latitude = d.Latitude;
                    existingDest.Longitude = d.Longitude;
                }
            }
            await context.SaveChangesAsync();

            var destMap = await context.Destinations.ToDictionaryAsync(d => d.Name);

            // ─────────────────────────────────────────────────────────────
            // 5. Sellable Tours (Experiences)
            // ─────────────────────────────────────────────────────────────
            if (!await context.Tours.AnyAsync())
            {
                var tours = new List<Tour>
                {
                    new Tour
                    {
                        DestinationId = destMap["Sigiriya"].Id,
                        Name = "Sigiriya Dawn Fortress Ascent & Water Gardens",
                        Category = "Heritage",
                        Description = "Early morning guided climb of the 5th-century rock citadel avoiding the midday heat, exploring frescoes and royal water gardens.",
                        ImageUrl = "https://images.unsplash.com/photo-1586861635167-e5223aadc9fe?auto=format&fit=crop&w=800&q=80",
                        Price = 75.00m,
                        Currency = "USD",
                        DurationHours = 3.5,
                        DefaultStartTime = new TimeSpan(6, 0, 0),
                        Latitude = 7.9570,
                        Longitude = 80.7603,
                        Status = "Active"
                    },
                    new Tour
                    {
                        DestinationId = destMap["Kandy"].Id,
                        Name = "Sacred Temple of the Tooth & Royal Botanic Walk",
                        Category = "Cultural",
                        Description = "Private cultural immersion at Sri Dalada Maligawa followed by an orchid and spice garden stroll through Royal Botanic Gardens Peradeniya.",
                        ImageUrl = "https://images.unsplash.com/photo-1546708973-b339540b5162?auto=format&fit=crop&w=800&q=80",
                        Price = 55.00m,
                        Currency = "USD",
                        DurationHours = 4.0,
                        DefaultStartTime = new TimeSpan(9, 0, 0),
                        Latitude = 7.2906,
                        Longitude = 80.6337,
                        Status = "Active"
                    },
                    new Tour
                    {
                        DestinationId = destMap["Ella"].Id,
                        Name = "Ella Nine Arch Bridge & Little Adam's Peak Trek",
                        Category = "Adventure",
                        Description = "Scenic mountain hike to witness the blue train pass over the 1921 British colonial viaduct, followed by sunset atop Little Adam's Peak.",
                        ImageUrl = "https://images.unsplash.com/photo-1588258524675-c61917a10786?auto=format&fit=crop&w=800&q=80",
                        Price = 65.00m,
                        Currency = "USD",
                        DurationHours = 5.0,
                        DefaultStartTime = new TimeSpan(7, 30, 0),
                        Latitude = 6.8667,
                        Longitude = 81.0466,
                        Status = "Active"
                    },
                    new Tour
                    {
                        DestinationId = destMap["Galle"].Id,
                        Name = "Galle Fort Living History & Artisan Heritage Walk",
                        Category = "Heritage",
                        Description = "Walking historical tour with a resident heritage expert exploring Dutch colonial bastions, maritime museums, and artisan gem jewelers.",
                        ImageUrl = "https://images.unsplash.com/photo-1552465011-b4e21bf6e79a?auto=format&fit=crop&w=800&q=80",
                        Price = 45.00m,
                        Currency = "USD",
                        DurationHours = 2.5,
                        DefaultStartTime = new TimeSpan(16, 0, 0),
                        Latitude = 6.0535,
                        Longitude = 80.2210,
                        Status = "Active"
                    },
                    new Tour
                    {
                        DestinationId = destMap["Yala"].Id,
                        Name = "Yala Block 1 Dawn Leopard & Elephant Safari",
                        Category = "Wildlife",
                        Description = "Private 4x4 open safari vehicle with an experienced tracker navigating the coastal lagoons and rocky outcrops for leopards and sloth bears.",
                        ImageUrl = "https://images.unsplash.com/photo-1561731216-c3a4d99437d5?auto=format&fit=crop&w=800&q=80",
                        Price = 120.00m,
                        Currency = "USD",
                        DurationHours = 6.0,
                        DefaultStartTime = new TimeSpan(5, 30, 0),
                        Latitude = 6.3725,
                        Longitude = 81.5204,
                        Status = "Active"
                    },
                    new Tour
                    {
                        DestinationId = destMap["Mirissa"].Id,
                        Name = "Mirissa Blue Whale & Spinner Dolphin Marine Cruise",
                        Category = "Marine",
                        Description = "Eco-certified boat excursion into the deep Indian Ocean trench to observe migrating blue whales, fin whales, and playful spinner dolphins.",
                        ImageUrl = "https://images.unsplash.com/photo-1507525428034-b723cf961d3e?auto=format&fit=crop&w=800&q=80",
                        Price = 85.00m,
                        Currency = "USD",
                        DurationHours = 4.5,
                        DefaultStartTime = new TimeSpan(6, 30, 0),
                        Latitude = 5.9483,
                        Longitude = 80.4716,
                        Status = "Active"
                    },
                    new Tour
                    {
                        DestinationId = destMap["Nuwara Eliya"].Id,
                        Name = "Pedro Estate Artisan Tea Plucking & Factory Cupping",
                        Category = "Scenic",
                        Description = "Contour-line tea plucking with field experts, followed by factory withering and tasting session of pure high-grown Ceylon BOP.",
                        ImageUrl = "https://images.unsplash.com/photo-1544735716-392fe2489ffa?auto=format&fit=crop&w=800&q=80",
                        Price = 50.00m,
                        Currency = "USD",
                        DurationHours = 3.0,
                        DefaultStartTime = new TimeSpan(9, 30, 0),
                        Latitude = 6.9497,
                        Longitude = 80.7891,
                        Status = "Active"
                    },
                    new Tour
                    {
                        DestinationId = destMap["Trincomalee"].Id,
                        Name = "Pigeon Island Marine Sanctuary Snorkel & Turtles",
                        Category = "Adventure",
                        Description = "Speedboat transit to Pigeon Island National Park for guided snorkeling over pristine coral gardens with blacktip reef sharks and sea turtles.",
                        ImageUrl = "https://images.unsplash.com/photo-1506744038136-46273834b3fb?auto=format&fit=crop&w=800&q=80",
                        Price = 95.00m,
                        Currency = "USD",
                        DurationHours = 4.0,
                        DefaultStartTime = new TimeSpan(8, 0, 0),
                        Latitude = 8.5874,
                        Longitude = 81.2152,
                        Status = "Active"
                    }
                };

                context.Tours.AddRange(tours);
                await context.SaveChangesAsync();
            }

            // ─────────────────────────────────────────────────────────────
            // 6. Hotels & Room Tiers
            // ─────────────────────────────────────────────────────────────
            if (!await context.Hotels.AnyAsync())
            {
                var hotels = new List<Hotel>
                {
                    new Hotel
                    {
                        DestinationId = destMap["Sigiriya"].Id,
                        Name = "Jetwing Vil Uyana",
                        Address = "Sigiriya Ecological Sanctuary, Dambulla",
                        Latitude = 7.9480,
                        Longitude = 80.7410,
                        StarRating = 5,
                        Status = HotelStatus.Active,
                        Rooms = new List<Room>
                        {
                            new Room { RoomType = "Water Dwelling Suite", Capacity = 2, TotalRooms = 10, PricePerNight = 280.00m, Currency = "USD" },
                            new Room { RoomType = "Paddy Villa Chalet", Capacity = 3, TotalRooms = 12, PricePerNight = 220.00m, Currency = "USD" }
                        }
                    },
                    new Hotel
                    {
                        DestinationId = destMap["Kandy"].Id,
                        Name = "Santani Wellness Resort & Spa",
                        Address = "Aratenna Estate, Kandy Highlands",
                        Latitude = 7.3320,
                        Longitude = 80.7550,
                        StarRating = 5,
                        Status = HotelStatus.Active,
                        Rooms = new List<Room>
                        {
                            new Room { RoomType = "Mountain View Chalet", Capacity = 2, TotalRooms = 16, PricePerNight = 350.00m, Currency = "USD" },
                            new Room { RoomType = "Garden Pavilion Suite", Capacity = 2, TotalRooms = 8, PricePerNight = 300.00m, Currency = "USD" }
                        }
                    },
                    new Hotel
                    {
                        DestinationId = destMap["Ella"].Id,
                        Name = "98 Acres Resort & Spa",
                        Address = "Greenland Estate, Passara Road, Ella",
                        Latitude = 6.8610,
                        Longitude = 81.0520,
                        StarRating = 5,
                        Status = HotelStatus.Active,
                        Rooms = new List<Room>
                        {
                            new Room { RoomType = "Greenland Deluxe Suite", Capacity = 2, TotalRooms = 14, PricePerNight = 260.00m, Currency = "USD" },
                            new Room { RoomType = "Superior Tea Chalet", Capacity = 2, TotalRooms = 10, PricePerNight = 195.00m, Currency = "USD" }
                        }
                    },
                    new Hotel
                    {
                        DestinationId = destMap["Galle"].Id,
                        Name = "Amangalla Heritage Villa",
                        Address = "10 Church Street, Fort, Galle",
                        Latitude = 6.0270,
                        Longitude = 80.2170,
                        StarRating = 5,
                        Status = HotelStatus.Active,
                        Rooms = new List<Room>
                        {
                            new Room { RoomType = "Historic Chamber", Capacity = 2, TotalRooms = 12, PricePerNight = 420.00m, Currency = "USD" },
                            new Room { RoomType = "Pariwar Suite", Capacity = 4, TotalRooms = 4, PricePerNight = 650.00m, Currency = "USD" }
                        }
                    },
                    new Hotel
                    {
                        DestinationId = destMap["Yala"].Id,
                        Name = "Cinnamon Wild Yala",
                        Address = "Palatupana, Kirinda, Yala",
                        Latitude = 6.3680,
                        Longitude = 81.5120,
                        StarRating = 4,
                        Status = HotelStatus.Active,
                        Rooms = new List<Room>
                        {
                            new Room { RoomType = "Jungle Chalet", Capacity = 2, TotalRooms = 20, PricePerNight = 210.00m, Currency = "USD" },
                            new Room { RoomType = "Beach Chalet", Capacity = 2, TotalRooms = 15, PricePerNight = 260.00m, Currency = "USD" }
                        }
                    }
                };

                context.Hotels.AddRange(hotels);
                await context.SaveChangesAsync();
            }

            // ─────────────────────────────────────────────────────────────
            // 7. Transport Options
            // ─────────────────────────────────────────────────────────────
            if (!await context.TransportOptions.AnyAsync())
            {
                var transportOptions = new List<TransportOption>
                {
                    new TransportOption
                    {
                        Type = TransportType.Train,
                        Provider = "Sri Lanka Railways (Ella Odyssey)",
                        RouteFrom = "Kandy Goodshed",
                        RouteTo = "Ella Railway Station",
                        RouteFromLatitude = 7.2906,
                        RouteFromLongitude = 80.6337,
                        RouteToLatitude = 6.8667,
                        RouteToLongitude = 81.0466,
                        DepartureTime = DateTime.UtcNow.AddDays(1).Date.AddHours(8).AddMinutes(30),
                        ArrivalTime = DateTime.UtcNow.AddDays(1).Date.AddHours(14).AddMinutes(45),
                        Capacity = 80,
                        Price = 25.00m,
                        Currency = "USD",
                        Status = TransportStatus.Active
                    },
                    new TransportOption
                    {
                        Type = TransportType.Car,
                        Provider = "Serendib Private Chauffeur Fleet",
                        RouteFrom = "Bandaranaike Int Airport (CMB)",
                        RouteTo = "Sigiriya Sanctuary",
                        RouteFromLatitude = 7.1808,
                        RouteFromLongitude = 79.8841,
                        RouteToLatitude = 7.9570,
                        RouteToLongitude = 80.7603,
                        DepartureTime = DateTime.UtcNow.AddDays(1).Date.AddHours(10),
                        ArrivalTime = DateTime.UtcNow.AddDays(1).Date.AddHours(13).AddMinutes(30),
                        Capacity = 4,
                        Price = 85.00m,
                        Currency = "USD",
                        Status = TransportStatus.Active
                    },
                    new TransportOption
                    {
                        Type = TransportType.Flight,
                        Provider = "Cinnamon Air (Amphibian Seaplane)",
                        RouteFrom = "Colombo Waters Edge (DWO)",
                        RouteTo = "Castlereagh Reservoir (NUW)",
                        RouteFromLatitude = 6.9050,
                        RouteFromLongitude = 79.9120,
                        RouteToLatitude = 6.8720,
                        RouteToLongitude = 80.5930,
                        DepartureTime = DateTime.UtcNow.AddDays(2).Date.AddHours(9),
                        ArrivalTime = DateTime.UtcNow.AddDays(2).Date.AddHours(9).AddMinutes(35),
                        Capacity = 8,
                        Price = 240.00m,
                        Currency = "USD",
                        Status = TransportStatus.Active
                    },
                    new TransportOption
                    {
                        Type = TransportType.Car,
                        Provider = "Southern Coastal Chauffeur",
                        RouteFrom = "Galle Fort",
                        RouteTo = "Mirissa Bay",
                        RouteFromLatitude = 6.0535,
                        RouteFromLongitude = 80.2210,
                        RouteToLatitude = 5.9483,
                        RouteToLongitude = 80.4716,
                        DepartureTime = DateTime.UtcNow.AddDays(3).Date.AddHours(11),
                        ArrivalTime = DateTime.UtcNow.AddDays(3).Date.AddHours(11).AddMinutes(45),
                        Capacity = 6,
                        Price = 40.00m,
                        Currency = "USD",
                        Status = TransportStatus.Active
                    },
                    new TransportOption
                    {
                        Type = TransportType.Bus,
                        Provider = "Intercity Superline Express Coach",
                        RouteFrom = "Colombo Bastian Mawatha",
                        RouteTo = "Kandy Clock Tower",
                        RouteFromLatitude = 6.9344,
                        RouteFromLongitude = 79.8540,
                        RouteToLatitude = 7.2906,
                        RouteToLongitude = 80.6337,
                        DepartureTime = DateTime.UtcNow.AddDays(1).Date.AddHours(7),
                        ArrivalTime = DateTime.UtcNow.AddDays(1).Date.AddHours(10).AddMinutes(15),
                        Capacity = 45,
                        Price = 12.00m,
                        Currency = "USD",
                        Status = TransportStatus.Active
                    }
                };

                context.TransportOptions.AddRange(transportOptions);
                await context.SaveChangesAsync();
            }

            // ─────────────────────────────────────────────────────────────
            // 8. Trip Requests with AI Agent Reasoning Trails
            // ─────────────────────────────────────────────────────────────
            var amelia = customerUsers.GetValueOrDefault("amelia.t@example.com");
            var kavinda = customerUsers.GetValueOrDefault("kavinda.silva@gmail.com");
            var priya = customerUsers.GetValueOrDefault("priya.raghavan@gmail.com");
            var tom = customerUsers.GetValueOrDefault("tom.whitfield@outlook.com");

            var firstTour = await context.Tours.FirstOrDefaultAsync();
            var sigiriyaDest = destMap.GetValueOrDefault("Sigiriya");

            if (amelia != null && !await context.TripRequests.AnyAsync(t => t.CustomerId == amelia.Id))
            {
                var tr = new TripRequest
                {
                    CustomerId = amelia.Id,
                    DestinationId = sigiriyaDest?.Id,
                    RawRequestText = "6-day cultural and tea trail journey through Sigiriya, Kandy and Ella for 2 adults with $2,800 ceiling.",
                    StartDate = DateTime.UtcNow.AddDays(10),
                    EndDate = DateTime.UtcNow.AddDays(16),
                    TravellerCount = 2,
                    BudgetCeiling = 2800m,
                    Currency = "USD",
                    Status = TripRequestStatus.Planned,
                    CreatedAt = DateTime.UtcNow.AddDays(-2)
                };
                context.TripRequests.Add(tr);
                await context.SaveChangesAsync();

                context.AgentLogs.AddRange(
                    new AgentLog
                    {
                        TripRequestId = tr.Id,
                        AgentName = "CoordinatorAgent",
                        StepName = "Analyzed traveler intent and seasonality window",
                        Status = "Completed",
                        Input = "Raw trip request: Sigiriya, Kandy, Ella for 2 travellers.",
                        Output = "Seasonality optimal. Selected 6-day heritage and scenic mountain route template with $2,800 ceiling.",
                        Timestamp = DateTime.UtcNow.AddDays(-2).AddHours(1)
                    },
                    new AgentLog
                    {
                        TripRequestId = tr.Id,
                        AgentName = "ItineraryAgent",
                        StepName = "Drafted 6-day timetable through cultural and hill country hubs",
                        Status = "Completed",
                        Input = "Route stops: Sigiriya -> Kandy -> Ella.",
                        Output = "Scheduled dawn climb at Sigiriya, Temple of Tooth, and Ella Odyssey train.",
                        Timestamp = DateTime.UtcNow.AddDays(-2).AddHours(2)
                    },
                    new AgentLog
                    {
                        TripRequestId = tr.Id,
                        AgentName = "BookingAgent",
                        StepName = "Validated boutique villa availability and express rail passes",
                        Status = "Completed",
                        Input = "Checking room holds and first-class train seats.",
                        Output = "Reserved boutique suites at Vil Uyana and confirmed chauffeur transit.",
                        Timestamp = DateTime.UtcNow.AddDays(-2).AddHours(3)
                    },
                    new AgentLog
                    {
                        TripRequestId = tr.Id,
                        AgentName = "ValidationAgent",
                        StepName = "Calculated total $2,180.00 <= $2,800.00 budget ceiling. Escalated for human sign-off.",
                        Status = "Completed",
                        Input = "Commercial breakdown validation.",
                        Output = "Total verified at $2,180.00. Ready for travel agent approval.",
                        Timestamp = DateTime.UtcNow.AddDays(-2).AddHours(4)
                    }
                );
                await context.SaveChangesAsync();

                // 9. Itinerary for Amelia
                var itin = new Itinerary
                {
                    CustomerId = amelia.Id,
                    TripRequestId = tr.Id,
                    StartDate = DateTime.UtcNow.AddDays(10),
                    EndDate = DateTime.UtcNow.AddDays(16),
                    Status = ItineraryStatus.Proposed,
                    TotalEstimatedCost = 2180m,
                    Currency = "USD",
                    CreatedAt = DateTime.UtcNow.AddDays(-2)
                };
                context.Itineraries.Add(itin);
                await context.SaveChangesAsync();

                if (firstTour != null)
                {
                    context.ItineraryItems.AddRange(
                        new ItineraryItem
                        {
                            ItineraryId = itin.Id,
                            TourId = firstTour.Id,
                            DayNumber = 1,
                            SequenceOrder = 1,
                            StartTime = new TimeSpan(6, 30, 0),
                            EndTime = new TimeSpan(10, 0, 0),
                            PriceAtSelection = firstTour.Price
                        }
                    );
                    await context.SaveChangesAsync();
                }
            }

            // ─────────────────────────────────────────────────────────────
            // 10. Bookings, Approvals & Payments
            // ─────────────────────────────────────────────────────────────
            if (!await context.Bookings.AnyAsync())
            {
                var primaryItin = await context.Itineraries.FirstOrDefaultAsync();
                var colomboAgent = staffUsers.GetValueOrDefault("agent@colombo.lk");
                var sahanAgent = staffUsers.GetValueOrDefault("s.perera@serendib.lk");

                if (primaryItin != null)
                {
                    var b1 = new Booking
                    {
                        BookingReference = "ST-BK-1001",
                        CustomerId = amelia?.Id ?? primaryItin.CustomerId,
                        ItineraryId = primaryItin.Id,
                        Status = BookingStatus.AwaitingApproval,
                        TotalCost = 2180.00m,
                        Currency = "USD",
                        CreatedAt = DateTime.UtcNow.AddHours(-3),
                        UpdatedAt = DateTime.UtcNow.AddHours(-3)
                    };

                    var b2 = new Booking
                    {
                        BookingReference = "ST-BK-1002",
                        CustomerId = kavinda?.Id ?? primaryItin.CustomerId,
                        ItineraryId = primaryItin.Id,
                        Status = BookingStatus.AwaitingApproval,
                        TotalCost = 1480.00m,
                        Currency = "USD",
                        CreatedAt = DateTime.UtcNow.AddHours(-8),
                        UpdatedAt = DateTime.UtcNow.AddHours(-8)
                    };

                    var b3 = new Booking
                    {
                        BookingReference = "ST-BK-1003",
                        CustomerId = tom?.Id ?? primaryItin.CustomerId,
                        ItineraryId = primaryItin.Id,
                        Status = BookingStatus.Confirmed,
                        TotalCost = 3200.00m,
                        Currency = "USD",
                        CreatedAt = DateTime.UtcNow.AddDays(-2),
                        UpdatedAt = DateTime.UtcNow.AddDays(-1)
                    };

                    var b4 = new Booking
                    {
                        BookingReference = "ST-BK-1004",
                        CustomerId = priya?.Id ?? primaryItin.CustomerId,
                        ItineraryId = primaryItin.Id,
                        Status = BookingStatus.Rejected,
                        TotalCost = 890.00m,
                        Currency = "USD",
                        CreatedAt = DateTime.UtcNow.AddDays(-4),
                        UpdatedAt = DateTime.UtcNow.AddDays(-3)
                    };

                    var b5 = new Booking
                    {
                        BookingReference = "ST-BK-1005",
                        CustomerId = kavinda?.Id ?? primaryItin.CustomerId,
                        ItineraryId = primaryItin.Id,
                        Status = BookingStatus.Confirmed,
                        TotalCost = 1650.00m,
                        Currency = "USD",
                        CreatedAt = DateTime.UtcNow.AddDays(-5),
                        UpdatedAt = DateTime.UtcNow.AddDays(-4)
                    };

                    context.Bookings.AddRange(b1, b2, b3, b4, b5);
                    await context.SaveChangesAsync();

                    if (sahanAgent != null || colomboAgent != null)
                    {
                        var reviewerId = sahanAgent?.Id ?? colomboAgent!.Id;

                        context.BookingApprovals.AddRange(
                            new BookingApproval
                            {
                                BookingId = b3.Id,
                                TravelAgentId = reviewerId,
                                Decision = ApprovalDecision.Approved,
                                Comment = "Chauffeur escort and boutique luxury chalets confirmed with Vil Uyana and Amangalla.",
                                DecidedAt = DateTime.UtcNow.AddDays(-1)
                            },
                            new BookingApproval
                            {
                                BookingId = b4.Id,
                                TravelAgentId = reviewerId,
                                Decision = ApprovalDecision.Rejected,
                                Comment = "Requested first-class rail carriages fully booked on Poya holiday weekend.",
                                DecidedAt = DateTime.UtcNow.AddDays(-3)
                            },
                            new BookingApproval
                            {
                                BookingId = b5.Id,
                                TravelAgentId = reviewerId,
                                Decision = ApprovalDecision.Approved,
                                Comment = "All tea estate tours and rail passes confirmed for travel dates.",
                                DecidedAt = DateTime.UtcNow.AddDays(-4)
                            }
                        );

                        // Seed payments
                        context.Payments.AddRange(
                            new Payment
                            {
                                BookingId = b3.Id,
                                Amount = 3200.00m,
                                Currency = "USD",
                                Status = PaymentStatus.Paid,
                                PaymentDate = DateTime.UtcNow.AddDays(-1),
                                StripeReference = "ch_live_demo_1003"
                            },
                            new Payment
                            {
                                BookingId = b5.Id,
                                Amount = 1650.00m,
                                Currency = "USD",
                                Status = PaymentStatus.Paid,
                                PaymentDate = DateTime.UtcNow.AddDays(-4),
                                StripeReference = "ch_live_demo_1005"
                            }
                        );

                        await context.SaveChangesAsync();
                    }
                }
            }

            // ─────────────────────────────────────────────────────────────
            // 11. Multi-Channel Notifications
            // ─────────────────────────────────────────────────────────────
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
                            Content = "Your reservation ST-BK-1003 has been confirmed by our operations team. View full voucher in your portal.",
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
