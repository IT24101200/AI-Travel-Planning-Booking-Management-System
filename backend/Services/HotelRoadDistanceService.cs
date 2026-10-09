using System.Text.Json;
using backend.Models;

namespace backend.Services;

public interface IHotelRoadDistanceService
{
    Task<Dictionary<int, double>> FromHotelAsync(Hotel origin, IReadOnlyList<Hotel> hotels, CancellationToken cancellationToken);
}

public sealed class HotelRoadDistanceService(IHttpClientFactory clients, IConfiguration configuration) : IHotelRoadDistanceService
{
    public async Task<Dictionary<int, double>> FromHotelAsync(Hotel origin, IReadOnlyList<Hotel> hotels, CancellationToken cancellationToken)
    {
        var result = new Dictionary<int, double>();
        static bool Located(Hotel h) => double.IsFinite(h.Latitude) && double.IsFinite(h.Longitude) &&
            Math.Abs(h.Latitude) <= 90 && Math.Abs(h.Longitude) <= 180 && (h.Latitude != 0 || h.Longitude != 0);
        if (!Located(origin)) throw new InvalidOperationException("This hotel's map location is missing. Please contact your travel agent.");
        using var client = clients.CreateClient();
        client.Timeout = TimeSpan.FromSeconds(25);
        // The public OSRM service rejects requests with an empty User-Agent.
        client.DefaultRequestHeaders.UserAgent.ParseAdd("AITravelPlanner/1.0");
        string Point(Hotel h) => FormattableString.Invariant($"{h.Longitude},{h.Latitude}");
        foreach (var batch in hotels.Where(h => h.Id != origin.Id && Located(h)).Chunk(98))
        {
            var coords = string.Join(";", new[] { Point(origin) }.Concat(batch.Select(Point)));
            var destinations = string.Join(";", Enumerable.Range(1, batch.Length));
            var baseUrl = (configuration["ROUTING_BASE_URL"] ?? "https://router.project-osrm.org").TrimEnd('/');
            using var response = await client.GetAsync($"{baseUrl}/table/v1/driving/{coords}?sources=0&destinations={destinations}&annotations=distance", cancellationToken);
            response.EnsureSuccessStatusCode();
            using var body = JsonDocument.Parse(await response.Content.ReadAsStringAsync(cancellationToken));
            if (body.RootElement.GetProperty("code").GetString() != "Ok")
                throw new HttpRequestException("Hotel road distances are temporarily unavailable.");
            var distances = body.RootElement.GetProperty("distances")[0];
            for (var i = 0; i < batch.Length; i++)
                if (distances[i].ValueKind == JsonValueKind.Number && distances[i].TryGetDouble(out var metres) && double.IsFinite(metres) && metres >= 0)
                    result[batch[i].Id] = metres / 1000;
        }
        result[origin.Id] = 0;
        return result;
    }
}
