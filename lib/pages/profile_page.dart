import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../auth/auth_session.dart';
import '../data/api_client.dart';
import '../utils/validators.dart';

/// 个人中心：点头像换图，改显示名称与邮箱；登录账号只读。
class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key, required this.session});

  final AuthSession session;

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  /// 与后端 spring.servlet.multipart 的上限保持一致，先在前端拦一次。
  static const _maxAvatarBytes = 2 * 1024 * 1024;

  /// 进入页面时快照一份：会话中途失效也不会让本页崩溃。
  late final SessionUser _profile = widget.session.user!;
  late final _nickname = TextEditingController(text: _profile.nickname);
  late final _email = TextEditingController(text: _profile.email);
  late final _phone = TextEditingController(text: _profile.phone);

  bool _busy = false;
  bool _uploading = false;
  String? _error;

  /// TextField 自己不会让父级重建，保存按钮的可用态需要在输入时刷新。
  void _onChanged(_) => setState(() {});

  bool get _dirty =>
      _nickname.text.trim() != _profile.nickname ||
      _email.text.trim() != _profile.email ||
      _phone.text.trim() != _profile.phone;

  @override
  void dispose() {
    _nickname.dispose();
    _email.dispose();
    _phone.dispose();
    super.dispose();
  }

  String? _validate() {
    final nickname = _nickname.text.trim();
    if (nickname.isEmpty) return '显示名称不能为空';
    if (nickname.length > 32) return '显示名称最多 32 个字符';
    final email = _email.text.trim();
    if (email.length > 255) return '邮箱最多 255 个字符';
    if (email.isNotEmpty && !emailPattern.hasMatch(email)) return '邮箱格式不正确';
    final phone = _phone.text.trim();
    if (phone.isNotEmpty && !cnMobilePattern.hasMatch(phone)) {
      return '手机号要填 11 位中国大陆号码，或者留空';
    }
    return null;
  }

  Future<void> _save() async {
    final message = _validate();
    if (message != null) {
      setState(() => _error = message);
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    var saved = false;
    try {
      await widget.session.updateProfile(
        nickname: _nickname.text,
        email: _email.text,
        phone: _phone.text,
      );
      saved = true;
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
    if (!mounted) return;
    setState(() => _busy = false);
    if (!saved) return;
    messenger.showSnackBar(const SnackBar(content: Text('资料已更新')));
    Navigator.of(context).pop();
  }

  Future<void> _pickAndUpload() async {
    final file = await FilePicker.pickFile(type: FileType.image);
    if (file == null || !mounted) return; // null 表示用户取消了选择
    final messenger = ScaffoldMessenger.of(context);
    setState(() {
      _uploading = true;
      _error = null;
    });
    try {
      final bytes = await file.readAsBytes();
      if (bytes.length > _maxAvatarBytes) {
        throw const ApiException('图片超过 2MB，换一张小一点的');
      }
      await widget.session.uploadAvatar(bytes: bytes, filename: file.name);
      messenger.showSnackBar(const SnackBar(content: Text('头像已更新')));
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Widget _avatar(BuildContext context) {
    final theme = Theme.of(context);
    final url = widget.session.avatarUrl;
    Widget? placeholder;
    if (_uploading) {
      placeholder = const SizedBox(
        width: 22,
        height: 22,
        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
      );
    } else if (url == null) {
      placeholder = const Icon(Icons.person, size: 28);
    }
    return SizedBox(
      width: 60,
      height: 60,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            top: 0,
            left: 0,
            child: InkWell(
              onTap: _uploading ? null : _pickAndUpload,
              customBorder: const CircleBorder(),
              child: Tooltip(
                message: '点击更换头像',
                child: CircleAvatar(
                  radius: 26,
                  backgroundColor: kPrimary,
                  foregroundColor: Colors.white,
                  backgroundImage: url == null
                      ? null
                      : NetworkImage(url, headers: widget.session.authHeaders),
                  child: placeholder,
                ),
              ),
            ),
          ),
          Positioned(
            right: 0,
            bottom: 2,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary,
                shape: BoxShape.circle,
                border: Border.all(color: theme.cardColor, width: 2),
              ),
              child: Icon(
                Icons.photo_camera,
                size: 12,
                color: theme.colorScheme.onPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('个人中心')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  _avatar(context),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _profile.nickname.isEmpty
                              ? _profile.username
                              : _profile.nickname,
                          style: theme.textTheme.titleMedium,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '登录账号 ${_profile.username}，不可修改',
                          style: theme.textTheme.bodySmall,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('资料设置', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _nickname,
                    enabled: !_busy,
                    maxLength: 32,
                    onChanged: _onChanged,
                    decoration: const InputDecoration(
                      labelText: '显示名称',
                      hintText: '账单与菜单里展示的名字',
                    ),
                    onSubmitted: (_) => _save(),
                  ),
                  const SizedBox(height: 4),
                  TextField(
                    controller: _phone,
                    enabled: !_busy,
                    keyboardType: TextInputType.phone,
                    maxLength: 11,
                    onChanged: _onChanged,
                    decoration: const InputDecoration(
                      labelText: '手机号',
                      hintText: '中国大陆 11 位，可留空',
                    ),
                    onSubmitted: (_) => _save(),
                  ),
                  const SizedBox(height: 4),
                  TextField(
                    controller: _email,
                    enabled: !_busy,
                    keyboardType: TextInputType.emailAddress,
                    onChanged: _onChanged,
                    decoration: const InputDecoration(
                      labelText: '邮箱',
                      hintText: '可留空',
                    ),
                    onSubmitted: (_) => _save(),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      _error!,
                      style: const TextStyle(
                        color: kExpense,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: _busy || !_dirty ? null : _save,
                    child: _busy
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('保存'),
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
