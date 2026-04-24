import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

class LaunchHelper {
  static const _channel = MethodChannel('com.mycontacts/native');

  static Future<void> makeCall(String phone) async {
    final cleaned = _cleanPhone(phone);
    final uri = Uri(scheme: 'tel', path: cleaned);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  static Future<void> sendSms(String phone) async {
    final cleaned = _cleanPhone(phone);
    final uri = Uri(scheme: 'sms', path: cleaned);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  static Future<void> openWhatsApp(String phone) async {
    // wa.me accepts both formats:  wa.me/+972509547074  or  wa.me/972509547074
    // Using the + prefix form as it is the most reliable.
    final international = _toWhatsAppNumber(phone);
    final uri = Uri.parse('https://wa.me/+$international');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  /// Normalises any Israeli phone number to digits-only international format
  /// (no leading +). The caller adds the + to the URL.
  ///
  /// Examples:
  ///   0509547074    → 972509547074
  ///   +972509547074 → 972509547074
  ///   972509547074  → 972509547074
  static String _toWhatsAppNumber(String phone) {
    String cleaned = phone.replaceAll(RegExp(r'[\s\-\(\)]'), '');
    if (cleaned.startsWith('+')) cleaned = cleaned.substring(1);
    if (cleaned.startsWith('0')) cleaned = '972${cleaned.substring(1)}';
    return cleaned;
  }

  static Future<void> sendEmail(String email, {String? subject}) async {
    final uri = Uri(
      scheme: 'mailto',
      path: email,
      query: subject != null ? 'subject=${Uri.encodeComponent(subject)}' : null,
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  /// Donates a Siri Shortcut so Siri learns "call [name]" via this app.
  static Future<void> donateSiriShortcut(String name, String phone) async {
    try {
      await _channel.invokeMethod('donateSiriShortcut', {
        'name': name,
        'phone': _cleanPhone(phone),
      });
    } catch (_) {
      // Silently ignore if native side not available
    }
  }

  /// Open address in Google Maps (web URL works on all platforms)
  static Future<void> openGoogleMaps(String address) async {
    final encoded = Uri.encodeComponent(address);
    final uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=$encoded');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  /// Open address in Waze
  static Future<void> openWaze(String address) async {
    final encoded = Uri.encodeComponent(address);
    // Try waze:// scheme first, fall back to web
    final wazeUri = Uri.parse('waze://?q=$encoded&navigate=yes');
    if (await canLaunchUrl(wazeUri)) {
      await launchUrl(wazeUri, mode: LaunchMode.externalApplication);
    } else {
      final webUri = Uri.parse('https://waze.com/ul?q=$encoded');
      if (await canLaunchUrl(webUri)) {
        await launchUrl(webUri, mode: LaunchMode.externalApplication);
      }
    }
  }

  /// Open address in Apple Maps (iOS) / Google Maps (Android fallback)
  static Future<void> openAppleMaps(String address) async {
    final encoded = Uri.encodeComponent(address);
    final uri = Uri.parse('https://maps.apple.com/?q=$encoded');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  static String _cleanPhone(String phone) {
    return phone.replaceAll(RegExp(r'[\s\-()]'), '');
  }
}
