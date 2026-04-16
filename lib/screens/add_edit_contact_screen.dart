import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../models/app_contact.dart';
import '../models/category.dart';
import '../services/storage_service.dart';
import '../utils/theme.dart';

const _phoneOptions = ['נייד', 'עבודה', 'בית', 'כללי'];
const _emailOptions = ['עבודה', 'בית', 'כללי'];

class AddEditContactScreen extends StatefulWidget {
  final AppContact? contact;
  final String? prefillName;
  // Prefill lists when importing from phone contacts
  final List<String>? prefillPhones;
  final List<String>? prefillPhoneLabels;
  final List<String>? prefillEmails;
  final List<String>? prefillEmailLabels;
  final String? prefillPhotoPath;

  const AddEditContactScreen({
    super.key,
    this.contact,
    this.prefillName,
    this.prefillPhones,
    this.prefillPhoneLabels,
    this.prefillEmails,
    this.prefillEmailLabels,
    this.prefillPhotoPath,
  });

  @override
  State<AddEditContactScreen> createState() => _AddEditContactScreenState();
}

class _AddEditContactScreenState extends State<AddEditContactScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _nicknameCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  DateTime? _birthday;

  final List<TextEditingController> _phoneCtrs = [];
  final List<String> _phoneLabels = [];
  int _primaryPhoneIdx = 0;

  final List<TextEditingController> _emailCtrs = [];
  final List<String> _emailLabels = [];

  String? _localPhotoPath;
  List<String> _selectedCategoryIds = [];
  List<Category> _categories = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _categories = StorageService.getAllCategories()
        .where((c) => c.id != 'all')
        .toList();

    if (widget.contact != null) {
      final c = widget.contact!;
      _nameCtrl.text = c.name;
      _nicknameCtrl.text = c.nickname ?? '';
      _birthday = c.birthday;
      _notesCtrl.text = c.notes ?? '';
      _localPhotoPath = c.localPhotoPath;
      _selectedCategoryIds = List.from(c.categoryIds);
      _primaryPhoneIdx = c.primaryPhoneIndex.clamp(0, c.phones.isEmpty ? 0 : c.phones.length - 1);

      // Phones
      if (c.phones.isNotEmpty) {
        for (int i = 0; i < c.phones.length; i++) {
          _phoneCtrs.add(TextEditingController(text: c.phones[i]));
          _phoneLabels.add(
            i < c.phoneLabels.length ? c.phoneLabels[i] : 'נייד',
          );
        }
      } else {
        // Legacy: only primaryPhone was stored
        _phoneCtrs.add(TextEditingController(text: c.primaryPhone));
        _phoneLabels.add('נייד');
      }

      // Emails
      if (c.emails.isNotEmpty) {
        for (int i = 0; i < c.emails.length; i++) {
          _emailCtrs.add(TextEditingController(text: c.emails[i]));
          _emailLabels.add(
            i < c.emailLabels.length ? c.emailLabels[i] : 'כללי',
          );
        }
      } else if (c.email != null && c.email!.isNotEmpty) {
        _emailCtrs.add(TextEditingController(text: c.email));
        _emailLabels.add('כללי');
      }
    } else {
      // Prefill from import
      _nameCtrl.text = widget.prefillName ?? '';
      _localPhotoPath = widget.prefillPhotoPath;

      final phones = widget.prefillPhones;
      final phoneLbls = widget.prefillPhoneLabels;
      if (phones != null && phones.isNotEmpty) {
        for (int i = 0; i < phones.length; i++) {
          _phoneCtrs.add(TextEditingController(text: phones[i]));
          _phoneLabels.add(
            (phoneLbls != null && i < phoneLbls.length)
                ? phoneLbls[i]
                : 'נייד',
          );
        }
      }

      final emails = widget.prefillEmails;
      final emailLbls = widget.prefillEmailLabels;
      if (emails != null && emails.isNotEmpty) {
        for (int i = 0; i < emails.length; i++) {
          _emailCtrs.add(TextEditingController(text: emails[i]));
          _emailLabels.add(
            (emailLbls != null && i < emailLbls.length)
                ? emailLbls[i]
                : 'כללי',
          );
        }
      }
    }

    // Always ensure at least one phone row
    if (_phoneCtrs.isEmpty) {
      _phoneCtrs.add(TextEditingController());
      _phoneLabels.add('נייד');
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _nicknameCtrl.dispose();
    _notesCtrl.dispose();
    for (final c in _phoneCtrs) c.dispose();
    for (final c in _emailCtrs) c.dispose();
    super.dispose();
  }

  // ── Phone helpers ──────────────────────────────────────────────────────────

  void _addPhone() {
    HapticFeedback.lightImpact();
    setState(() {
      _phoneCtrs.add(TextEditingController());
      _phoneLabels.add('נייד');
    });
  }

  void _removePhone(int i) {
    setState(() {
      _phoneCtrs[i].dispose();
      _phoneCtrs.removeAt(i);
      _phoneLabels.removeAt(i);
      if (_primaryPhoneIdx >= _phoneCtrs.length) {
        _primaryPhoneIdx = _phoneCtrs.isEmpty ? 0 : _phoneCtrs.length - 1;
      } else if (_primaryPhoneIdx > i) {
        _primaryPhoneIdx--;
      }
    });
  }

  // ── Email helpers ──────────────────────────────────────────────────────────

  void _addEmail() {
    HapticFeedback.lightImpact();
    setState(() {
      _emailCtrs.add(TextEditingController());
      _emailLabels.add('כללי');
    });
  }

  void _removeEmail(int i) {
    setState(() {
      _emailCtrs[i].dispose();
      _emailCtrs.removeAt(i);
      _emailLabels.removeAt(i);
    });
  }

  // ── Photo ──────────────────────────────────────────────────────────────────

  Future<void> _pickImage() async {
    final source = await showCupertinoModalPopup<ImageSource>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: const Text('בחר תמונה'),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(ctx, ImageSource.camera),
            child: const Text('מצלמה'),
          ),
          CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(ctx, ImageSource.gallery),
            child: const Text('גלריה'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          isDestructiveAction: true,
          onPressed: () => Navigator.pop(ctx),
          child: const Text('ביטול'),
        ),
      ),
    );
    if (source == null) return;

    final picked =
        await ImagePicker().pickImage(source: source, imageQuality: 80);
    if (picked == null) return;

    final appDir = await getApplicationDocumentsDirectory();
    final fileName = 'contact_${const Uuid().v4()}.jpg';
    final saved = await File(picked.path).copy(p.join(appDir.path, fileName));

    if (_localPhotoPath != null) {
      final old = File(_localPhotoPath!);
      if (await old.exists()) await old.delete();
    }
    setState(() => _localPhotoPath = saved.path);
  }

  Future<void> _removePhoto() async {
    if (_localPhotoPath != null) {
      final f = File(_localPhotoPath!);
      if (await f.exists()) await f.delete();
    }
    setState(() => _localPhotoPath = null);
  }

  // ── Save ───────────────────────────────────────────────────────────────────

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    // Collect non-empty phones/emails
    final phones = _phoneCtrs.map((c) => c.text.trim()).toList();
    final phoneLabels = List<String>.from(_phoneLabels);
    final emails =
        _emailCtrs.map((c) => c.text.trim()).where((e) => e.isNotEmpty).toList();
    final emailLabels = <String>[];
    for (int i = 0; i < _emailCtrs.length; i++) {
      if (_emailCtrs[i].text.trim().isNotEmpty) {
        emailLabels.add(_emailLabels[i]);
      }
    }

    final primaryIdx = _primaryPhoneIdx.clamp(0, phones.isEmpty ? 0 : phones.length - 1);

    setState(() => _isLoading = true);
    try {
      final contact = AppContact(
        id: widget.contact?.id ?? const Uuid().v4(),
        name: _nameCtrl.text.trim(),
        primaryPhone: phones.isNotEmpty ? phones[primaryIdx] : '',
        phones: phones,
        phoneLabels: phoneLabels,
        primaryPhoneIndex: primaryIdx,
        emails: emails,
        emailLabels: emailLabels,
        localPhotoPath: _localPhotoPath,
        categoryIds: _selectedCategoryIds,
        sortOrder: widget.contact?.sortOrder ?? DateTime.now().millisecondsSinceEpoch,
        notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
        nickname: _nicknameCtrl.text.trim().isEmpty
            ? null
            : _nicknameCtrl.text.trim(),
        birthdayMillis: _birthday?.millisecondsSinceEpoch,
      );
      await StorageService.saveContact(contact);
      if (mounted) Navigator.pop(context, true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.contact != null;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: Text(isEdit ? 'עריכת איש קשר' : 'איש קשר חדש'),
          actions: [
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.all(16),
                child: CupertinoActivityIndicator(),
              )
            else
              TextButton(
                onPressed: _save,
                child: const Text(
                  'שמור',
                  style: TextStyle(
                    color: AppTheme.primary,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
          ],
        ),
        body: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              // Photo
              Center(child: _buildPhotoPicker()),
              const SizedBox(height: 28),

              // Name
              _label('שם מלא'),
              const SizedBox(height: 8),
              TextFormField(
                controller: _nameCtrl,
                textDirection: TextDirection.rtl,
                decoration: const InputDecoration(
                  hintText: 'הכנס שם',
                  prefixIcon:
                      Icon(Icons.person_outline, color: AppTheme.primary),
                ),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'שם הוא שדה חובה' : null,
              ),
              const SizedBox(height: 16),

              // Nickname
              TextFormField(
                controller: _nicknameCtrl,
                textDirection: TextDirection.rtl,
                decoration: InputDecoration(
                  hintText: 'כינוי (אופציונלי)',
                  prefixIcon: const Icon(Icons.badge_outlined,
                      color: AppTheme.textLight),
                  fillColor: isDark
                      ? const Color(0xFF2A2A4A)
                      : const Color(0xFFF0EFFE),
                ),
              ),
              const SizedBox(height: 16),

              // Birthday
              _buildBirthdayPicker(isDark),
              const SizedBox(height: 24),

              // ── Phones ──────────────────────────────────────────────────
              _SectionHeader(
                icon: Icons.phone_rounded,
                title: 'טלפונים',
                trailing: TextButton.icon(
                  onPressed: _addPhone,
                  icon: const Icon(Icons.add, size: 16, color: AppTheme.primary),
                  label: const Text('הוסף',
                      style: TextStyle(color: AppTheme.primary, fontSize: 14)),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              for (int i = 0; i < _phoneCtrs.length; i++)
                _PhoneRow(
                  key: ValueKey('phone_$i'),
                  controller: _phoneCtrs[i],
                  label: _phoneLabels[i],
                  isPrimary: i == _primaryPhoneIdx,
                  canDelete: _phoneCtrs.length > 1,
                  isDark: isDark,
                  onLabelChanged: (val) =>
                      setState(() => _phoneLabels[i] = val),
                  onSetPrimary: () =>
                      setState(() => _primaryPhoneIdx = i),
                  onDelete: () => _removePhone(i),
                  isRequired: i == _primaryPhoneIdx,
                ),

              const SizedBox(height: 24),

              // ── Emails ───────────────────────────────────────────────────
              _SectionHeader(
                icon: Icons.mail_rounded,
                title: 'מייל',
                trailing: TextButton.icon(
                  onPressed: _addEmail,
                  icon: const Icon(Icons.add, size: 16, color: AppTheme.primary),
                  label: const Text('הוסף',
                      style: TextStyle(color: AppTheme.primary, fontSize: 14)),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              if (_emailCtrs.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    'אין כתובות מייל',
                    style: TextStyle(
                      color: AppTheme.textLight,
                      fontSize: 13,
                    ),
                  ),
                )
              else
                for (int i = 0; i < _emailCtrs.length; i++)
                  _EmailRow(
                    key: ValueKey('email_$i'),
                    controller: _emailCtrs[i],
                    label: _emailLabels[i],
                    isDark: isDark,
                    onLabelChanged: (val) =>
                        setState(() => _emailLabels[i] = val),
                    onDelete: () => _removeEmail(i),
                  ),
              const SizedBox(height: 24),

              // Notes
              _label('הערות אישיות (אופציונלי)'),
              const SizedBox(height: 8),
              TextFormField(
                controller: _notesCtrl,
                textDirection: TextDirection.rtl,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'למשל: יום הולדת, לא לפני 9...',
                  prefixIcon: const Icon(Icons.note_outlined,
                      color: AppTheme.textLight),
                  alignLabelWithHint: true,
                  fillColor: isDark
                      ? const Color(0xFF2A2A4A)
                      : const Color(0xFFF0EFFE),
                ),
              ),
              const SizedBox(height: 24),

              // Categories
              if (_categories.isNotEmpty) ...[
                _label('קטגוריות'),
                const SizedBox(height: 12),
                _buildCategoryChips(),
                const SizedBox(height: 24),
              ],

              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _save,
                  child: Text(isEdit ? 'עדכן' : 'הוסף איש קשר'),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBirthdayPicker(bool isDark) {
    return GestureDetector(
      onTap: _pickBirthday,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isDark
              ? const Color(0xFF2A2A4A)
              : const Color(0xFFF0EFFE),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: _birthday != null
                ? AppTheme.primary.withValues(alpha: 0.4)
                : Colors.transparent,
          ),
        ),
        child: Row(
          children: [
            const Icon(Icons.cake_rounded,
                color: AppTheme.primary, size: 22),
            const SizedBox(width: 12),
            Text(
              _birthday != null
                  ? '${_birthday!.day}/${_birthday!.month}/${_birthday!.year}'
                  : 'יום הולדת (אופציונלי)',
              style: TextStyle(
                color: _birthday != null
                    ? (isDark ? Colors.white : AppTheme.textDark)
                    : AppTheme.textLight,
                fontSize: 15,
              ),
            ),
            const Spacer(),
            if (_birthday != null)
              GestureDetector(
                onTap: () => setState(() => _birthday = null),
                child: const Icon(Icons.close,
                    color: AppTheme.textLight, size: 18),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickBirthday() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _birthday ?? DateTime(2000, 1, 1),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      helpText: 'בחר יום הולדת',
      cancelText: 'ביטול',
      confirmText: 'אישור',
    );
    if (picked != null) setState(() => _birthday = picked);
  }

  Future<void> _adjustPhoto() async {
    if (_localPhotoPath == null) return;
    final result = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => _ImageAdjustPage(imagePath: _localPhotoPath!),
      ),
    );
    if (result != null && mounted) {
      setState(() => _localPhotoPath = result);
    }
  }

  Widget _buildPhotoPicker() {
    final hasPhoto =
        _localPhotoPath != null && File(_localPhotoPath!).existsSync();
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: _pickImage,
          child: Stack(
            alignment: Alignment.bottomLeft,
            children: [
              Container(
                width: 110,
                height: 110,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.primary.withValues(alpha: 0.1),
                  border: Border.all(
                      color: AppTheme.primary.withValues(alpha: 0.3), width: 2),
                ),
                child: ClipOval(
                  child: hasPhoto
                      ? Image.file(File(_localPhotoPath!), fit: BoxFit.cover)
                      : const Icon(Icons.person,
                          size: 52, color: AppTheme.primary),
                ),
              ),
              if (hasPhoto)
                GestureDetector(
                  onTap: _removePhoto,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child:
                        const Icon(Icons.close, color: Colors.white, size: 14),
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppTheme.primary,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: const Icon(Icons.camera_alt,
                      color: Colors.white, size: 16),
                ),
            ],
          ),
        ),
        if (hasPhoto) ...[
          const SizedBox(height: 8),
          GestureDetector(
            onTap: _adjustPhoto,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: AppTheme.primary.withValues(alpha: 0.3)),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.crop_rotate,
                      size: 15, color: AppTheme.primary),
                  SizedBox(width: 5),
                  Text(
                    'ערוך תמונה',
                    style: TextStyle(
                        fontSize: 13,
                        color: AppTheme.primary,
                        fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _label(String text) => Text(
        text,
        style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppTheme.textMedium),
      );

  Widget _buildCategoryChips() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _categories.map((cat) {
        final selected = _selectedCategoryIds.contains(cat.id);
        final color = AppTheme.colorFromValue(cat.colorValue);
        return FilterChip(
          label: Text(cat.name),
          selected: selected,
          onSelected: (val) => setState(() {
            if (val) {
              _selectedCategoryIds.add(cat.id);
            } else {
              _selectedCategoryIds.remove(cat.id);
            }
          }),
          backgroundColor: color.withValues(alpha: 0.1),
          selectedColor: color.withValues(alpha: 0.25),
          checkmarkColor: color,
          labelStyle: TextStyle(
            color: selected ? color : AppTheme.textMedium,
            fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
          ),
          side: BorderSide(
            color: selected ? color : Colors.transparent,
            width: 1.5,
          ),
        );
      }).toList(),
    );
  }
}

// ── Section header ─────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget? trailing;
  const _SectionHeader(
      {required this.icon, required this.title, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: AppTheme.primary, size: 18),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppTheme.textDark),
        ),
        const Spacer(),
        if (trailing != null) trailing!,
      ],
    );
  }
}

// ── Phone row ──────────────────────────────────────────────────────────────

class _PhoneRow extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final bool isPrimary;
  final bool canDelete;
  final bool isDark;
  final bool isRequired;
  final ValueChanged<String> onLabelChanged;
  final VoidCallback onSetPrimary;
  final VoidCallback onDelete;

  const _PhoneRow({
    super.key,
    required this.controller,
    required this.label,
    required this.isPrimary,
    required this.canDelete,
    required this.isDark,
    required this.onLabelChanged,
    required this.onSetPrimary,
    required this.onDelete,
    this.isRequired = false,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isPrimary
            ? AppTheme.primary.withValues(alpha: 0.06)
            : (isDark ? const Color(0xFF252540) : Colors.white),
        border: Border.all(
          color: isPrimary
              ? AppTheme.primary.withValues(alpha: 0.35)
              : Colors.grey.withValues(alpha: 0.2),
          width: 1.5,
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          // Primary star
          GestureDetector(
            onTap: onSetPrimary,
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: Icon(
                isPrimary ? Icons.star_rounded : Icons.star_border_rounded,
                color:
                    isPrimary ? AppTheme.primary : AppTheme.textLight,
                size: 22,
              ),
            ),
          ),
          // Label dropdown
          _LabelDropdown(
            value: label,
            options: _phoneOptions,
            onChanged: onLabelChanged,
          ),
          const SizedBox(width: 6),
          // Phone field
          Expanded(
            child: TextFormField(
              controller: controller,
              keyboardType: TextInputType.phone,
              textDirection: TextDirection.ltr,
              textAlign: TextAlign.start,
              decoration: const InputDecoration(
                hintText: '050-0000000',
                filled: false,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(vertical: 12),
              ),
              validator: isRequired
                  ? (v) => v == null || v.trim().isEmpty ? 'שדה חובה' : null
                  : null,
            ),
          ),
          // Delete
          if (canDelete)
            GestureDetector(
              onTap: onDelete,
              child: const Padding(
                padding: EdgeInsets.all(6),
                child: Icon(Icons.remove_circle_outline,
                    color: Colors.red, size: 20),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Email row ──────────────────────────────────────────────────────────────

class _EmailRow extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final bool isDark;
  final ValueChanged<String> onLabelChanged;
  final VoidCallback onDelete;

  const _EmailRow({
    super.key,
    required this.controller,
    required this.label,
    required this.isDark,
    required this.onLabelChanged,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF252540) : Colors.white,
        border: Border.all(color: Colors.grey.withValues(alpha: 0.2), width: 1.5),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Padding(
            padding: EdgeInsets.all(6),
            child: Icon(Icons.mail_outline,
                color: Color(0xFFEA4335), size: 20),
          ),
          _LabelDropdown(
            value: label,
            options: _emailOptions,
            onChanged: onLabelChanged,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: TextFormField(
              controller: controller,
              keyboardType: TextInputType.emailAddress,
              textDirection: TextDirection.ltr,
              decoration: const InputDecoration(
                hintText: 'example@mail.com',
                filled: false,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          GestureDetector(
            onTap: onDelete,
            child: const Padding(
              padding: EdgeInsets.all(6),
              child: Icon(Icons.remove_circle_outline,
                  color: Colors.red, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Image Adjust Page ──────────────────────────────────────────────────────

class _ImageAdjustPage extends StatefulWidget {
  final String imagePath;
  const _ImageAdjustPage({required this.imagePath});

  @override
  State<_ImageAdjustPage> createState() => _ImageAdjustPageState();
}

class _ImageAdjustPageState extends State<_ImageAdjustPage> {
  final TransformationController _controller = TransformationController();
  final GlobalKey _repaintKey = GlobalKey();
  bool _saving = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _confirm() async {
    setState(() => _saving = true);
    try {
      final boundary = _repaintKey.currentContext!.findRenderObject()
          as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;
      final pngBytes = byteData.buffer.asUint8List();
      final appDir = await getApplicationDocumentsDirectory();
      final fileName = 'contact_adj_${const Uuid().v4()}.png';
      final file = File(p.join(appDir.path, fileName));
      await file.writeAsBytes(pngBytes);
      if (mounted) Navigator.pop(context, file.path);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('שגיאה בשמירה: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final cropSize = screenSize.width * 0.9;

    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D0D0D),
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context, null),
        ),
        title: const Text(
          'ערוך תמונה',
          style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w600),
        ),
        actions: [
          if (_saving)
            const Padding(
              padding: EdgeInsets.all(16),
              child: CupertinoActivityIndicator(color: Colors.white),
            )
          else
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: TextButton(
                onPressed: _confirm,
                style: TextButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                ),
                child: const Text(
                  'אישור',
                  style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700),
                ),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          const SizedBox(height: 12),
          // Instruction pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
            decoration: BoxDecoration(
              color: Colors.white10,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.touch_app_outlined, color: Colors.white54, size: 14),
                SizedBox(width: 6),
                Text('צבוט לזום  •  גרור להזזה', style: TextStyle(color: Colors.white54, fontSize: 13)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Crop area — black bg so letterbox areas are clearly empty
          Center(
            child: Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: SizedBox(
                    width: cropSize,
                    height: cropSize,
                    child: RepaintBoundary(
                      key: _repaintKey,
                      // Black background fills letterbox areas
                      child: ColoredBox(
                        color: Colors.black,
                        child: InteractiveViewer(
                          transformationController: _controller,
                          // Allow zooming out slightly so user can see full image
                          minScale: 0.3,
                          maxScale: 8.0,
                          // No boundary — image can be panned freely
                          boundaryMargin: const EdgeInsets.all(double.infinity),
                          child: Center(
                            child: Image.file(
                              File(widget.imagePath),
                              // contain = entire image visible, no cropping
                              fit: BoxFit.contain,
                              width: cropSize,
                              height: cropSize,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                // White corner guides — IgnorePointer so pinch/pan goes to InteractiveViewer
                IgnorePointer(
                  child: SizedBox(
                    width: cropSize,
                    height: cropSize,
                    child: CustomPaint(painter: _CropCornerPainter()),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          // Helper row: reset + hint about zoom to fill
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextButton.icon(
                onPressed: () => _controller.value = Matrix4.identity(),
                icon: const Icon(Icons.refresh_rounded, color: Colors.white54, size: 18),
                label: const Text('איפוס', style: TextStyle(color: Colors.white54, fontSize: 13)),
              ),
              const SizedBox(width: 16),
              TextButton.icon(
                onPressed: () {
                  // Zoom to fill: scale up so image fills the square
                  _controller.value = Matrix4.identity()..scale(1.5);
                },
                icon: const Icon(Icons.zoom_in_rounded, color: Colors.white54, size: 18),
                label: const Text('מלא מסגרת', style: TextStyle(color: Colors.white54, fontSize: 13)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// Corner guide painter for crop area
class _CropCornerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    const margin = 10.0;
    const len = 22.0;

    // Top-left
    canvas.drawLine(Offset(margin, margin + len), Offset(margin, margin), paint);
    canvas.drawLine(Offset(margin, margin), Offset(margin + len, margin), paint);
    // Top-right
    canvas.drawLine(Offset(size.width - margin - len, margin), Offset(size.width - margin, margin), paint);
    canvas.drawLine(Offset(size.width - margin, margin), Offset(size.width - margin, margin + len), paint);
    // Bottom-left
    canvas.drawLine(Offset(margin, size.height - margin - len), Offset(margin, size.height - margin), paint);
    canvas.drawLine(Offset(margin, size.height - margin), Offset(margin + len, size.height - margin), paint);
    // Bottom-right
    canvas.drawLine(Offset(size.width - margin - len, size.height - margin), Offset(size.width - margin, size.height - margin), paint);
    canvas.drawLine(Offset(size.width - margin, size.height - margin - len), Offset(size.width - margin, size.height - margin), paint);
  }

  @override
  bool shouldRepaint(_) => false;
}

// ── Label dropdown ─────────────────────────────────────────────────────────

class _LabelDropdown extends StatelessWidget {
  final String value;
  final List<String> options;
  final ValueChanged<String> onChanged;

  const _LabelDropdown(
      {required this.value, required this.options, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: AppTheme.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isDense: true,
          icon: const Icon(Icons.arrow_drop_down,
              size: 16, color: AppTheme.primary),
          style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppTheme.primary,
              fontFamily: 'SF Pro Display'),
          items: options
              .map((o) => DropdownMenuItem(value: o, child: Text(o)))
              .toList(),
          onChanged: (val) {
            if (val != null) onChanged(val);
          },
        ),
      ),
    );
  }
}
