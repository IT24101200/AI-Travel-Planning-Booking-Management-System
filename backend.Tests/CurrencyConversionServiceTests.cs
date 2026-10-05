using backend.Services;

namespace backend.Tests;

public class CurrencyConversionServiceTests
{
    private readonly CurrencyConversionService _service = new();

    [Fact]
    public void SupportsOnlyLkrAndUsd()
    {
        Assert.True(_service.IsSupported("LKR"));
        Assert.True(_service.IsSupported("usd"));
        Assert.False(_service.IsSupported("EUR"));
    }

    [Fact]
    public void NormalizesAndRejectsUnsupportedCurrencies()
    {
        Assert.Equal("USD", _service.Normalize(" usd "));
        Assert.Throws<ArgumentException>(() => _service.Normalize("EUR"));
    }

    [Fact]
    public void ConvertsLkrToUsdUsingConfiguredDemoRate()
    {
        Assert.Equal(50m, _service.Convert(15000m, "LKR", "USD"));
    }

    [Fact]
    public void ConvertsUsdToLkrUsingConfiguredDemoRate()
    {
        Assert.Equal(15000m, _service.Convert(50m, "USD", "LKR"));
    }

    [Fact]
    public void RoundsAwayFromZeroToTwoDecimals()
    {
        Assert.Equal(3.33m, _service.Convert(1000m, "LKR", "USD"));
    }

    [Fact]
    public void RejectsNegativeMoney()
    {
        Assert.Throws<ArgumentException>(() => _service.Convert(-1m, "LKR", "USD"));
    }

    [Fact]
    public void ExposesHistoricalRateSnapshot()
    {
        Assert.Equal(300m, _service.ExchangeRateToLkr("USD"));
        Assert.Equal(1m, _service.ExchangeRateToLkr("LKR"));
    }
}
