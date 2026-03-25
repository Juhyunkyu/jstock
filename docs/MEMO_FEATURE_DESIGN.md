# 메모 기능 설계서 v1.1

> **문서 버전**: 1.2 (design-review 반영 + 범위 조정: 상세화면 제거, relatedTicker→sortOrder, 드래그 정렬)
> **작성일**: 2026-03-20
> **대상 탭**: 6번째 메인 네비게이션 탭 (홈, 관심, My, 거래내역, **메모**, 설정)
> **기존 플레이스홀더**: `lib/presentation/screens/memo/memo_screen.dart` (빈 화면)

---

## 1. 개요

### 1.1 목적
주식 투자자가 종목 분석, 시장 인사이트, 학습 노트를 기록하고 관리하는 로컬 메모 기능.
이미지 첨부를 지원하되, 로컬 스토리지(Hive/IndexedDB) 용량을 고려하여 압축 저장한다.

### 1.2 핵심 원칙
- **단순함 우선**: 리치 텍스트 에디터 없이 플레인 텍스트 + 줄바꿈만 지원
- **로컬 저장**: 클라우드 동기화 없음, Hive 기반 영속화
- **기존 패턴 준수**: NotificationRecord, WatchlistGroup 모델 패턴과 동일한 구조
- **백업 통합**: 기존 `DataManagementService` 백업/복원 시스템에 포함

### 1.3 범위 외 (구현하지 않음)
- 리치 텍스트 에디터 (볼드, 이탤릭 등)
- 클라우드 동기화 / 공유 / 협업
- 마크다운 렌더링
- 폴더 계층 구조

---

## 2. 데이터 모델

### 2.1 Hive TypeId 할당

| TypeId | 모델 | 설명 |
|--------|------|------|
| 25 | `Memo` | 메모 본체 |
| 26 | `MemoCategory` | 카테고리 enum |

> 기존 사용 현황: 0-5, 10-16, 20-24 사용 중. 25부터 할당.

### 2.2 Memo 모델

```dart
// lib/data/models/memo.dart

import 'package:hive/hive.dart';

part 'memo.g.dart';

@HiveType(typeId: 26)
enum MemoCategory {
  @HiveField(0)
  general,      // 일반
  @HiveField(1)
  analysis,     // 종목 분석
  @HiveField(2)
  insight,      // 시장 인사이트
  @HiveField(3)
  study,        // 학습 노트
  @HiveField(4)
  strategy,     // 전략 메모
  @HiveField(5)
  diary,        // 매매 일지
}

@HiveType(typeId: 25)
class Memo extends HiveObject {
  /// 고유 ID (UUID)
  @HiveField(0)
  String id;

  /// 제목
  @HiveField(1)
  String title;

  /// 본문 (플레인 텍스트, 줄바꿈 포함)
  @HiveField(2)
  String content;

  /// 카테고리
  @HiveField(3, defaultValue: MemoCategory.general)
  MemoCategory category;

  /// 고정 여부
  @HiveField(4, defaultValue: false)
  bool isPinned;

  /// 생성일시
  @HiveField(5)
  DateTime createdAt;

  /// 수정일시
  @HiveField(6)
  DateTime updatedAt;

  /// 사용자 지정 날짜 (null이면 createdAt 사용)
  @HiveField(7)
  DateTime? customDate;

  /// 첨부 이미지 (base64 인코딩 문자열, 최대 3장)
  @HiveField(8, defaultValue: [])
  List<String> imageBase64List;

  /// 정렬 순서 (드래그 정렬용, 낮을수록 위에 표시)
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

  /// 표시용 날짜 (customDate 우선, 없으면 createdAt)
  DateTime get displayDate => customDate ?? createdAt;

  /// 첨부 이미지 수
  int get imageCount => imageBase64List.length;

  /// 이미지 추가 가능 여부
  bool get canAddImage => imageBase64List.length < maxImages;

  /// 최대 이미지 수
  static const int maxImages = 3;

  // 이미지 크기 제한 없음 — 리사이즈+압축 후 그대로 저장

  /// 본문 미리보기 (목록용, 최대 100자)
  String get contentPreview {
    if (content.isEmpty) return '';
    final singleLine = content.replaceAll(RegExp(r'\s+'), ' ').trim();
    return singleLine.length > 100
        ? '${singleLine.substring(0, 100)}...'
        : singleLine;
  }

  // === 직렬화 (백업/복원용) ===

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
    title: json['title'] as String,
    content: json['content'] as String,
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
```

### 2.3 이미지 저장 전략

```
[원본 이미지] → [Canvas 리사이즈] → [JPEG 압축] → [base64 인코딩] → [Hive 저장]
```

| 항목 | 값 | 근거 |
|------|-----|------|
| 최대 해상도 | 800 x 800px (긴 변 기준) | 모바일 열람에 충분, 용량 절감 |
| 압축 포맷 | JPEG | 사진에 최적, PNG 대비 용량 1/3~1/5 |
| 압축 품질 | 0.7 (70%) | 화질/용량 균형점 |
| 결과 크기 제한 | 없음 | 리사이즈+압축 후 보통 100~300KB, 그대로 저장 |
| 메모당 최대 이미지 | 3장 | |
| 전체 제한 | 없음 (사용자 책임) | 백업 파일 크기 경고로 대응 |

#### Web 환경 이미지 처리 (Canvas API)

```dart
// lib/data/services/image/image_compress_service.dart

/// Web: HTML Canvas를 이용한 이미지 리사이즈 + JPEG 압축
/// - FileReader로 이미지 로드
/// - Canvas에 drawImage (maxDimension 기준 비율 축소)
/// - canvas.toBlob('image/jpeg', 0.7) → base64 변환
///
/// APK 전환 시: image 패키지 사용으로 교체
///   - img.decodeImage() → img.copyResize() → img.encodeJpg(quality: 70)
```

#### 용량 경고 기준

| 메모 수 | 이미지 포함 시 예상 크기 | 경고 |
|---------|----------------------|------|
| ~50개 | 이미지 없이 ~500KB | 없음 |
| ~100개 | 이미지 3장씩 ~120MB | 백업 시 경고 |
| ~200개+ | ~240MB+ | 설정에서 용량 표시 |

---

## 3. Repository

### 3.1 MemoRepository

```dart
// lib/data/repositories/memo_repository.dart

/// Hive Box: 'memos'
/// 패턴: WatchlistGroupRepository 자체 등록 패턴 (main.dart에 등록하지 않음)
class MemoRepository {
  static const String _boxName = 'memos';
  Box<Memo>? _box;

  bool get isInitialized => _box != null && _box!.isOpen;

  /// 어댑터 자체 등록 + Box 오픈
  /// MemoListNotifier.load()에서 호출됨
  Future<void> init() async {
    if (!Hive.isAdapterRegistered(25)) Hive.registerAdapter(MemoAdapter());
    if (!Hive.isAdapterRegistered(26)) Hive.registerAdapter(MemoCategoryAdapter());
    _box ??= await Hive.openBox<Memo>(_boxName);
  }

  /// 전체 메모 (최신순, 고정 우선)
  List<Memo> getAll();

  /// ID로 조회
  Memo? getById(String id);

  /// 저장 (추가 또는 업데이트)
  Future<void> save(Memo memo) async;

  /// 삭제
  Future<void> delete(String id) async;

  /// 검색 (제목 + 본문)
  List<Memo> search(String query);

  /// 카테고리 필터
  List<Memo> getByCategory(MemoCategory category);

  /// 전체 삭제
  Future<void> clear() async;

  /// 메모 수
  int get count;
}
```

### 3.2 정렬 규칙

```
1순위: isPinned (고정 메모 상단)
2순위: sortOrder (드래그 정렬, 낮을수록 위)
3순위: displayDate 기준 정렬 (기본 최신순)
```

> 드래그 정렬: 관심종목과 동일 패턴 (`ReorderableListView` + `LongPressDraggable`).
> sortOrder는 드래그 시 인접 항목과 swap. 새 메모는 sortOrder=0 (최상단).

---

## 4. Provider 구조

### 4.1 Provider 파일

```dart
// lib/presentation/providers/memo_providers.dart

/// Repository Provider
final memoRepositoryProvider = Provider<MemoRepository>((ref) {
  return MemoRepository();
});

/// 메모 상태
class MemoListState {
  final List<Memo> memos;        // 현재 표시 중인 메모 목록
  final bool isLoading;
  final String searchQuery;       // 현재 검색어
  final MemoCategory? filterCategory;  // 현재 카테고리 필터
  final MemoSortOrder sortOrder;  // 정렬 방식
}

enum MemoSortOrder { newest, oldest }

/// 메모 목록 Notifier (수동 load 패턴 — Watchlist/Notification과 동일)
class MemoListNotifier extends StateNotifier<MemoListState> {
  /// 초기 로드 — repository.init() 호출 후 데이터 로드
  /// MainShell.initState에서는 호출하지 않음 (lazy load: 메모 탭 진입 시 로드)
  Future<void> load() async {
    await _repository.init(); // Hive 어댑터 등록 + Box 오픈
    // ... getAll() → state 업데이트
  }
  Future<void> save(Memo memo) async;
  Future<void> delete(String id) async;
  Future<void> togglePin(String id) async;
  void setSearchQuery(String query);
  void setFilterCategory(MemoCategory? category);
  void toggleSortOrder();
}

/// 메모 목록 Provider
final memoListProvider =
    StateNotifierProvider<MemoListNotifier, MemoListState>((ref) {
  final repository = ref.watch(memoRepositoryProvider);
  return MemoListNotifier(repository);
});

/// 메모 수 Provider (탭 배지용)
final memoCountProvider = Provider<int>((ref) {
  return ref.watch(memoListProvider).memos.length;
});
```

### 4.2 invalidate 패턴

수동 load Provider이므로 복원/초기화 후 반드시:
```dart
ref.invalidate(memoListProvider);
ref.read(memoListProvider.notifier).load();
```

> **settings_screen.dart의 `_refreshAllProviders()`에도 추가 필수.**
> MainShell.initState에서는 로드하지 않음 (lazy load — 메모 탭 진입 시 로드).

---

## 5. UI 설계

### 5.1 화면 구조

```
MemoScreen (메인 목록)
  └── MemoCreateEditScreen (생성/수정 통합)
```

> 상세 보기 화면 없음 — 카드 탭 → 바로 편집 모드. 목록 카드 미리보기로 충분.

### 5.2 라우트

| 라우트 | 화면 | 설명 |
|--------|------|------|
| `/memo` | MemoScreen | 메모 목록 |
| `/memo/create` | MemoCreateEditScreen | 새 메모 작성 |
| `/memo/edit/:memoId` | MemoCreateEditScreen | 메모 수정 (카드 탭 시) |

### 5.3 메모 목록 화면 (MemoScreen)

```
┌─────────────────────────────────────────┐
│  메모                          [🔍] [+] │  ← AppBar: 검색 토글 + FAB(또는 앱바 버튼)
├─────────────────────────────────────────┤
│  [전체] [분석] [인사이트] [학습] [전략] [일지] │  ← 카테고리 필터 칩 (가로 스크롤)
├─────────────────────────────────────────┤
│  ┌───────────────────────────────────┐  │
│  │ 📌 TQQQ 하락 시 대응 전략        │  │  ← 고정 메모 (핀 아이콘)
│  │ 분석 · 2026.03.18               │  │  ← 카테고리 · 날짜
│  │ TQQQ가 -30% 이상 하락 시 패닉... │  │  ← 본문 미리보기 (2줄)
│  │ 🖼 2                             │  │  ← 이미지 수 (있을 때만)
│  └───────────────────────────────────┘  │
│  ┌───────────────────────────────────┐  │
│  │ 무한매수법 회차별 수익률 정리      │  │
│  │ 학습 · 2026.03.15               │  │
│  │ 1회차: +12.3%, 2회차: +8.7%...  │  │
│  └───────────────────────────────────┘  │
│  ┌───────────────────────────────────┐  │
│  │ CNN 공포탐욕 20 이하 매수 규칙    │  │
│  │ 전략 · 2026.03.10               │  │
│  │ 공포탐욕지수가 20 이하로 떨어...  │  │
│  │ 🖼 1                             │  │
│  └───────────────────────────────────┘  │
│                                         │
│                          [+ 새 메모] ◉  │  ← FAB
└─────────────────────────────────────────┘
```

#### 데스크톱 (>=768px): 그리드 레이아웃

```
┌─────────────────────────────────────────────────────────┐
│  메모                                        [🔍] [+]   │
├─────────────────────────────────────────────────────────┤
│  [전체] [분석] [인사이트] [학습] [전략] [일지]             │
├─────────────────────────────────────────────────────────┤
│  ┌────────────────────┐  ┌────────────────────┐        │
│  │ 📌 TQQQ 하락 시..  │  │ 무한매수법 회차별.. │        │
│  │ 분석 · 03.18       │  │ 학습 · 03.15       │        │
│  │ TQQQ가 -30%...     │  │ 1회차: +12.3%...   │        │
│  │ 🖼 2               │  │                    │        │
│  └────────────────────┘  └────────────────────┘        │
│  ┌────────────────────┐  ┌────────────────────┐        │
│  │ CNN 공포탐욕 20..   │  │ 환율 1400원 돌파.. │        │
│  │ 전략 · 03.10       │  │ 인사이트 · 03.08   │        │
│  │ 공포탐욕지수가...   │  │ 환율이 1400원을... │        │
│  │ 🖼 1               │  │ 🖼 3               │        │
│  └────────────────────┘  └────────────────────┘        │
└─────────────────────────────────────────────────────────┘
```

#### 빈 상태

```
┌─────────────────────────────────────────┐
│  메모                          [🔍] [+] │
├─────────────────────────────────────────┤
│                                         │
│            📝 (아이콘, 64px)             │
│                                         │
│         주식 공부 메모를 작성하세요       │
│    종목 분석, 시장 인사이트, 매매 일지    │
│                                         │
│           [ + 첫 메모 작성하기 ]          │  ← OutlinedButton
│                                         │
└─────────────────────────────────────────┘
```

#### 검색 모드

```
┌─────────────────────────────────────────┐
│  [← ] [ 검색어 입력...          ] [취소] │  ← 검색 AppBar
├─────────────────────────────────────────┤
│  ┌───────────────────────────────────┐  │
│  │ TQQQ 하락 시 대응 전략            │  │  ← 검색 결과 (제목+본문 매칭)
│  │ 분석 · 2026.03.18               │  │
│  └───────────────────────────────────┘  │
│                                         │
│         "TQQQ" 검색 결과 1건            │
└─────────────────────────────────────────┘
```

### 5.4 메모 작성/수정 화면 (MemoCreateEditScreen)

```
┌─────────────────────────────────────────┐
│  [← ] 새 메모                   [저장]  │  ← AppBar (수정 시: "메모 수정")
├─────────────────────────────────────────┤
│                                         │
│  제목                                   │
│  ┌───────────────────────────────────┐  │
│  │ 메모 제목을 입력하세요              │  │  ← TextField (maxLength: 100)
│  └───────────────────────────────────┘  │
│                                         │
│  카테고리                               │
│  [일반] [분석] [인사이트] [학습] [전략] [일지] │  ← ChoiceChip 그룹
│                                         │
│  날짜                                   │
│  ┌───────────────────────────────────┐  │
│  │ 2026.03.20 (오늘)          [달력] │  │  ← 탭하면 DatePicker
│  └───────────────────────────────────┘  │
│                                         │
│  내용                                   │
│  ┌───────────────────────────────────┐  │
│  │                                   │  │
│  │ 메모 내용을 입력하세요...          │  │  ← TextField (multiline, minLines: 8)
│  │                                   │  │
│  │                                   │  │
│  │                                   │  │
│  └───────────────────────────────────┘  │
│                                         │
│  이미지 (0/3)                           │
│  ┌──────┐  ┌──────┐  ┌──────┐         │
│  │  +   │  │      │  │      │         │  ← 이미지 추가 버튼 + 썸네일
│  │ 추가  │  │      │  │      │         │
│  └──────┘  └──────┘  └──────┘         │
│                                         │
│  글자 수: 0                  [삭제 🗑️]  │  ← 수정 모드에서만 삭제 버튼
└─────────────────────────────────────────┘
```

#### 이미지 선택 후

```
│  이미지 (2/3)                           │
│  ┌──────┐  ┌──────┐  ┌──────┐         │
│  │ 🖼   │  │ 🖼   │  │  +   │         │
│  │ [x]  │  │ [x]  │  │ 추가  │         │  ← 썸네일 위 x 버튼으로 개별 삭제
│  └──────┘  └──────┘  └──────┘         │
```

---

## 6. 컴포넌트 상세

### 6.1 파일 구조

```
lib/
├── data/
│   ├── models/
│   │   ├── memo.dart              ← Hive 모델
│   │   └── memo.g.dart            ← 코드 생성
│   ├── repositories/
│   │   └── memo_repository.dart   ← CRUD + 검색 + 필터
│   └── services/
│       └── image/
│           └── image_compress_service.dart  ← Web Canvas 압축
├── presentation/
│   ├── providers/
│   │   └── memo_providers.dart    ← Riverpod 상태 관리
│   ├── screens/
│   │   └── memo/
│   │       ├── memo_screen.dart           ← 목록 (기존 파일 교체)
│   │       └── memo_create_edit_screen.dart ← 생성/수정 통합
│   └── widgets/
│       └── memo/
│           ├── memo_card.dart             ← 목록 카드
│           ├── memo_category_chips.dart    ← 카테고리 필터 칩
│           ├── memo_image_picker.dart      ← 이미지 선택/압축
│           └── memo_image_viewer.dart      ← 이미지 전체화면
```

### 6.2 카테고리 표시

| enum 값 | 한글명 | 색상 (Light) | 색상 (Dark) |
|---------|--------|-------------|-------------|
| general | 일반 | gray400 | gray500 |
| analysis | 분석 | blue500 | darkAccent (#58A6FF) |
| insight | 인사이트 | purple500 (#8B5CF6) | purple400 (#A78BFA) |
| study | 학습 | green500 (#10B981) | green400 (#34D399) |
| strategy | 전략 | orange500 (#F59E0B) | orange400 (#FBBF24) |
| diary | 일지 | red400 (#F87171) | red400 (#F87171) |

> 색상은 `app_colors.dart`의 `ThemeAwareColors` extension에 `memoCategoryColor(MemoCategory)` 메서드로 추가.
> 하드코딩 금지 규칙 준수.

### 6.3 메모 카드 위젯 (MemoCard)

```dart
/// 목록에서 사용하는 메모 카드
/// 구성: 제목 (1줄) + 카테고리 뱃지/날짜 (1줄) + 본문 미리보기 (2줄) + 이미지 수
/// 고정 메모: 좌측 상단 📌 아이콘
/// 탭: 편집 화면 이동 (/memo/edit/:id)
/// 길게 누르기: 드래그 정렬 시작 (250ms 딜레이)
```

### 6.4 이미지 압축 서비스

```dart
/// lib/data/services/image/image_compress_service.dart
class ImageCompressService {
  /// 최대 해상도 (긴 변 기준)
  static const int maxDimension = 800;

  /// JPEG 압축 품질 (0.0~1.0)
  static const double jpegQuality = 0.7;

  /// 파일 선택 + 리사이즈 + 압축 + base64 반환
  /// Web: <input type="file" accept="image/*"> → Canvas resize(800px) → JPEG 70% → base64
  /// 원본 크기 무관 — 리사이즈 후 결과만 저장
  /// 반환: base64 문자열 (null이면 취소 또는 실패)
  Future<String?> pickAndCompress();

  /// base64에서 이미지 위젯 생성
  /// Image.memory(base64Decode(base64String))
  static Widget imageFromBase64(String base64String);
}
```

#### Web 구현 핵심 (package:web + Canvas)

> **dart:html 사용 금지** — Flutter 3.22+ 이후 deprecated.
> 기존 프로젝트 패턴(`addEventListener('load', callback.toJS)`)에 맞춰 `package:web` 사용.

```
1. HTMLInputElement (package:web) → accept = 'image/*'
2. FileReader.readAsDataURL(file)
3. HTMLImageElement → onLoad → Canvas 생성
4. 비율 계산: if (width > maxDimension || height > maxDimension) → 축소
5. CanvasElement.context2D.drawImageScaled(img, 0, 0, newW, newH)
6. canvas.toBlob('image/jpeg', jpegQuality)
7. FileReader.readAsDataUrl(blob) → base64 추출 (data:image/jpeg;base64, 제거)
```

#### APK 전환 시 (향후)

```
- image_picker 패키지로 파일 선택
- image 패키지로 리사이즈
- dart:convert의 base64Encode
- 조건부 import로 Web/Mobile 분기
```

---

## 7. 통합 포인트

### 7.1 백업/복원 시스템

#### data_management_service.dart 수정

```dart
// 생성자에 추가
final MemoRepository memoRepository;

// createBackup() 수정
Map<String, dynamic> createBackup() {
  return {
    'version': 5,  // 4 → 5 버전업 (restoreFromBackup 가드도 > 4 → > 5 변경 필수)
    'createdAt': DateTime.now().toIso8601String(),
    'data': {
      // ... 기존 9개 ...
      'memos': memoRepository.getAll().map((m) => m.toJson()).toList(),
    },
  };
}

// restoreFromBackup() 수정
// 11. Memos 복원 (v5+)
if (data['memos'] != null) {
  for (final json in (data['memos'] as List)) {
    final memo = Memo.fromJson(json as Map<String, dynamic>);
    await memoRepository.save(memo);
  }
}

// resetAllData() 수정
await Future.wait([
  // ... 기존 8개 ...
  memoRepository.clear(),
]);
```

#### 백업 버전: 4 → 5

| 버전 | 변경 | 하위 호환 |
|------|------|----------|
| v5 | memos 필드 추가 | v4 백업 복원 시 memos 없으면 skip |

#### 이미지 포함 백업 크기 경고

백업 생성 시 메모 이미지가 포함되면 파일이 커질 수 있다.
`createBackup()` 호출 후 JSON 크기가 10MB 이상이면 사용자에게 경고 다이얼로그 표시.

### 7.2 어댑터 등록 (자체 등록 패턴)

```dart
// main.dart에 등록하지 않음!
// MemoRepository.init()에서 isAdapterRegistered 체크 후 자체 등록
// (WatchlistGroupRepository, RecentViewRepository와 동일 패턴)
```

### 7.3 models.dart barrel export

```dart
// lib/data/models/models.dart에 추가
export 'memo.dart';
```

### 7.4 data_management_providers.dart

```dart
// memoRepository 추가
final dataManagementServiceProvider = Provider<DataManagementService>((ref) {
  return DataManagementService(
    // ... 기존 8개 ...
    memoRepository: ref.watch(memoRepositoryProvider),
  );
});
```

### 7.5 라우터 (app_router.dart)

```dart
// 라우트 상수 추가
static const String memoCreate = '/memo/create';
static const String memoEdit = '/memo/edit/:memoId';

// ShellRoute 자식에 추가 (memo 탭 하위)
GoRoute(
  path: memoCreate,
  builder: (context, state) => const MemoCreateEditScreen(),
),
GoRoute(
  path: memoEdit,
  builder: (context, state) {
    final memoId = state.pathParameters['memoId']!;
    return MemoCreateEditScreen(memoId: memoId);
  },
),
```

### 7.6 테마 시스템

`app_colors.dart`의 `ThemeAwareColors` extension에 추가할 getter:

```dart
/// 메모 카테고리 색상
Color memoCategoryColor(MemoCategory category) {
  // Light/Dark 모드에 따라 분기
  // 6.2절 색상 테이블 참조
}

/// 메모 고정 아이콘 색상
Color get appMemoPinColor => isDarkMode
    ? const Color(0xFFFBBF24)  // amber-400
    : const Color(0xFFF59E0B); // amber-500
```

---

## 8. 사용자 인터랙션 상세

### 8.1 목록 화면 동작

| 동작 | 결과 |
|------|------|
| 카드 탭 | 편집 화면(`/memo/edit/:id`)으로 이동 |
| 카드 길게 누르기 | 드래그 정렬 시작 (250ms 딜레이, 관심종목 패턴) |
| 카드 좌측 스와이프 | 삭제 확인 다이얼로그 (Dismissible) |
| FAB 탭 | 작성 화면(`/memo/create`)으로 이동 |
| 검색 아이콘 탭 | 검색 AppBar 전환 (제목 + 본문 동시 검색) |
| 카테고리 칩 탭 | 해당 카테고리 필터 (전체 = 필터 해제) |

### 8.2 작성/수정 화면 동작

| 동작 | 결과 |
|------|------|
| 저장 탭 | 유효성 검증 → Hive 저장 → 목록으로 pop |
| 뒤로가기 | 변경사항 있으면 "저장하지 않고 나가시겠습니까?" 확인 |
| 이미지 + 탭 | 파일 선택 → 압축 → 썸네일 추가 |
| 이미지 x 탭 | 해당 이미지 제거 (확인 없이 즉시) |
| 날짜 탭 | DatePicker 표시 (기본값: 오늘) |
| 삭제 버튼 (수정 모드) | 확인 다이얼로그 → 삭제 → 목록으로 pop |

### 8.3 유효성 검증

| 필드 | 규칙 |
|------|------|
| 제목 | 필수, 1~100자 |
| 본문 | 선택, 최대 10,000자 |
| 이미지 | 최대 3장, 개당 최대 ~400KB(base64) |
| 카테고리 | 기본값: 일반 |
| 날짜 | 기본값: 오늘, 미래 날짜 허용 |

---

## 9. 구현 Phase

### Phase 1: 데이터 레이어
1. `memo.dart` — Hive 모델 + `MemoCategory` enum
2. `dart run build_runner build` — 코드 생성
3. `memo_repository.dart` — CRUD + 검색 + 필터
4. `main.dart` — 어댑터 등록
5. `models.dart` — barrel export 추가

### Phase 2: Provider 레이어
1. `memo_providers.dart` — Repository Provider + MemoListNotifier + State
2. `data_management_providers.dart` — memoRepository 주입 추가
3. `data_management_service.dart` — 백업 v5, 복원, 초기화에 memos 추가

### Phase 3: 이미지 서비스
1. `image_compress_service.dart` — Web Canvas 기반 이미지 압축
2. 파일 선택 → 리사이즈 → JPEG 압축 → base64 변환 파이프라인

### Phase 4: UI — 목록 화면
1. `memo_screen.dart` — 기존 플레이스홀더 교체
2. `memo_card.dart` — 목록 카드 위젯
3. `memo_category_chips.dart` — 카테고리 필터 칩
4. `app_colors.dart` — 카테고리 색상 + 핀 색상 추가
5. `app_router.dart` — 라우트 추가
6. 반응형: 모바일 리스트 / 데스크톱 그리드 (ResponsiveGrid 패턴)

### Phase 5: UI — 작성/수정 화면
1. `memo_create_edit_screen.dart` — 작성 + 수정 통합 화면
2. `memo_image_picker.dart` — 이미지 선택 + 미리보기 위젯
3. `memo_image_viewer.dart` — 이미지 전체화면 뷰어

### Phase 6: 통합 및 검증
1. 백업/복원 테스트 (v4 백업 → v5 복원 하위 호환)
2. 다크모드 전체 화면 검증
3. 모바일/태블릿/데스크톱 반응형 검증
4. 이미지 압축 품질 및 용량 검증
5. 스와이프 삭제 + 확인 다이얼로그 동작 검증

---

## 10. 기술적 고려사항

### 10.1 Hive 저장소 용량

이미지를 base64로 Hive에 저장하면 IndexedDB 용량을 소비한다.
- Chrome IndexedDB 기본 한도: 디스크 용량의 ~60% (실질적으로 수십 GB)
- 메모 100개 x 이미지 3장 x 400KB = ~120MB → 문제 없음
- 단, 백업 JSON 파일이 커지므로 백업 시 크기 경고 필요

### 10.2 base64 vs Blob 저장

| 방식 | 장점 | 단점 |
|------|------|------|
| **base64 (채택)** | Hive 직접 저장, 직렬화 간편, 백업 JSON 포함 | 33% 용량 증가, 대량 시 느림 |
| Blob/File | 용량 효율, 대용량 가능 | 별도 파일 관리, 백업 복잡, Hive 미지원 |

base64 채택 근거: 메모당 최대 3장, 장당 ~400KB 제한이면 실질적으로 문제 없음.
백업 시 JSON에 자연스럽게 포함되어 기존 백업/복원 파이프라인 변경 최소화.

### 10.3 검색 성능

- Hive는 인덱스 없이 전체 스캔 방식
- 메모 수가 수백 개 수준이면 성능 문제 없음
- 검색 시 `title.toLowerCase().contains(query)` + `content.toLowerCase().contains(query)` 패턴
- 디바운스 300ms 적용 (타이핑 중 연속 검색 방지)

### 10.4 Web ↔ APK 전환 대비

이미지 처리만 플랫폼 의존적이므로 조건부 import로 분리:

```
lib/data/services/image/
├── image_compress_service.dart       ← 인터페이스 (export 분기)
├── image_compress_service_web.dart   ← Web 구현 (Canvas API)
└── image_compress_service_mobile.dart ← Mobile 구현 (image 패키지, 향후)
```

---

## 11. 체크리스트

### 구현 전 확인
- [ ] TypeId 25, 26 미사용 확인
- [ ] Hive box 이름 'memos' 기존 사용 없음 확인
- [ ] 백업 버전 4 → 5 변경 영향 분석

### 구현 후 확인
- [ ] 다크모드에서 모든 텍스트/아이콘 가시성
- [ ] 하드코딩 색상 없음 (context.app* 사용)
- [ ] 빈 상태 UI 정상 표시
- [ ] 검색 빈 결과 UI
- [ ] 이미지 3장 제한 동작
- [ ] 이미지 없는 메모 정상 동작
- [ ] 스와이프 삭제 확인 다이얼로그
- [ ] 백업 → 메모 포함 확인
- [ ] v4 백업 복원 시 메모 없어도 에러 없음
- [ ] 초기화 시 메모 삭제 확인
- [ ] 모바일(375px) / 태블릿(768px) / 데스크톱(1280px) 반응형
- [ ] FAB 위치 기존 화면과 일관
- [ ] 뒤로가기 시 미저장 경고 다이얼로그
