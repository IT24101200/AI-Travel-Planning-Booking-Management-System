namespace backend.Services;

public sealed record StripePaymentResult(
    bool Succeeded,
    string PaymentIntentId,
    string? FailureReason = null);

public interface IStripePaymentGateway
{
    Task<StripePaymentResult> CreatePaymentIntentAsync(
        decimal amount,
        string currency,
        string paymentMethodId,
        string idempotencyKey,
        CancellationToken cancellationToken = default);
}
