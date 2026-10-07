namespace backend.Models;

/// <summary>
/// A destination selected for a trip request, stored in the request's
/// structured JSON selection list so order is preserved without joining names
/// into a single text field.
/// </summary>
public sealed class TripRequestDestinationSelection
{
    public int Id { get; set; }

    public string Name { get; set; } = string.Empty;

    public int Order { get; set; }
}
