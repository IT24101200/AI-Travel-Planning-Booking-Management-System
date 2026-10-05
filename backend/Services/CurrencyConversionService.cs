using backend.Models;

namespace backend.Services;

/// <summary>
/// The single authoritative FX boundary. Catalogue and seeded prices are LKR;
/// transaction values may be LKR or USD and are rounded here only.
/// </summary>
public sealed class CurrencyConversionService : ICurrencyConversionService
{
    private readonly decimal _usdToLkrRate;

    public CurrencyConversionService() : this(null) { }

    public CurrencyConversionService(IConfiguration? configuration)
    {
        var configured = configuration?["Currency:UsdToLkrRate"]
            ?? configuration?["Currency__UsdToLkrRate"];
        _usdToLkrRate = decimal.TryParse(configured, out var rate) && rate > 0m
            ? rate
            : 300m;
    }

    public string BaseCurrency => SupportedCurrency.LKR.ToString();
    public decimal UsdToLkrRate => _usdToLkrRate;

    public bool IsSupported(string? currency) => currency?.Trim().ToUpperInvariant() is "LKR" or "USD";

    public string Normalize(string? currency, string fieldName = "Currency")
    {
        var normalized = currency?.Trim().ToUpperInvariant();
        if (!IsSupported(normalized))
            throw new ArgumentException($"{fieldName} must be one of: LKR, USD.");
        return normalized!;
    }

    public decimal Convert(decimal amount, string fromCurrency, string toCurrency)
    {
        if (amount < 0m)
            throw new ArgumentException("Money amounts cannot be negative.");

        var from = Normalize(fromCurrency, "Source currency");
        var to = Normalize(toCurrency, "Target currency");
        if (from == to) return Round(amount);

        return from == "LKR"
            ? Round(amount / _usdToLkrRate)
            : Round(amount * _usdToLkrRate);
    }

    public decimal ExchangeRateToLkr(string currency) => Normalize(currency) == "USD" ? _usdToLkrRate : 1m;

    private static decimal Round(decimal value) => decimal.Round(value, 2, MidpointRounding.AwayFromZero);
}
