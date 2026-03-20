import 'package:hive/hive.dart';

part 'memo.g.dart';

/// 메모 카테고리
@HiveType(typeId: 26)
enum MemoCategory {
  @HiveField(0)
  general, // 일반
  @HiveField(1)
  analysis, // 종목 분석
  @HiveField(2)
  insight, // 시장 인사이트
  @HiveField(3)
  study, // 학습 노트
  @HiveField(4)
  strategy, // 전략 메모
  @HiveField(5)
  diary, // 매매 일지
}

/// 메모 모델
@HiveType(typeId: 25)
class Memo extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String title;

  @HiveField(2)
  String content;

  @HiveField(3, defaultValue: MemoCategory.general)
  MemoCategory category;

  @HiveField(4, defaultValue: false)
  bool isPinned;

  @HiveField(5)
  DateTime createdAt;

  @HiveField(6)
  DateTime updatedAt;

  @HiveField(7)
  DateTime? customDate;

  @HiveField(8, defaultValue: [])
  List<String> imageBase64List;

  @HiveField(9, defaultValue: 0)
  int sortOrder;

  Memo({
    required this.id,
    required this.title,
    required this.content,
    this.category = MemoCategory.general,
    this.isPinned = false,
    this.customDate,
    List<String>? imageBase64List,
    this.sortOrder = 0,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : imageBase64List = imageBase64List ?? [],
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  DateTime get displayDate => customDate ?? createdAt;

  int get imageCount => imageBase64List.length;

  static final _whitespaceRegex = RegExp(r'\s+');
  static final _imgMarkerRegex = RegExp(r'\[IMG:\d+\]');

  String get contentPreview {
    if (content.isEmpty) return '';
    final stripped = content.replaceAll(_imgMarkerRegex, '');
    final singleLine = stripped.replaceAll(_whitespaceRegex, ' ').trim();
    return singleLine.length > 100
        ? '${singleLine.substring(0, 100)}...'
        : singleLine;
  }

  Memo copyWith({
    String? title,
    String? content,
    MemoCategory? category,
    bool? isPinned,
    DateTime? customDate,
    List<String>? imageBase64List,
    int? sortOrder,
  }) {
    return Memo(
      id: id,
      title: title ?? this.title,
      content: content ?? this.content,
      category: category ?? this.category,
      isPinned: isPinned ?? this.isPinned,
      customDate: customDate ?? this.customDate,
      imageBase64List: imageBase64List ?? this.imageBase64List,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'content': content,
        'category': category.name,
        'isPinned': isPinned,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'customDate': customDate?.toIso8601String(),
        'imageBase64List': imageBase64List,
        'sortOrder': sortOrder,
      };

  factory Memo.fromJson(Map<String, dynamic> json) => Memo(
        id: json['id'] as String,
        title: json['title'] as String? ?? '',
        content: json['content'] as String? ?? '',
        category: _parseCategory(json['category'] as String?),
        isPinned: json['isPinned'] as bool? ?? false,
        createdAt: json['createdAt'] != null
            ? DateTime.parse(json['createdAt'] as String)
            : null,
        updatedAt: json['updatedAt'] != null
            ? DateTime.parse(json['updatedAt'] as String)
            : null,
        customDate: json['customDate'] != null
            ? DateTime.parse(json['customDate'] as String)
            : null,
        imageBase64List: (json['imageBase64List'] as List<dynamic>?)
            ?.map((e) => e as String)
            .toList(),
        sortOrder: json['sortOrder'] as int? ?? 0,
      );

  static MemoCategory _parseCategory(String? value) {
    if (value == null) return MemoCategory.general;
    try {
      return MemoCategory.values.byName(value);
    } catch (_) {
      return MemoCategory.general;
    }
  }
}
