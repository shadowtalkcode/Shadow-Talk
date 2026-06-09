import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../data/chat_repository.dart';
import '../../theme/app_colors.dart';
import '../../widgets/common.dart';

/// Editable profile screen reached from Settings → Profile.
/// (The onboarding ProfileSetupScreen is a separate screen and is unchanged.)
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _picker = ImagePicker();
  File? _photo;

  late String _name = ChatRepository.instance.me.userName;
  late final TextEditingController _about =
      TextEditingController(text: 'Heeey I am using Shadow Talk!');
  late final String _phone = ChatRepository.instance.me.phone;

  @override
  void dispose() {
    _about.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF221D34),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera, color: AppColors.primary),
              title: const Text('Take photo', style: TextStyle(color: AppColors.white)),
              onTap: () {
                Navigator.pop(sheetContext);
                _capture(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: AppColors.primary),
              title: const Text('Choose from gallery', style: TextStyle(color: AppColors.white)),
              onTap: () {
                Navigator.pop(sheetContext);
                _capture(ImageSource.gallery);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _capture(ImageSource source) async {
    try {
      final file = await _picker.pickImage(
          source: source, maxWidth: 1024, maxHeight: 1024, imageQuality: 85);
      if (file != null) setState(() => _photo = File(file.path));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not pick image: $e')),
      );
    }
  }

  Future<void> _editName() async {
    final ctrl = TextEditingController(text: _name);
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: const Color(0xFF221D34),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Edit name',
                  style: TextStyle(
                      color: AppColors.white, fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              TextField(
                controller: ctrl,
                autofocus: true,
                style: const TextStyle(color: AppColors.white, fontSize: 16),
                cursorColor: AppColors.primary,
                decoration: const InputDecoration(
                  enabledBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: AppColors.divider)),
                  focusedBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: AppColors.primary)),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    child: const Text('Cancel', style: TextStyle(color: AppColors.textDesc)),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(dialogContext, ctrl.text.trim()),
                    child: const Text('Save',
                        style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (result != null && result.isNotEmpty) setState(() => _name = result);
  }

  @override
  Widget build(BuildContext context) {
    return GradientScaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: const BackButton(color: AppColors.white),
        titleSpacing: 0,
        title: const Text('Profile',
            style: TextStyle(
                fontFamily: 'Inter', fontSize: 22, fontWeight: FontWeight.w700)),
      ),
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          const SizedBox(height: 28),
          // Avatar with camera badge
          Center(
            child: GestureDetector(
              onTap: _pickPhoto,
              child: SizedBox(
                width: 190,
                height: 190,
                child: Stack(
                  children: [
                    Center(
                      child: Container(
                        width: 170,
                        height: 170,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.transparent,
                          border: Border.all(color: const Color(0xFF6B6880), width: 1.5),
                          image: _photo != null
                              ? DecorationImage(image: FileImage(_photo!), fit: BoxFit.cover)
                              : null,
                        ),
                      ),
                    ),
                    Positioned(
                      right: 18,
                      bottom: 28,
                      child: Container(
                        width: 56,
                        height: 56,
                        decoration: const BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.photo_camera, color: Colors.white, size: 26),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          // Name band
          Container(
            color: const Color(0xFF1A1626),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Row(
              children: [
                Expanded(
                  child: Text(_name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: AppColors.white, fontSize: 20)),
                ),
                IconButton(
                  icon: const Icon(Icons.edit, color: AppColors.textDesc),
                  onPressed: _editName,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // About + Phone band
          Container(
            color: const Color(0xFF1A1626),
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('About and Phone Number',
                    style: TextStyle(
                        color: AppColors.white, fontSize: 18, fontWeight: FontWeight.w700)),
                const SizedBox(height: 12),
                TextField(
                  controller: _about,
                  style: const TextStyle(color: AppColors.white, fontSize: 18),
                  cursorColor: AppColors.primary,
                  decoration: const InputDecoration(
                    isDense: true,
                    contentPadding: EdgeInsets.only(bottom: 10),
                    enabledBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: AppColors.divider)),
                    focusedBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: AppColors.primary)),
                  ),
                ),
                const SizedBox(height: 18),
                Text(_phone.isEmpty ? '+1 456 456 4567' : _phone,
                    style: const TextStyle(color: AppColors.white, fontSize: 18)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
