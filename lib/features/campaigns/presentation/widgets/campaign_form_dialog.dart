import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../../domain/entities/campaign.dart';
import '../providers/campaigns_providers.dart';

/// Диалог создания/переименования кампании (FR-3.10).
class CampaignFormDialog extends ConsumerStatefulWidget {
  const CampaignFormDialog({this.existing, super.key});

  final Campaign? existing;

  static Future<void> show(BuildContext context, {Campaign? existing}) {
    return showDialog<void>(
      context: context,
      builder: (context) => CampaignFormDialog(existing: existing),
    );
  }

  @override
  ConsumerState<CampaignFormDialog> createState() => _CampaignFormDialogState();
}

class _CampaignFormDialogState extends ConsumerState<CampaignFormDialog> {
  late final _nameController = TextEditingController(text: widget.existing?.name);

  bool _isSubmitting = false;
  String? _error;

  bool get _isEditing => widget.existing != null;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _isSubmitting = true;
      _error = null;
    });

    final controller = ref.read(campaignsListProvider.notifier);
    final result = _isEditing
        ? await controller.updateCampaign(id: widget.existing!.id, name: _nameController.text)
        : await controller.create(_nameController.text);

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
      title: Text(_isEditing ? 'Переименовать кампанию' : 'Новая кампания'),
      content: SizedBox(
        width: 320,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppTextField(label: 'Название', controller: _nameController, autofocus: true),
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
