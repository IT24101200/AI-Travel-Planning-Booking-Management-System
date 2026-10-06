namespace backend.Services;

internal static class AgentServiceTimeouts
{
    // Allow a sleeping hosted service to start before declaring it unavailable.
    public static TimeSpan Connection(IConfiguration configuration) =>
        Read(configuration, "AgentService:ConnectionTimeoutSeconds", 120);

    public static TimeSpan Pipeline(IConfiguration configuration) =>
        Read(configuration, "AgentService:PipelineTimeoutSeconds", 180);

    private static TimeSpan Read(IConfiguration configuration, string key, int fallback) =>
        TimeSpan.FromSeconds(int.TryParse(configuration[key], out var seconds) && seconds > 0
            ? seconds
            : fallback);
}
