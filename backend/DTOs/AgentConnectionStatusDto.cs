namespace backend.DTOs;

public sealed class AgentConnectionStatusDto
{
    public string Status { get; init; } = "unavailable";
    public bool Reachable { get; init; }
    public int? LatencyMs { get; init; }
    public DateTime CheckedAtUtc { get; init; }
}
