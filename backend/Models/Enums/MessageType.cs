namespace backend.Models.Enums
{
    /// <summary>
    /// Type/category of notification message.
    /// </summary>
    public enum MessageType
    {
        TripUpdate,
        BookingConfirmation,
        PaymentReceipt,
        SystemAlert,
        Promotion,
        Reminder,
        TripPlanningReady,
        TripPlanningFailed,
        TripApproved,
        TripRejected,
        TripRevisionRequested,
        TripRevisionReady,
        TripCancelled,
        BookingConfirmed,
        BookingRejected,
        BookingCancelled,
        PaymentSucceeded,
        PaymentFailed,
        RefundCompleted
    }
}
