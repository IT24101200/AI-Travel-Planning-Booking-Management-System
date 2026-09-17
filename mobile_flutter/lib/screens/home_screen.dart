import 'package:flutter/material.dart';
import 'tours/tour_search_browse_screen.dart';
import 'profile/trip_history_screen.dart';
import 'profile/notifications_screen.dart';
import 'profile/profile_preferences_screen.dart';

/// Main home screen with bottom navigation bar.
/// Four tabs: Explore, My Trips, Notifications, Profile.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  // Tab screens
  final List<Widget> _screens = const [
    TourSearchBrowseScreen(),
    TripHistoryScreen(),
    NotificationsScreen(),
    ProfilePreferencesScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_currentIndex],
      // FAB to quickly access trip request form
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.pushNamed(context, '/trip-request'),
        backgroundColor: const Color(0xFF7C5CFC),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Plan a Trip', style: TextStyle(color: Colors.white)),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() { _currentIndex = index; }),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: const Color(0xFF0D9488),
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.explore),
            label: 'Explore',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.card_travel),
            label: 'My Trips',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.notifications_outlined),
            label: 'Alerts',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
