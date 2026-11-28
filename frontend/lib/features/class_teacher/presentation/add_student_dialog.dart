import 'package:flutter/material.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/mobile_widgets.dart';

/// Lets a class teacher admit a student straight into their own class.
/// The server always enrols the student in the class teacher's class.
/// Returns true when a student was added.
Future<bool> showAddStudentDialog(BuildContext context, {required String className}) async {
  final added = await showDialog<bool>(context: context, builder: (_) => AddStudentDialog(className: className));
  return added == true;
}

class AddStudentDialog extends StatefulWidget {
  final String className;
  const AddStudentDialog({super.key, required this.className});

  @override
  State<AddStudentDialog> createState() => _AddStudentDialogState();
}

class _AddStudentDialogState extends State<AddStudentDialog> {
  final _form = GlobalKey<FormState>();
  final _first = TextEditingController();
  final _last = TextEditingController();
  final _admission = TextEditingController();
  final _roll = TextEditingController();
  final _guardian = TextEditingController();
  final _phone = TextEditingController();
  String _gender = 'MALE';
  DateTime? _dob;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    for (final c in [_first, _last, _admission, _roll, _guardian, _phone]) {
      c.dispose();
    }
    super.dispose();
  }

  String? _required(String? v) => (v == null || v.trim().isEmpty) ? 'Required' : null;

  Future<void> _submit() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    if (_guardian.text.trim().isNotEmpty != _phone.text.trim().isNotEmpty) {
      return setState(() => _error = 'Enter both the parent’s name and phone, or neither');
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ApiClient().dio.post('/students', data: {
        'firstName': _first.text.trim(),
        'lastName': _last.text.trim(),
        'gender': _gender,
        if (_dob != null) 'dob': '${_dob!.year}-${_dob!.month.toString().padLeft(2, '0')}-${_dob!.day.toString().padLeft(2, '0')}',
        if (_admission.text.trim().isNotEmpty) 'admissionNo': _admission.text.trim(),
        if (int.tryParse(_roll.text.trim()) != null) 'rollNo': int.parse(_roll.text.trim()),
        if (_guardian.text.trim().isNotEmpty) 'guardianName': _guardian.text.trim(),
        if (_phone.text.trim().isNotEmpty) 'guardianPhone': _phone.text.trim(),
      });
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = apiErrorMessage(e);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const gap = SizedBox(height: AppSpacing.md);
    return AlertDialog(
      title: Text('Add student to ${widget.className}'),
      content: SizedBox(
        width: 460,
        child: Form(
          key: _form,
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              TextFormField(controller: _first, decoration: const InputDecoration(labelText: 'First name'), validator: _required),
              gap,
              TextFormField(controller: _last, decoration: const InputDecoration(labelText: 'Last name'), validator: _required),
              gap,
              DropdownButtonFormField<String>(
                initialValue: _gender,
                decoration: const InputDecoration(labelText: 'Gender'),
                items: const [
                  DropdownMenuItem(value: 'MALE', child: Text('Male')),
                  DropdownMenuItem(value: 'FEMALE', child: Text('Female')),
                  DropdownMenuItem(value: 'OTHER', child: Text('Other')),
                ],
                onChanged: (v) => setState(() => _gender = v ?? _gender),
              ),
              gap,
              OutlinedButton.icon(
                icon: const Icon(Icons.cake_outlined),
                label: Text(_dob == null ? 'Date of birth' : 'Born ${_dob!.day}/${_dob!.month}/${_dob!.year}'),
                onPressed: () async {
                  final now = DateTime.now();
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _dob ?? DateTime(now.year - 12),
                    firstDate: DateTime(now.year - 25),
                    lastDate: now,
                  );
                  if (picked != null) setState(() => _dob = picked);
                },
              ),
              gap,
              Row(children: [
                Expanded(child: TextFormField(controller: _admission, decoration: const InputDecoration(labelText: 'Admission no. (optional)'))),
                const SizedBox(width: AppSpacing.sm),
                SizedBox(
                  width: 96,
                  child: TextFormField(controller: _roll, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Roll no.')),
                ),
              ]),
              gap,
              TextFormField(controller: _guardian, decoration: const InputDecoration(labelText: 'Parent / guardian name (optional)')),
              gap,
              TextFormField(controller: _phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Parent phone (optional)')),
              if (_error != null) ...[gap, MessageBanner(message: _error!)],
            ]),
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: _busy ? null : () => Navigator.pop(context, false), child: const Text('Cancel')),
        FilledButton(
          onPressed: _busy ? null : _submit,
          child: _busy
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text('Add student'),
        ),
      ],
    );
  }
}
