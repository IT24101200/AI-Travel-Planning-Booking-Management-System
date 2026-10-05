using backend.Data;
using backend.DTOs;
using backend.Models;
using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;

namespace backend.Services
{
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

            // Search by name or phone
            if (!string.IsNullOrWhiteSpace(search))
            {
                var term = search.ToLower();
                query = query.Where(c =>
                    c.FullName.ToLower().Contains(term) ||
                    (c.Phone != null && c.Phone.Contains(term)));
            }

            // Sort
            query = sortBy?.ToLower() switch
            {
                "name" => descending ? query.OrderByDescending(c => c.FullName) : query.OrderBy(c => c.FullName),
                "joined" => descending ? query.OrderByDescending(c => c.JoinedAt) : query.OrderBy(c => c.JoinedAt),
                "lastactive" => descending ? query.OrderByDescending(c => c.LastActiveAt) : query.OrderBy(c => c.LastActiveAt),
                _ => query.OrderByDescending(c => c.JoinedAt)
            };

            var customers = await query
                .Skip((page - 1) * pageSize)
                .Take(pageSize)
                .ToListAsync();

            var agents = await _db.TravelAgents.ToDictionaryAsync(ta => ta.Id);

            var dtos = new List<CustomerDto>();
            foreach (var c in customers)
            {
                var user = await _userManager.FindByIdAsync(c.Id);
                agents.TryGetValue(c.Id, out var agent);
                dtos.Add(MapToDto(c, user?.Email, agent?.Department));
            }

            return dtos;
        }

        public async Task<int> GetTotalCountAsync(string? search)
        {
            var query = _db.Customers.AsQueryable();

            if (!string.IsNullOrWhiteSpace(search))
            {
                var term = search.ToLower();
                query = query.Where(c =>
                    c.FullName.ToLower().Contains(term) ||
                    (c.Phone != null && c.Phone.Contains(term)));
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

            // Remove associated travel agent record if any
            var agent = await _db.TravelAgents.FindAsync(customerId);
            if (agent != null) _db.TravelAgents.Remove(agent);

            // Remove associated preference if any
            var pref = await _db.Preferences.FirstOrDefaultAsync(p => p.CustomerId == customerId);
            if (pref != null) _db.Preferences.Remove(pref);

            // Remove customer record
            _db.Customers.Remove(customer);

            // Remove ASP.NET Identity user
            var user = await _userManager.FindByIdAsync(customerId);
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
                JoinedAt = customer.JoinedAt,
                LastActiveAt = customer.LastActiveAt,
                HasPreference = pref != null,
                BudgetMin = pref?.BudgetMin,
                BudgetMax = pref?.BudgetMax,
                Currency = pref?.Currency ?? "USD",
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
                    UpdatedAt = pref.UpdatedAt
                }
            };
        }
    }
}
