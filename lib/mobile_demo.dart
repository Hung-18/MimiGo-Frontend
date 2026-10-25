import 'package:flutter/material.dart';

import 'learning_models.dart';
import 'main.dart' show Frame;
import 'mimigo_design.dart';

/// An explicitly local presentation, never an authenticated account/session.
/// It cannot access an API, vault, PIN, consent record or live learning cache.
class MobileDemo extends StatefulWidget {
  const MobileDemo({super.key, this.startInChildMode = false});
  final bool startInChildMode;

  @override
  State<MobileDemo> createState() => _MobileDemoState();
}

enum _DemoPage { parent, child, introduction, story, cue, feedback, completed }

const _fruits = ['Táo', 'Chuối', 'Lê'];

/// Reuses the Learning cue/option contract; timing is authored story position,
/// not a claim that a video has played. Correctness is local demo content only.
final fruitDemoCues = List<LearningCue>.unmodifiable([
  for (final item in [
    (1, 'Quả nào là quả táo?', 2000),
    (2, 'Chọn quả chuối để vào giỏ nhé!', 5000),
    (3, 'Quả nào còn lại trên bàn?', 8000),
  ])
    LearningCue.fromJson({
      'cueId': 'local-fruit-${item.$1}',
      'seq': item.$1,
      'pauseAtMs': item.$3,
      'promptText': item.$2,
      'promptAssetId': null,
      'options': [
        for (var i = 0; i < _fruits.length; i++)
          {'optionId': 'fruit-$i', 'position': i + 1, 'labelText': _fruits[i]},
      ],
    }),
]);

class _MobileDemoState extends State<MobileDemo> {
  late _DemoPage page = widget.startInChildMode
      ? _DemoPage.child
      : _DemoPage.parent;
  String alias = 'Bé Mây';
  int cueIndex = 0;
  int? selected;
  bool exiting = false;
  String? emptyDomain;
  final answers = <int, int>{};

  void begin() => setState(() {
    cueIndex = 0;
    selected = null;
    answers.clear();
    page = _DemoPage.story;
  });

  Future<void> exit() async {
    if (exiting) return;
    exiting = true;
    final leave = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Kết thúc bản demo?'),
        content: const Text(
          'Lựa chọn và kết quả trong lượt thử này sẽ được xóa. Muốn dùng tài khoản, phụ huynh cần đăng nhập ở màn hình chào.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Ở lại'),
          ),
          FilledButton(
            key: const Key('demoConfirmExit'),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Kết thúc demo'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    exiting = false;
    if (leave == true) {
      answers.clear();
      Navigator.pop(context);
    }
  }

  void back() {
    if (page == _DemoPage.parent || page == _DemoPage.child) {
      if (emptyDomain != null) {
        setState(() => emptyDomain = null);
      } else {
        exit();
      }
    } else {
      setState(() => page = _DemoPage.child);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: false,
    onPopInvokedWithResult: (didPop, result) {
      if (!didPop) back();
    },
    child: Scaffold(
      body: SafeArea(
        child: Frame(
          title: switch (page) {
            _DemoPage.parent => 'Cùng bé khám phá',
            _DemoPage.child => 'Chào $alias!',
            _ => 'Giỏ trái cây vui vẻ',
          },
          childMode: page != _DemoPage.parent,
          back: back,
          // Suppress the general engineering banner on this explicitly labeled
          // local route; it remains on every existing integration screen.
          demoPresentation: true,
          children: [
            const Text(
              'DEMO · Không kết nối mạng',
              key: Key('mobileDemoLabel'),
              style: TextStyle(color: MimiColors.muted, fontSize: 14),
            ),
            ...switch (page) {
              _DemoPage.parent => parent(context),
              _DemoPage.child => child(context),
              _DemoPage.introduction => introduction(context),
              _DemoPage.story => story(context),
              _DemoPage.cue || _DemoPage.feedback => question(context),
              _DemoPage.completed => completed(context),
            },
          ],
        ),
      ),
    ),
  );

  List<Widget> parent(BuildContext context) => [
    const MimiNotice(
      icon: Icons.family_restroom,
      child: Text(
        'Chọn một hồ sơ mẫu để thử. Đây không phải tài khoản hay dữ liệu của trẻ thật; không tạo đồng ý hoặc xác minh phụ huynh.',
      ),
    ),
    Text(
      'Hôm nay ai cùng chơi?',
      style: Theme.of(context).textTheme.titleLarge,
    ),
    for (final name in ['Bé Mây', 'Bé Nắng'])
      Card(
        child: RadioListTile<String>(
          key: Key('demoProfile-$name'),
          value: name,
          // ignore: deprecated_member_use
          groupValue: alias,
          // ignore: deprecated_member_use
          onChanged: (value) => setState(() => alias = value!),
          title: Text(name),
          subtitle: const Text('Hồ sơ mẫu · chỉ trong lượt demo'),
          secondary: const MimiAvatar(stockKey: 'bee-yellow'),
        ),
      ),
    Text(
      'Không gian của $alias',
      style: Theme.of(context).textTheme.titleLarge,
    ),
    const Text(
      'Khám phá trái cây qua ba điểm dừng tương tác. Không có điểm số hay đánh giá năng lực.',
    ),
    FilledButton.icon(
      key: const Key('demoEnterChild'),
      onPressed: () => setState(() => page = _DemoPage.child),
      icon: const Icon(Icons.play_arrow_rounded),
      label: const Text('Bắt đầu khám phá'),
    ),
    const OutlinedButton(
      onPressed: null,
      child: Text('Lịch sử và tiến độ · Đã khóa'),
    ),
    const OutlinedButton(
      onPressed: null,
      child: Text('Khu phụ huynh · Cần xác minh'),
    ),
    const Text(
      'Demo không hỗ trợ PIN, hồ sơ riêng tư hoặc lịch sử đã lưu. Dùng luồng đăng nhập và Parent Gate của chế độ API để truy cập khi được cấp quyền.',
    ),
  ];

  List<Widget> child(BuildContext context) => [
    if (emptyDomain != null) ...[
      Icon(
        MimiDomainStyle.forCode(emptyDomain!).icon,
        size: 64,
        color: MimiColors.blueText,
      ),
      Text(
        'Mình khám phá sau nhé!',
        style: Theme.of(context).textTheme.titleLarge,
      ),
      const Text('Lĩnh vực này chưa có bài trong bản demo.'),
      FilledButton(
        onPressed: () => setState(() => emptyDomain = null),
        child: const Text('Về trang khám phá'),
      ),
    ] else ...[
      Text(
        'Chạm để cùng chơi nhé!',
        style: Theme.of(context).textTheme.titleLarge,
      ),
      const FruitScene(stage: 0),
      FilledButton.icon(
        key: const Key('demoFruitLesson'),
        onPressed: () => setState(() => page = _DemoPage.introduction),
        icon: const Icon(Icons.shopping_basket_outlined),
        label: const Text('Giỏ trái cây vui vẻ'),
      ),
      const Text('Câu chuyện tương tác · 3 điểm dừng'),
      MimiTileGrid(
        children: [
          for (final domain in const [
            ('MATH', 'Toán'),
            ('LANGUAGE', 'Ngôn ngữ'),
            ('ENGLISH', 'Tiếng Anh'),
            ('LIFESKILLS', 'Kỹ năng sống'),
            ('LOGIC', 'Logic'),
            ('DISCOVERY', 'Khám phá'),
          ])
            MimiDomainTile(
              key: Key('demoDomain-${domain.$1}'),
              label: domain.$2,
              code: domain.$1,
              description: domain.$1 == 'LOGIC'
                  ? 'Giỏ trái cây · mẫu'
                  : 'Chưa có bài mẫu',
              onPressed: () => setState(() {
                if (domain.$1 == 'LOGIC') {
                  page = _DemoPage.introduction;
                } else {
                  emptyDomain = domain.$1;
                }
              }),
            ),
        ],
      ),
    ],
    OutlinedButton.icon(
      key: const Key('demoParentLocked'),
      onPressed: null,
      icon: const Icon(Icons.lock_outline),
      label: const Text('Phụ huynh / đổi bé · Đã khóa'),
    ),
    TextButton(onPressed: exit, child: const Text('Kết thúc bản demo')),
  ];

  List<Widget> introduction(BuildContext context) => [
    const FruitScene(stage: 0),
    Text(
      'Cùng xếp trái cây vào giỏ!',
      style: Theme.of(context).textTheme.headlineSmall,
    ),
    const Text(
      'Nhìn hình, chọn quả và khám phá điều tiếp theo. Bé có thể nhờ người lớn đọc cùng.',
    ),
    const MimiNotice(
      icon: Icons.auto_stories_outlined,
      child: Text(
        'Truyện tranh tương tác tại máy · không phải video. Hình minh họa đơn giản được vẽ trong ứng dụng; chưa phải nội dung phát hành đã duyệt.',
      ),
    ),
    FilledButton(
      key: const Key('demoStartStory'),
      onPressed: begin,
      child: const Text('Cùng chơi nào!'),
    ),
  ];

  List<Widget> story(BuildContext context) => [
    FruitScene(stage: cueIndex),
    Text(
      const [
        'Trên bàn có táo, chuối và lê. Mình cùng chuẩn bị một giỏ trái cây nhé!',
        'Táo đã vào giỏ. Chuối vàng đang chờ mình đấy!',
        'Táo và chuối đã vào giỏ. Còn một quả trên bàn này!',
      ][cueIndex],
      style: Theme.of(context).textTheme.titleLarge,
    ),
    Text('Trang ${cueIndex + 1} / 3 · Truyện tranh demo'),
    FilledButton.icon(
      key: const Key('demoPauseCue'),
      onPressed: () => setState(() => page = _DemoPage.cue),
      icon: const Icon(Icons.touch_app_outlined),
      label: const Text('Dừng lại, cùng chọn nhé!'),
    ),
  ];

  List<Widget> question(BuildContext context) {
    final cue = fruitDemoCues[cueIndex];
    final feedback = page == _DemoPage.feedback;
    final correct = selected == cueIndex;
    return [
      Text(
        'Cùng chọn ${cue.seq} / 3',
        style: Theme.of(context).textTheme.titleMedium,
      ),
      FruitScene(stage: cueIndex),
      Semantics(
        header: true,
        child: Text(
          cue.promptText,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
      ),
      MimiTileGrid(
        minimumWidth: 120,
        children: [
          for (var i = 0; i < cue.options.length; i++)
            Semantics(
              selected: selected == i,
              child: OutlinedButton(
                key: Key('demoAnswer-$i'),
                style: OutlinedButton.styleFrom(
                  disabledForegroundColor: MimiColors.ink,
                  backgroundColor: selected == i
                      ? MimiColors.sky
                      : Colors.white,
                  side: BorderSide(
                    color: selected == i
                        ? MimiColors.blueText
                        : MimiColors.border,
                    width: selected == i ? 3 : 1.5,
                  ),
                ),
                onPressed: feedback
                    ? null
                    : () => setState(() {
                        selected = i;
                        answers[cueIndex] = i;
                        page = _DemoPage.feedback;
                      }),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FruitPicture(kind: i, size: 76),
                    Text(cue.options[i].labelText),
                  ],
                ),
              ),
            ),
        ],
      ),
      if (feedback) ...[
        Semantics(
          liveRegion: true,
          child: MimiNotice(
            icon: correct
                ? Icons.check_circle_outline
                : Icons.lightbulb_outline,
            color: correct ? const Color(0xFFEAF6EB) : const Color(0xFFFFF4CD),
            child: Text(
              correct
                  ? 'Đúng rồi! ${_fruits[cueIndex]} vào giỏ nhé.'
                  : 'Cùng nhìn lại nhé: đây là ${_fruits[cueIndex].toLowerCase()}. Mình cùng nhớ hình của quả này!',
              key: const Key('demoFeedback'),
            ),
          ),
        ),
        if (!correct) Center(child: FruitPicture(kind: cueIndex, size: 96)),
        FilledButton(
          key: const Key('demoContinueStory'),
          onPressed: () => setState(() {
            selected = null;
            if (cueIndex < fruitDemoCues.length - 1) {
              cueIndex++;
              page = _DemoPage.story;
            } else if (answers.length == fruitDemoCues.length) {
              page = _DemoPage.completed;
            }
          }),
          child: Text(
            cueIndex < 2 ? 'Xem tiếp câu chuyện' : 'Xếp xong giỏ rồi!',
          ),
        ),
      ],
    ];
  }

  List<Widget> completed(BuildContext context) => [
    const FruitScene(stage: 3),
    Text(
      'Giỏ trái cây đã sẵn sàng!',
      key: const Key('demoCompleted'),
      style: Theme.of(context).textTheme.headlineSmall,
    ),
    const Text('Cảm ơn bé đã cùng khám phá táo, chuối và lê.'),
    const MimiNotice(
      icon: Icons.info_outline,
      child: Text(
        'Đã chơi xong bản demo trong lượt này. Không gửi hay lưu tiến độ lên máy chủ. Kết quả sẽ xóa khi chơi lại hoặc thoát.',
      ),
    ),
    FilledButton.icon(
      key: const Key('demoReplay'),
      onPressed: begin,
      icon: const Icon(Icons.replay),
      label: const Text('Chơi lại câu chuyện'),
    ),
    OutlinedButton(
      onPressed: () => setState(() => page = _DemoPage.child),
      child: const Text('Về trang khám phá'),
    ),
  ];
}

class FruitScene extends StatelessWidget {
  const FruitScene({super.key, required this.stage});
  final int stage;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: MimiColors.sky,
      borderRadius: BorderRadius.circular(24),
    ),
    child: Column(
      children: [
        const Icon(Icons.wb_sunny_outlined, color: MimiColors.ink, size: 32),
        const SizedBox(height: 12),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          children: [
            for (var i = stage; i < 3; i++) FruitPicture(kind: i, size: 72),
          ],
        ),
        const Divider(color: MimiColors.muted),
        const Icon(
          Icons.shopping_basket_outlined,
          size: 48,
          color: MimiColors.ink,
          semanticLabel: 'Giỏ trái cây',
        ),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          children: [
            for (var i = 0; i < stage; i++) FruitPicture(kind: i, size: 48),
          ],
        ),
      ],
    ),
  );
}

/// Original code-drawn fruit silhouettes; no extracted reference artwork,
/// downloaded media, emoji font dependency or official mascot claim.
class FruitPicture extends StatelessWidget {
  const FruitPicture({super.key, required this.kind, this.size = 72});
  final int kind;
  final double size;
  @override
  Widget build(BuildContext context) => Semantics(
    image: true,
    label: _fruits[kind],
    child: CustomPaint(size: Size.square(size), painter: _FruitPainter(kind)),
  );
}

class _FruitPainter extends CustomPainter {
  _FruitPainter(this.kind);
  final int kind;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 100, size.height / 100);
    final paint = Paint()
      ..color = [
        const Color(0xFFD83B48),
        MimiColors.yellow,
        const Color(0xFF5C9E35),
      ][kind];
    final path = Path();
    if (kind == 0) {
      path.moveTo(50, 28);
      path.cubicTo(4, 4, 9, 88, 41, 89);
      path.quadraticBezierTo(50, 85, 59, 89);
      path.cubicTo(91, 88, 96, 4, 50, 28);
    } else if (kind == 1) {
      path.moveTo(20, 18);
      path.cubicTo(7, 80, 57, 101, 87, 39);
      path.quadraticBezierTo(39, 80, 20, 18);
    } else {
      path.moveTo(43, 23);
      path.cubicTo(39, 45, 15, 52, 20, 75);
      path.cubicTo(25, 97, 77, 97, 81, 74);
      path.cubicTo(85, 53, 59, 44, 57, 23);
    }
    path.close();
    canvas.drawPath(path, paint);
    canvas.drawPath(
      path,
      Paint()
        ..color = MimiColors.ink
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    canvas.drawLine(
      Offset(kind == 1 ? 20 : 50, kind == 1 ? 18 : 26),
      Offset(kind == 1 ? 18 : 53, 12),
      Paint()
        ..color = MimiColors.ink
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round,
    );
    if (kind != 1)
      canvas.drawOval(
        const Rect.fromLTWH(54, 9, 22, 10),
        Paint()..color = const Color(0xFF32773B),
      );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _FruitPainter oldDelegate) =>
      kind != oldDelegate.kind;
}
