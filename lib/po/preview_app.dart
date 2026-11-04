import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'po_design.dart';
import 'preview_state.dart';
import 'preview_learning.dart';

class PoPreview extends StatefulWidget {
  const PoPreview({super.key});
  @override
  State<PoPreview> createState() => _PoPreviewState();
}

class _PoPreviewState extends State<PoPreview> with WidgetsBindingObserver {
  final model = PreviewState();
  bool childMode = false;
  int tab = 0;
  String? previewPin;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    model.dispose();
    previewPin = null;
    super.dispose();
  }

  Future<void> push(Widget page) async {
    await Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => page));
    if (mounted) setState(() {});
  }

  Future<void> gate({bool enterChild = false}) async {
    final value = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) =>
            PreviewGate(setup: previewPin == null, expected: previewPin),
      ),
    );
    if (!mounted || value == null) return;
    previewPin ??= value;
    setState(() {
      childMode = enterChild;
      tab = 0;
    });
  }

  void open(int index) {
    setState(() => tab = index);
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: model,
    builder: (context, _) => PopScope(
      canPop: !childMode,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && childMode) gate();
      },
      child: PoScaffold(
        key: ValueKey((childMode, tab)),
        title: childMode ? 'Thế giới của ${model.child.name}' : 'Góc phụ huynh',
        actions: [
          if (childMode)
            IconButton(
              onPressed: gate,
              icon: const Icon(Icons.lock_outline_rounded),
              tooltip: 'Cổng phụ huynh',
            )
          else
            IconButton(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.close),
              tooltip: 'Kết thúc preview',
            ),
        ],
        bottom: NavigationBar(
          selectedIndex: tab,
          onDestinationSelected: open,
          destinations: childMode
              ? const [
                  NavigationDestination(
                    icon: Icon(Icons.cottage_outlined),
                    selectedIcon: Icon(Icons.cottage_rounded),
                    label: 'Khám phá',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.auto_stories_outlined),
                    label: 'Bài học',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.smart_display_outlined),
                    label: 'Video',
                  ),
                ]
              : const [
                  NavigationDestination(
                    icon: Icon(Icons.cottage_outlined),
                    label: 'Gia đình',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.insights_rounded),
                    label: 'Hoạt động',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.settings_outlined),
                    label: 'Cài đặt',
                  ),
                ],
        ),
        children: childMode
            ? childHome()
            : switch (tab) {
                0 => parentHome(),
                1 => activity(),
                _ => settings(),
              },
      ),
    ),
  );
  List<Widget> parentHome() => [
    const PoGarden(
      title: 'Cùng con lớn lên,\nmỗi ngày một chút',
      subtitle: 'Một không gian nhỏ, ngàn điều mới.',
      compact: true,
    ),
    const PoHeading(
      'Hôm nay ai cùng học?',
      subtitle: 'Mỗi bé có một hành trình riêng',
    ),
    for (var i = 0; i < model.children.length; i++)
      PoCard(
        color: i == model.selected ? PoPalette.lavender : Colors.white,
        onTap: () => model.choose(i),
        child: Row(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: Colors.white,
              child: PoPicture(
                ['flower', 'sun', 'panda', 'cat'][model.children[i].avatar % 4],
                size: 42,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    model.children[i].name,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Text(
                    '${model.children[i].age} tuổi · Hồ sơ tổng hợp',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            Icon(
              i == model.selected
                  ? Icons.check_circle_rounded
                  : Icons.circle_outlined,
              color: PoPalette.pink,
            ),
          ],
        ),
      ),
    PoAction(
      'Vào thế giới của bé',
      icon: Icons.play_arrow_rounded,
      onPressed: () => gate(enterChild: true),
    ),
    PoAction(
      'Thêm hồ sơ mẫu',
      icon: Icons.add_rounded,
      secondary: true,
      onPressed: () => push(PreviewChildForm(model: model)),
    ),
    PoCard(
      color: PoPalette.peach,
      onTap: () => push(PreviewPremium(childName: model.child.name)),
      child: const Row(
        children: [
          Icon(
            Icons.workspace_premium_rounded,
            color: PoPalette.pink,
            size: 36,
          ),
          SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Khám phá Premium Core',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                Text(
                  'Xem phạm vi & lựa chọn gói',
                  style: TextStyle(fontSize: 14),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right),
        ],
      ),
    ),
    const PoHeading('Một chút gợi ý cho ba mẹ'),
    const PoCard(
      color: PoPalette.mint,
      child: Text(
        'Cùng con gọi tên các đồ vật xung quanh. Cho con thời gian thử và khuyến khích sự tò mò.',
      ),
    ),
  ];
  List<Widget> activity() => [
    const PoGarden(
      title: 'Những bước nhỏ\nđáng nhớ',
      subtitle: 'Hoạt động trong lượt preview này',
      compact: true,
    ),
    const PoHeading(
      'Lượt chơi của bé',
      subtitle: 'Chỉ lưu trong bộ nhớ, không phải lịch sử máy chủ',
    ),
    if (model.completed.isEmpty)
      const PoCard(
        child: Column(
          children: [
            Icon(Icons.spa_outlined, size: 50),
            SizedBox(height: 12),
            Text('Hành trình đang chờ bé'),
            Text('Chơi một hoạt động mẫu để xem kết quả tại đây.'),
          ],
        ),
      ),
    for (final name in model.completed.reversed)
      PoCard(
        child: ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.check_circle_outline, color: Colors.green),
          title: Text(name),
          subtitle: const Text('Đã chơi xong · chỉ trong preview'),
        ),
      ),
    const PoCard(
      color: PoPalette.lavender,
      child: Text(
        'MimiGo không suy ra điểm số, xếp hạng hay mức độ thành thạo từ số lượt chơi. Lịch sử thật cần xác minh phụ huynh và dữ liệu máy chủ.',
      ),
    ),
  ];
  List<Widget> settings() => [
    const PoGarden(
      title: 'Ba mẹ an tâm,\nbé vui khám phá',
      subtitle: 'Quản lý gia đình trong một nơi',
      compact: true,
    ),
    _setting(
      Icons.person_outline,
      'Tài khoản phụ huynh',
      'Tài khoản mẫu · không có phiên đăng nhập thật',
      () => push(const PreviewAccount()),
    ),
    _setting(
      Icons.face_retouching_natural,
      'Hồ sơ của bé',
      model.child.name,
      () => push(PreviewChildForm(model: model, edit: true)),
    ),
    _setting(
      Icons.shield_outlined,
      'Quyền riêng tư & đồng ý',
      'Thông tin minh bạch, lựa chọn độc lập',
      () => push(const PreviewPrivacy()),
    ),
    _setting(
      Icons.workspace_premium_outlined,
      'Gói học & phạm vi',
      'Trả trước · không tự động gia hạn',
      () => push(PreviewPremium(childName: model.child.name)),
    ),
    _setting(
      Icons.lock_outline,
      'Cổng phụ huynh',
      'Thiết lập lại PIN mẫu trong bộ nhớ',
      () async {
        previewPin = null;
        await gate();
      },
    ),
    PoCard(
      child: Column(
        children: [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Âm thanh hoạt động'),
            subtitle: const Text('Tùy chọn giao diện · chưa phát âm thanh'),
            value: model.sound,
            onChanged: (v) => model.preferences(audio: v),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Nhắc học'),
            subtitle: const Text('Preview · không đặt thông báo thiết bị'),
            value: model.reminders,
            onChanged: (v) => model.preferences(reminder: v),
          ),
        ],
      ),
    ),
    PoAction(
      'Kết thúc preview',
      icon: Icons.logout,
      secondary: true,
      onPressed: () => Navigator.pop(context),
    ),
  ];
  Widget _setting(
    IconData icon,
    String title,
    String subtitle,
    VoidCallback action,
  ) => PoCard(
    onTap: action,
    child: Row(
      children: [
        Icon(icon, color: PoPalette.pink),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
              Text(subtitle, style: const TextStyle(fontSize: 13)),
            ],
          ),
        ),
        const Icon(Icons.chevron_right),
      ],
    ),
  );
  List<Widget> childHome() => [
    PoGarden(
      title: tab == 2
          ? 'Rạp phim nhỏ\ncủa Mimi'
          : 'Chào ${model.child.name}!\nMình cùng khám phá',
      subtitle: tab == 2
          ? 'Video thật chưa có trong preview.'
          : 'Chọn một điều bé muốn thử hôm nay.',
    ),
    if (tab == 2) ...[
      const PoHeading(
        'Kho video',
        subtitle: 'Không dùng hình động thay cho video thật',
      ),
      const PoCard(
        child: Column(
          children: [
            Icon(Icons.video_library_outlined, size: 64, color: PoPalette.pink),
            SizedBox(height: 12),
            Text('Chưa có video phát hành'),
            Text(
              'Nội dung và quyền phát cần được dịch vụ xác nhận. Bé vẫn có thể chơi hoạt động mẫu.',
            ),
          ],
        ),
      ),
      PoAction(
        'Chơi cùng Mimi',
        onPressed: () =>
            push(PreviewLesson(domain: previewDomains.first, model: model)),
      ),
    ] else ...[
      const PoHeading(
        'Bé thích khám phá gì?',
        subtitle: '6 góc chơi mẫu · không phải danh mục đã phát hành',
      ),
      LayoutBuilder(
        builder: (context, c) => Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (var i = 0; i < previewDomains.length; i++)
              SizedBox(
                width: MediaQuery.textScalerOf(context).scale(16) > 24
                    ? c.maxWidth
                    : (c.maxWidth - 12) / 2,
                child: PoCard(
                  color: [
                    PoPalette.peach,
                    PoPalette.lavender,
                    PoPalette.sky,
                    PoPalette.mint,
                    PoPalette.lavender,
                    PoPalette.peach,
                  ][i],
                  onTap: () => push(
                    PreviewSubject(domain: previewDomains[i], model: model),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      PoDomainMark(i),
                      Text(
                        previewDomains[i].name,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 6),
                      const Row(
                        children: [
                          Text('Khám phá', style: TextStyle(fontSize: 13)),
                          Spacer(),
                          Icon(Icons.arrow_forward_rounded, size: 18),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
      const PoHeading('Mimi rủ bé cùng chơi'),
      PoCard(
        color: PoPalette.mint,
        onTap: () =>
            push(PreviewLesson(domain: previewDomains.first, model: model)),
        child: const Row(
          children: [
            PoPicture('apple', size: 48),
            SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  PoPill('HOẠT ĐỘNG MẪU'),
                  SizedBox(height: 8),
                  Text(
                    'Giỏ táo của Mimi',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  Text('Đếm thật vui, chọn thật khéo'),
                ],
              ),
            ),
            Icon(Icons.play_circle_fill, color: PoPalette.pink, size: 36),
          ],
        ),
      ),
    ],
  ];
}

class PreviewGate extends StatefulWidget {
  const PreviewGate({super.key, required this.setup, this.expected});
  final bool setup;
  final String? expected;
  @override
  State<PreviewGate> createState() => _PreviewGateState();
}

class _PreviewGateState extends State<PreviewGate> {
  final pin = TextEditingController(), confirm = TextEditingController();
  String? error;
  @override
  void dispose() {
    pin.dispose();
    confirm.dispose();
    super.dispose();
  }

  void submit() {
    if (!RegExp(r'^\d{6}$').hasMatch(pin.text)) {
      setState(() => error = 'Nhập đủ 6 chữ số.');
      return;
    }
    if (widget.setup && pin.text != confirm.text) {
      setState(() => error = 'Hai mã PIN chưa khớp.');
      return;
    }
    if (!widget.setup && pin.text != widget.expected) {
      pin.clear();
      setState(() => error = 'PIN mẫu chưa đúng. Thử lại nhé.');
      return;
    }
    Navigator.pop(context, pin.text);
  }

  @override
  Widget build(BuildContext context) => PoScaffold(
    title: 'Cổng phụ huynh',
    back: () => Navigator.pop(context),
    children: [
      const Center(child: MimiBee(size: 120)),
      PoHeading(
        widget.setup ? 'Tạo PIN mẫu của ba mẹ' : 'Mời ba mẹ nhập PIN',
        subtitle: 'Chỉ mô phỏng · không bảo vệ tài khoản thật',
      ),
      const Text(
        'Dùng một mã thử riêng. Không nhập PIN thật. PIN mẫu chỉ ở trong bộ nhớ đến khi kết thúc preview.',
      ),
      TextField(
        key: const Key('previewPin'),
        controller: pin,
        obscureText: true,
        keyboardType: TextInputType.number,
        enableSuggestions: false,
        autocorrect: false,
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(6),
        ],
        decoration: const InputDecoration(labelText: 'PIN mẫu 6 chữ số'),
      ),
      if (widget.setup)
        TextField(
          key: const Key('previewPinConfirm'),
          controller: confirm,
          obscureText: true,
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(6),
          ],
          decoration: const InputDecoration(labelText: 'Nhập lại PIN mẫu'),
        ),
      if (error != null)
        Text(
          error!,
          style: const TextStyle(color: Colors.red),
          semanticsLabel: error,
        ),
      PoAction('Tiếp tục preview', onPressed: submit),
    ],
  );
}

class PreviewChildForm extends StatefulWidget {
  const PreviewChildForm({super.key, required this.model, this.edit = false});
  final PreviewState model;
  final bool edit;
  @override
  State<PreviewChildForm> createState() => _PreviewChildFormState();
}

class _PreviewChildFormState extends State<PreviewChildForm> {
  final form = GlobalKey<FormState>();
  late final name = TextEditingController(
    text: widget.edit ? widget.model.child.name : '',
  );
  late int avatar = widget.edit ? widget.model.child.avatar : 0;
  late int age = widget.edit ? widget.model.child.age : 4;
  bool reviewed = false, purpose = false, declared = false;
  @override
  void dispose() {
    name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PoScaffold(
    title: widget.edit ? 'Hồ sơ mẫu của bé' : 'Thêm một bạn nhỏ',
    back: () => Navigator.pop(context),
    children: [
      const PoGarden(
        title: 'Mỗi bé là một\nđiều đặc biệt',
        subtitle: 'Tạo không gian học tập riêng',
        compact: true,
      ),
      if (!widget.edit && !reviewed) ...[
        const PoHeading('Ba mẹ cùng xem trước'),
        const PoCard(
          child: Text(
            'Thông báo mẫu · không phải văn bản pháp lý. Bản preview không gửi ngày sinh, tên hay lựa chọn của bé lên mạng. Luồng thật tải phiên bản thông báo từ máy chủ trước khi thu thập ngày sinh.',
          ),
        ),
        CheckboxListTile(
          value: purpose,
          onChanged: (v) => setState(() => purpose = v!),
          title: const Text('Cho phép hồ sơ tổng hợp dùng để thử giao diện'),
        ),
        CheckboxListTile(
          value: declared,
          onChanged: (v) => setState(() => declared = v!),
          title: const Text(
            'Tôi hiểu đây không phải đồng ý xử lý dữ liệu thật',
          ),
        ),
        PoAction(
          'Tiếp tục với hồ sơ mẫu',
          onPressed: purpose && declared
              ? () => setState(() => reviewed = true)
              : null,
        ),
      ] else
        Form(
          key: form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const PoHeading(
                'Thông tin của bé',
                subtitle: 'Không nhập dữ liệu của trẻ thật',
              ),
              Wrap(
                spacing: 10,
                children: [
                  for (var i = 0; i < 4; i++)
                    IconButton.filledTonal(
                      onPressed: () => setState(() => avatar = i),
                      isSelected: avatar == i,
                      tooltip: 'Ảnh đại diện ${i + 1}',
                      icon: PoPicture(
                        ['flower', 'sun', 'panda', 'cat'][i],
                        size: 36,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(
                key: const Key('previewChildName'),
                controller: name,
                maxLength: 40,
                decoration: const InputDecoration(labelText: 'Tên gọi mẫu'),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Nhập tên gọi mẫu.' : null,
              ),
              const SizedBox(height: 12),
              if (!widget.edit)
                DropdownButtonFormField<int>(
                  initialValue: age,
                  decoration: const InputDecoration(labelText: 'Tuổi mẫu'),
                  items: [
                    for (var i = 2; i <= 6; i++)
                      DropdownMenuItem(value: i, child: Text('$i tuổi')),
                  ],
                  onChanged: (v) => setState(() => age = v!),
                ),
              if (widget.edit)
                Text(
                  '${widget.model.child.age} tuổi · tuổi tổng hợp, không phải xác nhận của máy chủ. Chỉnh sửa ngày sinh thật chưa được hỗ trợ.',
                ),
              const SizedBox(height: 20),
              PoAction(
                'Lưu hồ sơ mẫu',
                onPressed: () {
                  if (!form.currentState!.validate()) return;
                  final child = PreviewChild(
                    name.text.trim(),
                    avatar,
                    age: age,
                  );
                  if (widget.edit) {
                    widget.model.edit(child);
                  } else {
                    widget.model.add(child);
                  }
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        ),
    ],
  );
}

class PreviewPremium extends StatefulWidget {
  const PreviewPremium({super.key, required this.childName});
  final String childName;
  @override
  State<PreviewPremium> createState() => _PreviewPremiumState();
}

class _PreviewPremiumState extends State<PreviewPremium> {
  int months = 3;
  bool summary = false;
  @override
  Widget build(BuildContext context) => PoScaffold(
    title: summary ? 'Tóm tắt lựa chọn mẫu' : 'Premium Core',
    back: () {
      if (summary) {
        setState(() => summary = false);
      } else {
        Navigator.pop(context);
      }
    },
    children: [
      const PoGarden(
        title: 'Thêm cánh cho\nsự tò mò',
        subtitle: 'Học theo nhịp riêng của mỗi bé',
        compact: true,
      ),
      const PoPill('CHƯA CÓ GIÁ THƯƠNG MẠI ĐƯỢC DUYỆT', color: PoPalette.peach),
      PoHeading('Gói dành cho ${widget.childName}'),
      const PoCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Free', style: TextStyle(fontWeight: FontWeight.w800)),
            Text('Bài Free theo tuổi và quyền do máy chủ xác nhận.'),
            Divider(),
            Text('Premium Core', style: TextStyle(fontWeight: FontWeight.w800)),
            Text(
              'Quyền theo từng bé và phiên bản phạm vi thương mại. Chương trình đặc biệt không tự động bao gồm.',
            ),
          ],
        ),
      ),
      if (!summary) ...[
        const PoHeading('Chọn thời hạn để xem trước'),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final n in [1, 3, 6, 12])
              ChoiceChip(
                label: Text('$n tháng'),
                selected: months == n,
                onSelected: (_) => setState(() => months = n),
              ),
          ],
        ),
        PoAction(
          'Xem tóm tắt',
          onPressed: () => setState(() => summary = true),
        ),
      ] else ...[
        PoCard(
          color: PoPalette.lavender,
          child: Text(
            '${widget.childName}\nPremium Core · $months tháng\nGiá: Chờ dữ liệu máy chủ\nTrạng thái: Chưa mua · không có quyền được cấp',
          ),
        ),
        const PoAction(
          'Thanh toán chưa khả dụng trong preview',
          icon: Icons.lock_outline,
          onPressed: null,
        ),
      ],
      const Text(
        'Trả trước, không tự động gia hạn. Giá và phạm vi của giao dịch cũ được giữ theo phiên bản đã mua. Quy tắc tuổi và hạn quyền do máy chủ xử lý.',
      ),
      const Text(
        'Không thu tiền thật. Luồng simulator chỉ ở khu vực phụ huynh đã xác minh trên API; preview không tạo giao dịch hay quyền.',
      ),
    ],
  );
}

class PreviewPrivacy extends StatelessWidget {
  const PreviewPrivacy({super.key});
  @override
  Widget build(BuildContext context) => PoScaffold(
    title: 'Quyền riêng tư',
    back: () => Navigator.pop(context),
    children: const [
      PoHeading('Ba mẹ chủ động lựa chọn'),
      PoCard(
        child: Text(
          'Preview chỉ dùng bộ nhớ tạm. Khi rời preview, các hồ sơ và hoạt động mẫu được xóa. Không có dữ liệu gửi đến Neon hoặc Render.',
        ),
      ),
      PoHeading('Trong chế độ API'),
      PoCard(
        child: Text(
          'Mỗi lần tạo hồ sơ phải tải thông báo riêng và chọn từng mục đích từ trạng thái chưa tích. OTP không chứng minh quyền giám hộ. Phiên bản pháp lý đầy đủ, xác minh giám hộ, thu hồi đồng ý, xuất và xóa dữ liệu còn chờ chính sách và hợp đồng được duyệt.',
        ),
      ),
      PoAction(
        'Thu hồi / xuất / xóa chưa khả dụng',
        icon: Icons.lock_outline,
        onPressed: null,
      ),
    ],
  );
}

class PreviewAccount extends StatelessWidget {
  const PreviewAccount({super.key});
  @override
  Widget build(BuildContext context) => PoScaffold(
    title: 'Tài khoản mẫu',
    back: () => Navigator.pop(context),
    children: const [
      Center(child: MimiBee()),
      PoHeading('Gia đình Mimi'),
      PoCard(
        child: Text(
          'Đây là hồ sơ giao diện tổng hợp. Không có địa chỉ email, mật khẩu hay mã phiên thật. Đăng nhập thật nằm ở màn hình chào, trong chế độ Live API.',
        ),
      ),
      PoAction(
        'Sửa tài khoản chưa được hỗ trợ',
        onPressed: null,
        icon: Icons.lock_outline,
      ),
    ],
  );
}

/// Optional walkthrough: generated local OTP, never a real verification claim.
class PreviewRegistration extends StatefulWidget {
  const PreviewRegistration({super.key});
  @override
  State<PreviewRegistration> createState() => _PreviewRegistrationState();
}

class _PreviewRegistrationState extends State<PreviewRegistration> {
  final form = GlobalKey<FormState>();
  final email = TextEditingController(),
      name = TextEditingController(),
      password = TextEditingController(),
      code = TextEditingController();
  bool accepted = false;
  int step = 0, remaining = 0;
  String? error;
  late String otp;
  Timer? timer;
  void issue() {
    otp = '${100000 + Random.secure().nextInt(900000)}';
    remaining = 60;
    timer?.cancel();
    timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() => remaining--);
      if (remaining == 0) t.cancel();
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    email.dispose();
    name.dispose();
    password.dispose();
    code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PoScaffold(
    title: ['Tạo tài khoản · mẫu', 'Xác nhận · mẫu', 'Sẵn sàng khám phá'][step],
    back: () => Navigator.pop(context),
    children: [
      const Center(child: MimiBee(size: 120)),
      if (step == 0)
        Form(
          key: form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Không nhập thông tin thật. Luồng này không tạo tài khoản.',
              ),
              TextFormField(
                controller: name,
                decoration: const InputDecoration(
                  labelText: 'Tên phụ huynh mẫu',
                ),
                validator: (v) =>
                    (v ?? '').trim().isEmpty ? 'Nhập tên mẫu.' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: email,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Email mẫu'),
                validator: (v) =>
                    RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v ?? '')
                    ? null
                    : 'Kiểm tra định dạng email.',
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: password,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Mật khẩu mẫu (ít nhất 8 ký tự)',
                ),
                validator: (v) =>
                    (v ?? '').length < 8 ? 'Cần ít nhất 8 ký tự.' : null,
              ),
              CheckboxListTile(
                value: accepted,
                onChanged: (v) => setState(() => accepted = v!),
                title: const Text(
                  'Tôi hiểu đây là giao diện thử, không phải điều khoản pháp lý',
                ),
              ),
              PoAction(
                'Tiếp tục mô phỏng',
                onPressed: accepted
                    ? () {
                        if (form.currentState!.validate()) {
                          password.clear();
                          issue();
                          setState(() => step = 1);
                        }
                      }
                    : null,
              ),
            ],
          ),
        ),
      if (step == 1) ...[
        Text('Mã tổng hợp trong bộ nhớ: $otp. Không có email được gửi.'),
        TextField(
          controller: code,
          keyboardType: TextInputType.number,
          maxLength: 6,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: const InputDecoration(labelText: 'Mã 6 chữ số'),
        ),
        if (error != null)
          Text(error!, style: const TextStyle(color: Colors.red)),
        PoAction(
          'Xác nhận mã mẫu',
          onPressed: () {
            if (code.text != otp) {
              setState(() => error = 'Mã mẫu chưa khớp.');
            } else {
              timer?.cancel();
              setState(() => step = 2);
            }
          },
        ),
        TextButton(
          onPressed: remaining > 0
              ? null
              : () {
                  issue();
                  code.clear();
                  setState(() => error = null);
                },
          child: Text(
            remaining > 0 ? 'Gửi lại sau ${remaining}s' : 'Tạo mã mẫu mới',
          ),
        ),
      ],
      if (step == 2) ...[
        const PoHeading('Đã xem xong luồng đăng ký!'),
        const Text(
          'Chưa có tài khoản thật nào được tạo hay xác minh. Bây giờ ba mẹ có thể thử không gian gia đình bằng dữ liệu tổng hợp.',
        ),
        PoAction(
          'Khám phá gia đình mẫu',
          onPressed: () => Navigator.pushReplacement(
            context,
            MaterialPageRoute<void>(builder: (_) => const PreviewFamilySetup()),
          ),
        ),
      ],
    ],
  );
}

class PreviewFamilySetup extends StatefulWidget {
  const PreviewFamilySetup({super.key});
  @override
  State<PreviewFamilySetup> createState() => _PreviewFamilySetupState();
}

class _PreviewFamilySetupState extends State<PreviewFamilySetup> {
  int count = 1;
  @override
  Widget build(BuildContext context) => PoScaffold(
    title: 'Gia đình mình có mấy bé?',
    back: () => Navigator.pop(context),
    children: [
      const PoGarden(
        title: 'Mỗi bạn nhỏ,\nmột hành trình',
        subtitle: 'Ba mẹ có thể thêm từng hồ sơ riêng',
        compact: true,
      ),
      const Text(
        'Số lượng chỉ dùng để xem trước. Mỗi hồ sơ thật luôn cần một lần xem xét thông báo và lựa chọn mục đích độc lập. Không có giới hạn 5 bé.',
      ),
      PoCard(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            IconButton(
              onPressed: count > 1 ? () => setState(() => count--) : null,
              icon: const Icon(Icons.remove_circle_outline),
              tooltip: 'Bớt một bé',
            ),
            Text(
              '$count bé',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            IconButton(
              onPressed: () => setState(() => count++),
              icon: const Icon(Icons.add_circle_outline),
              tooltip: 'Thêm một bé',
            ),
          ],
        ),
      ),
      const Text(
        'Không có hồ sơ hay sự đồng ý nào được tự động tạo từ số lượng đã chọn. Gia đình mẫu tiếp theo có hai bé tổng hợp để thử chuyển hồ sơ.',
      ),
      PoAction(
        'Xem gia đình mẫu',
        onPressed: () => Navigator.pushReplacement(
          context,
          MaterialPageRoute<void>(builder: (_) => const PoPreview()),
        ),
      ),
    ],
  );
}
