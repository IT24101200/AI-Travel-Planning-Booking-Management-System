namespace backend.Services;

public sealed class DestinationConflictException : Exception
{
    public DestinationConflictException(string message, object? details = null)
        : base(message) => Details = details;

    public object? Details { get; }
}

public sealed record DestinationDependencyCounts(int Tours, int Hotels);
