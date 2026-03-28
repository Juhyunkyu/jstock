import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/memo.dart';
import '../../../data/services/image/image_compress_service.dart';
import '../../providers/providers.dart';
import '../../widgets/memo/memo_category_chips.dart';
import '../../widgets/memo/memo_image_viewer.dart';
import '../../widgets/shared/confirm_dialog.dart';

// ---------------------------------------------------------------------------
// Content segment model
// ---------------------------------------------------------------------------

/// Base class for inline content segments (text or image).
abstract class _ContentSegment {}

/// A text segment backed by its own controller and focus node.
class _TextSegment extends _ContentSegment {
  final TextEditingController controller;
  final FocusNode focusNode;

  _TextSegment({String text = ''})
      : controller = TextEditingController(text: text),
        focusNode = FocusNode();

  void dispose() {
    controller.dispose();
    focusNode.dispose();
  }
}

/// An image segment pointing to an index in imageBase64List.
class _ImageSegment extends _ContentSegment {
  int imageIndex;

  _ImageSegment({required this.imageIndex});
}

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------

/// 메모 작성/수정 통합 화면 (인라인 이미지 편집)
///
/// [memoId] null이면 새 메모 작성, 값이 있으면 수정 모드.
/// 이미지를 커서 위치에 인라인으로 삽입/삭제할 수 있다.
/// 저장 시 [IMG:N] 마커 형식으로 직렬화하여 Memo 모델에 저장.
class MemoCreateEditScreen extends ConsumerStatefulWidget {
  final String? memoId;

  const MemoCreateEditScreen({super.key, this.memoId});

  @override
  ConsumerState<MemoCreateEditScreen> createState() =>
      _MemoCreateEditScreenState();
}

class _MemoCreateEditScreenState extends ConsumerState<MemoCreateEditScreen> {
  final _titleController = TextEditingController();
  final _titleFocusNode = FocusNode();

  MemoCategory _category = MemoCategory.general;
  DateTime _selectedDate = DateTime.now();
  List<String> _images = [];
  bool _hasUnsavedChanges = false;

  /// Inline content segments (text and image interleaved).
  List<_ContentSegment> _segments = [];

  /// Track the last focused text segment index for image insertion.
  int _lastFocusedTextIndex = 0;

  // 편집 모드용 원본 데이터
  Memo? _originalMemo;

  bool get _isEditMode => widget.memoId != null;

  static final _imgMarkerRegex = RegExp(r'\[IMG:(\d+)\]');

  // -------------------------------------------------------------------------
  // Lifecycle
  // -------------------------------------------------------------------------

  @override
  void initState() {
    super.initState();
    _titleController.addListener(_markChanged);

    if (_isEditMode) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadMemo());
    } else {
      // 새 메모: 빈 텍스트 세그먼트 하나
      _segments = [_TextSegment()];
      _attachListeners();
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _titleFocusNode.dispose();
    _disposeSegments();
    super.dispose();
  }

  void _disposeSegments() {
    for (final seg in _segments) {
      if (seg is _TextSegment) {
        seg.dispose();
      }
    }
  }

  // -------------------------------------------------------------------------
  // Load / Parse
  // -------------------------------------------------------------------------

  void _loadMemo() {
    final memoState = ref.read(memoListProvider);
    final memo =
        memoState.memos.where((m) => m.id == widget.memoId).firstOrNull;
    if (memo == null) return;

    _originalMemo = memo;
    _titleController.text = memo.title;
    _category = memo.category;
    _selectedDate = memo.displayDate;
    _images = List<String>.from(memo.imageBase64List);

    // Parse content into segments
    _disposeSegments();
    _segments = _parseContent(memo.content);
    _attachListeners();

    _hasUnsavedChanges = false;
    setState(() {});
  }

  /// Parse a content string with [IMG:N] markers into segments.
  /// Always ensures text segments surround every image (even if empty).
  List<_ContentSegment> _parseContent(String content) {
    final segments = <_ContentSegment>[];
    final matches = _imgMarkerRegex.allMatches(content).toList();

    if (matches.isEmpty) {
      segments.add(_TextSegment(text: content));
      return segments;
    }

    int lastEnd = 0;
    for (final match in matches) {
      // Text before this marker
      final textBefore = content.substring(lastEnd, match.start);
      segments.add(_TextSegment(text: _trimEdgeNewlines(textBefore)));

      // Image
      final imgIndex = int.tryParse(match.group(1) ?? '');
      if (imgIndex != null && imgIndex >= 0 && imgIndex < _images.length) {
        segments.add(_ImageSegment(imageIndex: imgIndex));
      }

      lastEnd = match.end;
    }

    // Text after last marker
    final textAfter = content.substring(lastEnd);
    segments.add(_TextSegment(text: _trimEdgeNewlines(textAfter)));

    // Ensure we always have a text segment at the end for typing
    if (_segments.isNotEmpty && _segments.last is! _TextSegment) {
      segments.add(_TextSegment());
    }

    return segments;
  }

  /// Remove leading/trailing newlines that were part of marker formatting.
  String _trimEdgeNewlines(String text) {
    var result = text;
    if (result.startsWith('\n')) result = result.substring(1);
    if (result.endsWith('\n')) result = result.substring(0, result.length - 1);
    return result;
  }

  /// Attach change listeners and focus listeners to all text segments.
  void _attachListeners() {
    for (int i = 0; i < _segments.length; i++) {
      final seg = _segments[i];
      if (seg is _TextSegment) {
        seg.controller.addListener(_markChanged);
        final capturedIndex = i;
        seg.focusNode.addListener(() {
          if (seg.focusNode.hasFocus) {
            _lastFocusedTextIndex = capturedIndex;
          }
        });
      }
    }
  }

  // -------------------------------------------------------------------------
  // Serialize (segments -> content string)
  // -------------------------------------------------------------------------

  /// Build the re-ordered image list matching the serialized order.
  List<String> _serializeImages() {
    final result = <String>[];
    for (final seg in _segments) {
      if (seg is _ImageSegment) {
        if (seg.imageIndex >= 0 && seg.imageIndex < _images.length) {
          result.add(_images[seg.imageIndex]);
        }
      }
    }
    return result;
  }

  // -------------------------------------------------------------------------
  // Operations: Add / Delete image
  // -------------------------------------------------------------------------

  /// Insert an image at the cursor position in the currently focused text field.
  void _insertImageAtCursor(String base64) {
    // Add base64 to images list
    final newImageIndex = _images.length;
    _images.add(base64);

    // Find the focused text segment
    int targetSegIndex = _lastFocusedTextIndex;
    // Validate that the index points to a text segment
    if (targetSegIndex < 0 ||
        targetSegIndex >= _segments.length ||
        _segments[targetSegIndex] is! _TextSegment) {
      // Fallback: find last text segment
      targetSegIndex = _segments.lastIndexWhere((s) => s is _TextSegment);
      if (targetSegIndex < 0) {
        // No text segments at all (shouldn't happen, but be safe)
        _segments.add(_TextSegment());
        targetSegIndex = _segments.length - 1;
      }
    }

    final textSeg = _segments[targetSegIndex] as _TextSegment;
    final text = textSeg.controller.text;
    final selection = textSeg.controller.selection;
    final cursorPos =
        selection.isValid ? selection.baseOffset : text.length;

    // Split the text at cursor
    final beforeText = text.substring(0, cursorPos);
    final afterText = text.substring(cursorPos);

    // Update current text segment with "before" text
    textSeg.controller.removeListener(_markChanged);
    textSeg.controller.text = beforeText;
    textSeg.controller.addListener(_markChanged);

    // Create new segments: image + text-after
    final newImageSeg = _ImageSegment(imageIndex: newImageIndex);
    final newTextSeg = _TextSegment(text: afterText);
    newTextSeg.controller.addListener(_markChanged);

    // Insert after current text segment
    _segments.insert(targetSegIndex + 1, newImageSeg);
    _segments.insert(targetSegIndex + 2, newTextSeg);

    // Update focus listener index for the new text segment
    newTextSeg.focusNode.addListener(() {
      if (newTextSeg.focusNode.hasFocus) {
        _lastFocusedTextIndex = _segments.indexOf(newTextSeg);
      }
    });

    _hasUnsavedChanges = true;
    setState(() {});

    // Focus the new text segment after build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      newTextSeg.focusNode.requestFocus();
      newTextSeg.controller.selection =
          TextSelection.collapsed(offset: 0);
    });
  }

  /// Delete an image segment and merge adjacent text segments.
  void _removeImageSegment(int segmentIndex) {
    if (segmentIndex < 0 || segmentIndex >= _segments.length) return;
    final seg = _segments[segmentIndex];
    if (seg is! _ImageSegment) return;

    final removedImageIndex = seg.imageIndex;

    // Remove the image segment
    _segments.removeAt(segmentIndex);

    // Remove from base64 list
    if (removedImageIndex >= 0 && removedImageIndex < _images.length) {
      _images.removeAt(removedImageIndex);

      // Re-index remaining image segments
      for (final s in _segments) {
        if (s is _ImageSegment && s.imageIndex > removedImageIndex) {
          s.imageIndex--;
        }
      }
    }

    // Merge adjacent text segments around the removed position
    _mergeAdjacentTextSegments(segmentIndex);

    // Ensure at least one text segment exists
    if (_segments.isEmpty) {
      _segments.add(_TextSegment());
      _segments.first is _TextSegment
          ? (_segments.first as _TextSegment).controller.addListener(_markChanged)
          : null;
    }

    _hasUnsavedChanges = true;
    setState(() {});
  }

  /// Merge text segments at [index - 1] and [index] if both are text.
  void _mergeAdjacentTextSegments(int atIndex) {
    // Check if segments at atIndex-1 and atIndex are both text
    if (atIndex <= 0 || atIndex >= _segments.length) return;

    final before = _segments[atIndex - 1];
    final after = _segments[atIndex];

    if (before is _TextSegment && after is _TextSegment) {
      final mergedText = before.controller.text.isEmpty && after.controller.text.isEmpty
          ? ''
          : before.controller.text.isEmpty
              ? after.controller.text
              : after.controller.text.isEmpty
                  ? before.controller.text
                  : '${before.controller.text}\n${after.controller.text}';

      before.controller.removeListener(_markChanged);
      before.controller.text = mergedText;
      before.controller.addListener(_markChanged);

      // Dispose and remove the "after" segment
      after.dispose();
      _segments.removeAt(atIndex);
    }
  }

  // -------------------------------------------------------------------------
  // Changed / navigation
  // -------------------------------------------------------------------------

  void _markChanged() {
    if (!_hasUnsavedChanges) {
      setState(() => _hasUnsavedChanges = true);
    }
  }

  void _goBack() {
    if (_isEditMode) {
      context.go('/memo/detail/${widget.memoId}');
    } else {
      context.go('/memo');
    }
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

  // -------------------------------------------------------------------------
  // Save / Delete
  // -------------------------------------------------------------------------

  Future<void> _save() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('제목을 입력하세요')),
      );
      _titleFocusNode.requestFocus();
      return;
    }

    // Serialize: re-order images to match sequential markers
    final reorderedImages = _serializeImages();

    // Now rebuild the content with sequential indices
    final buffer = StringBuffer();
    int imgCounter = 0;
    for (int i = 0; i < _segments.length; i++) {
      final seg = _segments[i];
      if (seg is _TextSegment) {
        buffer.write(seg.controller.text);
      } else if (seg is _ImageSegment) {
        final current = buffer.toString();
        if (current.isNotEmpty && !current.endsWith('\n')) {
          buffer.write('\n');
        }
        buffer.write('[IMG:$imgCounter]');
        buffer.write('\n');
        imgCounter++;
      }
    }
    final content = buffer.toString();

    final memo = _isEditMode && _originalMemo != null
        ? _originalMemo!.copyWith(
            title: title,
            content: content,
            category: _category,
            customDate: _selectedDate,
            imageBase64List: reorderedImages,
          )
        : Memo(
            id: const Uuid().v4(),
            title: title,
            content: content,
            category: _category,
            customDate: _selectedDate,
            imageBase64List: reorderedImages,
            sortOrder: 0,
          );

    await ref.read(memoListProvider.notifier).save(memo);
    _hasUnsavedChanges = false;

    if (mounted) {
      context.go('/memo/detail/${memo.id}');
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

  // -------------------------------------------------------------------------
  // Date picker
  // -------------------------------------------------------------------------

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
            colorScheme: context.isDarkMode
                ? ColorScheme.dark(
                    primary: context.appAccent,
                    onPrimary: Colors.white,
                    onSurface: context.appTextPrimary,
                    surface: context.appSurface,
                  )
                : ColorScheme.light(
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

  // -------------------------------------------------------------------------
  // Content character count (excluding markers)
  // -------------------------------------------------------------------------

  int get _contentLength {
    int total = 0;
    for (final seg in _segments) {
      if (seg is _TextSegment) {
        total += seg.controller.text.trim().length;
      }
    }
    return total;
  }

  // -------------------------------------------------------------------------
  // Build
  // -------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_hasUnsavedChanges,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldPop = await _onWillPop();
        if (shouldPop && context.mounted) {
          _goBack();
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
                  _goBack();
                }
              } else {
                _goBack();
              }
            },
          ),
          title: Text(
            _isEditMode ? '메모 수정' : '새 메모',
            style: TextStyle(color: context.appTextPrimary),
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ElevatedButton(
                onPressed: _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: context.appAccent,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  '저장',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
        body: GestureDetector(
          onTap: () {
            // Tap outside text fields -> dismiss keyboard
            FocusScope.of(context).unfocus();
          },
          behavior: HitTestBehavior.translucent,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // 제목
              _buildSectionLabel('제목'),
              const SizedBox(height: 8),
              _buildTitleField(),
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

              // 내용 header
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

              // 인라인 편집 영역
              _buildInlineEditArea(),

              const SizedBox(height: 12),

              // 이미지 추가 버튼
              _buildAddImageButton(),

              const SizedBox(height: 24),

              // 하단 정보 + 삭제 버튼
              Row(
                children: [
                  Text(
                    '글자 수: $_contentLength',
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

  // -------------------------------------------------------------------------
  // Inline edit area: interleaved TextFields + Images
  // -------------------------------------------------------------------------

  Widget _buildInlineEditArea() {
    return Container(
      decoration: BoxDecoration(
        color: context.appSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.appDivider),
      ),
      clipBehavior: Clip.hardEdge,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (int i = 0; i < _segments.length; i++) ...[
            if (_segments[i] is _TextSegment)
              _buildSegmentTextField(i, _segments[i] as _TextSegment)
            else if (_segments[i] is _ImageSegment)
              _buildSegmentImage(i, _segments[i] as _ImageSegment),
          ],
        ],
      ),
    );
  }

  Widget _buildSegmentTextField(int segIndex, _TextSegment segment) {
    // Show hint only on the first text segment when it is empty
    // and there are no images yet
    final isFirstText = _segments.indexWhere((s) => s is _TextSegment) == segIndex;
    final showHint = isFirstText && _images.isEmpty;

    return TextField(
      controller: segment.controller,
      focusNode: segment.focusNode,
      maxLines: null,
      minLines: isFirstText && _segments.length == 1 ? 6 : 1,
      style: TextStyle(
        fontSize: 15,
        color: context.appTextPrimary,
        height: 1.5,
      ),
      decoration: InputDecoration(
        hintText: showHint ? '메모 내용을 입력하세요...' : null,
        hintStyle: TextStyle(color: context.appTextHint),
        filled: true,
        fillColor: context.appSurface,
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 8,
        ),
        counterText: '',
      ),
      maxLength: 10000,
      onTap: () {
        _lastFocusedTextIndex = segIndex;
      },
    );
  }

  Widget _buildSegmentImage(int segIndex, _ImageSegment segment) {
    if (segment.imageIndex < 0 || segment.imageIndex >= _images.length) {
      return const SizedBox.shrink();
    }
    final base64 = _images[segment.imageIndex];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Stack(
        children: [
          // Image
          GestureDetector(
            onTap: () => MemoImageViewer.show(
              context,
              _images,
              segment.imageIndex,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.memory(
                base64Decode(base64),
                fit: BoxFit.fitWidth,
                width: double.infinity,
                errorBuilder: (_, __, ___) => Container(
                  height: 120,
                  decoration: BoxDecoration(
                    color: context.appIconBg,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Icon(
                      Icons.broken_image_outlined,
                      size: 40,
                      color: context.appTextHint,
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Delete button (top-right)
          Positioned(
            top: 6,
            right: 6,
            child: GestureDetector(
              onTap: () => _removeImageSegment(segIndex),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.6),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.close,
                  size: 16,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Add image button
  // -------------------------------------------------------------------------

  Widget _buildAddImageButton() {
    return Row(
      children: [
        InkWell(
          onTap: () async {
            final base64 = await ImageCompressService.pickAndCompress();
            if (base64 != null) {
              _insertImageAtCursor(base64);
            }
          },
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: context.appAccent
                  .withValues(alpha: context.isDarkMode ? 0.15 : 0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: context.appAccent.withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.add_photo_alternate_outlined,
                  size: 18,
                  color: context.appAccent,
                ),
                const SizedBox(width: 6),
                Text(
                  '이미지 추가',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: context.appAccent,
                  ),
                ),
              ],
            ),
          ),
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
    );
  }

  // -------------------------------------------------------------------------
  // Common widgets (title, section label, date)
  // -------------------------------------------------------------------------

  Widget _buildTitleField() {
    return TextField(
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
                color: context.appAccent
                    .withValues(alpha: context.isDarkMode ? 0.15 : 0.08),
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
