using backend.Data;
using backend.DTOs;
using backend.Models;
using Microsoft.EntityFrameworkCore;

namespace backend.Services
{
    public class PreferenceService : IPreferenceService
    {
        private readonly AppDbContext _db;

        public PreferenceService(AppDbContext db)
        {
            _db = db;
        }

        public async Task<PreferenceDto?> GetByCustomerIdAsync(string customerId)
        {
            var pref = await _db.Preferences
                .FirstOrDefaultAsync(p => p.CustomerId == customerId);

            return pref == null ? null : MapToDto(pref);
        }

        public async Task<PreferenceDto> CreateOrUpdateAsync(string customerId, PreferenceUpdateDto dto)
        {
            // Validate: BudgetMax >= BudgetMin
            if (dto.BudgetMax < dto.BudgetMin)
            {
                throw new ArgumentException("BudgetMax must be greater than or equal to BudgetMin.");
            }

            var existing = await _db.Preferences
                .FirstOrDefaultAsync(p => p.CustomerId == customerId);

            if (existing != null)
            {
                // Update
                existing.BudgetMin = dto.BudgetMin;
                existing.BudgetMax = dto.BudgetMax;
                existing.Currency = dto.Currency;
                existing.PreferredActivities = dto.PreferredActivities;
                existing.DietaryNotes = dto.DietaryNotes;
                existing.AccessibilityNotes = dto.AccessibilityNotes;
                existing.UpdatedAt = DateTime.UtcNow;

                await _db.SaveChangesAsync();
                return MapToDto(existing);
            }
            else
            {
                // Create
                var pref = new Preference
                {
                    CustomerId = customerId,
                    BudgetMin = dto.BudgetMin,
                    BudgetMax = dto.BudgetMax,
                    Currency = dto.Currency,
                    PreferredActivities = dto.PreferredActivities,
                    DietaryNotes = dto.DietaryNotes,
                    AccessibilityNotes = dto.AccessibilityNotes,
                    UpdatedAt = DateTime.UtcNow
                };

                _db.Preferences.Add(pref);
                await _db.SaveChangesAsync();
                return MapToDto(pref);
            }
        }

        public async Task<List<PreferenceDto>> SearchAsync(string? customerId, decimal? minBudget, decimal? maxBudget, string? sortBy, bool descending, int page, int pageSize)
        {
            var query = _db.Preferences.AsQueryable();

            if (!string.IsNullOrWhiteSpace(customerId))
                query = query.Where(p => p.CustomerId == customerId);
            
            if (minBudget.HasValue)
                query = query.Where(p => p.BudgetMin >= minBudget.Value);

            if (maxBudget.HasValue)
                query = query.Where(p => p.BudgetMax <= maxBudget.Value);

            query = sortBy?.ToLower() switch
            {
                "budgetmin" => descending ? query.OrderByDescending(p => p.BudgetMin) : query.OrderBy(p => p.BudgetMin),
                "budgetmax" => descending ? query.OrderByDescending(p => p.BudgetMax) : query.OrderBy(p => p.BudgetMax),
                _ => descending ? query.OrderByDescending(p => p.CustomerId) : query.OrderBy(p => p.CustomerId)
            };

            var prefs = await query
                .Skip((page - 1) * pageSize)
                .Take(pageSize)
                .ToListAsync();

            return prefs.Select(MapToDto).ToList();
        }

        private static PreferenceDto MapToDto(Preference pref)
        {
            return new PreferenceDto
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
            };
        }
    }
}
