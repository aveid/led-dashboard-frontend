import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../../domain/entities/landlord.dart';
import '../providers/landlords_providers.dart';

/// Диалог создания/редактирования арендодателя (FR-8).
///
/// Один виджет на оба сценария: [existing] == null → создание, иначе — правка
/// (поля предзаполнены). Сама мутация идёт через [LandlordsListController], диалог
/// только собирает ввод и показывает ошибку, если она есть.
class LandlordFormDialog extends ConsumerStatefulWidget {
  const LandlordFormDialog({this.existing, super.key});

  final Landlord? existing;

  static Future<void> show(BuildContext context, {Landlord? existing}) {
    return showDialog<void>(
      context: context,
      builder: (context) => LandlordFormDialog(existing: existing),
    );
  }

  @override
  ConsumerState<LandlordFormDialog> createState() => _LandlordFormDialogState();
}

class _LandlordFormDialogState extends ConsumerState<LandlordFormDialog> {
  late final _nameController = TextEditingController(text: widget.existing?.name);
  late final _contactController = TextEditingController(text: widget.existing?.contactPerson);
  late final _phoneController = TextEditingController(text: widget.existing?.phone);
  late final _emailController = TextEditingController(text: widget.existing?.email);

  bool _isSubmitting = false;
  String? _error;

  bool get _isEditing => widget.existing != null;

  @override
  void dispose() {
    _nameController.dispose();
    _contactController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _isSubmitting = true;
      _error = null;
    });

    final controller = ref.read(landlordsListProvider.notifier);
    final result = _isEditing
        ? await controller.updateLandlord(
            id: widget.existing!.id,
            name: _nameController.text,
            contactPerson: _contactController.text,
            phone: _phoneController.text,
            email: _emailController.text,
          )
        : await controller.create(
            name: _nameController.text,
            contactPerson: _contactController.text,
            phone: _phoneController.text,
            email: _emailController.text,
          );

    if (!mounted) return;

    result.when(
      onSuccess: (_) => Navigator.of(context).pop(),
      onFailure: (failure) => setState(() {
        _isSubmitting = false;
        _error = failure.message;
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_isEditing ? 'Редактировать арендодателя' : 'Новый арендодатель'),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppTextField(label: 'Название', controller: _nameController, autofocus: true),
            const SizedBox(height: 12),
            AppTextField(label: 'Контактное лицо', controller: _contactController),
            const SizedBox(height: 12),
            AppTextField(
              label: 'Телефон',
              controller: _phoneController,
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 12),
            AppTextField(
              label: 'Email',
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 13)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
          child: const Text('Отмена'),
        ),
        SizedBox(
          width: 140,
          child: AppButton(
            label: _isEditing ? 'Сохранить' : 'Создать',
            isLoading: _isSubmitting,
            onPressed: _submit,
          ),
        ),
      ],
    );
  }
}
