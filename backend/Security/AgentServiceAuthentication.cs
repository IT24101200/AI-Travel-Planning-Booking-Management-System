using System.Security.Cryptography;
using System.Text;

namespace backend.Security;

public static class AgentServiceAuthentication
{
    public const string HeaderName = "X-Agent-Service-Key";

    public static bool IsValid(HttpRequest request, IConfiguration configuration)
    {
        var configuredKey = new[]
        {
            configuration["AgentService:ApiKey"],
            configuration["AGENT_SERVICE_API_KEY"],
            Environment.GetEnvironmentVariable("AGENT_SERVICE_API_KEY")
        }.FirstOrDefault(value => !string.IsNullOrWhiteSpace(value));

        if (string.IsNullOrWhiteSpace(configuredKey) ||
            !request.Headers.TryGetValue(HeaderName, out var suppliedValues))
            return false;

        var suppliedKey = suppliedValues.ToString();
        var expected = Encoding.UTF8.GetBytes(configuredKey);
        var supplied = Encoding.UTF8.GetBytes(suppliedKey);
        return CryptographicOperations.FixedTimeEquals(expected, supplied);
    }
}
