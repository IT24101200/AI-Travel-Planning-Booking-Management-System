import 'package:flutter/material.dart';

import '../../services/api_service.dart';
import '../../widgets/common_widgets.dart';

class DestinationsScreen extends StatefulWidget {
  const DestinationsScreen({super.key});

  @override
  State<DestinationsScreen> createState() => _DestinationsScreenState();
}

class _DestinationsScreenState extends State<DestinationsScreen> {
  late Future<List<dynamic>> _destinations;

  @override
  void initState() {
    super.initState();
    _destinations = ApiService.getDestinations();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Dream destinations')),
      body: SafeArea(
        child: FutureBuilder<List<dynamic>>(
          future: _destinations,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Could not load destinations.'),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: () => setState(() {
                        _destinations = ApiService.getDestinations();
                      }),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              );
            }
            final destinations = snapshot.data ?? [];
            if (destinations.isEmpty) {
              return const Center(child: Text('No destinations available'));
            }
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1200),
                child: GridView.builder(
                  padding: const EdgeInsets.all(20),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 360,
                    mainAxisExtent: 260,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                  ),
                  itemCount: destinations.length,
                  itemBuilder: (context, index) {
                    final destination = destinations[index];
                    final data = destination is Map
                        ? destination
                        : {'name': destination.toString()};
                    final name = data['name']?.toString() ?? 'Sri Lanka';
                    final country = data['country']?.toString() ?? 'Sri Lanka';
                    final image = ApiService.resolveMediaUrl(
                      data['imageUrl']?.toString(),
                    );
                    return Card(
                      margin: EdgeInsets.zero,
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: () => Navigator.pushNamed(
                          context,
                          '/tour-search',
                          arguments: name,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(
                              child: AppNetworkImage(
                                imageUrl: image.isEmpty
                                    ? 'assets/photos/sigiriya-1280.jpg'
                                    : image,
                                width: double.infinity,
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    name,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.titleMedium,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    country,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodySmall,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
