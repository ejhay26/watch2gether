import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../constants/theme.dart';
import '../../services/local_store_service.dart';
import '../../services/room_service.dart';
import 'app_toast.dart';

class ProfileNameModal extends StatefulWidget {
  final bool isFirstBoot;
  const ProfileNameModal({super.key, this.isFirstBoot = false});

  static Future<void> show(BuildContext context, {bool isFirstBoot = false}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: !isFirstBoot,
      enableDrag: !isFirstBoot,
      backgroundColor: Colors.transparent,
      builder: (_) => ProfileNameModal(isFirstBoot: isFirstBoot),
    );
  }

  @override
  State<ProfileNameModal> createState() => _ProfileNameModalState();
}

class _ProfileNameModalState extends State<ProfileNameModal> {
  late final TextEditingController _nameController;
  final List<Color> _avatarColors = [
    AppColors.accent,
    Colors.tealAccent,
    Colors.amberAccent,
    Colors.pinkAccent,
    Colors.purpleAccent,
    Colors.blueAccent,
  ];

  @override
  void initState() {
    super.initState();
    final localStore = Provider.of<LocalStoreService>(context, listen: false);
    _nameController = TextEditingController(text: localStore.username);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _saveProfile() {
    final newName = _nameController.text.trim();
    if (newName.isEmpty) {
      AppToast.show(context, 'Name cannot be empty', type: ToastType.warning);
      return;
    }

    final localStore = Provider.of<LocalStoreService>(context, listen: false);
    final roomService = Provider.of<RoomService>(context, listen: false);

    localStore.updateUsername(newName);
    if (roomService.isInParty) {
      roomService.renameUser(newName);
    }

    Navigator.of(context).pop();
    AppToast.show(
      context,
      'Display name updated to "$newName"',
      type: ToastType.success,
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final localStore = Provider.of<LocalStoreService>(context);

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + bottomInset),
          decoration: BoxDecoration(
            color: const Color(0xFF131625).withValues(alpha: 0.95),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.all(color: Colors.white12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.accent.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.person_rounded, color: AppColors.accent, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.isFirstBoot ? 'Welcome to Watch2gether! 👋' : 'Your Profile',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        widget.isFirstBoot
                            ? 'Choose your preferred name for watch parties & chat'
                            : 'Sovereign Identity • No Account Required',
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Center(
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 34,
                      backgroundColor: _avatarColors[localStore.avatarIndex % _avatarColors.length],
                      child: Text(
                        _nameController.text.isNotEmpty
                            ? _nameController.text[0].toUpperCase()
                            : 'U',
                        style: const TextStyle(
                          color: Colors.black,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(_avatarColors.length, (index) {
                        final isSelected = localStore.avatarIndex == index;
                        return GestureDetector(
                          onTap: () => localStore.updateAvatarIndex(index),
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 5),
                            width: 26,
                            height: 26,
                            decoration: BoxDecoration(
                              color: _avatarColors[index],
                              shape: BoxShape.circle,
                              border: isSelected
                                  ? Border.all(color: Colors.white, width: 2.5)
                                  : null,
                            ),
                          ),
                        );
                      }),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'DISPLAY NAME',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _nameController,
                style: const TextStyle(color: Colors.white, fontSize: 15),
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: 'Enter your name (e.g. Ejhay, Alex)',
                  hintStyle: const TextStyle(color: Colors.white30),
                  filled: true,
                  fillColor: const Color(0xFF0D0F1A),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.white12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.accent, width: 1.5),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF0A0C16),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white10),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.shield_outlined, color: Colors.greenAccent, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Device ID: ${localStore.peerId} (${localStore.deviceType})',
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 11,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _saveProfile,
                  child: Text(
                    widget.isFirstBoot ? 'Get Started' : 'Save Display Name',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
