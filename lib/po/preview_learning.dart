import 'package:flutter/material.dart';

import 'po_design.dart';
import 'preview_state.dart';

class PreviewSubject extends StatelessWidget {
  const PreviewSubject({super.key, required this.domain, required this.model});
  final PreviewDomain domain;
  final PreviewState model;
  @override
  Widget build(BuildContext context) => PoScaffold(
    title: domain.name,
    back: () => Navigator.pop(context),
    children: [
      PoGarden(title: domain.name, subtitle: domain.description),
      if (domain.kind == 2)
        const PoCard(
          color: PoPalette.lavender,
          child: Text(
            'English Companion: biểu đạt tiếng Anh trong bài học tiếng Việt phù hợp. Đây không phải chuyển ngôn ngữ toàn ứng dụng. Tuổi và nội dung thật do máy chủ xác nhận.',
          ),
        ),
      const PoHeading(
        'Góc chơi thử của bé',
        subtitle: 'Nội dung tổng hợp, không lưu tiến độ thật',
      ),
      PoCard(
        color: PoPalette.peach,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute<void>(
            builder: (_) => PreviewLesson(domain: domain, model: model),
          ),
        ),
        child: Row(
          children: [
            PoDomainMark(domain.kind),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    domain.activity,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const Text(
                    'Chạm, chọn và khám phá',
                    style: TextStyle(fontSize: 14),
                  ),
                ],
              ),
            ),
            const Icon(Icons.play_circle_fill, size: 38, color: PoPalette.pink),
          ],
        ),
      ),
      const PoHeading('Bài học từ dịch vụ'),
      const PoCard(
        child: Text(
          'Preview không tải danh mục thật. Khi dùng API, chỉ bài đã phát hành và được máy chủ cho phép mới có thể bắt đầu.',
        ),
      ),
    ],
  );
}

class PreviewLesson extends StatelessWidget {
  const PreviewLesson({super.key, required this.domain, required this.model});
  final PreviewDomain domain;
  final PreviewState model;
  @override
  Widget build(BuildContext context) => PoScaffold(
    title: 'Cùng Mimi khám phá',
    back: () => Navigator.pop(context),
    children: [
      PoGarden(title: domain.activity, subtitle: domain.description),
      const PoPill('TƯƠNG TÁC CỤC BỘ · KHÔNG PHẢI VIDEO'),
      const PoHeading('Bé sẽ thử điều gì?'),
      PoCard(
        child: Text(switch (domain.kind) {
          0 => 'Đếm số táo và chọn con số phù hợp.',
          1 => 'Nhìn hình và ghép với từ gọi tên.',
          2 => 'Thử lời chào Hello trong một tình huống tiếng Việt.',
          3 => 'Sắp xếp các bước rửa tay theo thứ tự.',
          4 => 'Phân loại hình tròn và hình vuông vào đúng giỏ.',
          _ => 'Chọn bạn động vật sống dưới nước.',
        }),
      ),
      PoAction(
        'Chơi ngay',
        icon: Icons.play_arrow_rounded,
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute<void>(
            builder: (_) => PreviewGame(domain: domain, model: model),
          ),
        ),
      ),
      const Text(
        'Không có điểm thưởng, huy hiệu hay kết quả thật được cấp. Bé có thể thử lại tự do trong hoạt động mẫu.',
      ),
    ],
  );
}

class PreviewGame extends StatefulWidget {
  const PreviewGame({super.key, required this.domain, required this.model});
  final PreviewDomain domain;
  final PreviewState model;
  @override
  State<PreviewGame> createState() => _PreviewGameState();
}

class _PreviewGameState extends State<PreviewGame> {
  int round = 0;
  bool? correct;
  int? selected;
  bool finished = false;
  int get kind => widget.domain.kind;
  final sorted = <int>{};
  List<String> get choices => switch (kind) {
    0 => ['1', '2', '3'],
    1 => ['Mèo', 'Chó', 'Thỏ'],
    2 => ['Hello!', 'Goodbye!'],
    3 => ['Làm ướt tay', 'Xoa xà phòng', 'Rửa & lau khô'],
    4 => ['Giỏ hình tròn', 'Giỏ hình vuông'],
    _ => ['Cá', 'Mèo', 'Bướm'],
  };
  int get expected => switch (kind) {
    0 => round,
    1 => 0,
    2 => 0,
    3 => round,
    4 => round % 2,
    _ => 0,
  };
  String get prompt => switch (kind) {
    0 => 'Có bao nhiêu quả táo?',
    1 => 'Ghép từ “mèo” với bạn nhỏ nhé!',
    2 => 'Gặp bạn mới, mình chào thế nào?',
    3 => 'Bước ${round + 1}: chọn việc cần làm',
    4 => round % 2 == 0 ? 'Hình tròn vào giỏ nào?' : 'Hình vuông vào giỏ nào?',
    _ => 'Bạn nào sống dưới nước?',
  };
  int get rounds => [0, 3, 4].contains(kind) ? 3 : 1;
  void answer(int i) {
    if (correct == true) return;
    setState(() {
      selected = i;
      correct = i == expected;
    });
  }

  void next() {
    if (correct != true) return;
    if (round + 1 < rounds) {
      setState(() {
        sorted.add(round);
        round++;
        selected = null;
        correct = null;
      });
    } else {
      widget.model.finish(widget.domain.activity);
      setState(() => finished = true);
    }
  }

  void replay() {
    setState(() {
      round = 0;
      selected = null;
      correct = null;
      finished = false;
      sorted.clear();
    });
  }

  @override
  Widget build(BuildContext context) => PoScaffold(
    title: widget.domain.activity,
    back: () => Navigator.pop(context),
    children: [
      if (finished) ...[
        const Center(child: MimiBee(size: 170)),
        const PoHeading(
          'Bé đã chơi xong!',
          subtitle: 'Cảm ơn bé đã khám phá cùng Mimi',
        ),
        const PoCard(
          color: PoPalette.mint,
          child: Text(
            'Lượt chơi mẫu đã kết thúc. Không phải hoàn thành bài học trên máy chủ.',
          ),
        ),
        PoAction('Chơi lại', icon: Icons.replay_rounded, onPressed: replay),
        PoAction(
          'Chọn hoạt động khác',
          secondary: true,
          onPressed: () => Navigator.pop(context),
        ),
      ] else ...[
        Row(
          children: [
            PoPill('LƯỢT ${round + 1}/$rounds'),
            const Spacer(),
            const Icon(Icons.touch_app_outlined, color: PoPalette.pink),
          ],
        ),
        LinearProgressIndicator(
          value: round / rounds,
          minHeight: 8,
          borderRadius: BorderRadius.circular(8),
          backgroundColor: PoPalette.lavender,
          color: PoPalette.pink,
        ),
        PoCard(
          color: PoPalette.sky,
          child: Column(
            children: [
              const MimiBee(size: 100),
              if (kind == 0)
                Wrap(
                  spacing: 12,
                  children: [
                    for (var i = 0; i <= round; i++)
                      const PoPicture('apple', size: 64),
                  ],
                ),
              if (kind == 1)
                const Text(
                  'MÈO',
                  style: TextStyle(
                    fontFamily: 'Baloo2',
                    fontSize: 52,
                    color: PoPalette.plum,
                  ),
                ),
              if (kind == 2)
                const Icon(
                  Icons.waving_hand_rounded,
                  size: 60,
                  color: Colors.amber,
                ),
              if (kind == 3)
                const Icon(Icons.wash_rounded, size: 70, color: Colors.blue),
              if (kind == 4)
                Icon(
                  round % 2 == 0 ? Icons.circle : Icons.square_rounded,
                  size: 80,
                  color: PoPalette.pink,
                ),
              if (kind == 5)
                const Icon(Icons.waves_rounded, size: 70, color: Colors.blue),
            ],
          ),
        ),
        PoHeading(prompt),
        for (var i = 0; i < choices.length; i++)
          if (kind != 3 || !sorted.contains(i))
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                key: Key('gameChoice-$i'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(64, 80),
                  backgroundColor: selected == i
                      ? (correct == true ? PoPalette.mint : PoPalette.peach)
                      : Colors.white,
                  side: BorderSide(
                    color: selected == i ? PoPalette.pink : PoPalette.lavender,
                    width: 2,
                  ),
                ),
                onPressed: correct == true ? null : () => answer(i),
                child: kind == 1 || kind == 5
                    ? Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          PoPicture(
                            (kind == 1
                                ? ['cat', 'dog', 'rabbit']
                                : ['fish', 'cat', 'butterfly'])[i],
                            size: 56,
                          ),
                          const SizedBox(width: 16),
                          Text(
                            choices[i],
                            style: const TextStyle(fontSize: 24),
                          ),
                        ],
                      )
                    : Text(
                        choices[i],
                        style: TextStyle(
                          fontSize: kind == 1 || kind == 5 ? 40 : 25,
                        ),
                      ),
              ),
            ),
        if (correct != null)
          Semantics(
            liveRegion: true,
            child: PoCard(
              color: correct! ? PoPalette.mint : PoPalette.peach,
              child: Row(
                children: [
                  Icon(
                    correct!
                        ? Icons.check_circle_outline
                        : Icons.lightbulb_outline,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      correct!
                          ? 'Đúng rồi! Bé làm tốt lắm.'
                          : 'Mình thử một lựa chọn khác nhé!',
                    ),
                  ),
                ],
              ),
            ),
          ),
        if (correct == true)
          PoAction(
            round + 1 == rounds ? 'Xong rồi!' : 'Tiếp tục',
            key: const Key('gameNext'),
            onPressed: next,
          ),
      ],
    ],
  );
}
