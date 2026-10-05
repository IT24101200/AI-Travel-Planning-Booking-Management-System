using backend.Models;

namespace backend.Services;

public interface ICurrencyConversionService
{
    string BaseCurrency { get; }
    decimal UsdToLkrRate { get; }
    string Normalize(string? currency, string fieldName = "Currency");
    bool IsSupported(string? currency);
    decimal Convert(decimal amount, string fromCurrency, string toCurrency);
    decimal ExchangeRateToLkr(string currency);
}
