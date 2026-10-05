using System.Security.Claims;
using System.Text.Json;
using backend.Controllers;
using backend.DTOs;
using backend.Models.Enums;
using backend.Services;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Moq;

namespace backend.Tests;

public class IntegrationSecurityTests
{
    private static IConfiguration Configuration => new ConfigurationBuilder()
        .AddInMemoryCollection(new Dictionary<string, string?>
        {
            ["AgentService:ApiKey"] = "agent-test-key"
        })
        .Build();

    private static DefaultHttpContext Context(string? key = null, string userId = "customer-1")
    {
        var context = new DefaultHttpContext
        {
            User = new ClaimsPrincipal(new ClaimsIdentity(
                new[] { new Claim(ClaimTypes.NameIdentifier, userId), new Claim(ClaimTypes.Role, "Customer") },
                "Test"))
        };
        if (key != null)
            context.Request.Headers["X-Agent-Service-Key"] = key;
        return context;
    }

    [Theory]
    [InlineData(null)]
    [InlineData("wrong-key")]
    public async Task AgentLog_RejectsMissingOrWrongServiceKey(string? key)
    {
        var service = new Mock<ITripRequestService>();
        var controller = new TripRequestController(
            service.Object, Mock.Of<IAgentProposalPersistenceService>(), Mock.Of<ICustomerService>(), Mock.Of<IHttpClientFactory>(),
            Configuration, Mock.Of<IServiceScopeFactory>(), Mock.Of<Microsoft.Extensions.Logging.ILogger<TripRequestController>>())
        {
            ControllerContext = new ControllerContext { HttpContext = Context(key) }
        };

        var result = await controller.AddAgentLog(new AgentLogCreateDto());

        Assert.IsType<UnauthorizedObjectResult>(result);
        service.Verify(s => s.AddAgentLogAsync(It.IsAny<AgentLogCreateDto>()), Times.Never);
    }

    [Fact]
    public async Task AgentLog_AcceptsCorrectServiceKey()
    {
        var service = new Mock<ITripRequestService>();
        service.Setup(s => s.AddAgentLogAsync(It.IsAny<AgentLogCreateDto>()))
            .ReturnsAsync(new AgentLogDto());
        var controller = new TripRequestController(
            service.Object, Mock.Of<IAgentProposalPersistenceService>(), Mock.Of<ICustomerService>(), Mock.Of<IHttpClientFactory>(),
            Configuration, Mock.Of<IServiceScopeFactory>(), Mock.Of<Microsoft.Extensions.Logging.ILogger<TripRequestController>>())
        {
            ControllerContext = new ControllerContext { HttpContext = Context("agent-test-key") }
        };

        var result = await controller.AddAgentLog(new AgentLogCreateDto
        {
            TripRequestId = 1,
            AgentName = "ValidationAgent",
            StepName = "Validate"
        });

        Assert.IsType<OkObjectResult>(result);
        service.Verify(s => s.AddAgentLogAsync(It.IsAny<AgentLogCreateDto>()), Times.Once);
    }

    [Theory]
    [InlineData(null)]
    [InlineData("wrong-key")]
    public async Task AgentUpdate_RejectsMissingOrWrongServiceKey(string? key)
    {
        var service = new Mock<ITripRequestService>();
        var controller = new TripRequestController(
            service.Object, Mock.Of<IAgentProposalPersistenceService>(), Mock.Of<ICustomerService>(), Mock.Of<IHttpClientFactory>(),
            Configuration, Mock.Of<IServiceScopeFactory>(), Mock.Of<Microsoft.Extensions.Logging.ILogger<TripRequestController>>())
        {
            ControllerContext = new ControllerContext { HttpContext = Context(key) }
        };

        var result = await controller.AgentUpdate(1, new TripRequestAgentUpdateDto());

        Assert.IsType<UnauthorizedObjectResult>(result);
        service.Verify(s => s.UpdateAgentPlanAsync(It.IsAny<int>(), It.IsAny<TripRequestAgentUpdateDto>()), Times.Never);
    }

    [Fact]
    public async Task AgentUpdate_AcceptsCorrectServiceKey()
    {
        var service = new Mock<ITripRequestService>();
        service.Setup(s => s.UpdateAgentPlanAsync(1, It.IsAny<TripRequestAgentUpdateDto>()))
            .ReturnsAsync(new TripRequestDto { Id = 1, Status = "Planning" });
        var controller = new TripRequestController(
            service.Object, Mock.Of<IAgentProposalPersistenceService>(), Mock.Of<ICustomerService>(), Mock.Of<IHttpClientFactory>(),
            Configuration, Mock.Of<IServiceScopeFactory>(), Mock.Of<Microsoft.Extensions.Logging.ILogger<TripRequestController>>())
        {
            ControllerContext = new ControllerContext { HttpContext = Context("agent-test-key") }
        };

        var result = await controller.AgentUpdate(1, new TripRequestAgentUpdateDto { Status = "Planning" });

        Assert.IsType<OkObjectResult>(result);
        service.Verify(s => s.UpdateAgentPlanAsync(1, It.IsAny<TripRequestAgentUpdateDto>()), Times.Once);
    }

    [Fact]
    public async Task AgentUpdate_FinalProposalUsesSinglePersistenceOwner()
    {
        var tripService = new Mock<ITripRequestService>();
        var persistence = new Mock<IAgentProposalPersistenceService>();
        persistence.Setup(s => s.PersistAsync(1, It.IsAny<JsonElement>(), 0, It.IsAny<CancellationToken>()))
            .ReturnsAsync(new AgentProposalPersistenceResult
            {
                TripRequestId = 1,
                ItineraryId = 20,
                BookingId = 30,
                BookingReference = "ST-REAL-30",
                BookingStatus = "AwaitingApproval"
            });
        var controller = new TripRequestController(
            tripService.Object, persistence.Object, Mock.Of<ICustomerService>(), Mock.Of<IHttpClientFactory>(),
            Configuration, Mock.Of<IServiceScopeFactory>(), Mock.Of<Microsoft.Extensions.Logging.ILogger<TripRequestController>>())
        {
            ControllerContext = new ControllerContext { HttpContext = Context("agent-test-key") }
        };

        using var document = JsonDocument.Parse("{\"itinerary\":{},\"booking_details\":{}}");
        var result = await controller.AgentUpdate(1, new TripRequestAgentUpdateDto
        {
            Status = "AwaitingApproval",
            RetryCount = 0,
            PlanJson = document.RootElement.Clone()
        });

        var response = Assert.IsType<OkObjectResult>(result);
        Assert.Equal(30, ((AgentProposalPersistenceResult)response.Value!).BookingId);
        persistence.Verify(s => s.PersistAsync(1, It.IsAny<JsonElement>(), 0, It.IsAny<CancellationToken>()), Times.Once);
        tripService.Verify(s => s.UpdateAgentPlanAsync(It.IsAny<int>(), It.IsAny<TripRequestAgentUpdateDto>()), Times.Never);
    }

    [Fact]
    public async Task CustomerCannotCreateBookingForAnotherCustomer()
    {
        var service = new Mock<IBookingService>();
        var controller = new BookingController(service.Object, Configuration)
        {
            ControllerContext = new ControllerContext { HttpContext = Context(userId: "customer-1") }
        };

        var result = await controller.CreateBooking(new BookingCreateDto { CustomerId = "customer-2" });

        Assert.IsType<ForbidResult>(result);
        service.Verify(s => s.CreateBookingAsync(It.IsAny<BookingCreateDto>()), Times.Never);
    }

    [Fact]
    public async Task CustomerCannotPayAnotherCustomersBooking()
    {
        var payment = new Mock<IPaymentService>();
        var bookings = new Mock<IBookingService>();
        bookings.Setup(s => s.GetBookingByIdAsync(7, "customer-1", false))
            .ThrowsAsync(new UnauthorizedAccessException());
        var controller = new PaymentController(payment.Object, bookings.Object)
        {
            ControllerContext = new ControllerContext { HttpContext = Context(userId: "customer-1") }
        };

        var result = await controller.ProcessPayment(new PaymentCreateDto { BookingId = 7 });

        Assert.IsType<ForbidResult>(result);
        payment.Verify(s => s.ProcessPaymentAsync(It.IsAny<PaymentCreateDto>()), Times.Never);
    }
}
