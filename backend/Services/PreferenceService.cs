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
