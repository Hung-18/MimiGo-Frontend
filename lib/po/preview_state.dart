import 'package:flutter/foundation.dart';

class PreviewChild {
  const PreviewChild(this.name, this.avatar, {this.age = 4});
  final String name;
  final int avatar, age;
}

/// A network-free presentation model. Never passed to live repositories.
class PreviewState extends ChangeNotifier {
  final children = <PreviewChild>[
    const PreviewChild('Bé Mây', 0),
    const PreviewChild('Bé Nắng', 1, age: 3),
  ];
  int selected = 0;
  bool sound = true, reminders = false;
  final completed = <String>[];
  PreviewChild get child => children[selected];
  void choose(int index) {
    selected = index;
    notifyListeners();
  }

  void add(PreviewChild child) {
    children.add(child);
    selected = children.length - 1;
    notifyListeners();
  }

  void edit(PreviewChild child) {
    children[selected] = child;
    notifyListeners();
  }

  void finish(String activity) {
    completed.add(activity);
    notifyListeners();
  }

  void preferences({bool? audio, bool? reminder}) {
    sound = audio ?? sound;
    reminders = reminder ?? reminders;
    notifyListeners();
  }
}

class PreviewDomain {
  const PreviewDomain(
    this.name,
    this.symbol,
    this.description,
    this.activity,
    this.kind,
  );
  final String name, symbol, description, activity;
  final int kind;
}

const previewDomains = [
  PreviewDomain(
    'Toán học',
    '123',
    'Đếm, so sánh và làm quen số lượng',
    'Giỏ táo của Mimi',
    0,
  ),
  PreviewDomain(
    'Ngôn ngữ',
    'Aa',
    'Lắng nghe và gọi tên thế giới',
    'Bạn nào là mèo?',
    1,
  ),
  PreviewDomain(
    'Tiếng Anh',
    'Hi!',
    'English Companion trong bài học tiếng Việt',
    'Chào bạn nhỏ · Hello!',
    2,
  ),
  PreviewDomain(
    'Kỹ năng sống',
    '♡',
    'Tập những thói quen tốt mỗi ngày',
    'Đôi tay sạch xinh',
    3,
  ),
  PreviewDomain(
    'Logic',
    '△',
    'Ghép đôi, tìm quy luật và phân loại',
    'Xếp hình vào đúng giỏ',
    4,
  ),
  PreviewDomain(
    'Khám phá',
    '✿',
    'Tò mò với thiên nhiên quanh bé',
    'Ai sống dưới nước?',
    5,
  ),
];
