using backend.Models;
using backend.Models.Enums;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Identity.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore;
namespace backend.Data
{
    public class AppDbContext : IdentityDbContext<IdentityUser>
    {
        public AppDbContext(DbContextOptions<AppDbContext> options)
            : base(options)
        {
        }

        // ── Student A DbSets ──
        public DbSet<Customer> Customers => Set<Customer>();
        public DbSet<Preference> Preferences => Set<Preference>();
        public DbSet<Notification> Notifications => Set<Notification>();
        public DbSet<TripRequest> TripRequests => Set<TripRequest>();
        public DbSet<AgentLog> AgentLogs => Set<AgentLog>();

        // ── Shared / Other Student DbSets ──
        public DbSet<Destination> Destinations { get; set; }
        public DbSet<Tour> Tours { get; set; }
        public DbSet<Itinerary> Itineraries { get; set; }
        public DbSet<ItineraryItem> ItineraryItems { get; set; }

        protected override void OnModelCreating(ModelBuilder builder)
        {
            base.OnModelCreating(builder); // Required for Identity tables

            // ── Customer ──
            builder.Entity<Customer>(entity =>
            {
                entity.HasKey(c => c.Id);
                entity.Property(c => c.FullName).IsRequired().HasMaxLength(150);
                entity.Property(c => c.Phone).HasMaxLength(20);
                entity.Property(c => c.JoinedAt).HasDefaultValueSql("NOW()");
                entity.Property(c => c.LastActiveAt).HasDefaultValueSql("NOW()");
            });

            // ── Preference (1:1 with Customer, unique FK) ──
            builder.Entity<Preference>(entity =>
            {
                entity.HasIndex(p => p.CustomerId).IsUnique();

                entity.HasOne(p => p.Customer)
                      .WithOne(c => c.Preference)
                      .HasForeignKey<Preference>(p => p.CustomerId)
                      .OnDelete(DeleteBehavior.Cascade);

                entity.Property(p => p.BudgetMin).HasColumnType("decimal(18,2)");
                entity.Property(p => p.BudgetMax).HasColumnType("decimal(18,2)");
                entity.Property(p => p.Currency).HasMaxLength(10).HasDefaultValue("USD");
                entity.Property(p => p.UpdatedAt).HasDefaultValueSql("NOW()");
            });

            // ── Notification ──
            builder.Entity<Notification>(entity =>
            {
                entity.HasOne(n => n.Customer)
                      .WithMany(c => c.Notifications)
                      .HasForeignKey(n => n.CustomerId)
                      .OnDelete(DeleteBehavior.Cascade);

                entity.Property(n => n.Channel)
                      .HasConversion<string>()
                      .HasMaxLength(20);

                entity.Property(n => n.MessageType)
                      .HasConversion<string>()
                      .HasMaxLength(30);

                entity.Property(n => n.Status)
                      .HasConversion<string>()
                      .HasMaxLength(20)
                      .HasDefaultValue(NotificationStatus.Pending);

                entity.Property(n => n.Content).IsRequired().HasMaxLength(2000);
                entity.Property(n => n.SentAt).HasDefaultValueSql("NOW()");
            });

            // ── TripRequest ──
            builder.Entity<TripRequest>(entity =>
            {
                entity.HasOne(t => t.Customer)
                      .WithMany(c => c.TripRequests)
                      .HasForeignKey(t => t.CustomerId)
                      .OnDelete(DeleteBehavior.Cascade);

                entity.HasOne(t => t.Destination)
                      .WithMany(d => d.TripRequests)
                      .HasForeignKey(t => t.DestinationId)
                      .OnDelete(DeleteBehavior.SetNull)
                      .IsRequired(false);

                entity.Property(t => t.Status)
                      .HasConversion<string>()
                      .HasMaxLength(30)
                      .HasDefaultValue(TripRequestStatus.Pending);

                entity.Property(t => t.BudgetCeiling).HasColumnType("decimal(18,2)");
                entity.Property(t => t.Currency).HasMaxLength(10).HasDefaultValue("USD");
                entity.Property(t => t.RawRequestText).IsRequired().HasMaxLength(2000);
                entity.Property(t => t.PlanJson).HasColumnType("jsonb");
                entity.Property(t => t.RetryCount).HasDefaultValue(0);
                entity.Property(t => t.CreatedAt).HasDefaultValueSql("NOW()");
            });

            // ── AgentLog ──
            builder.Entity<AgentLog>(entity =>
            {
                entity.HasOne(a => a.TripRequest)
                      .WithMany(t => t.AgentLogs)
                      .HasForeignKey(a => a.TripRequestId)
                      .OnDelete(DeleteBehavior.Cascade);

                entity.Property(a => a.AgentName).IsRequired().HasMaxLength(100);
                entity.Property(a => a.StepName).IsRequired().HasMaxLength(100);
                entity.Property(a => a.Timestamp).HasDefaultValueSql("NOW()");
            });

            // ── Itinerary ──
            builder.Entity<Itinerary>(entity =>
            {
                entity.Property(i => i.Status)
                      .HasConversion<string>()
                      .HasMaxLength(20)
                      .HasDefaultValue(ItineraryStatus.Draft);

                entity.HasOne(i => i.Customer)
                      .WithMany()
                      .HasForeignKey(i => i.CustomerId)
                      .OnDelete(DeleteBehavior.Restrict);

                entity.HasOne(i => i.TripRequest)
                      .WithMany()
                      .HasForeignKey(i => i.TripRequestId)
                      .OnDelete(DeleteBehavior.Cascade);

                entity.Property(i => i.TotalEstimatedCost).HasColumnType("decimal(18,2)");
                entity.Property(i => i.Currency).HasMaxLength(10).HasDefaultValue("USD");
                entity.Property(i => i.CreatedAt).HasDefaultValueSql("NOW()");
            });

            // ── ItineraryItem ──
            builder.Entity<ItineraryItem>(entity =>
            {
                entity.HasOne(ii => ii.Itinerary)
                      .WithMany(i => i.ItineraryItems)
                      .HasForeignKey(ii => ii.ItineraryId)
                      .OnDelete(DeleteBehavior.Cascade);

                entity.HasOne(ii => ii.Tour)
                      .WithMany()
                      .HasForeignKey(ii => ii.TourId)
                      .OnDelete(DeleteBehavior.Restrict);

                entity.Property(ii => ii.PriceAtSelection).HasColumnType("decimal(18,2)");
            });
        }
    }
}