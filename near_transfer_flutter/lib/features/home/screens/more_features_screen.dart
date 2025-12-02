import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import 'package:go_router/go_router.dart';
import '../../../shared/widgets/animated_background.dart';
import '../../../core/constants.dart';

class MoreFeaturesScreen extends StatelessWidget {
  const MoreFeaturesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'More Features',
          style: TextStyle(color: Colors.white),
        ),
      ),
      body: AnimatedBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: GridView.count(
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              children: [
                // Browse Files
                _buildFeatureCard(
                  context,
                  title: 'Browse Files',
                  icon: Icons.folder,
                  color: Colors.blue,
                  onTap: () => context.push('/file-manager'),
                ),
                
                // Share Apps
                _buildFeatureCard(
                  context,
                  title: 'Share Apps',
                  icon: Icons.apps,
                  color: Colors.deepPurple,
                  onTap: () => context.push('/app-manager'),
                ),
                
                // Clipboard Sync
                _buildFeatureCard(
                  context,
                  title: 'Clipboard',
                  icon: Icons.content_paste,
                  color: Colors.purple,
                  onTap: () => context.push('/clipboard'),
                ),
                
                // Share Contacts
                _buildFeatureCard(
                  context,
                  title: 'Contacts',
                  icon: Icons.contacts,
                  color: Colors.orange,
                  onTap: () => context.push('/contact-manager'),
                ),
                
                // Shake to Connect
                _buildFeatureCard(
                  context,
                  title: 'Shake',
                  icon: Icons.vibration,
                  color: Colors.teal,
                  onTap: () => context.push('/shake-connect'),
                ),
                
                // Transfer History
                _buildFeatureCard(
                  context,
                  title: 'History',
                  icon: Icons.history,
                  color: Colors.amber,
                  onTap: () => context.push('/history'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureCard(
    BuildContext context, {
    required String title,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return FadeInUp(
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  color.withOpacity(0.8),
                  color,
                ],
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 48,
                  color: Colors.white,
                ),
                const SizedBox(height: 12),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
