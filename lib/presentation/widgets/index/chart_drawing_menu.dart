import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import 'drawing_tool_help_data.dart';
import 'drawing_toolbar.dart';

/// 드로잉 도구 메뉴 버튼 (연필 아이콘 + 오버레이 팝업 메뉴)
class ChartDrawingMenuButton extends StatefulWidget {
  final DrawingMode drawingMode;
  final String? selectedDrawingId;
  final ValueChanged<DrawingMode> onSelectMode;
  final VoidCallback onCancel;
  final VoidCallback onResetAll;
  final VoidCallback onDeselectDrawing;

  const ChartDrawingMenuButton({
    super.key,
    required this.drawingMode,
    required this.selectedDrawingId,
    required this.onSelectMode,
    required this.onCancel,
    required this.onResetAll,
    required this.onDeselectDrawing,
  });

  @override
  State<ChartDrawingMenuButton> createState() => _ChartDrawingMenuButtonState();
}

class _ChartDrawingMenuButtonState extends State<ChartDrawingMenuButton> {
  final GlobalKey _drawingToggleKey = GlobalKey();
  OverlayEntry? _drawingMenuOverlay;
  OverlayEntry? _toolHelpOverlay;

  @override
  void dispose() {
    _dismissDrawingMenu();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _buildDrawingToggle();
  }

  Widget _buildDrawingToggle() {
    final isDesktop = MediaQuery.sizeOf(context).width >= 600;

    if (widget.drawingMode != DrawingMode.none) {
      // 드로잉 모드 활성 -> 취소(X) 버튼
      final size = isDesktop ? 28.0 : 24.0;
      return GestureDetector(
        onTap: widget.onCancel,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: context.isDarkMode ? AppColors.gray700 : AppColors.gray400,
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.close, size: isDesktop ? 15 : 13, color: Colors.white),
        ),
      );
    }

    // 기본 -> 연필 아이콘 + 커스텀 팝업
    final pencilSize = isDesktop ? 32.0 : 28.0;
    return GestureDetector(
      key: _drawingToggleKey,
      onTap: _toggleDrawingMenu,
      child: Container(
        width: pencilSize,
        height: pencilSize,
        decoration: BoxDecoration(
          color: context.appIconBg,
          shape: BoxShape.circle,
        ),
        child: Center(
          child: Icon(Icons.edit, size: isDesktop ? 18 : 15, color: context.appTextHint),
        ),
      ),
    );
  }

  void _toggleDrawingMenu() {
    if (_drawingMenuOverlay != null) {
      _dismissDrawingMenu();
      return;
    }

    // 선택된 드로잉 해제
    if (widget.selectedDrawingId != null) {
      widget.onDeselectDrawing();
    }

    final renderBox = _drawingToggleKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;
    final offset = renderBox.localToGlobal(Offset.zero);
    final size = renderBox.size;

    final isDesktop = MediaQuery.sizeOf(context).width >= 600;

    _drawingMenuOverlay = OverlayEntry(
      builder: (ctx) => Stack(
        children: [
          // 배경 탭 -> 메뉴 닫기
          Positioned.fill(
            child: GestureDetector(
              onTap: _dismissDrawingMenu,
              behavior: HitTestBehavior.opaque,
              child: const ColoredBox(color: Colors.transparent),
            ),
          ),
          // 메뉴 버블 (연필 아이콘 아래에 표시)
          Positioned(
            right: MediaQuery.sizeOf(context).width - offset.dx - size.width - 4,
            top: offset.dy + size.height + 6,
            child: Material(
              color: Colors.transparent,
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: isDesktop ? 4 : 4,
                  vertical: isDesktop ? 4 : 4,
                ),
                decoration: BoxDecoration(
                  color: context.appCardBackground,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(30),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                  border: Border.all(
                    color: context.appDivider,
                    width: 0.5,
                  ),
                ),
                child: IntrinsicWidth(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildMenuItem(
                            icon: Icons.horizontal_rule,
                            label: '수평선',
                            helpKey: 'horizontalLine',
                            isDesktop: isDesktop,
                            onTap: () => _selectDrawingMode(DrawingMode.horizontalLine),
                          ),
                          _buildMenuItem(
                            icon: Icons.trending_up,
                            label: '추세선',
                            helpKey: 'trendLine',
                            isDesktop: isDesktop,
                            onTap: () => _selectDrawingMode(DrawingMode.trendLine),
                          ),
                          _buildMenuItem(
                            icon: Icons.stacked_line_chart,
                            label: '피보나치',
                            helpKey: 'fibonacci',
                            isDesktop: isDesktop,
                            onTap: () => _selectDrawingMode(DrawingMode.fibonacci),
                          ),
                          _buildMenuItem(
                            icon: Icons.view_stream,
                            label: '지지/저항',
                            helpKey: 'supportResistanceZone',
                            isDesktop: isDesktop,
                            onTap: () => _selectDrawingMode(DrawingMode.supportResistanceZone),
                          ),
                          _buildMenuItem(
                            icon: Icons.straighten,
                            label: '측정',
                            helpKey: 'measure',
                            isDesktop: isDesktop,
                            onTap: () => _selectDrawingMode(DrawingMode.measure),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: Divider(height: 1, color: context.appDivider),
                          ),
                          _buildMenuItem(
                            icon: Icons.delete_sweep,
                            label: '초기화',
                            isDesktop: isDesktop,
                            onTap: () {
                              _dismissDrawingMenu();
                              widget.onResetAll();
                            },
                          ),
                        ],
                      ),
                    ),
              ),
            ),
          ),
        ],
      ),
    );

    Overlay.of(context).insert(_drawingMenuOverlay!);
  }

  /// 메뉴 아이템 (수직 일렬, 도구는 ? 포함)
  Widget _buildMenuItem({
    required IconData icon,
    required String label,
    required bool isDesktop,
    required VoidCallback onTap,
    String? helpKey,
  }) {
    final iconSize = isDesktop ? 18.0 : 16.0;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: isDesktop ? 8 : 6,
          vertical: isDesktop ? 6 : 5,
        ),
        child: Row(
          children: [
            SizedBox(
              width: isDesktop ? 24 : 20,
              height: isDesktop ? 24 : 20,
              child: Center(
                child: Icon(icon, size: iconSize, color: context.appTextPrimary),
              ),
            ),
            SizedBox(width: isDesktop ? 8 : 6),
            Text(
              label,
              style: TextStyle(
                fontSize: isDesktop ? 13 : 12,
                fontWeight: FontWeight.w500,
                color: context.appTextPrimary,
              ),
            ),
            if (helpKey != null) ...[
              SizedBox(width: isDesktop ? 8 : 6),
              GestureDetector(
                onTap: () {
                  _showToolHelpOverlay(helpKey);
                },
                child: Icon(
                  Icons.help_outline,
                  size: isDesktop ? 15 : 14,
                  color: context.appTextHint,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _selectDrawingMode(DrawingMode mode) {
    _dismissDrawingMenu();
    widget.onSelectMode(mode);
  }

  void _dismissDrawingMenu() {
    _dismissToolHelp();
    _drawingMenuOverlay?.remove();
    _drawingMenuOverlay = null;
  }

  void _dismissToolHelp() {
    _toolHelpOverlay?.remove();
    _toolHelpOverlay = null;
  }

  void _showToolHelpOverlay(String helpKey) {
    _dismissToolHelp();

    final helpData = DrawingToolHelpData.getToolHelp(helpKey);
    if (helpData == null) return;

    final screenWidth = MediaQuery.sizeOf(context).width;
    final isDesktop = screenWidth >= 600;

    _toolHelpOverlay = OverlayEntry(
      builder: (ctx) => Stack(
        children: [
          // 배경 탭 -> 도움말만 닫기 (메뉴는 유지)
          Positioned.fill(
            child: GestureDetector(
              onTap: _dismissToolHelp,
              behavior: HitTestBehavior.translucent,
              child: const SizedBox.expand(),
            ),
          ),
          // 도움말 카드 (화면 중앙)
          Positioned(
            left: isDesktop ? screenWidth * 0.25 : 24,
            right: isDesktop ? screenWidth * 0.25 : 24,
            top: isDesktop ? 120 : 100,
            child: Material(
              color: Colors.transparent,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: context.appSurface,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(40),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                  border: Border.all(color: context.appDivider, width: 0.5),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(helpData['icon'] as IconData, size: 20, color: context.appAccent),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            helpData['title'] as String,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: context.appTextPrimary,
                            ),
                          ),
                        ),
                        GestureDetector(
                          onTap: _dismissToolHelp,
                          child: Icon(Icons.close, size: 18, color: context.appTextHint),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    ConstrainedBox(
                      constraints: BoxConstraints(maxHeight: isDesktop ? 300 : 250),
                      child: SingleChildScrollView(
                        child: Text(
                          helpData['description'] as String,
                          style: TextStyle(
                            fontSize: 13,
                            color: context.appTextSecondary,
                            height: 1.6,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );

    Overlay.of(context).insert(_toolHelpOverlay!);
  }
}
