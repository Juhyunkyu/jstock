import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/memo.dart';
import '../../providers/providers.dart';
import '../../widgets/memo/memo_category_chips.dart';
import '../../widgets/memo/memo_image_picker.dart';
import '../../widgets/memo/memo_image_viewer.dart';
import '../../widgets/shared/confirm_dialog.dart';

/// 메모 작성/수정 통합 화면
///
/// [memoId] null이면 새 메모 작성, 값이 있으면 수정 모드.
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

  // 편집 모드용 원본 데이터
  Memo? _originalMemo;

  bool get _isEditMode => widget.memoId != null;

  @override
  void initState() {
    super.initState();
    _titleController.addListener(_markChanged);
    _contentController.addListener(_markChanged);

    if (_isEditMode) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadMemo());
    }
  }

  void _loadMemo() {
    final memoState = ref.read(memoListProvider);
    final memo = memoState.memos.where((m) => m.id == widget.memoId).firstOrNull;
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
    final contentLength = _contentController.text.length;

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
                    borderSide: BorderSide(color: context.appAccent, width: 1.5),
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

              // 내용
              _buildSectionLabel('내용'),
              const SizedBox(height: 8),
              TextField(
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
                  hintText: '메모 내용을 입력하세요...',
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
              ),
              const SizedBox(height: 20),

              // 이미지
              MemoImagePicker(
                images: _images,
                onAdd: (base64) {
                  setState(() {
                    _images.add(base64);
                    _hasUnsavedChanges = true;
                  });
                },
                onRemove: (index) {
                  setState(() {
                    _images.removeAt(index);
                    _hasUnsavedChanges = true;
                  });
                },
                onTap: (index) {
                  MemoImageViewer.show(context, _images, index);
                },
              ),
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
