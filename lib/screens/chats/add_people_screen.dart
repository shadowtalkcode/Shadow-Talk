import 'package:flutter/material.dart';

import '../../data/mock_data.dart';
import '../../theme/app_colors.dart';
import '../../widgets/avatar.dart';

/// "Add people" screen (e.g. to a group/call). Matches XD reference 19.
class AddPeopleScreen extends StatefulWidget {
  const AddPeopleScreen({super.key});

  @override
  State<AddPeopleScreen> createState() => _AddPeopleScreenState();
}

class _AddPeopleScreenState extends State<AddPeopleScreen> {
  final _selected = <String>{};

  @override
  Widget build(BuildContext context) {
    final people = MockData.allContacts.where((u) => !u.isGroup).toList();
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        centerTitle: true,
        leading: const BackButton(color: AppColors.white),
        title: const Text('End-to-end encrypted',
            style: TextStyle(fontSize: 14, color: AppColors.textDesc)),
      ),
      body: Container(
        margin: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF221D34),
          borderRadius: BorderRadius.circular(28),
        ),
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Center(
              child: Text('Add people',
                  style: TextStyle(
                      fontSize: 24, fontWeight: FontWeight.w800, color: AppColors.white)),
            ),
            const SizedBox(height: 4),
            Center(
              child: Text('${_selected.length}/5',
                  style: const TextStyle(fontSize: 15, color: AppColors.textDesc)),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView(
                children: [
                  for (final u in people)
                    ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                      leading: Avatar(user: u, size: 48, showBorder: false),
                      title: Text(u.userName,
                          style: const TextStyle(color: AppColors.white, fontSize: 17)),
                      trailing: Icon(
                        _selected.contains(u.uid)
                            ? Icons.check_circle
                            : Icons.radio_button_unchecked,
                        color: _selected.contains(u.uid) ? AppColors.primary : AppColors.textDesc,
                      ),
                      onTap: () => setState(() {
                        if (_selected.contains(u.uid)) {
                          _selected.remove(u.uid);
                        } else if (_selected.length < 5) {
                          _selected.add(u.uid);
                        }
                      }),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
