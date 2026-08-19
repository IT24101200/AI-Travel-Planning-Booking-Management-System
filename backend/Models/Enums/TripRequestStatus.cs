namespace backend.Models.Enums
{
    /// <summary>
    /// Workflow status of a trip request through the agentic pipeline.
    /// </summary>
    public enum TripRequestStatus
    {
        Pending,
        Planning,
        Planned,
        Failed,
        Cancelled,
        AwaitingApproval,
        Approved,
        Rejected
    }
}
