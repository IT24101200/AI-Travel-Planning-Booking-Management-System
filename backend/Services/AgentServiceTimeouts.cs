namespace backend.Services;

internal static class AgentServiceTimeouts
{
    // This budget is only for health/async acknowledgement, not the full LLM pipeline.
    public static TimeSpan Connection(IConfiguration configuration) =>
        Read(configuration, "AgentService:ConnectionTimeoutSeconds", 15);

    public static TimeSpan HealthDegradedThreshold(IConfiguration configuration) =>
        ReadMilliseconds(configuration, "AgentService:HealthDegradedLatencyMilliseconds", 3000);

    public static TimeSpan Pipeline(IConfiguration configuration) =>
        Read(configuration, "AgentService:PipelineTimeoutSeconds", 180);

    private static TimeSpan Read(IConfiguration configuration, string key, int fallback) =>
        TimeSpan.FromSeconds(int.TryParse(configuration[key], out var seconds) && seconds > 0
            ? seconds
            : fallback);

    private static TimeSpan ReadMilliseconds(IConfiguration configuration, string key, int fallback) =>
        TimeSpan.FromMilliseconds(int.TryParse(configuration[key], out var milliseconds) && milliseconds > 0
            ? milliseconds
            : fallback);
}
