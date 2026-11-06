import 'package:flutter/material.dart';

import '../api_failure.dart';
import '../child_onboarding.dart' show acceptableChildNickname;
import 'mobile_services.dart';
import 'po_design.dart';
import '../user_messages.dart';

class ProfilePanel extends StatefulWidget {
  const ProfilePanel({super.key, required this.service, required this.childId});
  final ProfileService service;
  final String childId;
  @override
  State<ProfilePanel> createState() => _ProfilePanelState();
}

class _ProfilePanelState extends State<ProfilePanel> {
  final alias = TextEditingController();
  final form = GlobalKey<FormState>();
  String avatar = 'bear-blue';
  int? version;
  bool busy = false;
  ApiFailure? error;
  String? notice;
  String? key, lockedAlias, lockedAvatar;
  int? lockedVersion;
  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    alias.dispose();
    super.dispose();
  }

  Future<void> run(Future<void> Function() work) async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
      notice = null;
    });
    try {
      await work();
    } on ApiFailure catch (e) {
      if (mounted) setState(() => error = e);
    } catch (_) {
      if (mounted)
        setState(
          () => error = const ApiInvalidResponse('Invalid profile response.'),
        );
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> load() => run(() async {
    // Refresh always means a fresh review; never rebase a failed edit.
    setState(() {
      version = null;
      key = null;
      alias.clear();
    });
    final value = await widget.service.read(widget.childId);
    if (mounted)
      setState(() {
        version = value['profileVersion'];
        alias.text = value['childAlias'];
        avatar = value['stockAvatarKey'] as String? ?? 'bear-blue';
      });
  });
  Future<void> save() => run(() async {
    if (key == null) {
      if (!form.currentState!.validate()) return;
      key = mobileRequestKey();
      lockedAlias = alias.text.trim();
      lockedAvatar = avatar;
      lockedVersion = version;
    }
    final value = await widget.service.update(
      widget.childId,
      lockedVersion!,
      lockedAlias!,
      lockedAvatar!,
      key!,
    );
    if (mounted)
      setState(() {
        key = null;
        version = value['profileVersion'];
        alias.text = value['childAlias'];
        avatar = value['stockAvatarKey'] as String? ?? 'bear-blue';
        notice = 'Đã lưu thông tin hồ sơ.';
      });
  });
  @override
  Widget build(BuildContext context) => PoCard(
    color: PoPalette.lavender,
    child: Form(
      key: form,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const PoHeading(
            'Tên gọi & ảnh đại diện',
            subtitle: 'Cập nhật thông tin của bé',
          ),
          const Text(
            'Ngày sinh không thể sửa tại đây. Khi gặp xung đột, tải lại hồ sơ và xem lại trước khi gửi yêu cầu mới.',
          ),
          if (busy) const LinearProgressIndicator(),
          if (version != null) ...[
            TextFormField(
              controller: alias,
              enabled: !busy && key == null,
              maxLength: 30,
              decoration: const InputDecoration(labelText: 'Tên gọi của bé'),
              validator: (v) => acceptableChildNickname(v ?? '')
                  ? null
                  : 'Tên này chưa được phiên bản hiện tại hỗ trợ.',
            ),
            Wrap(
              spacing: 8,
              children: [
                for (final a in {'bear-blue', 'bee-yellow', avatar})
                  ChoiceChip(
                    label: Text(
                      a == 'bear-blue'
                          ? 'Gấu xanh'
                          : a == 'bee-yellow'
                          ? 'Ong vàng'
                          : 'Ảnh hiện tại',
                    ),
                    selected: avatar == a,
                    onSelected: busy || key != null
                        ? null
                        : (_) => setState(() => avatar = a),
                  ),
              ],
            ),
            PoAction(
              key == null ? 'Lưu thay đổi' : 'Thử lại cùng thay đổi',
              onPressed: busy ? null : save,
            ),
          ],
          if (error != null) UserError(error),
          if (notice != null) Text(notice!),
          TextButton(
            onPressed: busy ? null : load,
            child: const Text('Tải lại & bắt đầu xem xét mới'),
          ),
        ],
      ),
    ),
  );
}
