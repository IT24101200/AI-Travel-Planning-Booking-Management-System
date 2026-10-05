using System.Text.Json.Serialization;

namespace backend.Models.Enums
{
    [JsonConverter(typeof(JsonStringEnumConverter))]
    public enum BookingStatus
    {
        Draft,
        AwaitingApproval,
        Confirmed,
        Rejected,
        Cancelled,
        Completed
    }

    [JsonConverter(typeof(JsonStringEnumConverter))]
    public enum BookingItemType
    {
        Tour,
        Room,
        Transport
    }

    [JsonConverter(typeof(JsonStringEnumConverter))]
    public enum ApprovalDecision
    {
        Approved,
        Rejected,
        RevisionRequested
    }

    [JsonConverter(typeof(JsonStringEnumConverter))]
    public enum PaymentStatus
    {
        Pending,
        Paid,
        Failed,
        Refunded
    }
}
