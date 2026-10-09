using backend.Data;
using backend.DTOs;
using backend.Models;
using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;

namespace backend.Services
{
    public sealed class CustomerDeletionConflictException : InvalidOperationException
    {
        public IReadOnlyDictionary<string, int> Details { get; }

        public CustomerDeletionConflictException(string message, IReadOnlyDictionary<string, int> details)
            : base(message)
        {
            Details = details;
        }
    }

    public class CustomerService : ICustomerService
    {
        private readonly AppDbContext _db;
        private readonly UserManager<IdentityUser> _userManager;

        public CustomerService(AppDbContext db, UserManager<IdentityUser> userManager)
        {
            _db = db;
            _userManager = userManager;
        }

        public async Task<CustomerDto?> GetByIdAsync(string customerId)
        {
            var customer = await _db.Customers
                .Include(c => c.Preference)
                .FirstOrDefaultAsync(c => c.Id == customerId);

            if (customer == null) return null;

            var user = await _userManager.FindByIdAsync(customerId);

            return MapToDto(customer, user?.Email);
        }

        public async Task<List<CustomerDto>> GetAllAsync(string? search, string? sortBy, bool descending, int page, int pageSize)
        {
            var query = _db.Customers
                .Include(c => c.Preference)
                .Include(c => c.TripRequests)
                .AsQueryable();

            // Search across the directory identity and profile fields.  Email is
            // owned by ASP.NET Identity, so keep the lookup server-side instead
            // of requiring the frontend to download every page first.
            if (!string.IsNullOrWhiteSpace(search))
            {
                var term = search.Trim().ToLower();
                query = query.Where(c =>
                    c.FullName.ToLower().Contains(term) ||
                    (c.Phone != null && c.Phone.ToLower().Contains(term)) ||
                    _db.Users.Any(u => u.Id == c.Id && u.Email != null && u.Email.ToLower().Contains(term)));
            }

            // Sort
            query = sortBy?.ToLower() switch
            {
                "name" => descending
                    ? query.OrderByDescending(c => c.FullName).ThenBy(c => c.Id)
                    : query.OrderBy(c => c.FullName).ThenBy(c => c.Id),
                "joined" => descending
                    ? query.OrderByDescending(c => c.JoinedAt).ThenBy(c => c.Id)
                    : query.OrderBy(c => c.JoinedAt).ThenBy(c => c.Id),
                "lastactive" => descending
                    ? query.OrderByDescending(c => c.LastActiveAt).ThenBy(c => c.Id)
                    : query.OrderBy(c => c.LastActiveAt).ThenBy(c => c.Id),
                "trips" => descending
                    ? query.OrderByDescending(c => c.TripRequests.Count).ThenBy(c => c.Id)
                    : query.OrderBy(c => c.TripRequests.Count).ThenBy(c => c.Id),
                _ => query.OrderByDescending(c => c.JoinedAt).ThenBy(c => c.Id)
            };

            var customers = await query
                .Skip((page - 1) * pageSize)
                .Take(pageSize)
                .ToListAsync();

            var agents = await _db.TravelAgents.ToDictionaryAsync(ta => ta.Id);
            var userEmails = await _db.Users
                .Where(u => customers.Select(c => c.Id).Contains(u.Id))
                .ToDictionaryAsync(u => u.Id, u => u.Email ?? string.Empty);

            var dtos = new List<CustomerDto>();
            foreach (var c in customers)
            {
                agents.TryGetValue(c.Id, out var agent);
                userEmails.TryGetValue(c.Id, out var email);
                dtos.Add(MapToDto(c, email, agent?.Department));
            }

            return dtos;
        }

        public async Task<int> GetTotalCountAsync(string? search)
        {
            var query = _db.Customers.AsQueryable();

            if (!string.IsNullOrWhiteSpace(search))
            {
                var term = search.Trim().ToLower();
                query = query.Where(c =>
                    c.FullName.ToLower().Contains(term) ||
                    (c.Phone != null && c.Phone.ToLower().Contains(term)) ||
                    _db.Users.Any(u => u.Id == c.Id && u.Email != null && u.Email.ToLower().Contains(term)));
            }

            return await query.CountAsync();
        }

        public async Task<CustomerDto?> UpdateAsync(string customerId, CustomerUpdateDto dto)
        {
            var customer = await _db.Customers
                .Include(c => c.Preference)
                .FirstOrDefaultAsync(c => c.Id == customerId);

            if (customer == null) return null;

            customer.FullName = dto.FullName;
            customer.Phone = dto.Phone;
            customer.LastActiveAt = DateTime.UtcNow;

            var user = await _userManager.FindByIdAsync(customerId);

            // Update role if provided
            if (!string.IsNullOrWhiteSpace(dto.Role) && dto.Role != customer.Role)
            {
                customer.Role = dto.Role;
                if (user != null)
                {
                    var existingRoles = await _userManager.GetRolesAsync(user);
                    if (existingRoles.Any())
                    {
                        await _userManager.RemoveFromRolesAsync(user, existingRoles);
                    }
                    await _userManager.AddToRoleAsync(user, dto.Role);
                }
            }

            // Sync with TravelAgents table if user is staff
            var agent = await _db.TravelAgents.FindAsync(customerId);
            if (customer.Role == "TravelAgent" || customer.Role == "Admin")
            {
                var dept = !string.IsNullOrWhiteSpace(dto.Department)
                    ? dto.Department
                    : (agent?.Department ?? "Tour Operations");

                if (agent == null)
                {
                    agent = new TravelAgent
                    {
                        Id = customerId,
                        FullName = dto.FullName,
                        Department = dept
                    };
                    _db.TravelAgents.Add(agent);
                }
                else
                {
                    agent.FullName = dto.FullName;
                    agent.Department = dept;
                }
            }

            await _db.SaveChangesAsync();

            return MapToDto(customer, user?.Email, agent?.Department);
        }

        public async Task<bool> DeleteAsync(string customerId)
        {
            var customer = await _db.Customers.FindAsync(customerId);
            if (customer == null) return false;

            var user = await _userManager.FindByIdAsync(customerId);
            if (user?.Email?.Equals("admin@serendibtrails.lk", StringComparison.OrdinalIgnoreCase) == true)
            {
                throw new CustomerDeletionConflictException(
                    "The system administrator account is protected and cannot be deleted.",
                    new Dictionary<string, int> { ["systemAdministrator"] = 1 });
            }

            var isAdministrator = string.Equals(customer.Role, "Admin", StringComparison.OrdinalIgnoreCase)
                || (user != null && await _userManager.IsInRoleAsync(user, "Admin"));
            if (isAdministrator)
            {
                var administrators = await _userManager.GetUsersInRoleAsync("Admin");
                if (administrators.Count <= 1)
                {
                    throw new CustomerDeletionConflictException(
                        "The last administrator account is protected and cannot be deleted.",
                        new Dictionary<string, int> { ["lastAdministrator"] = 1 });
                }
            }

            var references = new Dictionary<string, int>
            {
                ["tripRequests"] = await _db.TripRequests.CountAsync(t => t.CustomerId == customerId),
                ["itineraries"] = await _db.Itineraries.CountAsync(i => i.CustomerId == customerId),
                ["bookings"] = await _db.Bookings.CountAsync(b => b.CustomerId == customerId),
                ["bookingApprovals"] = await _db.BookingApprovals.CountAsync(a => a.TravelAgentId == customerId),
            };
            references["payments"] = await _db.Payments
                .Where(p => _db.Bookings.Any(b => b.Id == p.BookingId && b.CustomerId == customerId))
                .CountAsync();

            var protectedHistory = references.Where(pair => pair.Value > 0)
                .ToDictionary(pair => pair.Key, pair => pair.Value);
            if (protectedHistory.Count > 0)
            {
                throw new CustomerDeletionConflictException(
                    "This user cannot be deleted because booking or trip history must be retained.",
                    protectedHistory);
            }

            // Remove associated travel agent record if any
            var agent = await _db.TravelAgents.FindAsync(customerId);
            if (agent != null) _db.TravelAgents.Remove(agent);

            // Remove associated preference if any
            var pref = await _db.Preferences.FirstOrDefaultAsync(p => p.CustomerId == customerId);
            if (pref != null) _db.Preferences.Remove(pref);

            // Remove customer record
            _db.Customers.Remove(customer);

            // Remove ASP.NET Identity user
            if (user != null) await _userManager.DeleteAsync(user);

            await _db.SaveChangesAsync();
            return true;
        }

        public async Task<bool> ExistsAsync(string customerId)
        {
            return await _db.Customers.AnyAsync(c => c.Id == customerId);
        }

        public async Task UpdateLastActiveAsync(string customerId)
        {
            var customer = await _db.Customers.FindAsync(customerId);
            if (customer != null)
            {
                customer.LastActiveAt = DateTime.UtcNow;
                await _db.SaveChangesAsync();
            }
        }

        private static CustomerDto MapToDto(Customer customer, string? email, string? department = null)
        {
            var pref = customer.Preference;
            return new CustomerDto
            {
                Id = customer.Id,
                FullName = customer.FullName,
                Phone = customer.Phone,
                Email = email ?? string.Empty,
                Role = string.IsNullOrWhiteSpace(customer.Role) ? "Customer" : customer.Role,
                Department = department,
                TripCount = customer.TripRequests?.Count ?? 0,
                JoinedAt = DateTimeContract.AsStoredUtc(customer.JoinedAt),
                LastActiveAt = DateTimeContract.AsStoredUtc(customer.LastActiveAt),
                HasPreference = pref != null,
                BudgetMin = pref?.BudgetMin,
                BudgetMax = pref?.BudgetMax,
                Currency = pref?.Currency ?? "LKR",
                PreferredActivities = pref?.PreferredActivities,
                DietaryNotes = pref?.DietaryNotes,
                AccessibilityNotes = pref?.AccessibilityNotes,
                Preference = pref == null ? null : new PreferenceDto
                {
                    Id = pref.Id,
                    CustomerId = pref.CustomerId,
                    BudgetMin = pref.BudgetMin,
                    BudgetMax = pref.BudgetMax,
                    Currency = pref.Currency,
                    PreferredActivities = pref.PreferredActivities,
                    DietaryNotes = pref.DietaryNotes,
                    AccessibilityNotes = pref.AccessibilityNotes,
                    UpdatedAt = DateTimeContract.AsStoredUtc(pref.UpdatedAt)
                }
            };
        }
    }
}
