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

        // ── Student D DbSets ──
        public DbSet<Booking> Bookings => Set<Booking>();
        public DbSet<BookingItem> BookingItems => Set<BookingItem>();
        public DbSet<BookingApproval> BookingApprovals => Set<BookingApproval>();
        public DbSet<Payment> Payments => Set<Payment>();
        public DbSet<TravelAgent> TravelAgents => Set<TravelAgent>();

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

            // ── Student D: Booking ──
            builder.Entity<Booking>(entity =>
            {
                entity.HasIndex(b => b.BookingReference).IsUnique();

                entity.Property(b => b.BookingReference).IsRequired().HasMaxLength(50);
                entity.Property(b => b.Status)
                      .HasConversion<string>()
                      .HasMaxLength(30)
                      .HasDefaultValue(BookingStatus.Draft);

                entity.Property(b => b.TotalCost).HasColumnType("decimal(18,2)");
                entity.Property(b => b.Currency).HasMaxLength(10).HasDefaultValue("USD");
                entity.Property(b => b.CreatedAt).HasDefaultValueSql("NOW()");
                entity.Property(b => b.UpdatedAt).HasDefaultValueSql("NOW()");

                entity.HasOne(b => b.Customer)
                      .WithMany()
                      .HasForeignKey(b => b.CustomerId)
                      .OnDelete(DeleteBehavior.Restrict);

                entity.HasOne(b => b.Itinerary)
                      .WithMany()
                      .HasForeignKey(b => b.ItineraryId)
                      .OnDelete(DeleteBehavior.Restrict);
            });

            // ── Student D: BookingItem ──
            builder.Entity<BookingItem>(entity =>
            {
                entity.Property(bi => bi.ItemType)
                      .HasConversion<string>()
                      .HasMaxLength(20);

                entity.Property(bi => bi.UnitPrice).HasColumnType("decimal(18,2)");
                entity.Property(bi => bi.Subtotal).HasColumnType("decimal(18,2)");

                entity.HasOne(bi => bi.Booking)
                      .WithMany(b => b.BookingItems)
                      .HasForeignKey(bi => bi.BookingId)
                      .OnDelete(DeleteBehavior.Cascade);

                entity.HasOne(bi => bi.Tour)
                      .WithMany()
                      .HasForeignKey(bi => bi.TourId)
                      .OnDelete(DeleteBehavior.SetNull);

                entity.HasOne(bi => bi.Room)
                      .WithMany()
                      .HasForeignKey(bi => bi.RoomId)
                      .OnDelete(DeleteBehavior.SetNull);

                entity.HasOne(bi => bi.TransportOption)
                      .WithMany()
                      .HasForeignKey(bi => bi.TransportOptionId)
                      .OnDelete(DeleteBehavior.SetNull);
            });

            // ── Student D: BookingApproval ──
            builder.Entity<BookingApproval>(entity =>
            {
                entity.Property(ba => ba.Decision)
                      .HasConversion<string>()
                      .HasMaxLength(30);

                entity.Property(ba => ba.Comment).HasMaxLength(1000);
                entity.Property(ba => ba.DecidedAt).HasDefaultValueSql("NOW()");

                entity.HasOne(ba => ba.Booking)
                      .WithMany(b => b.BookingApprovals)
                      .HasForeignKey(ba => ba.BookingId)
                      .OnDelete(DeleteBehavior.Cascade);

                entity.HasOne(ba => ba.TravelAgent)
                      .WithMany(ta => ta.BookingApprovals)
                      .HasForeignKey(ba => ba.TravelAgentId)
                      .OnDelete(DeleteBehavior.Restrict);
            });

            // ── Student D: Payment ──
            builder.Entity<Payment>(entity =>
            {
                entity.Property(p => p.Status)
                      .HasConversion<string>()
                      .HasMaxLength(20)
                      .HasDefaultValue(PaymentStatus.Pending);

                entity.Property(p => p.Amount).HasColumnType("decimal(18,2)");
                entity.Property(p => p.Currency).HasMaxLength(10).HasDefaultValue("USD");
                entity.Property(p => p.StripeReference).HasMaxLength(100);
                entity.Property(p => p.PaymentDate).HasDefaultValueSql("NOW()");

                entity.HasOne(p => p.Booking)
                      .WithMany(b => b.Payments)
                      .HasForeignKey(p => p.BookingId)
                      .OnDelete(DeleteBehavior.Cascade);
            });

            // ── Student D: TravelAgent ──
            builder.Entity<TravelAgent>(entity =>
            {
                entity.HasKey(ta => ta.Id);
                entity.Property(ta => ta.FullName).IsRequired().HasMaxLength(150);
                entity.Property(ta => ta.Department).HasMaxLength(100);
                entity.Property(ta => ta.HireDate).HasDefaultValueSql("NOW()");
            });
        }
    }
}