import 'package:flutter/foundation.dart';

/// A salon customer, as the front-desk picker needs it. Deliberately minimal
/// (id / name / phone only) — never pull more client PII than a screen uses.
@immutable
class Client {
  const Client({required this.id, required this.name, this.phone});

  final String id;
  final String name;
  final String? phone;

  /// Initials for the avatar (e.g. "Rania Abou Jaoude" → "RA").
  String get initials {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    // First + second word (e.g. "Rania Abou Jaoude" → "RA"), matching the mockups.
    return (parts[0].substring(0, 1) + parts[1].substring(0, 1)).toUpperCase();
  }

  static Client fromMap(Map<String, dynamic> m) => Client(
        id: m['id'] as String,
        name: m['name'] as String,
        phone: m['phone'] as String?,
      );

  Map<String, dynamic> toJson() =>
      <String, dynamic>{'id': id, 'name': name, if (phone != null) 'phone': phone};

  static Client fromJson(Map<String, dynamic> j) => Client(
        id: j['id'] as String,
        name: j['name'] as String,
        phone: j['phone'] as String?,
      );

  @override
  bool operator ==(Object other) => other is Client && other.id == id;
  @override
  int get hashCode => id.hashCode;
}
