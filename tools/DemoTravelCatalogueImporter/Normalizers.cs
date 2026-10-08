namespace DemoTravelCatalogueImporter;

public static class Normalizers
{
    public static string Name(string value)
    {
        return string.Join(
            ' ',
            value.Trim().Split((char[]?)null, StringSplitOptions.RemoveEmptyEntries))
            .ToUpperInvariant();
    }

    public static string Route(string from, string to) => $"{Name(from)}\u001f{Name(to)}";

    public static string Hotel(string destination, string hotel) =>
        $"{Name(destination)}\u001f{Name(hotel)}";

    public static string Tour(string destination, string tour) =>
        $"{Name(destination)}\u001f{Name(tour)}";

    public static string Transport(string provider, string from, string to, DateTime departure) =>
        $"{Name(provider)}\u001f{Name(from)}\u001f{Name(to)}\u001f{departure:O}";
}
