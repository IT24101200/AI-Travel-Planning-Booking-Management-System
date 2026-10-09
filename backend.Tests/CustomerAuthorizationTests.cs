using System.Reflection;
using backend.Controllers;
using Microsoft.AspNetCore.Authorization;
using Xunit;

namespace backend.Tests;

public class CustomerAuthorizationTests
{
    [Fact]
    public void DirectoryListRequiresTravelAgentOrAdmin()
    {
        var method = typeof(CustomerController).GetMethod(nameof(CustomerController.GetAll))!;
        var authorize = method.GetCustomAttribute<AuthorizeAttribute>();

        Assert.Equal("TravelAgent,Admin", authorize?.Roles);
    }

    [Fact]
    public void DeleteRequiresAdmin()
    {
        var method = typeof(CustomerController).GetMethod(nameof(CustomerController.DeleteCustomer))!;
        var authorize = method.GetCustomAttribute<AuthorizeAttribute>();

        Assert.Equal("Admin", authorize?.Roles);
    }

    [Fact]
    public void StaffInviteRequiresAdminAndIsNotAnonymous()
    {
        var method = typeof(AuthController).GetMethod("RegisterStaff")!;
        var authorize = method.GetCustomAttribute<AuthorizeAttribute>();

        Assert.Equal("Admin", authorize?.Roles);
        Assert.Null(method.GetCustomAttribute<AllowAnonymousAttribute>());
    }

    [Fact]
    public void DirectoryControllerRequiresAuthenticationByDefault()
    {
        var authorize = typeof(CustomerController).GetCustomAttribute<AuthorizeAttribute>();
        Assert.NotNull(authorize);
    }
}
