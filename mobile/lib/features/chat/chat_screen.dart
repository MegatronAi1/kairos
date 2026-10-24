import 'package:flutter/material.dart';
import 'package:kairos_pager/widgets/states.dart';
import 'package:lucide_icons/lucide_icons.dart';

/// Ask Kairos. Wired to the agent (POST /agent/chat, SSE) once the backend agent lands.
class ChatScreen extends StatelessWidget {
  const ChatScreen({super.key, this.reactorId});

  final String? reactorId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(reactorId == null ? 'Ask Kairos' : 'Ask Kairos · $reactorId')),
      body: const EmptyState(
        icon: LucideIcons.messageCircle,
        title: 'Ask Kairos is not connected yet',
        message: 'The copilot answers from the yield, fault and energy models once the agent is online.',
      ),
    );
  }
}
