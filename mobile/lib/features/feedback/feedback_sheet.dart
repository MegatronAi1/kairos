import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kairos_pager/core/api/kairos_api.dart';
import 'package:kairos_pager/core/providers.dart';
import 'package:kairos_pager/core/theme/kairos_theme.dart';
import 'package:kairos_pager/core/theme/tokens.dart';
import 'package:lucide_icons/lucide_icons.dart';

const feedbackCategories = {'bug': 'Bug', 'idea': 'Idea', 'data': 'Data/model', 'other': 'Other'};

/// Opens the feedback form. `page` and `reactorId` tell the team where it came from.
Future<void> showFeedbackSheet(BuildContext context, {required String page, String? reactorId}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => FeedbackSheet(page: page, reactorId: reactorId),
  );
}

class FeedbackSheet extends ConsumerStatefulWidget {
  const FeedbackSheet({required this.page, this.reactorId, super.key});

  final String page;
  final String? reactorId;

  @override
  ConsumerState<FeedbackSheet> createState() => _FeedbackSheetState();
}

class _FeedbackSheetState extends ConsumerState<FeedbackSheet> {
  final _form = GlobalKey<FormState>();
  final _message = TextEditingController();
  String _category = 'idea';
  int _rating = 4;
  bool _sending = false;

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (!_form.currentState!.validate()) return;
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    setState(() => _sending = true);
    try {
      await ref
          .read(apiProvider)
          ?.sendFeedback(
            FeedbackPayload(
              category: _category,
              rating: _rating,
              message: _message.text.trim(),
              page: widget.page,
              reactorId: widget.reactorId,
            ),
          );
      navigator.pop();
      messenger.showSnackBar(const SnackBar(content: Text('Thanks - your feedback reached the Kairos team')));
    } on Exception catch (_) {
      if (!mounted) return;
      setState(() => _sending = false);
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Could not send feedback right now. Check the connection and try again.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        KSpace.s4,
        0,
        KSpace.s4,
        MediaQuery.viewInsetsOf(context).bottom + KSpace.s4,
      ),
      child: Form(
        key: _form,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Send feedback', style: KText.display(KSize.xl)),
              if (widget.reactorId != null)
                Text(
                  'About ${widget.reactorId}',
                  style: KText.ui(KSize.sm, color: KColors.textSecondary),
                ),
              const SizedBox(height: KSpace.s4),
              Text('CATEGORY', style: KText.overline()),
              const SizedBox(height: KSpace.s2),
              Wrap(
                spacing: KSpace.s2,
                children: [
                  for (final e in feedbackCategories.entries)
                    ChoiceChip(
                      label: Text(e.value),
                      selected: _category == e.key,
                      onSelected: (_) => setState(() => _category = e.key),
                    ),
                ],
              ),
              const SizedBox(height: KSpace.s4),
              Text('HOW USEFUL IS KAIROS?', style: KText.overline()),
              Row(
                children: [
                  for (var i = 1; i <= 5; i++)
                    IconButton(
                      key: ValueKey('rating-$i'),
                      tooltip: '$i of 5',
                      onPressed: () => setState(() => _rating = i),
                      icon: Icon(
                        LucideIcons.star,
                        color: i <= _rating ? KColors.stateWatch : KColors.textMuted,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: KSpace.s2),
              TextFormField(
                key: const ValueKey('feedback-message'),
                controller: _message,
                maxLength: 2000,
                minLines: 3,
                maxLines: 6,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Message',
                  hintText: 'What worked, what was confusing, what should change?',
                ),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Please write a short message' : null,
              ),
              const SizedBox(height: KSpace.s3),
              FilledButton(
                onPressed: _sending ? null : _send,
                child: Text(_sending ? 'Sending...' : 'Send'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
