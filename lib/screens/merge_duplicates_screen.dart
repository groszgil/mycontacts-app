import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import '../models/app_contact.dart';
import '../services/storage_service.dart';
import '../utils/theme.dart';

class MergeDuplicatesScreen extends StatefulWidget {
  const MergeDuplicatesScreen({super.key});

  @override
  State<MergeDuplicatesScreen> createState() => _MergeDuplicatesScreenState();
}

class _MergeDuplicatesScreenState extends State<MergeDuplicatesScreen> {
  List<List<AppContact>> _groups = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    setState(() {
      _groups = StorageService.findDuplicates();
      _loading = false;
    });
  }

  Future<void> _merge(List<AppContact> group) async {
    final ok = await showCupertinoDialog<bool>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('מיזוג אנשי קשר'),
        content: Text(
            'ימוזגו ${group.length} אנשי קשר לאיש קשר אחד. הראשון ברשימה ישמר כבסיס.'),
        actions: [
          CupertinoDialogAction(
            child: const Text('ביטול'),
            onPressed: () => Navigator.pop(ctx, false),
          ),
          CupertinoDialogAction(
            child: const Text('מזג'),
            isDefaultAction: true,
            onPressed: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    );
    if (ok == true) {
      await StorageService.mergeContacts(group);
      _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('אנשי הקשר מוזגו בהצלחה')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = AppTheme.primaryOf(context);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('מיזוג כפילויות')),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _groups.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.check_circle_outline,
                            size: 64,
                            color: Colors.green.withValues(alpha: 0.7)),
                        const SizedBox(height: 16),
                        const Text('לא נמצאו כפילויות!',
                            style: TextStyle(
                                fontSize: 18, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 8),
                        const Text('כל אנשי הקשר שלך ייחודיים',
                            style: TextStyle(color: AppTheme.textLight)),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _groups.length,
                    itemBuilder: (context, i) {
                      final group = _groups[i];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF252540)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: primary.withValues(alpha: 0.08),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            )
                          ],
                        ),
                        child: Column(
                          children: [
                            ...group.map((c) => ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor:
                                        primary.withValues(alpha: 0.15),
                                    child: Text(
                                      c.name.isNotEmpty ? c.name[0] : '?',
                                      style: TextStyle(
                                          color: primary,
                                          fontWeight: FontWeight.w700),
                                    ),
                                  ),
                                  title: Text(
                                    c.name,
                                    style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: isDark
                                            ? Colors.white
                                            : AppTheme.textDark),
                                  ),
                                  subtitle: Text(
                                    c.effectivePrimaryPhone,
                                    style: const TextStyle(
                                        color: AppTheme.textLight),
                                  ),
                                )),
                            const Divider(height: 1),
                            ListTile(
                              leading: Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: primary.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(Icons.merge_type_rounded,
                                    color: primary),
                              ),
                              title: Text(
                                'מזג ${group.length} אנשי קשר',
                                style: TextStyle(
                                    color: primary,
                                    fontWeight: FontWeight.w700),
                              ),
                              onTap: () => _merge(group),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
      ),
    );
  }
}
