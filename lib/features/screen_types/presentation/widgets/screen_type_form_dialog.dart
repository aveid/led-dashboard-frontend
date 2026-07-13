import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../../domain/entities/screen_type.dart';
import '../providers/screen_types_providers.dart';

/// Диалог создания/редактирования типа экрана.
///
/// Один виджет на оба сценария: [existing] == null → создание, иначе — правка
/// (поля предзаполнены). Поле «Код» опционально и спрятано за «Дополнительно»,
/// чтобы не усложнять типичный сценарий (только название). Серверная ошибка
/// (`422`, частая — дубль названия) показывается инлайн под полями.
class ScreenTypeFormDialog extends ConsumerStatefulWidget {
  const ScreenTypeFormDialog({this.existing, super.key});

  final ScreenType? existing;

  static Future<void> show(BuildContext context, {ScreenType? existing}) {
    return showDialog<void>(
      context: context,
      builder: (context) => ScreenTypeFormDialog(existing: existing),
    );
  }

  @override
  ConsumerState<ScreenTypeFormDialog> createState() => _ScreenTypeFormDialogState();
}

class _ScreenTypeFormDialogState extends ConsumerState<ScreenTypeFormDialog> {
  late final _nameController = TextEditingController(text: widget.existing?.name);
  late final _codeController = TextEditingController(text: widget.existing?.code);

  /// Раскрывать ли блок «Дополнительно» (код). Открыт сразу, если у типа уже есть
  /// код (при редактировании), чтобы значение было видно.
  late bool _showAdvanced = (widget.existing?.code ?? '').isNotEmpty;

  bool _isSubmitting = false;
  String? _error;

  bool get _isEditing => widget.existing != null;

  /// Паттерн кода из контракта: `^[a-z0-9_-]+$`, ≤50 (проверяем на клиенте до
  /// отправки, серверную ошибку тоже показываем).
  static final _codePattern = RegExp(r'^[a-z0-9_-]+$');

  @override
  void dispose() {
    _nameController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    final code = _codeController.text.trim();

    if (name.isEmpty) {
      setState(() => _error = 'Введите название типа.');
      return;
    }
    if (name.length > 100) {
      setState(() => _error = 'Название не длиннее 100 символов.');
      return;
    }
    if (code.isNotEmpty) {
      if (code.length > 50) {
        setState(() => _error = 'Код не длиннее 50 символов.');
        return;
      }
      if (!_codePattern.hasMatch(code)) {
        setState(() => _error = 'Код: только a-z, 0-9, «_» и «-».');
        return;
      }
    }

    setState(() {
      _isSubmitting = true;
      _error = null;
    });

    final controller = ref.read(screenTypesControllerProvider.notifier);
    // При редактировании код можно очистить: если поле пустое — отправляем ''
    // (бэк снимет код). При создании пустой код просто не шлём (см. датасорс).
    final result = _isEditing
        ? await controller.edit(
            widget.existing!.id,
            name: name,
            code: code,
          )
        : await controller.add(
            name: name,
            code: code.isEmpty ? null : code,
          );

    if (!mounted) return;

    result.when(
      onSuccess: (_) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_isEditing ? 'Тип обновлён.' : 'Тип добавлен.')),
        );
      },
      onFailure: (failure) => setState(() {
        _isSubmitting = false;
        _error = failure.message;
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_isEditing ? 'Редактировать тип' : 'Новый тип'),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppTextField(
              label: 'Название',
              controller: _nameController,
              autofocus: true,
              hintText: 'Напр. Вертикальный',
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 8),
            if (!_showAdvanced)
              TextButton.icon(
                onPressed: () => setState(() => _showAdvanced = true),
                icon: const Icon(Icons.tune, size: 16),
                label: const Text('Дополнительно'),
              )
            else ...[
              const SizedBox(height: 4),
              AppTextField(
                label: 'Код (опционально)',
                controller: _codeController,
                hintText: 'напр. vertical',
                onSubmitted: (_) => _submit(),
              ),
            ],
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
