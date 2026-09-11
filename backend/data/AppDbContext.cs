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

        // ── Identity-Linked Profiles ──
        public DbSet<Customer> Customers => Set<Customer>();
        public DbSet<TravelAgent> TravelAgents => Set<TravelAgent>();

        // ── Component A: Preferences, Notifications, Trip Requests ──
        public DbSet<Preference> Preferences => Set<Preference>();
        public DbSet<Notification> Notifications => Set<Notification>();
        public DbSet<TripRequest> TripRequests => Set<TripRequest>();
        public DbSet<AgentLog> AgentLogs => Set<AgentLog>();

        // ── Component B: Destinations, Tours, Itineraries ──
        public DbSet<Destination> Destinations => Set<Destination>();
        public DbSet<Tour> Tours => Set<Tour>();
        public DbSet<Itinerary> Itineraries => Set<Itinerary>();
        public DbSet<ItineraryItem> ItineraryItems => Set<ItineraryItem>();

        // ── Component C: Accommodation & Transport ──
        public DbSet<Hotel> Hotels => Set<Hotel>();
        public DbSet<Room> Rooms => Set<Room>();
        public DbSet<TransportOption> TransportOptions => Set<TransportOption>();

        // ── Component D: Bookings, Approvals & Payments ──
        public DbSet<Booking> Bookings => Set<Booking>();
        public DbSet<BookingItem> BookingItems => Set<BookingItem>();
        public DbSet<BookingApproval> BookingApprovals => Set<BookingApproval>();
        public DbSet<Payment> Payments => Set<Payment>();

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

            // ── TravelAgent ──
            builder.Entity<TravelAgent>(entity =>
            {
                entity.HasKey(a => a.Id);
                entity.Property(a => a.FullName).IsRequired().HasMaxLength(150);
                entity.Property(a => a.Department).HasMaxLength(100).HasDefaultValue("Operations");
                entity.Property(a => a.HireDate).HasDefaultValueSql("NOW()");
            });

            // ── Booking (Component D) ──
            builder.Entity<Booking>(entity =>
            {
                entity.HasKey(b => b.Id);
                entity.HasIndex(b => b.BookingReference).IsUnique();
                entity.Property(b => b.BookingReference).IsRequired().HasMaxLength(50);
                entity.Property(b => b.Status).IsRequired().HasMaxLength(30).HasDefaultValue("AwaitingApproval");
                entity.Property(b => b.Currency).HasMaxLength(10).HasDefaultValue("USD");
                entity.Property(b => b.CreatedAt).HasDefaultValueSql("NOW()");
                entity.Property(b => b.UpdatedAt).HasDefaultValueSql("NOW()");

                entity.HasOne(b => b.Customer)
                      .WithMany()
                      .HasForeignKey(b => b.CustomerId)
                      .OnDelete(DeleteBehavior.Restrict);

                entity.HasOne(b => b.Itinerary)
                      .WithOne(i => i.Booking)
                      .HasForeignKey<Booking>(b => b.ItineraryId)
                      .OnDelete(DeleteBehavior.Restrict);
            });

            // ── BookingApproval (Component D: Human in the loop) ──
            builder.Entity<BookingApproval>(entity =>
            {
                entity.HasKey(a => a.Id);

                entity.HasOne(a => a.Booking)
                      .WithMany(b => b.Approvals)
                      .HasForeignKey(a => a.BookingId)
                      .OnDelete(DeleteBehavior.Cascade);

                entity.HasOne(a => a.TravelAgent)
                      .WithMany(t => t.BookingApprovals)
                      .HasForeignKey(a => a.TravelAgentId)
                      .OnDelete(DeleteBehavior.Restrict);

                entity.Property(a => a.Decision).IsRequired().HasMaxLength(30);
                entity.Property(a => a.Comment).HasMaxLength(1000);
                entity.Property(a => a.DecidedAt).HasDefaultValueSql("NOW()");
            });

            // ── Payment (Component D) ──
            builder.Entity<Payment>(entity =>
            {
                entity.HasKey(p => p.Id);

                entity.HasOne(p => p.Booking)
                      .WithOne(b => b.Payment)
                      .HasForeignKey<Payment>(p => p.BookingId)
                      .OnDelete(DeleteBehavior.Cascade);

                entity.Property(p => p.Status).IsRequired().HasMaxLength(30).HasDefaultValue("Pending");
                entity.Property(p => p.Currency).HasMaxLength(10).HasDefaultValue("USD");
                entity.Property(p => p.StripeReference).HasMaxLength(120);
                entity.Property(p => p.PaymentDate).HasDefaultValueSql("NOW()");
            });
        }
    }
}