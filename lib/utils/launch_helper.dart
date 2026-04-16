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
    final cleaned = _cleanPhone(phone).replaceAll('+', '');
    final uri = Uri.parse('https://wa.me/$cleaned');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
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

  static String _cleanPhone(String phone) {
    return phone.replaceAll(RegExp(r'[\s\-()]'), '');
  }
}
