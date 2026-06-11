import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../services/auth_service.dart';
import '../../services/profile_store.dart';
import '../../theme/app_colors.dart';
import '../../utils/image_storage.dart';
import '../../widgets/common.dart';
import '../main_screen.dart';

/// "Profile info" setup screen with a working profile-photo picker.
/// Matches XD reference 05.
class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final _picker = ImagePicker();
  File? _photo;
  final _nameCtrl = TextEditingController();
  final _aboutCtrl = TextEditingController();

  @override
  void dispose() {
    _nameCtrl.dispose();
    _aboutCtrl.dispose();
    super.dispose();
  }

  Future<void> _pick(ImageSource source) async {
    try {
      final file = await _picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      if (file != null) {
        final path = await ImageStorage.persist(file.path);
        if (!mounted) return;
        setState(() => _photo = File(path));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not pick image: $e')),
      );
    }
  }

  void _showPickerSheet() {
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
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('Profile photo',
                    style: TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.white)),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera, color: AppColors.primary),
              title: const Text('Take photo', style: TextStyle(color: AppColors.white)),
              onTap: () {
                Navigator.pop(sheetContext);
                _pick(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: AppColors.primary),
              title: const Text('Choose from gallery', style: TextStyle(color: AppColors.white)),
              onTap: () {
                Navigator.pop(sheetContext);
                _pick(ImageSource.gallery);
              },
            ),
            if (_photo != null)
              ListTile(
                leading: const Icon(Icons.delete_outline, color: AppColors.red),
                title: const Text('Remove photo', style: TextStyle(color: AppColors.red)),
                onTap: () {
                  Navigator.pop(sheetContext);
                  setState(() => _photo = null);
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _onNext() async {
    // Persist what the user entered so Settings → Profile shows it.
    await ProfileStore.instance.save(
      name: _nameCtrl.text.trim(),
      about: _aboutCtrl.text.trim(),
      photoPath: _photo?.path,
      phone: AuthService.instance.phoneNumber,
    );
    await AuthService.instance.setProfileCompleted(true);
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const MainScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return GradientScaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 24),
              const Center(
                child: Text(
                  'Profile info',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: AppColors.white,
                  ),
                ),
              ),
              const SizedBox(height: 18),
              const Center(
                child: Text('Enter your details',
                    style: TextStyle(fontSize: 16, color: AppColors.textDesc)),
              ),
              const SizedBox(height: 36),
              Center(
                child: GestureDetector(
                  onTap: _showPickerSheet,
                  child: SizedBox(
                    width: 180,
                    height: 180,
                    child: Stack(
                      children: [
                        Center(
                          child: Container(
                            width: 168,
                            height: 168,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.surface,
                              border: Border.all(color: AppColors.primary, width: 2),
                              image: (_photo != null && _photo!.existsSync())
                                  ? DecorationImage(image: FileImage(_photo!), fit: BoxFit.cover)
                                  : null,
                            ),
                            child: (_photo == null || !_photo!.existsSync())
                                ? const Icon(Icons.photo_camera,
                                    color: Color(0xFF4B4860), size: 40)
                                : null,
                          ),
                        ),
                        Positioned(
                          right: 8,
                          bottom: 18,
                          child: Container(
                            width: 44,
                            height: 44,
                            decoration: const BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(_photo == null ? Icons.add : Icons.edit,
                                color: Colors.white, size: 22),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 40),
              _Field(controller: _nameCtrl, hint: 'Enter name'),
              const SizedBox(height: 28),
              _Field(controller: _aboutCtrl, hint: 'Enter about yourself'),
              const SizedBox(height: 36),
              Center(
                child: PrimaryButton(
                  label: 'Next',
                  width: 280,
                  onPressed: _onNext,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  final String hint;
  final TextEditingController controller;
  const _Field({required this.hint, required this.controller});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      style: const TextStyle(fontSize: 18, color: AppColors.white),
      cursorColor: AppColors.primary,
      decoration: InputDecoration(
        isDense: true,
        hintText: hint,
        hintStyle: const TextStyle(fontSize: 18, color: AppColors.textDesc),
        enabledBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: AppColors.divider),
        ),
        focusedBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: AppColors.primary),
        ),
      ),
    );
  }
}
