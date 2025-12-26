import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../shared/widgets/animated_background.dart';
import '../../../shared/widgets/help_button.dart';
import '../../../core/constants.dart';
import '../models/contact_item.dart';
import '../services/contact_service.dart';
import '../widgets/contact_list_item.dart';

class ContactManagerScreen extends StatefulWidget {
  const ContactManagerScreen({super.key});

  @override
  State<ContactManagerScreen> createState() => _ContactManagerScreenState();
}

class _ContactManagerScreenState extends State<ContactManagerScreen> {
  final ContactService _contactService = ContactService();
  final TextEditingController _searchController = TextEditingController();
  
  List<ContactItem> _allContacts = [];
  List<ContactItem> _filteredContacts = [];
  bool _isLoading = true;
  
  @override
  void initState() {
    super.initState();
    _loadContacts();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadContacts() async {
    setState(() => _isLoading = true);

    final contacts = await _contactService.getAllContacts();
    
    if (mounted) {
      setState(() {
        _allContacts = contacts;
        _filteredContacts = contacts;
        _isLoading = false;
      });
    }
  }

  void _onSearch(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredContacts = _allContacts;
      } else {
        final lower = query.toLowerCase();
        _filteredContacts = _allContacts.where((c) {
          return c.displayName.toLowerCase().contains(lower) ||
                 c.displayInfo.toLowerCase().contains(lower);
        }).toList();
      }
    });
  }

  void _toggleSelection(int index) {
    setState(() {
      _filteredContacts[index].isSelected = !_filteredContacts[index].isSelected;
    });
  }

  List<ContactItem> get _selectedContacts {
    return _filteredContacts.where((c) => c.isSelected).toList();
  }

  void _shareContacts() async {
    final selected = _selectedContacts;
    if (selected.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select contacts to share')),
      );
      return;
    }

    // Export to vCard
    final vcardData = _contactService.exportToVCard(selected);
    final vcardBytes = Uint8List.fromList(vcardData.codeUnits);

    // Navigate to device discovery with vCard file
    context.push('/discovery', extra: {
      'type': 'contacts',
      'content': vcardData,
      'fileName': 'contacts_${DateTime.now().millisecondsSinceEpoch}.vcf',
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Share Contacts',
          style: TextStyle(color: Colors.white),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => context.pop(),
        ),
        actions: const [
          HelpButton(
            featureName: 'Share Contacts',
            helpText: 'Share your contacts with other devices.\n\n• Select contacts to share\n• Exported as vCard format\n• Search to find specific contacts\n• Recipient can import to their address book',
          ),
        ],
      ),
      body: AnimatedBackground(
        child: Container(
          margin: const EdgeInsets.only(top: kToolbarHeight + 60),
          padding: const EdgeInsets.fromLTRB(
            AppConstants.spacingMd,
            AppConstants.spacingMd,
            AppConstants.spacingMd,
            0,
          ),
          decoration: const BoxDecoration(
            color: AppColors.surfaceAlt,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(30),
              topRight: Radius.circular(30),
            ),
          ),
          child: Column(
            children: [
              // Search bar
              TextField(
                controller: _searchController,
                onChanged: _onSearch,
                decoration: InputDecoration(
                  hintText: 'Search contacts...',
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              
              const SizedBox(height: 16),

              // Contacts list
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _filteredContacts.isEmpty
                        ? const Center(
                            child: Text('No contacts found'),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.only(bottom: 100),
                            itemCount: _filteredContacts.length,
                            itemBuilder: (context, index) {
                              final contact = _filteredContacts[index];
                              return ContactListItem(
                                contact: contact,
                                onTap: () => _toggleSelection(index),
                                onCheckboxChanged: (_) => _toggleSelection(index),
                              );
                            },
                          ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: _selectedContacts.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: _shareContacts,
              backgroundColor: const Color(0xFF6C63FF),
              icon: const Icon(Icons.share),
              label: Text('Share ${_selectedContacts.length}'),
            )
          : null,
    );
  }
}
