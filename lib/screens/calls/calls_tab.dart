import 'package:flutter/material.dart';

import '../../data/chat_repository.dart';
import '../../models/call_log.dart';
import '../../models/enums.dart';
import '../../theme/app_colors.dart';
import '../../utils/time_format.dart';
import '../../widgets/avatar.dart';
import 'call_screen.dart';

/// Calls tab — call history (display only). Matches the XD dark style.
class CallsTab extends StatelessWidget {
  const CallsTab({super.key});

  @override
  Widget build(BuildContext context) {
    final calls = ChatRepository.instance.calls;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          slivers: [
            const SliverPadding(
              padding: EdgeInsets.fromLTRB(24, 12, 24, 8),
              sliver: SliverToBoxAdapter(
                child: Text('Calls',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 34,
                      fontWeight: FontWeight.w800,
                      color: AppColors.white,
                    )),
              ),
            ),
            SliverList.builder(
              itemCount: calls.length,
              itemBuilder: (context, i) => _CallRow(call: calls[i]),
            ),
          ],
        ),
      ),
    );
  }
}

class _CallRow extends StatelessWidget {
  final CallLog call;
  const _CallRow({required this.call});

  @override
  Widget build(BuildContext context) {
    final (icon, color, label) = switch (call.type) {
      CallType.incoming => (Icons.call_received, AppColors.green, 'Incoming'),
      CallType.outgoing => (Icons.call_made, AppColors.green, 'Outgoing'),
      CallType.missed => (Icons.call_missed, AppColors.red, 'Missed'),
    };
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 6),
      leading: Avatar(user: call.user, size: 54, showBorder: false),
      title: Text(call.user.userName,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: call.type == CallType.missed ? AppColors.red : AppColors.white,
          )),
      subtitle: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text('$label · ${TimeFormat.shortStamp(call.time)}',
              style: const TextStyle(color: AppColors.textDesc, fontSize: 13)),
        ],
      ),
      trailing: IconButton(
        icon: Icon(call.isVideo ? Icons.videocam : Icons.call, color: AppColors.primary),
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => CallScreen(user: call.user, isVideo: call.isVideo),
          ),
        ),
      ),
    );
  }
}
