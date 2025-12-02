import 'dart:typed_data';

/// Represents a contact with basic information
class ContactItem {
  final String id;
  final String displayName;
  final List<String> phoneNumbers;
  final List<String> emails;
  final Uint8List? avatar;
  bool isSelected;

  ContactItem({
    required this.id,
    required this.displayName,
    this.phoneNumbers = const [],
    this.emails = const [],
    this.avatar,
    this.isSelected = false,
  });

  /// Get primary phone number
  String? get primaryPhone => phoneNumbers.isNotEmpty ? phoneNumbers.first : null;

  /// Get primary email
  String? get primaryEmail => emails.isNotEmpty ? emails.first : null;

  /// Get formatted display info (phone or email)
  String get displayInfo {
    if (primaryPhone != null) return primaryPhone!;
    if (primaryEmail != null) return primaryEmail!;
    return 'No contact info';
  }

  /// Get initials for avatar placeholder
  String get initials {
    final parts = displayName.trim().split(' ');
    if (parts.isEmpty) return '?';
    if (parts.length == 1) {
      return parts[0].substring(0, 1).toUpperCase();
    }
    return '${parts[0].substring(0, 1)}${parts[1].substring(0, 1)}'.toUpperCase();
  }

  /// Convert to vCard format (simplified)
  String toVCard() {
    final buffer = StringBuffer();
    buffer.writeln('BEGIN:VCARD');
    buffer.writeln('VERSION:3.0');
    buffer.writeln('FN:$displayName');
    
    // Add phone numbers
    for (final phone in phoneNumbers) {
      buffer.writeln('TEL:$phone');
    }
    
    // Add emails
    for (final email in emails) {
      buffer.writeln('EMAIL:$email');
    }
    
    buffer.writeln('END:VCARD');
    return buffer.toString();
  }

  /// Parse from vCard format
  static ContactItem? fromVCard(String vcard) {
    try {
      final lines = vcard.split('\n');
      String? name;
      final phones = <String>[];
      final emails = <String>[];
      
      for (final line in lines) {
        if (line.startsWith('FN:')) {
          name = line.substring(3).trim();
        } else if (line.startsWith('TEL:')) {
          phones.add(line.substring(4).trim());
        } else if (line.startsWith('EMAIL:')) {
          emails.add(line.substring(6).trim());
        }
      }
      
      if (name == null || name.isEmpty) return null;
      
      return ContactItem(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        displayName: name,
        phoneNumbers: phones,
        emails: emails,
      );
    } catch (e) {
      return null;
    }
  }

  /// Create copy with modified fields
  ContactItem copyWith({
    String? id,
    String? displayName,
    List<String>? phoneNumbers,
    List<String>? emails,
    Uint8List? avatar,
    bool? isSelected,
  }) {
    return ContactItem(
      id: id ?? this.id,
      displayName: displayName ?? this.displayName,
      phoneNumbers: phoneNumbers ?? this.phoneNumbers,
      emails: emails ?? this.emails,
      avatar: avatar ?? this.avatar,
      isSelected: isSelected ?? this.isSelected,
    );
  }

  @override
  String toString() => 'ContactItem($displayName, $displayInfo)';
}
