import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kairos_pager/core/fleet_providers.dart';
import 'package:kairos_pager/core/models/chat.dart';
import 'package:kairos_pager/core/process_providers.dart';
import 'package:kairos_pager/core/providers.dart';
import 'package:kairos_pager/core/theme/kairos_theme.dart';
import 'package:kairos_pager/core/theme/tokens.dart';
import 'package:kairos_pager/widgets/chips.dart';
import 'package:kairos_pager/widgets/ui.dart';
import 'package:lucide_icons/lucide_icons.dart';

/// Ask Kairos: the copilot (Claude on Amazon Bedrock) answers from the Kairos models,
/// streamed over Server-Sent Events.
class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key, this.reactorId, this.inTab = false});

  final String? reactorId;

  /// Shown as a tab (no back button, room for the floating nav bar).
  final bool inTab;

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  final _messages = <ChatMessage>[];
  String? _context;
  String? _activity;
  bool _busy = false;
  CancelToken? _cancel;
  StreamSubscription<ChatEvent>? _sub;

  @override
  void initState() {
    super.initState();
    _context = widget.reactorId;
  }

  @override
  void dispose() {
    _cancel?.cancel();
    unawaited(_sub?.cancel());
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  List<String> get _suggestions {
    final id = _context;
    return id == null
        ? const [
            'Which reactor needs me most right now?',
            'Where can we save energy today?',
            'How accurate are your yield forecasts?',
          ]
        : [
            'Why is $id drifting and what should I do?',
            'How much energy can $id save safely?',
            'What yield will $id reach?',
          ];
  }

  void _toBottom() => WidgetsBinding.instance.addPostFrameCallback((_) {
    if (_scroll.hasClients) {
      unawaited(
        _scroll.animateTo(_scroll.position.maxScrollExtent, duration: KMotion.base, curve: KMotion.standard),
      );
    }
  });

  void _stop() {
    _cancel?.cancel();
    unawaited(_sub?.cancel());
    setState(() {
      _busy = false;
      _activity = null;
    });
  }

  void _send([String? text]) {
    final q = (text ?? _input.text).trim();
    final api = ref.read(apiProvider);
    if (q.isEmpty || _busy || api == null) return;
    _input.clear();
    FocusScope.of(context).unfocus();
    final history = [
      ..._messages.where((m) => !m.error && m.content.isNotEmpty),
      ChatMessage(role: 'user', content: q),
    ];
    setState(() {
      _messages
        ..add(ChatMessage(role: 'user', content: q))
        ..add(const ChatMessage(role: 'assistant', content: ''));
      _busy = true;
      _activity = 'thinking';
    });
    _toBottom();
    _cancel = CancelToken();
    final stream = api.chat(
      history.length > 20 ? history.sublist(history.length - 20) : history,
      reactorId: _context,
      processId: ref.read(selectedProcessIdProvider),
      cancel: _cancel,
    );
    void patchLast(ChatMessage Function(ChatMessage) f) {
      if (!mounted || _messages.isEmpty) return;
      setState(() => _messages[_messages.length - 1] = f(_messages.last));
    }

    _sub = stream.listen(
      (ev) {
        switch (ev) {
          case ChatText(:final delta):
            if (_activity != null) setState(() => _activity = null);
            patchLast((m) => m.copyWith(content: m.content + delta));
            _toBottom();
          case final ChatTool t:
            setState(() => _activity = 'checking ${t.label}');
          case ChatEvidence(:final items):
            patchLast((m) => m.copyWith(evidence: items));
          case ChatError(:final message):
            patchLast((m) => m.copyWith(content: message, error: true));
          case ChatDone():
            break;
        }
      },
      onError: (Object e) {
        if (e is DioException && CancelToken.isCancel(e)) return;
        patchLast(
          (m) => m.copyWith(
            content: m.content.isEmpty
                ? "Kairos couldn't answer right now. Check the connection and try again."
                : m.content,
            error: m.content.isEmpty,
          ),
        );
        if (mounted) {
          setState(() {
            _busy = false;
            _activity = null;
          });
        }
      },
      onDone: () {
        if (!mounted) return;
        if (_messages.isNotEmpty && _messages.last.content.isEmpty && !_messages.last.error) {
          patchLast((m) => m.copyWith(content: 'No answer came back. Try asking again.', error: true));
        }
        setState(() {
          _busy = false;
          _activity = null;
        });
      },
    );
  }

  void _retry() {
    final lastUser = _messages.lastWhere(
      (m) => m.isUser,
      orElse: () => const ChatMessage(role: 'user', content: ''),
    );
    if (lastUser.content.isEmpty) return;
    setState(() {
      if (_messages.isNotEmpty && !_messages.last.isUser) _messages.removeLast();
      if (_messages.isNotEmpty && _messages.last.isUser) _messages.removeLast();
    });
    _send(lastUser.content);
  }

  Future<void> _pickContext() async {
    final reactors = ref.read(reactorsProvider).values.toList()
      ..sort((a, b) {
        final c = urgencyRank(a).compareTo(urgencyRank(b));
        return c != 0 ? c : a.id.compareTo(b.id);
      });
    final picked = await showModalBottomSheet<String>(
      context: context,
      useRootNavigator: true,
      showDragHandle: true,
      backgroundColor: KColors.bgSurface,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        builder: (context, controller) => ListView(
          controller: controller,
          padding: const EdgeInsets.fromLTRB(KSpace.s4, 0, KSpace.s4, KSpace.s6),
          children: [
            Text('Ask about', style: KText.display(KSize.xl)),
            const SizedBox(height: KSpace.s3),
            ListTile(
              leading: Icon(LucideIcons.globe, color: KColors.accentX500),
              title: Text('Whole fleet', style: KText.ui(KSize.md, weight: FontWeight.w600)),
              trailing: _context == null ? Icon(LucideIcons.check, color: KColors.accentX500) : null,
              onTap: () => Navigator.pop(context, ''),
            ),
            for (final r in reactors)
              ListTile(
                leading: StateDot(r.state, size: 10),
                title: Text(r.id, style: KText.ui(KSize.md, weight: FontWeight.w600)),
                subtitle: Text(stateLabel(r.state), style: KText.ui(KSize.xs, color: KColors.textMuted)),
                trailing: _context == r.id ? Icon(LucideIcons.check, color: KColors.accentX500) : null,
                onTap: () => Navigator.pop(context, r.id),
              ),
          ],
        ),
      ),
    );
    if (picked != null && mounted) setState(() => _context = picked.isEmpty ? null : picked);
  }

  @override
  Widget build(BuildContext context) {
    final bottomPad = widget.inTab ? 92.0 : 12.0;
    return Scaffold(
      appBar: widget.inTab ? null : AppBar(title: Text('Ask Kairos', style: KText.display(KSize.xl))),
      body: SafeArea(
        bottom: !widget.inTab,
        child: Column(
          children: [
            if (widget.inTab)
              PageTitle(
                'Ask Kairos',
                subtitle: 'Your fermentation copilot',
                trailing: _messages.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'New chat',
                        onPressed: _busy ? null : () => setState(_messages.clear),
                        icon: Icon(LucideIcons.edit, color: KColors.textSecondary),
                      ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(KSpace.s4, 0, KSpace.s4, KSpace.s2),
              child: Align(
                alignment: Alignment.centerLeft,
                child: ActionChip(
                  avatar: Icon(
                    _context == null ? LucideIcons.globe : LucideIcons.flaskConical,
                    size: 15,
                    color: KColors.accentX500,
                  ),
                  label: Text('Context: ${_context ?? 'Whole fleet'}'),
                  labelStyle: KText.ui(KSize.sm, weight: FontWeight.w600, color: KColors.textPrimary),
                  onPressed: _busy ? null : _pickContext,
                ),
              ),
            ),
            Expanded(
              child: _messages.isEmpty
                  ? _Welcome(suggestions: _suggestions, onTap: _send)
                  : ListView.builder(
                      controller: _scroll,
                      padding: const EdgeInsets.fromLTRB(KSpace.s4, KSpace.s2, KSpace.s4, KSpace.s4),
                      itemCount: _messages.length + (_activity != null ? 1 : 0),
                      itemBuilder: (_, i) {
                        if (i == _messages.length) return _Activity(text: _activity!);
                        final m = _messages[i];
                        if (!m.isUser && m.content.isEmpty && !m.error) return const SizedBox.shrink();
                        return m.isUser
                            ? _UserBubble(text: m.content)
                            : _AssistantBubble(
                                m: m,
                                onRetry: m.error && i == _messages.length - 1 && !_busy ? _retry : null,
                              );
                      },
                    ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(KSpace.s4, KSpace.s2, KSpace.s4, bottomPad),
              child: _Composer(controller: _input, busy: _busy, onSend: _send, onStop: _stop),
            ),
          ],
        ),
      ),
    );
  }
}

class _Welcome extends StatelessWidget {
  const _Welcome({required this.suggestions, required this.onTap});

  final List<String> suggestions;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(KSpace.s4),
    children: [
      const SizedBox(height: KSpace.s4),
      Center(
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(color: AskKairosButton.background(context), shape: BoxShape.circle),
          child: Icon(LucideIcons.sparkles, size: 30, color: AskKairosButton.foreground(context)),
        ),
      ),
      const SizedBox(height: KSpace.s4),
      Center(
        child: Text('How can I help?', style: KText.display(KSize.x2xl, weight: FontWeight.w800)),
      ),
      const SizedBox(height: KSpace.s1),
      Center(
        child: Text(
          'Answers come from live Kairos models.',
          style: KText.ui(KSize.sm, color: KColors.textSecondary),
        ),
      ),
      const SizedBox(height: KSpace.s6),
      for (final s in suggestions)
        Padding(
          padding: const EdgeInsets.only(bottom: KSpace.s2),
          child: KCard(
            radius: KR.tile,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            onTap: () => onTap(s),
            child: Row(
              children: [
                Expanded(
                  child: Text(s, style: KText.ui(KSize.md, weight: FontWeight.w500)),
                ),
                Icon(LucideIcons.arrowUpRight, size: 16, color: KColors.accentX500),
              ],
            ),
          ),
        ),
    ],
  );
}

class _UserBubble extends StatelessWidget {
  const _UserBubble({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.centerRight,
    child: Container(
      margin: const EdgeInsets.only(left: 48, bottom: KSpace.s3),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AskKairosButton.background(context),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(18),
          topRight: Radius.circular(18),
          bottomLeft: Radius.circular(18),
          bottomRight: Radius.circular(6),
        ),
      ),
      child: Text(
        text,
        style: KText.ui(KSize.md, weight: FontWeight.w500, color: AskKairosButton.foreground(context)),
      ),
    ),
  );
}

class _AssistantBubble extends StatelessWidget {
  const _AssistantBubble({required this.m, this.onRetry});

  final ChatMessage m;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final base = KText.ui(KSize.md, color: m.error ? KColors.textSecondary : KColors.textPrimary);
    return Padding(
      padding: const EdgeInsets.only(bottom: KSpace.s3, right: 24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 2),
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(color: KColors.accentGlow, shape: BoxShape.circle),
            child: Icon(LucideIcons.sparkles, size: 14, color: KColors.accentX500),
          ),
          const SizedBox(width: KSpace.s2),
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: KColors.bgSurface,
                border: Border.all(
                  color: m.error ? KColors.stateAlarm.withValues(alpha: 0.5) : KColors.borderSubtle,
                ),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(6),
                  topRight: Radius.circular(18),
                  bottomLeft: Radius.circular(18),
                  bottomRight: Radius.circular(18),
                ),
                boxShadow: cardShadow(),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  MarkdownBody(
                    data: m.content,
                    styleSheet: MarkdownStyleSheet(
                      p: base,
                      listBullet: base,
                      strong: base.copyWith(fontWeight: FontWeight.w700),
                      h1: KText.display(KSize.lg),
                      h2: KText.display(KSize.lg),
                      h3: KText.display(KSize.md + 1),
                      code: KText.mono(KSize.sm),
                      blockSpacing: 8,
                    ),
                  ),
                  if (m.evidence.isNotEmpty) ...[
                    const SizedBox(height: KSpace.s2),
                    const Divider(),
                    const SizedBox(height: KSpace.s2),
                    Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text('Based on', style: KText.ui(KSize.xs, color: KColors.textMuted)),
                        for (final e in m.evidence) EvidenceChip(source: e),
                      ],
                    ),
                  ],
                  if (onRetry != null)
                    TextButton.icon(
                      onPressed: onRetry,
                      icon: const Icon(LucideIcons.rotateCcw, size: 14),
                      label: const Text('Try again'),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Activity extends StatelessWidget {
  const _Activity({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(left: 34, bottom: KSpace.s3),
    child: Row(
      children: [
        SizedBox.square(
          dimension: 14,
          child: CircularProgressIndicator(strokeWidth: 2, color: KColors.accentX500),
        ),
        const SizedBox(width: KSpace.s2),
        Text('Kairos is $text…', style: KText.ui(KSize.sm, color: KColors.textMuted)),
      ],
    ),
  );
}

class _Composer extends StatelessWidget {
  const _Composer({required this.controller, required this.busy, required this.onSend, required this.onStop});

  final TextEditingController controller;
  final bool busy;
  final VoidCallback onSend;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(16, 4, 6, 4),
    decoration: BoxDecoration(
      color: KColors.bgSurface,
      borderRadius: BorderRadius.circular(KR.pill),
      border: Border.all(color: KColors.borderSubtle),
      boxShadow: cardShadow(),
    ),
    child: Row(
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            enabled: !busy,
            minLines: 1,
            maxLines: 4,
            textInputAction: TextInputAction.send,
            onSubmitted: (_) => onSend(),
            style: KText.ui(KSize.md),
            decoration: const InputDecoration(
              hintText: 'Ask about a reactor, yield or energy',
              filled: false,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              disabledBorder: InputBorder.none,
              isDense: true,
            ),
          ),
        ),
        IconButton.filled(
          tooltip: busy ? 'Stop' : 'Send',
          style: IconButton.styleFrom(
            backgroundColor: AskKairosButton.background(context),
            foregroundColor: AskKairosButton.foreground(context),
          ),
          onPressed: busy ? onStop : onSend,
          icon: Icon(busy ? LucideIcons.square : LucideIcons.arrowUp, size: 18),
        ),
      ],
    ),
  );
}
