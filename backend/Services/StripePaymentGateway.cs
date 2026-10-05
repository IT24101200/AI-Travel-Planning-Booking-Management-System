using Stripe;

namespace backend.Services;

public sealed class StripePaymentGateway : IStripePaymentGateway
{
    private readonly string _secretKey;

    public StripePaymentGateway(IConfiguration configuration)
    {
        _secretKey = configuration["Stripe:SecretKey"]
            ?? configuration["STRIPE_SECRET_KEY"]
            ?? Environment.GetEnvironmentVariable("STRIPE_SECRET_KEY")
            ?? string.Empty;
    }

    public async Task<StripePaymentResult> CreatePaymentIntentAsync(
        decimal amount,
        string currency,
        string paymentMethodId,
        string idempotencyKey,
        CancellationToken cancellationToken = default)
    {
        if (string.IsNullOrWhiteSpace(_secretKey) || !_secretKey.StartsWith("sk_test_", StringComparison.Ordinal))
            throw new InvalidOperationException("A Stripe TEST secret key (sk_test_...) is not configured.");

        var client = new StripeClient(_secretKey);
        var options = new PaymentIntentCreateOptions
        {
            Amount = ToMinorUnits(amount, currency),
            Currency = currency.ToLowerInvariant(),
            PaymentMethod = paymentMethodId,
            Confirm = true,
            PaymentMethodTypes = new List<string> { "card" }
        };
        var requestOptions = new RequestOptions { IdempotencyKey = idempotencyKey };
        var intent = await client.V1.PaymentIntents.CreateAsync(options, requestOptions, cancellationToken);

        var succeeded = string.Equals(intent.Status, "succeeded", StringComparison.OrdinalIgnoreCase);
        return new StripePaymentResult(
            succeeded,
            intent.Id,
            succeeded ? null : intent.LastPaymentError?.Message ?? $"Stripe PaymentIntent status was '{intent.Status}'.");
    }

    private static long ToMinorUnits(decimal amount, string currency)
    {
        var zeroDecimal = currency is "BIF" or "CLP" or "DJF" or "GNF" or "JPY" or "KMF" or "KRW" or "MGA" or "PYG" or "RWF" or "UGX" or "VND" or "VUV" or "XAF" or "XOF" or "XPF";
        var multiplier = zeroDecimal ? 1m : 100m;
        return checked((long)decimal.Round(amount * multiplier, 0, MidpointRounding.AwayFromZero));
    }
}
