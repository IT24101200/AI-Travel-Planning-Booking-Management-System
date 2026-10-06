The 50 fictional tours were replaced in Supabase on 6 October 2026 with named
real attractions across ten destinations. No existing booking or itinerary item
referenced these records at the time of replacement.

`real_tour_locations.json` records each original ID/name, replacement, exact GPS
pair and coordinate source. `replace_demo_tours_with_real_attractions.sql` is the
exact-match SQL equivalent; it changes only records that still have their original
names and destination IDs. `all_tour_locations.csv` is the verified catalog export
after the changes were applied.
`tour_records_before_real_attractions.json` preserves the original records for
recovery.

The attraction names and GPS locations were researched. Package prices, durations
and start times remain the operator's existing configuration. These values are
not verified attraction admission fees, official opening times, or contracted
supplier rates. Descriptions do not promise a contracted guide or provider.

Coordinates identify an attraction, an explicitly described car park/visitor
point, or a documented beach viewpoint. Mountain summits and forest trails require
walking; a driving route can only approach their nearest accessible road.

Location data is principally derived from [OpenStreetMap contributors](https://www.openstreetmap.org/copyright)
and is available under the [Open Database License](https://opendatacommons.org/licenses/odbl/).
Nominatim responses were collected in a single-threaded, rate-limited lookup and
cached during research. Temporary lookup files were removed after the reviewed
coordinates and source links were saved. Other coordinate sources are
linked beside each affected record, including GeoNames, a documented heritage
site and Wikimedia Commons photo coordinates.
