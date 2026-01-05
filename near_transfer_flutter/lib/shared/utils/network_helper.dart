import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class NetworkHelper {
  static void showNetworkSetupDialog(BuildContext context, {required bool isSender}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.wifi, color: Colors.blue[700]),
            const SizedBox(width: 12),
            const Text('Network Setup Required'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Both devices must be on the same WiFi network for file transfer.',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 16),
              _buildSetupOption(
                '1',
                'Same WiFi Network',
                'Connect both devices to the same WiFi network',
                Icons.wifi,
                Colors.blue,
              ),
              const SizedBox(height: 12),
              const Text('OR', style: TextStyle(fontWeight: FontWeight.bold), textAlign: TextAlign.center),
              const SizedBox(height: 12),
              _buildSetupOption(
                '2',
                'Mobile Hotspot',
                isSender
                    ? 'Create a hotspot on this device, then connect the receiver to it'
                    : 'Connect to the sender\'s mobile hotspot',
                Icons.router,
                Colors.orange,
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue[200]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue[700]),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'No internet required! Transfer works offline once connected.',
                        style: TextStyle(fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _showHotspotInstructions(context, isSender: isSender);
            },
            child: const Text('How to Setup Hotspot'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
            ),
            child: const Text('I\'m Connected'),
          ),
        ],
      ),
    );
  }

  static Widget _buildSetupOption(
    String number,
    String title,
    String description,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            backgroundColor: color,
            radius: 16,
            child: Text(
              number,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: color,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: const TextStyle(fontSize: 13),
                ),
              ],
            ),
          ),
          Icon(icon, color: color),
        ],
      ),
    );
  }

  static void _showHotspotInstructions(BuildContext context, {required bool isSender}) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Mobile Hotspot Setup'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isSender) ...[
                const Text(
                  'Sender Instructions:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 12),
                _buildInstructionStep('1', 'Open Settings on this device'),
                _buildInstructionStep('2', 'Go to "Network & Internet" or "Connections"'),
                _buildInstructionStep('3', 'Tap "Hotspot & Tethering" or "Mobile Hotspot"'),
                _buildInstructionStep('4', 'Turn ON "Mobile Hotspot"'),
                _buildInstructionStep('5', 'Note the hotspot name and password'),
                _buildInstructionStep('6', 'Share the hotspot name with the receiver'),
              ] else ...[
                const Text(
                  'Receiver Instructions:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 12),
                _buildInstructionStep('1', 'Ask the sender to create a mobile hotspot'),
                _buildInstructionStep('2', 'Open WiFi settings on this device'),
                _buildInstructionStep('3', 'Find the sender\'s hotspot in the WiFi list'),
                _buildInstructionStep('4', 'Connect to the hotspot using the password'),
                _buildInstructionStep('5', 'Return to the app once connected'),
              ],
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.lightbulb_outline, color: Colors.orange[700]),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Tip: Keep both devices close to each other for better connection.',
                        style: TextStyle(fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got it!'),
          ),
        ],
      ),
    );
  }

  static Widget _buildInstructionStep(String number, String instruction) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            backgroundColor: Colors.blue[100],
            radius: 12,
            child: Text(
              number,
              style: TextStyle(
                color: Colors.blue[900],
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              instruction,
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  static void showConnectionCheckDialog(BuildContext context, VoidCallback onConfirmed) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.check_circle_outline, color: Colors.green[700]),
            const SizedBox(width: 12),
            const Text('Ready to Connect?'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Please confirm both devices are:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              _buildCheckItem('Connected to the same WiFi network OR'),
              _buildCheckItem('Receiver connected to sender\'s hotspot'),
              _buildCheckItem('Both devices are nearby'),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.yellow[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.yellow[700]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning_amber, color: Colors.yellow[900]),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Connection will fail if devices are on different networks!',
                        style: TextStyle(fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Not Yet'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              onConfirmed();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
            ),
            child: const Text('Yes, Continue'),
          ),
        ],
      ),
    );
  }

  static Widget _buildCheckItem(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(Icons.check_circle, color: Colors.green[600], size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}
