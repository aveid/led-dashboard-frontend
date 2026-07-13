import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../providers/screens_providers.dart';

/// Диалог активации экрана (FR-4): условия договора аренды.
///
/// Сервер проверит правило FR-4.2 (нужны арендодатель + договор + фото) — если
/// оно нарушено, придёт `ConflictFailure`, и диалог покажет его сообщение как
/// есть (текст ошибки формирует бэк, см. `Screen.activate()`).
class ActivateScreenDialog extends ConsumerStatefulWidget {
  const ActivateScreenDialog({required this.screenId, super.key});

  final String screenId;

  static Future<void> show(BuildContext context, {required String screenId}) {
    return showDialog<void>(
      context: context,
      builder: (context) => ActivateScreenDialog(screenId: screenId),
    );
  }

  @override
  ConsumerState<ActivateScreenDialog> createState() => _ActivateScreenDialogState();
}

class _ActivateScreenDialogState extends ConsumerState<ActivateScreenDialog> {
  final _priceController = TextEditingController();
  DateTime? _startDate = DateTime.now();
  DateTime? _endDate;

  bool _isSubmitting = false;
  String? _error;

  @override
  void dispose() {
    _priceController.dispose();
    super.dispose();
  }

  Future<void> _pickDate({required bool isStart}) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: (isStart ? _startDate : _endDate) ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    setState(() {
      if (isStart) {
        _startDate = picked;
      } else {
        _endDate = picked;
      }
    });
  }

  Future<void> _submit() async {
    final price = double.tryParse(_priceController.text.trim());
    if (price == null) {
      setState(() => _error = 'Стоимость должна быть числом.');
      return;
    }
    if (_startDate == null || _endDate == null) {
      setState(() => _error = 'Укажите даты начала и окончания.');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _error = null;
    });

    final result = await ref.read(activateScreenUseCaseProvider).call(
          id: widget.screenId,
          rentPrice: price,
          startDate: _startDate!,
          endDate: _endDate!,
        );

    if (!mounted) return;

    result.when(
      onSuccess: (_) {
        ref.invalidate(screensProvider);
        Navigator.of(context).pop();
      },
      onFailure: (failure) {
        setState(() {
          _isSubmitting = false;
          _error = failure.message;
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Активировать экран'),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppTextField(
              label: 'Стоимость аренды в месяц (сом)',
              controller: _priceController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              autofocus: true,
            ),
            const SizedBox(height: 12),
            _DateRow(label: 'Дата начала', date: _startDate, onTap: () => _pickDate(isStart: true)),
            const SizedBox(height: 8),
            _DateRow(label: 'Дата окончания', date: _endDate, onTap: () => _pickDate(isStart: false)),
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
          width: 160,
          child: AppButton(
            label: 'Активировать',
            isLoading: _isSubmitting,
            onPressed: _submit,
          ),
        ),
      ],
    );
  }
}

class _DateRow extends StatelessWidget {
  const _DateRow({required this.label, required this.date, required this.onTap});

  final String label;
  final DateTime? date;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Row(
        children: [
          Expanded(child: Text(label, style: Theme.of(context).textTheme.bodyMedium)),
          Text(
            date == null ? 'Выбрать дату' : _formatDate(date!),
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(width: 6),
          const Icon(Icons.calendar_today_outlined, size: 16),
        ],
      ),
    );
  }

  // Ручное форматирование без intl.DateFormat — см. пояснение в screen_card_sheet.dart.
  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day.$month.${date.year}';
  }
}
