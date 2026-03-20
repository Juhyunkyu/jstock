import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/memo.dart';
import '../../providers/providers.dart';
import '../../widgets/memo/memo_category_chips.dart';
import '../../widgets/memo/memo_content_renderer.dart';
import '../../widgets/memo/memo_image_picker.dart';
import '../../widgets/memo/memo_image_viewer.dart';
import '../../widgets/shared/confirm_dialog.dart';

/// 메모 작성/수정 통합 화면
///
/// [memoId] null이면 새 메모 작성, 값이 있으면 수정 모드.
/// 이미지를 커서 위치에 [IMG:N] 마커로 삽입하여 인라인 표시.
class MemoCreateEditScreen extends ConsumerStatefulWidget {
  final String? memoId;

  const MemoCreateEditScreen({super.key, this.memoId});

  @override
  ConsumerState<MemoCreateEditScreen> createState() =>
      _MemoCreateEditScreenState();
}

class _MemoCreateEditScreenState extends ConsumerState<MemoCreateEditScreen> {
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  final _titleFocusNode = FocusNode();
  final _contentFocusNode = FocusNode();

  MemoCategory _category = MemoCategory.general;
  DateTime _selectedDate = DateTime.now();
  List<String> _images = [];
  bool _hasUnsavedChanges = false;
  bool _showPreview = false;

  // 편집 모드용 원본 데이터
  Memo? _originalMemo;

  bool get _isEditMode => widget.memoId != null;

  static final _imgMarkerRegex = RegExp(r'\[IMG:(\d+)\]');

  @override
  void initState() {
    super.initState();
    _titleController.addListener(_markChanged);
    _contentController.addListener(_onContentChanged);

    if (_isEditMode) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadMemo());
    }
  }

  void _loadMemo() {
    final memoState = ref.read(memoListProvider);
    final memo =
        memoState.memos.where((m) => m.id == widget.memoId).firstOrNull;
    if (memo == null) return;

    _originalMemo = memo;
    _titleController.text = memo.title;
    _contentController.text = memo.content;
    _category = memo.category;
    _selectedDate = memo.displayDate;
    _images = List<String>.from(memo.imageBase64List);
    _hasUnsavedChanges = false;
    setState(() {});
  }

  void _markChanged() {
    if (!_hasUnsavedChanges) {
      setState(() => _hasUnsavedChanges = true);
    }
  }

  void _onContentChanged() {
    _markChanged();
    if (_showPreview) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _titleFocusNode.dispose();
    _contentFocusNode.dispose();
    super.dispose();
  }

  Future<bool> _onWillPop() async {
    if (!_hasUnsavedChanges) return true;
    final confirmed = await ConfirmDialog.show(
      context: context,
      title: '저장하지 않고 나가기',
      message: '저장하지 않고 나가시겠습니까?\n변경사항이 사라집니다.',
      confirmText: '나가기',
      isDanger: true,
    );
    return confirmed;
  }

  /// 커서 위치에 이미지 마커 삽입
  void _insertImageAtCursor(String base64) {
    final newIndex = _images.length;
    _images.add(base64);

    final text = _contentController.text;
    final selection = _contentController.selection;
    final cursorPos = selection.isValid ? selection.baseOffset : text.length;

    final marker = '\n[IMG:$newIndex]\n';
    final before = text.substring(0, cursorPos);
    final after = text.substring(cursorPos);
    _contentController.text = '$before$marker$after';

    // 커서를 마커 뒤로 이동
    final newPos = cursorPos + marker.length;
    _contentController.selection = TextSelection.collapsed(offset: newPos);

    _hasUnsavedChanges = true;
    setState(() {});
  }

  /// 이미지 삭제 + 마커 제거 + 리인덱싱
  void _removeImage(int index) {
    if (index < 0 || index >= _images.length) return;

    // 이미지 리스트에서 제거
    _images.removeAt(index);

    // 콘텐츠에서 해당 마커 제거
    var text = _contentController.text;
    text = text.replaceAll(RegExp(r'\n?\[IMG:' + index.toString() + r'\]\n?'), '\n');

    // N > index인 마커의 인덱스를 1씩 감소
    text = text.replaceAllMapped(_imgMarkerRegex, (match) {
      final n = int.parse(match.group(1)!);
      if (n > index) {
        return '[IMG:${n - 1}]';
      }
      return match.group(0)!;
    });

    _contentController.text = text.trim();
    _hasUnsavedChanges = true;
    setState(() {});
  }

  Future<void> _save() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('제목을 입력하세요')),
      );
      _titleFocusNode.requestFocus();
      return;
    }

    final content = _contentController.text;

    final memo = _isEditMode && _originalMemo != null
        ? _originalMemo!.copyWith(
            title: title,
            content: content,
            category: _category,
            customDate: _selectedDate,
            imageBase64List: _images,
          )
        : Memo(
            id: const Uuid().v4(),
            title: title,
            content: content,
            category: _category,
            customDate: _selectedDate,
            imageBase64List: _images,
            sortOrder: 0,
          );

    await ref.read(memoListProvider.notifier).save(memo);
    _hasUnsavedChanges = false;

    if (mounted) {
      context.go('/memo');
    }
  }

  Future<void> _delete() async {
    if (_originalMemo == null) return;
    final confirmed = await ConfirmDialog.show(
      context: context,
      title: '메모 삭제',
      message: '"${_originalMemo!.title}" 메모를 삭제하시겠습니까?',
      confirmText: '삭제',
      isDanger: true,
    );
    if (confirmed && mounted) {
      await ref.read(memoListProvider.notifier).delete(_originalMemo!.id);
      _hasUnsavedChanges = false;
      context.go('/memo');
    }
  }

  Future<void> _showDatePicker() async {
    final now = DateTime.now();
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000, 1, 1),
      lastDate: DateTime(now.year + 5, 12, 31),
      locale: const Locale('ko', 'KR'),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              onSurface: context.appTextPrimary,
              surface: context.appSurface,
            ),
            datePickerTheme: DatePickerThemeData(
              backgroundColor: context.appSurface,
              headerBackgroundColor: AppColors.primary,
              headerForegroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
          child: child!,
        );
      },
    );
    if (pickedDate != null) {
      setState(() {
        _selectedDate = pickedDate;
        _hasUnsavedChanges = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final contentLength = _contentController.text
        .replaceAll(_imgMarkerRegex, '')
        .trim()
        .length;

    return PopScope(
      canPop: !_hasUnsavedChanges,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldPop = await _onWillPop();
        if (shouldPop && context.mounted) {
          context.go('/memo');
        }
      },
      child: Scaffold(
        backgroundColor: context.appBackground,
        appBar: AppBar(
          backgroundColor: context.appSurface,
          elevation: 0,
          toolbarHeight: 64,
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: context.appTextPrimary),
            onPressed: () async {
              if (_hasUnsavedChanges) {
                final shouldPop = await _onWillPop();
                if (shouldPop && context.mounted) {
                  context.go('/memo');
                }
              } else {
                context.go('/memo');
              }
            },
          ),
          title: Text(
            _isEditMode ? '메모 수정' : '새 메모',
            style: TextStyle(color: context.appTextPrimary),
          ),
          actions: [
            // 미리보기 토글
            IconButton(
              icon: Icon(
                _showPreview ? Icons.edit_rounded : Icons.visibility_rounded,
                color: context.appTextSecondary,
                size: 22,
              ),
              tooltip: _showPreview ? '편집' : '미리보기',
              onPressed: () => setState(() => _showPreview = !_showPreview),
            ),
            TextButton(
              onPressed: _save,
              child: Text(
                '저장',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: context.appAccent,
                ),
              ),
            ),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 제목
              _buildSectionLabel('제목'),
              const SizedBox(height: 8),
              TextField(
                controller: _titleController,
                focusNode: _titleFocusNode,
                maxLength: 100,
                style: TextStyle(
                  fontSize: 16,
                  color: context.appTextPrimary,
                ),
                decoration: InputDecoration(
                  hintText: '메모 제목을 입력하세요',
                  hintStyle: TextStyle(color: context.appTextHint),
                  filled: true,
                  fillColor: context.appSurface,
                  counterStyle: TextStyle(color: context.appTextHint),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: context.appDivider),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: context.appDivider),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        BorderSide(color: context.appAccent, width: 1.5),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // 카테고리
              _buildSectionLabel('카테고리'),
              const SizedBox(height: 8),
              MemoCategoryChoiceChips(
                selected: _category,
                onSelected: (cat) {
                  setState(() {
                    _category = cat;
                    _hasUnsavedChanges = true;
                  });
                },
              ),
              const SizedBox(height: 20),

              // 날짜
              _buildSectionLabel('날짜'),
              const SizedBox(height: 8),
              _buildDateField(),
              const SizedBox(height: 20),

              // 내용 (편집 or 미리보기)
              Row(
                children: [
                  _buildSectionLabel('내용'),
                  const Spacer(),
                  if (_images.isNotEmpty)
                    Text(
                      '이미지 ${_images.length}장',
                      style: TextStyle(
                        fontSize: 12,
                        color: context.appTextHint,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),

              if (_showPreview)
                _buildPreviewArea()
              else
                _buildEditArea(),

              const SizedBox(height: 12),

              // 이미지 추가 버튼 + 이미지 썸네일 목록
              if (!_showPreview) ...[
                Row(
                  children: [
                    MemoImagePickButton(
                      onImagePicked: _insertImageAtCursor,
                    ),
                    if (_images.isNotEmpty) ...[
                      const SizedBox(width: 12),
                      Text(
                        '커서 위치에 삽입됩니다',
                        style: TextStyle(
                          fontSize: 11,
                          color: context.appTextHint,
                        ),
                      ),
                    ],
                  ],
                ),
                // 이미지 썸네일 목록 (삭제용)
                if (_images.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _buildImageThumbnails(),
                ],
              ],

              const SizedBox(height: 24),

              // 하단 정보 + 삭제 버튼
              Row(
                children: [
                  Text(
                    '글자 수: $contentLength',
                    style: TextStyle(
                      fontSize: 12,
                      color: context.appTextHint,
                    ),
                  ),
                  const Spacer(),
                  if (_isEditMode)
                    TextButton.icon(
                      onPressed: _delete,
                      icon: Icon(
                        Icons.delete_outline,
                        size: 18,
                        color: AppColors.red500,
                      ),
                      label: Text(
                        '삭제',
                        style: TextStyle(
                          color: AppColors.red500,
                          fontSize: 14,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  /// 편집 모드: TextField
  Widget _buildEditArea() {
    return TextField(
      controller: _contentController,
      focusNode: _contentFocusNode,
      maxLines: null,
      minLines: 8,
      maxLength: 10000,
      style: TextStyle(
        fontSize: 15,
        color: context.appTextPrimary,
        height: 1.5,
      ),
      decoration: InputDecoration(
        hintText: '메모 내용을 입력하세요...\n\n이미지 추가 버튼으로 커서 위치에 이미지를 삽입할 수 있습니다.',
        hintStyle: TextStyle(color: context.appTextHint),
        filled: true,
        fillColor: context.appSurface,
        counterStyle: TextStyle(color: context.appTextHint),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: context.appDivider),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: context.appDivider),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: context.appAccent, width: 1.5),
        ),
        contentPadding: const EdgeInsets.all(16),
      ),
    );
  }

  /// 미리보기 모드: 인라인 렌더링
  Widget _buildPreviewArea() {
    final content = _contentController.text;
    if (content.isEmpty && _images.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: context.appSurface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: context.appDivider),
        ),
        child: Center(
          child: Text(
            '내용이 비어있습니다',
            style: TextStyle(
              fontSize: 14,
              color: context.appTextHint,
            ),
          ),
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.appSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.appDivider),
      ),
      child: MemoContentRenderer(
        content: content,
        imageBase64List: _images,
        textStyle: TextStyle(
          fontSize: 15,
          color: context.appTextPrimary,
          height: 1.6,
        ),
      ),
    );
  }

  /// 이미지 썸네일 리스트 (삭제 가능)
  Widget _buildImageThumbnails() {
    return SizedBox(
      height: 72,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _images.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          return _ImageThumbnailItem(
            base64String: _images[index],
            index: index,
            onRemove: () => _removeImage(index),
            onTap: () => MemoImageViewer.show(context, _images, index),
          );
        },
      ),
    );
  }

  Widget _buildSectionLabel(String text) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: context.appTextPrimary,
      ),
    );
  }

  Widget _buildDateField() {
    final dateStr = _formatDate(_selectedDate);
    return InkWell(
      onTap: _showDatePicker,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: context.appSurface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: context.appDivider, width: 1),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: context.appAccent.withValues(
                    alpha: context.isDarkMode ? 0.15 : 0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.calendar_today_rounded,
                size: 20,
                color: context.appAccent,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                dateStr,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: context.appTextPrimary,
                ),
              ),
            ),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 24,
              color: context.appTextHint,
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final dateFormat = DateFormat('yyyy.MM.dd');
    try {
      final weekdayFormat = DateFormat('E', 'ko_KR');
      final weekday = weekdayFormat.format(date);
      return '${dateFormat.format(date)} ($weekday)';
    } catch (e) {
      final weekdays = ['월', '화', '수', '목', '금', '토', '일'];
      final weekday = weekdays[date.weekday - 1];
      return '${dateFormat.format(date)} ($weekday)';
    }
  }
}

/// 이미지 썸네일 (인덱스 뱃지 + X 삭제 버튼)
class _ImageThumbnailItem extends StatelessWidget {
  final String base64String;
  final int index;
  final VoidCallback onRemove;
  final VoidCallback onTap;

  const _ImageThumbnailItem({
    required this.base64String,
    required this.index,
    required this.onRemove,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              width: 64,
              height: 64,
              child: Image.memory(
                base64Decode(base64String),
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  color: context.appIconBg,
                  child: Icon(
                    Icons.broken_image_outlined,
                    size: 24,
                    color: context.appTextHint,
                  ),
                ),
              ),
            ),
          ),
          // 인덱스 뱃지
          Positioned(
            bottom: 2,
            left: 2,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '$index',
                style: const TextStyle(
                  fontSize: 10,
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          // X 삭제 버튼
          Positioned(
            top: 2,
            right: 2,
            child: GestureDetector(
              onTap: onRemove,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.6),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.close,
                  size: 12,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

}
