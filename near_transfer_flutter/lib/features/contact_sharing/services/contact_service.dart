import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/contact_item.dart' as models;

/// Service for managing contacts
class ContactService {
  static final ContactService _instance = ContactService._internal();
  factory ContactService() => _instance;
  ContactService._internal();

  /// Request contacts permission
  Future<bool> requestPermission() async {
    final status = await Permission.contacts.request();
    return status.isGranted;
  }

  /// Check if contacts permission is granted
  Future<bool> hasPermission() async {
    final status = await Permission.contacts.status;
    return status.isGranted;
  }

  /// Get all contacts from device
  Future<List<models.ContactItem>> getAllContacts() async {
    try {
      final hasPerms = await hasPermission();
      if (!hasPerms) {
        final granted = await requestPermission();
        if (!granted) return [];
      }

      final contacts = await FlutterContacts.getContacts(
        withProperties: true,
        withPhoto: true,
      );
      
      return contacts.map((contact) => _convertToContactItem(contact)).toList();
    } catch (e) {
      print('Error getting contacts: $e');
      return [];
    }
  }

  /// Search contacts by query
  Future<List<models.ContactItem>> searchContacts(String query) async {
    if (query.isEmpty) return getAllContacts();

    try {
      final allContacts = await getAllContacts();
      final lowerQuery = query.toLowerCase();
      
      return allContacts.where((contact) {
        return contact.displayName.toLowerCase().contains(lowerQuery) ||
               contact.primaryPhone?.contains(query) == true ||
               contact.primaryEmail?.toLowerCase().contains(lowerQuery) == true;
      }).toList();
    } catch (e) {
      print('Error searching contacts: $e');
      return [];
    }
  }

  /// Export contacts to vCard format
  String exportToVCard(List<models.ContactItem> contacts) {
    final buffer = StringBuffer();
    
    for (final contact in contacts) {
      buffer.write(contact.toVCard());
      buffer.writeln();
    }
    
    return buffer.toString();
  }

  /// Import contacts from vCard string
  List<models.ContactItem> importFromVCard(String vcardData) {
    final contacts = <models.ContactItem>[];
    
    final vcards = vcardData.split('BEGIN:VCARD');
    
    for (var vcard in vcards) {
      if (vcard.trim().isEmpty) continue;
      
      vcard = 'BEGIN:VCARD$vcard';
      
      final contact = models.ContactItem.fromVCard(vcard);
      if (contact != null) {
        contacts.add(contact);
      }
    }
    
    return contacts;
  }

  /// Save contact to device
  Future<bool> saveContact(models.ContactItem contactItem) async {
    try {
      final hasPerms = await hasPermission();
      if (!hasPerms) {
        final granted = await requestPermission();
        if (!granted) return false;
      }

      final contact = Contact()
        ..name = Name(first: contactItem.displayName)
        ..phones = contactItem.phoneNumbers.map((p) => Phone(p)).toList()
        ..emails = contactItem.emails.map((e) => Email(e)).toList();

      await contact.insert();
      return true;
    } catch (e) {
      print('Error saving contact: $e');
      return false;
    }
  }

  /// Save multiple contacts
  Future<int> saveContacts(List<models.ContactItem> contacts) async {
    int savedCount = 0;
    
    for (final contact in contacts) {
      final saved = await saveContact(contact);
      if (saved) savedCount++;
    }
    
    return savedCount;
  }

  /// Convert flutter_contacts Contact to ContactItem
  models.ContactItem _convertToContactItem(Contact contact) {
    return models.ContactItem(
      id: contact.id,
      displayName: contact.displayName,
      phoneNumbers: contact.phones.map((p) => p.number).toList(),
      emails: contact.emails.map((e) => e.address).toList(),
      avatar: contact.photo,
    );
  }

  /// Get total contacts count
  Future<int> getContactsCount() async {
    final contacts = await getAllContacts();
    return contacts.length;
  }
}
