import 'package:flutter/material.dart';
import '../../../shared/widgets/animated_background.dart';
import '../../../core/constants.dart';
import '../models/contact_item.dart';
import '../services/contact_service.dart';

class ContactImportScreen extends StatefulWidget {
  final String vcardData;
  final String senderName;

  const ContactImportScreen({
    super.key,
    required this.vcardData,
    required this.senderName,
  });

  @override
  State<ContactImportScreen> createState() => _ContactImportScreenState();
}

class _ContactImportScreenState extends State<ContactImportScreen> {
  final ContactService _contactService = ContactService();
  List<ContactItem> _contacts = [];
  bool _isImporting = false;

  @override
  void initState() {
    super.initState();
    _parseContacts();
  }

  void _parseContacts() {
    final contacts = _contactService.importFromVCard(widget.vcardData);
    setState(() {
      _contacts = contacts;
    });
  }

  Future<void> _importAll() async {
    setState(() => _isImporting = true);

    final count = await _contactService.saveContacts(_contacts);

    if (mounted) {
      setState(() => _isImporting = false);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Imported $count of ${_contacts.length} contacts'),
          backgroundColor: Colors.green,
        ),
      );

      // Close screen after short delay
      await Future.delayed(const Duration(seconds: 1));
      if (mounted) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Import Contacts',
          style: TextStyle(color: Colors.white),
        ),
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: AnimatedBackground(
        child: Container(
          margin: const EdgeInsets.only(top: kToolbarHeight + 60),
          padding: const EdgeInsets.all(AppConstants.spacingMd),
          decoration: const BoxDecoration(
            color: AppColors.surfaceAlt,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(30),
              topRight: Radius.circular(30),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Text(
                'From: ${widget.senderName}',
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${_contacts.length} Contacts',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),

              // Contact list
              Expanded(
                child: _contacts.isEmpty
                    ? const Center(child: Text('No contacts found'))
                    : ListView.builder(
                        itemCount: _contacts.length,
                        itemBuilder: (context, index) {
                          final contact = _contacts[index];
                          return Card(
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: const Color(0xFF6C63FF),
                                child: Text(
                                  contact.initials,
                                  style: const TextStyle(color: Colors.white),
                                ),
                              ),
                              title: Text(contact.displayName),
                              subtitle: Text(contact.displayInfo),
                            ),
                          );
                        },
                      ),
              ),

              // Action buttons
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isImporting ? null : () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: _isImporting ? null : _importAll,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6C63FF),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: _isImporting
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation(Colors.white),
                              ),
                            )
                          : Text('Import All (${_contacts.length})'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
