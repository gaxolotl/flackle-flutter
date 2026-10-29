import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../core/media.dart';
import '../core/state.dart';
import '../core/theme.dart';
import '../ui/common.dart';

/// Edit the signed-in user's banner, avatar and display name.
class ProfileEditorScreen extends StatefulWidget {
  const ProfileEditorScreen({super.key});

  @override
  State<ProfileEditorScreen> createState() => _ProfileEditorScreenState();
}

class _ProfileEditorScreenState extends State<ProfileEditorScreen> {
  late final TextEditingController _name = TextEditingController(
    text: FlackleScope.read(context).me?.displayName ?? '',
  );
  String? _avatarUrl;
  String? _bannerUrl;
  bool _busy = false;
  bool _uploadingAvatar = false;
  bool _uploadingBanner = false;
  String? _error;

  AppState get _state => FlackleScope.read(context);

  @override
  void initState() {
    super.initState();
    final me = _state.me;
    _avatarUrl = me?.avatarUrl;
    _bannerUrl = me?.bannerUrl;
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _pickBanner() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );
    final file =
        result == null || result.files.isEmpty ? null : result.files.first;
    if (file == null) return;
    final bytes = file.bytes;
    if (bytes == null) {
      if (mounted) showAppToast(context, 'Could not read that image.');
      return;
    }
    if (bytes.lengthInBytes > 10 * 1024 * 1024) {
      if (mounted) showAppToast(context, 'Banners must be 10MB or smaller.');
      return;
    }
    setState(() => _uploadingBanner = true);
    try {
      final url = await _state.client.uploadBanner(file.name, bytes);
      await _state.refreshMe();
      if (mounted) {
        setState(() => _bannerUrl = url);
        showAppToast(context, 'Banner updated.');
      }
    } catch (failure) {
      if (mounted) showAppToast(context, failure.toString());
    } finally {
      if (mounted) setState(() => _uploadingBanner = false);
    }
  }

  Future<void> _pickAvatar() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );
    final file =
        result == null || result.files.isEmpty ? null : result.files.first;
    if (file == null) return;
    final bytes = file.bytes;
    if (bytes == null) {
      if (mounted) showAppToast(context, 'Could not read that image.');
      return;
    }
    if (bytes.lengthInBytes > 5 * 1024 * 1024) {
      if (mounted) showAppToast(context, 'Avatars must be 5MB or smaller.');
      return;
    }
    setState(() => _uploadingAvatar = true);
    try {
      final url = await _state.client.uploadAvatar(file.name, bytes);
      await _state.refreshMe();
      if (mounted) {
        setState(() => _avatarUrl = url);
        showAppToast(context, 'Avatar updated.');
      }
    } catch (failure) {
      if (mounted) showAppToast(context, failure.toString());
    } finally {
      if (mounted) setState(() => _uploadingAvatar = false);
    }
  }

  Future<void> _save() async {
    if (_busy || _uploadingAvatar || _uploadingBanner) return;
    if (_name.text.trim() == (_state.me?.displayName ?? '').trim()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _state.client.updateProfile(displayName: _name.text.trim());
      await _state.refreshMe();
      if (mounted) {
        showAppToast(context, 'Profile updated.');
        Navigator.of(context).maybePop();
      }
    } catch (failure) {
      if (mounted) setState(() => _error = failure.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final me = FlackleScope.of(context).me;
    return Scaffold(
      appBar: AppBar(
        title: Text('Edit profile',
            style: context.display(17, weight: FontWeight.w600)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 30),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    height: 210,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Positioned(
                          top: 0,
                          left: 0,
                          right: 0,
                          height: 165,
                          child: InkWell(
                            onTap: _uploadingBanner ? null : _pickBanner,
                            borderRadius: BorderRadius.circular(14),
                            child: Container(
                              clipBehavior: Clip.antiAlias,
                              decoration: BoxDecoration(
                                color: c.panel2,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: c.line),
                              ),
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  if (_bannerUrl != null)
                                    AppImage(_bannerUrl!, fit: BoxFit.cover)
                                  else
                                    Center(
                                      child: Icon(Icons.image_outlined,
                                          size: 34, color: c.muted),
                                    ),
                                  Positioned(
                                    right: 10,
                                    bottom: 10,
                                    child: OutlinedButton.icon(
                                      onPressed:
                                          _uploadingBanner ? null : _pickBanner,
                                      icon: _uploadingBanner
                                          ? const SizedBox(
                                              width: 13,
                                              height: 13,
                                              child: CircularProgressIndicator(
                                                  strokeWidth: 2),
                                            )
                                          : const Icon(
                                              Icons.photo_camera_outlined,
                                              size: 15),
                                      label: const Text('Change banner'),
                                      style: OutlinedButton.styleFrom(
                                        backgroundColor:
                                            Colors.black.withValues(alpha: 0.5),
                                        foregroundColor: Colors.white,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          left: 18,
                          bottom: 0,
                          child: GestureDetector(
                            onTap: _uploadingAvatar ? null : _pickAvatar,
                            child: Stack(
                              children: [
                                AppAvatar(
                                  url: _avatarUrl,
                                  name: me?.name ?? 'You',
                                  size: 96,
                                  ring: c.panel,
                                ),
                                Positioned(
                                  right: 0,
                                  bottom: 0,
                                  child: Container(
                                    width: 30,
                                    height: 30,
                                    decoration: BoxDecoration(
                                      color: c.accent,
                                      shape: BoxShape.circle,
                                      border:
                                          Border.all(color: c.panel, width: 2),
                                    ),
                                    child: _uploadingAvatar
                                        ? const Padding(
                                            padding: EdgeInsets.all(7),
                                            child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: Colors.white),
                                          )
                                        : const Icon(Icons.photo_camera,
                                            size: 15, color: Colors.white),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Banner max 10MB · Avatar max 5MB',
                    style: context.label(10.5, color: c.muted),
                  ),
                  const SizedBox(height: 20),
                  Text('Display name',
                      style: context.label(11.5,
                          weight: FontWeight.w600, color: c.muted)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _name,
                    enabled: !_busy,
                    maxLength: 100,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _save(),
                    decoration: InputDecoration(
                      hintText: me?.username ?? 'Display name',
                    ),
                  ),
                  Text('Username',
                      style: context.label(11.5,
                          weight: FontWeight.w600, color: c.muted)),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 12),
                    decoration: BoxDecoration(
                      color: c.input,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: c.line),
                    ),
                    child: Text('@${me?.username ?? 'unknown'}',
                        style: context.label(12.5, color: c.textDim)),
                  ),
                  const SizedBox(height: 24),
                  if (_error != null) ...[
                    InlineNotice(_error!),
                    const SizedBox(height: 12),
                  ],
                  ValueListenableBuilder<TextEditingValue>(
                    valueListenable: _name,
                    builder: (context, value, _) => FilledButton(
                      onPressed: _busy ||
                              _uploadingAvatar ||
                              _uploadingBanner ||
                              value.text.trim() ==
                                  (me?.displayName ?? '').trim()
                          ? null
                          : _save,
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(44),
                      ),
                      child: _busy
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : const Text('Save changes'),
                    ),
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
