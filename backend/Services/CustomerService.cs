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

            var dtos = new List<CustomerDto>();
            foreach (var c in customers)
            {
                var user = await _userManager.FindByIdAsync(c.Id);
                dtos.Add(MapToDto(c, user?.Email));
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

            await _db.SaveChangesAsync();

            var user = await _userManager.FindByIdAsync(customerId);
            return MapToDto(customer, user?.Email);
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

        private static CustomerDto MapToDto(Customer customer, string? email)
        {
            return new CustomerDto
            {
                Id = customer.Id,
                FullName = customer.FullName,
                Phone = customer.Phone,
                Email = email ?? string.Empty,
                JoinedAt = customer.JoinedAt,
                LastActiveAt = customer.LastActiveAt,
                HasPreference = customer.Preference != null
            };
        }
    }
}
