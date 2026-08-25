namespace backend.Models.Enums
{
    public enum BookingStatus
    {
        Draft,
        AwaitingApproval,
        Confirmed,
        Rejected,
        Cancelled,
        Completed
    }

    public enum BookingItemType
    {
        Tour,
        Room,
        Transport
    }

    public enum ApprovalDecision
    {
        Approved,
        Rejected,
        RevisionRequested
    }

    public enum PaymentStatus
    {
        Pending,
        Paid,
        Failed,
        Refunded
    }
}
