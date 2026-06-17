import 'package:flutter/material.dart';

import '../../models/call.dart';
import '../../models/user.dart';
import '../../services/call_service.dart';
import '../../services/chat_service.dart';
import '../../theme/app_colors.dart';
import '../../utils/time_format.dart';
import '../../widgets/avatar.dart';
import 'call_launcher.dart';

/// Calls tab — dynamic call history backed by [CallService]. Shows a centered
/// empty state until the user makes/receives a call; tapping a row redials.
class CallsTab extends StatelessWidget {
  const CallsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      // floatingActionButton: FloatingActionButton(
      //   heroTag: 'fab_new_call',
      //   backgroundColor: AppColors.primary,
      //   onPressed: () => Navigator.of(context).push(
      //     MaterialPageRoute(builder: (_) => const NewCallScreen()),
      //   ),
      //   child: const Icon(Icons.add_call, color: Colors.white),
      // ),
      body: SafeArea(
        bottom: false,
        child: ValueListenableBuilder<List<CallRecord>>(
          valueListenable: CallService.instance.history,
          builder: (context, calls, _) {
            return CustomScrollView(
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
                if (calls.isEmpty)
                  const SliverFillRemaining(
                    hasScrollBody: false,
                    child: _EmptyCalls(),
                  )
                else
                  SliverList.builder(
                    itemCount: calls.length,
                    itemBuilder: (context, i) => _CallRow(call: calls[i]),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Matches the Android `layout_empty_calls`: a 72dp semi-transparent phone
/// icon, "No calls yet" (18sp, #F8F9FA), then "Your call history will appear
/// here" (14sp, #ADB5BD), centered.
class _EmptyCalls extends StatelessWidget {
  const _EmptyCalls();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Opacity(
            opacity: 0.4,
            child: Icon(Icons.phone, color: const Color(0xFFF8F9FA), size: 72),
          ),
          const SizedBox(height: 16),
          const Text('No calls yet',
              style: TextStyle(color: Color(0xFFF8F9FA), fontSize: 18)),
          const SizedBox(height: 8),
          const Text('Your call history will appear here',
              style: TextStyle(color: Color(0xFFADB5BD), fontSize: 14)),
        ],
      ),
    );
  }
}

class _CallRow extends StatelessWidget {
  final CallRecord call;
  const _CallRow({required this.call});

  @override
  Widget build(BuildContext context) {
    final (icon, color, label) = switch (call.direction) {
      CallDirection.incoming => (Icons.call_received, AppColors.green, 'Incoming'),
      CallDirection.answered => (Icons.call_received, AppColors.green, 'Incoming'),
      CallDirection.outgoing => (Icons.call_made, AppColors.green, 'Outgoing'),
      CallDirection.missed => (Icons.call_missed, AppColors.red, 'Missed'),
    };
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 6),
      // Resolve the peer's CURRENT photo (cached-instant) so old call rows also
      // show it; fall back to the photo captured at call time, then initials.
      leading: FutureBuilder<DirUser?>(
        future: ChatService.instance.getUser(call.peerUid),
        initialData: ChatService.instance.cachedUser(call.peerUid),
        builder: (context, snap) {
          final photo = snap.data?.photo ?? call.peerPhoto;
          return Avatar(
            user: User(
                uid: call.peerUid,
                userName: snap.data?.name ?? call.peerName,
                photoUrl: photo),
            size: 54,
            showBorder: false,
          );
        },
      ),
      onTap: () => startCall(context,
          peerUid: call.peerUid,
          peerName: call.peerName,
          peerPhoto: call.peerPhoto,
          isVideo: call.isVideo),
      title: Text(call.peerName,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: call.isMissed ? AppColors.red : AppColors.white,
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
        onPressed: () => startCall(context,
            peerUid: call.peerUid,
            peerName: call.peerName,
            peerPhoto: call.peerPhoto,
            isVideo: call.isVideo),
      ),
    );
  }
}
