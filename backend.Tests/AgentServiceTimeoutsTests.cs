using backend.Services;
using Microsoft.Extensions.Configuration;

namespace backend.Tests;

public class AgentServiceTimeoutsTests
{
    [Theory]
    [InlineData(null, 120)]
    [InlineData("90", 90)]
    [InlineData("0", 120)]
    [InlineData("-1", 120)]
    [InlineData("invalid", 120)]
    public void Connection_UsesPositiveConfiguredValueOrStartupDefault(string? value, int expected)
    {
        var configuration = new ConfigurationBuilder().AddInMemoryCollection(
            new Dictionary<string, string?> { ["AgentService:ConnectionTimeoutSeconds"] = value }).Build();

        Assert.Equal(TimeSpan.FromSeconds(expected), AgentServiceTimeouts.Connection(configuration));
    }

    [Theory]
    [InlineData(null, 180)]
    [InlineData("240", 240)]
    [InlineData("0", 180)]
    public void Pipeline_AllowsSeparateExecutionBudget(string? value, int expected)
    {
        var configuration = new ConfigurationBuilder().AddInMemoryCollection(
            new Dictionary<string, string?> { ["AgentService:PipelineTimeoutSeconds"] = value }).Build();

        Assert.Equal(TimeSpan.FromSeconds(expected), AgentServiceTimeouts.Pipeline(configuration));
    }
}
