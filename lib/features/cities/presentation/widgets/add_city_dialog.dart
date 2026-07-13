import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/failure.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../providers/cities_providers.dart';

/// Диалог добавления города (раздел «Города / Регионы»).
///
/// Только создание: поле названия + «Сохранить». Дубликат имени
/// ([CityDuplicateFailure]) показывается инлайн под полем.
class AddCityDialog extends ConsumerStatefulWidget {
  const AddCityDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog<void>(
      context: context,
      builder: (context) => const AddCityDialog(),
    );
  }

  @override
  ConsumerState<AddCityDialog> createState() => _AddCityDialogState();
}

class _AddCityDialogState extends ConsumerState<AddCityDialog> {
  final _nameController = TextEditingController();

  bool _isSubmitting = false;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Введите название города.');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _error = null;
    });

    final result = await ref.read(citiesControllerProvider.notifier).add(name);
    if (!mounted) return;

    result.when(
      onSuccess: (_) => Navigator.of(context).pop(),
      onFailure: (failure) => setState(() {
        _isSubmitting = false;
        _error = failure is CityDuplicateFailure
            ? 'Город с таким названием уже существует'
            : failure.message;
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Новый город'),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppTextField(
              label: 'Название',
              controller: _nameController,
              autofocus: true,
              onSubmitted: (_) => _submit(),
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
            label: 'Сохранить',
            isLoading: _isSubmitting,
            onPressed: _submit,
          ),
        ),
      ],
    );
  }
}
