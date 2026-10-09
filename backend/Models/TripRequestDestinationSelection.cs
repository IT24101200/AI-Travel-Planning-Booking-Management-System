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

    /// <summary>
    /// True only when the customer explicitly selected this destination as
    /// the journey starter. Existing JSONB selections default to false.
    /// </summary>
    public bool IsStarter { get; set; }
}
