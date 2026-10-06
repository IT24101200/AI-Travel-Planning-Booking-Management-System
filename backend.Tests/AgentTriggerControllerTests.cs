using System.Net;
using System.Security.Claims;
using System.Text.Json;
using backend.Controllers;
using backend.DTOs;
using backend.Services;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;
using Moq;

namespace backend.Tests;

public class AgentTriggerControllerTests
{
    private sealed class CaptureHandler : HttpMessageHandler
    {
        public string? RequestBody { get; private set; }
        public HttpStatusCode StatusCode { get; init; } = HttpStatusCode.OK;

        protected override async Task<HttpResponseMessage> SendAsync(
            HttpRequestMessage request, CancellationToken cancellationToken)
        {
            RequestBody = request.Content is null
                ? null
                : await request.Content.ReadAsStringAsync(cancellationToken);
            return new HttpResponseMessage(StatusCode)
            {
                Content = new StringContent("{\"status\":\"AwaitingApproval\"}")
            };
        }
    }

    private static AgentTriggerController CreateController(
        string callerId,
        string tripOwnerId,
        CaptureHandler handler,
        string bearerToken = "test-jwt")
    {
        var trips = new Mock<ITripRequestService>();
        trips.Setup(service => service.GetByIdAsync(123))
            .ReturnsAsync(new TripRequestDto
            {
                Id = 123,
                CustomerId = tripOwnerId,
                DestinationId = 5,
                DestinationName = "Kandy",
                StartDate = DateTime.UtcNow.AddDays(10),
                EndDate = DateTime.UtcNow.AddDays(14),
                TravellerCount = 2,
                BudgetCeiling = 2000,
                Currency = "USD"
            });

        var preferences = new Mock<IPreferenceService>();
        preferences.Setup(service => service.GetByCustomerIdAsync(tripOwnerId))
            .ReturnsAsync((PreferenceDto?)null);

        var clientFactory = new Mock<IHttpClientFactory>();
        clientFactory.Setup(factory => factory.CreateClient(It.IsAny<string>()))
            .Returns(new HttpClient(handler));

        var controller = new AgentTriggerController(
            trips.Object,
            preferences.Object,
            clientFactory.Object,
            new ConfigurationBuilder().Build(),
            Mock.Of<ILogger<AgentTriggerController>>());

        var claims = new[]
        {
            new Claim(ClaimTypes.NameIdentifier, callerId),
            new Claim(ClaimTypes.Role, "Customer")
        };
        var context = new DefaultHttpContext
        {
            User = new ClaimsPrincipal(new ClaimsIdentity(claims, "Test"))
        };
        context.Request.Headers.Authorization = $"Bearer {bearerToken}";
        controller.ControllerContext = new ControllerContext { HttpContext = context };
        return controller;
    }

    [Fact]
    public async Task CheckAgentHealth_PreservesUpstreamFailureStatus()
    {
        var handler = new CaptureHandler { StatusCode = HttpStatusCode.ServiceUnavailable };
        var controller = CreateController("customer-1", "customer-1", handler);

        var result = Assert.IsType<ContentResult>(await controller.CheckAgentHealth());

        Assert.Equal(503, result.StatusCode);
    }

    [Fact]
    public async Task TriggerPipeline_Owner_DoesNotForwardRawJwtAcrossAgentBoundary()
    {
        var handler = new CaptureHandler();
        var controller = CreateController("customer-1", "customer-1", handler);

        var result = await controller.TriggerPipeline(123);

        Assert.IsType<ContentResult>(result);
        Assert.NotNull(handler.RequestBody);
        using var document = JsonDocument.Parse(handler.RequestBody!);
        Assert.False(document.RootElement.TryGetProperty("access_token", out _));
        Assert.Equal("customer-1", document.RootElement.GetProperty("customer_id").GetString());
    }

    [Fact]
    public async Task TriggerPipelineAsync_PreservesAcceptedStatus()
    {
        var handler = new CaptureHandler { StatusCode = HttpStatusCode.Accepted };
        var controller = CreateController("customer-1", "customer-1", handler);

        var result = await controller.TriggerPipeline(123, runAsync: true);

        var content = Assert.IsType<ContentResult>(result);
        Assert.Equal(202, content.StatusCode);
    }

    [Fact]
    public async Task TriggerPipeline_UpstreamFailureReturnsSafeError()
    {
        var handler = new CaptureHandler { StatusCode = HttpStatusCode.BadGateway };
        var controller = CreateController("customer-1", "customer-1", handler);

        var result = await controller.TriggerPipeline(123);

        var objectResult = Assert.IsType<ObjectResult>(result);
        Assert.Equal(502, objectResult.StatusCode);
        Assert.DoesNotContain("test-jwt", System.Text.Json.JsonSerializer.Serialize(objectResult.Value));
    }

    [Fact]
    public async Task TriggerPipeline_DifferentCustomer_IsForbiddenAndTokenIsNotForwarded()
    {
        var handler = new CaptureHandler();
        var controller = CreateController("customer-2", "customer-1", handler);

        var result = await controller.TriggerPipeline(123);

        Assert.IsType<ForbidResult>(result);
        Assert.Null(handler.RequestBody);
    }
}
