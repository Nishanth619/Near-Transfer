import 'package:flutter/material.dart';
import '../models/contact_item.dart';

/// Widget to display a single contact in the list
class ContactListItem extends StatelessWidget {
  final ContactItem contact;
  final VoidCallback onTap;
  final ValueChanged<bool?>? onCheckboxChanged;

  const ContactListItem({
    super.key,
    required this.contact,
    required this.onTap,
    this.onCheckboxChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: ListTile(
        leading: _buildAvatar(),
        title: Text(
          contact.displayName,
          style: const TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 16,
          ),
        ),
        subtitle: Text(
          contact.displayInfo,
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 14,
          ),
        ),
        trailing: onCheckboxChanged != null
            ? Checkbox(
                value: contact.isSelected,
                onChanged: onCheckboxChanged,
                activeColor: const Color(0xFF6C63FF),
              )
            : null,
        onTap: onTap,
      ),
    );
  }

  Widget _buildAvatar() {
    if (contact.avatar != null) {
      return CircleAvatar(
        backgroundImage: MemoryImage(contact.avatar!),
      );
    }

    // Show initials
    return CircleAvatar(
      backgroundColor: const Color(0xFF6C63FF),
      child: Text(
        contact.initials,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
