using System.Security.Claims;
using backend.Controllers;
using backend.Services;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Moq;

namespace backend.Tests;

public class PreferenceControllerTests
{
    [Fact]
    public async Task GetMyPreferences_ReturnsNoContentWhenCustomerHasNoSavedPreferences()
    {
        var service = new Mock<IPreferenceService>();
        service.Setup(s => s.GetByCustomerIdAsync("customer-1"))
            .ReturnsAsync((backend.DTOs.PreferenceDto?)null);
        var controller = new PreferenceController(service.Object, Mock.Of<ICustomerService>());
        var context = new DefaultHttpContext
        {
            User = new ClaimsPrincipal(new ClaimsIdentity(
                new[] { new Claim(ClaimTypes.NameIdentifier, "customer-1") }, "Test"))
        };
        controller.ControllerContext = new ControllerContext { HttpContext = context };

        var result = await controller.GetMyPreferences();

        Assert.IsType<NoContentResult>(result);
    }
}
