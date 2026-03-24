part of 'detail_chart_section.dart';

// ═══════════════════════════════════════════════════════════════
// 드로잉 제스처 핸들링 (part of _DetailChartSectionState)
// ═══════════════════════════════════════════════════════════════

extension _DrawingGestureHandler on _DetailChartSectionState {
  // ─── 탭 핸들러 ──────────────────────────────────────────────

  void handleChartTap(
    TapUpDetails details,
    double chartWidth,
    List<OHLCData> displayData,
    List<BBResult>? displayBB,
    List<IchimokuResult>? displayIchimoku,
    String? bbSummary,
    String? ichSummary,
    int scrollOffset,
  ) {
    // 인라인 버튼(Listener)이 먼저 처리한 경우 -> 탭 무시
    if (_ignoreNextTap) {
      _ignoreNextTap = false;
      return;
    }

    final localPos = details.localPosition;
    final yRange = ChartCoordinateCalculator.calculate(
      data: displayData,
      width: chartWidth,
      height: 300,
      bollingerBands: displayBB,
      ichimoku: displayIchimoku,
      bbSummary: bbSummary,
      ichSummary: ichSummary,
    );

    if (_drawingMode != DrawingMode.none) {
      _handleDrawingTap(localPos, yRange, displayData, scrollOffset);
      return;
    }

    // 인라인 버튼 영역 탭 무시 (버튼이 자체 처리)
    if (_selectedDrawingId != null) {
      final selY = _getSelectedLineY(yRange);
      if (selY != null &&
          localPos.dx >= 14 && localPos.dx <= 50 &&
          localPos.dy >= selY - 38 && localPos.dy <= selY + 38) {
        return;
      }
    }

    // 일반 모드: hit test -> 가장 가까운 드로잉 선택
    _handleSelectionTap(localPos, yRange, displayData, scrollOffset);
  }

  void _handleDrawingTap(
    Offset localPos,
    ChartYRange yRange,
    List<OHLCData> displayData,
    int scrollOffset,
  ) {
    final price = yRange.fromY(localPos.dy);

    // 수평선: 탭으로도 배치
    if (_drawingMode == DrawingMode.horizontalLine) {
      _createHorizontalLine(price);
      return;
    }

    // 측정/지지저항: 탭으로는 동작하지 않음 (드래그 전용)
    if (_drawingMode == DrawingMode.measure ||
        _drawingMode == DrawingMode.supportResistanceZone) {
      return;
    }

    final dataIndex = yRange.fromX(localPos.dx);
    final fullIndex = dataIndex + scrollOffset;

    DateTime? date;
    if (fullIndex >= 0 && fullIndex < widget.chartData.length) {
      date = widget.chartData[fullIndex].date;
    }

    // 추세선: 2탭 배치
    if (_drawingMode == DrawingMode.trendLine) {
      if (!_waitingSecondPoint) {
        setState(() {
          _tempTrendLineStartDate = date;
          _tempTrendLineStartPrice = price;
          _waitingSecondPoint = true;
        });
      } else {
        _createTrendLine(
          _tempTrendLineStartDate!,
          _tempTrendLineStartPrice!,
          date!,
          price,
        );
      }
    }

    // 피보나치: 2탭 배치 (100% 고점 -> 0% 저점)
    if (_drawingMode == DrawingMode.fibonacci) {
      if (!_waitingSecondPoint) {
        setState(() {
          _tempTrendLineStartDate = date;
          _tempTrendLineStartPrice = price;
          _waitingSecondPoint = true;
        });
      } else {
        _createFibonacci(
          _tempTrendLineStartDate!,
          _tempTrendLineStartPrice!,
          date!,
          price,
        );
      }
    }
  }

  void _handleSelectionTap(
    Offset localPos,
    ChartYRange yRange,
    List<OHLCData> displayData,
    int scrollOffset,
  ) {
    final drawings = ref.read(chartDrawingProvider);
    const hitThreshold = 20.0; // px
    String? closestId;
    double closestDist = double.infinity;

    for (final drawing in drawings) {
      double dist;
      switch (drawing.type) {
        case DrawingType.horizontalLine:
          final lineY = yRange.toY(drawing.price);
          dist = (localPos.dy - lineY).abs();
          break;
        case DrawingType.trendLine:
          dist = _trendLineDistance(localPos, drawing, yRange, scrollOffset);
          break;
        case DrawingType.fibonacci:
          dist = _fibonacciDistance(localPos, drawing, yRange);
          break;
        case DrawingType.supportResistanceZone:
          dist = _zoneDistance(localPos, drawing, yRange);
          break;
      }
      if (dist < closestDist) {
        closestDist = dist;
        closestId = drawing.id;
      }
    }

    setState(() {
      _selectedDrawingId = closestDist <= hitThreshold ? closestId : null;
    });
    _notifyDrawingActive();
  }

  // ─── 드로잉 생성 ──────────────────────────────────────────

  void _createHorizontalLine(double price) {
    final drawing = ChartDrawing(
      id: _uuid.v4(),
      symbol: widget.symbol,
      type: DrawingType.horizontalLine,
      price: price,
      colorValue: _drawingColors[_colorIndex % _drawingColors.length],
    );
    _colorIndex++;
    ref.read(chartDrawingProvider.notifier).addDrawing(drawing);
    setState(() {
      _drawingMode = DrawingMode.none;
    });
    _notifyDrawingActive();
  }

  void _createTrendLine(
    DateTime startDate,
    double startPrice,
    DateTime endDate,
    double endPrice,
  ) {
    final drawing = ChartDrawing(
      id: _uuid.v4(),
      symbol: widget.symbol,
      type: DrawingType.trendLine,
      price: startPrice,
      startDate: startDate,
      startPrice: startPrice,
      endDate: endDate,
      endPrice: endPrice,
      colorValue: _drawingColors[_colorIndex % _drawingColors.length],
    );
    _colorIndex++;
    ref.read(chartDrawingProvider.notifier).addDrawing(drawing);
    setState(() {
      _drawingMode = DrawingMode.none;
      _waitingSecondPoint = false;
      _tempTrendLineStartDate = null;
      _tempTrendLineStartPrice = null;
    });
    _notifyDrawingActive();
  }

  void _createFibonacci(
    DateTime startDate,
    double startPrice,
    DateTime endDate,
    double endPrice,
  ) {
    final drawing = ChartDrawing(
      id: _uuid.v4(),
      symbol: widget.symbol,
      type: DrawingType.fibonacci,
      price: startPrice,
      startDate: startDate,
      startPrice: startPrice,
      endDate: endDate,
      endPrice: endPrice,
      colorValue: _drawingColors[_colorIndex % _drawingColors.length],
    );
    _colorIndex++;
    ref.read(chartDrawingProvider.notifier).addDrawing(drawing);
    setState(() {
      _drawingMode = DrawingMode.none;
      _waitingSecondPoint = false;
      _tempTrendLineStartDate = null;
      _tempTrendLineStartPrice = null;
    });
    _notifyDrawingActive();
  }

  void _createSRZone(double upperPrice, double lowerPrice) {
    final upper = math.max(upperPrice, lowerPrice);
    final lower = math.min(upperPrice, lowerPrice);
    final drawing = ChartDrawing(
      id: _uuid.v4(),
      symbol: widget.symbol,
      type: DrawingType.supportResistanceZone,
      price: upper,
      lowerPrice: lower,
      colorValue: _drawingColors[_colorIndex % _drawingColors.length],
    );
    _colorIndex++;
    ref.read(chartDrawingProvider.notifier).addDrawing(drawing);
    setState(() {
      _drawingMode = DrawingMode.none;
    });
    _notifyDrawingActive();
  }

  // ─── 드로잉 액션 ──────────────────────────────────────────

  void resetAllDrawings() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.appSurface,
        title: Text(
          '드로잉 초기화',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: context.appTextPrimary),
        ),
        content: Text(
          '이 차트의 모든 드로잉을 삭제하시겠습니까?\n삭제된 드로잉은 복구할 수 없습니다.',
          style: TextStyle(fontSize: 13, color: context.appTextSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('취소', style: TextStyle(color: context.appTextHint)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(chartDrawingProvider.notifier).clearAllForSymbol(widget.symbol);
              setState(() {
                _selectedDrawingId = null;
              });
              _notifyDrawingActive();
            },
            child: const Text('삭제', style: TextStyle(color: AppColors.stockDown)),
          ),
        ],
      ),
    );
  }

  void deleteSelectedDrawing() {
    if (_selectedDrawingId == null) return;
    ref.read(chartDrawingProvider.notifier).removeDrawing(_selectedDrawingId!);
    setState(() {
      _selectedDrawingId = null;
    });
    _notifyDrawingActive();
  }

  void cancelDrawing() {
    setState(() {
      _drawingMode = DrawingMode.none;
      _waitingSecondPoint = false;
      _tempTrendLineStartDate = null;
      _tempTrendLineStartPrice = null;
      _isDraggingNewLine = false;
      _tempHorizontalPrice = null;
      _isMeasuring = false;
      _measureStartFullIndex = null;
      _measureEndFullIndex = null;
      _measureStartPrice = null;
      _measureEndPrice = null;
      _isDraggingNewZone = false;
      _tempZoneUpperPrice = null;
      _tempZoneLowerPrice = null;
    });
    _notifyDrawingActive();
  }

  void selectDrawingMode(DrawingMode mode) {
    setState(() {
      _drawingMode = mode;
      _rsiWatchMode = false; // 드로잉 모드 진입 시 감시점 모드 해제
      _selectedDrawingId = null;
      _selectedCandleIndex = null;
      _waitingSecondPoint = false;
      _tempTrendLineStartDate = null;
      _tempTrendLineStartPrice = null;
      _isMeasuring = false;
      _measureStartFullIndex = null;
      _measureEndFullIndex = null;
      _measureStartPrice = null;
      _measureEndPrice = null;
      _isDraggingNewZone = false;
      _tempZoneUpperPrice = null;
      _tempZoneLowerPrice = null;
    });
    _notifyDrawingActive();
  }

  // ─── 드래그 제스처 (수평선 배치 + 기존 선 이동 + 스크롤/줌) ───

  void handleScaleStart(ScaleStartDetails details, double chartWidth,
      ChartYRange yRange) {
    // 1) 수평선 드래그 배치 모드
    if (_drawingMode == DrawingMode.horizontalLine) {
      final price = yRange.fromY(details.localFocalPoint.dy);
      setState(() {
        _isDraggingNewLine = true;
        _tempHorizontalPrice = price;
        _cachedYRange = yRange;
      });
      return;
    }

    // 2) 지지/저항 영역 드래그 배치 모드
    if (_drawingMode == DrawingMode.supportResistanceZone) {
      final price = yRange.fromY(details.localFocalPoint.dy);
      setState(() {
        _isDraggingNewZone = true;
        _tempZoneUpperPrice = price;
        _tempZoneLowerPrice = price;
        _cachedYRange = yRange;
      });
      return;
    }

    // 3) 측정 도구 드래그 모드
    if (_drawingMode == DrawingMode.measure) {
      final price = yRange.fromY(details.localFocalPoint.dy);
      final dataIndex = yRange.fromX(details.localFocalPoint.dx);
      final fullIndex = (dataIndex + _scrollOffset).clamp(0, widget.chartData.length - 1);
      setState(() {
        _isMeasuring = true;
        _measureStartFullIndex = fullIndex;
        _measureStartPrice = price;
        _measureEndFullIndex = fullIndex;
        _measureEndPrice = price;
        _cachedYRange = yRange;
      });
      return;
    }

    // 인라인 버튼 영역 터치 -> 제스처 무시 (버튼이 자체 처리)
    if (_selectedDrawingId != null) {
      final selY = _getSelectedLineY(yRange);
      final touchX = details.localFocalPoint.dx;
      final touchY = details.localFocalPoint.dy;
      if (selY != null &&
          touchX >= 14 && touchX <= 50 &&
          touchY >= selY - 38 && touchY <= selY + 38) {
        return;
      }
    }

    // 4) 선택된 드로잉 드래그 이동 (잠금 아니고, 근처)
    if (_drawingMode == DrawingMode.none && _selectedDrawingId != null) {
      final drawings = ref.read(chartDrawingProvider);
      final selected = drawings.where((d) => d.id == _selectedDrawingId).firstOrNull;
      if (selected != null && !selected.isLocked) {
        final touchX = details.localFocalPoint.dx;
        final touchY = details.localFocalPoint.dy;
        bool isNearLine = false;

        if (selected.type == DrawingType.horizontalLine) {
          final lineY = yRange.toY(selected.price);
          isNearLine = (touchY - lineY).abs() <= 30;
        } else if (selected.type == DrawingType.trendLine &&
            selected.startDate != null && selected.endDate != null &&
            selected.startPrice != null && selected.endPrice != null) {
          // 앵커 점 근처인지 먼저 확인 (25px 이내 -> 앵커 드래그)
          final startIdx = _findDateIndex(widget.chartData, selected.startDate!);
          final endIdx = _findDateIndex(widget.chartData, selected.endDate!);
          if (startIdx != null && endIdx != null) {
            final startX = yRange.toX(startIdx - _scrollOffset);
            final startY = yRange.toY(selected.startPrice!);
            final endX = yRange.toX(endIdx - _scrollOffset);
            final endY = yRange.toY(selected.endPrice!);

            final distToStart = (Offset(touchX, touchY) - Offset(startX, startY)).distance;
            final distToEnd = (Offset(touchX, touchY) - Offset(endX, endY)).distance;

            const anchorThreshold = 25.0;
            if (distToStart <= anchorThreshold || distToEnd <= anchorThreshold) {
              final anchor = distToStart <= distToEnd ? 'start' : 'end';
              setState(() {
                _isMovingDrawing = true;
                _movingDrawingId = selected.id;
                _draggingAnchor = anchor;
                _cachedYRange = yRange;
              });
              return;
            }
          }

          // 선 몸통 근처 -> 평행 이동
          final dist = _trendLineDistance(
            Offset(touchX, touchY), selected, yRange, _scrollOffset,
          );
          isNearLine = dist <= 30;
        } else if (selected.type == DrawingType.fibonacci &&
            selected.startDate != null && selected.endDate != null &&
            selected.startPrice != null && selected.endPrice != null) {
          // 피보나치 앵커 드래그 (100%/0% 앵커)
          final startIdx = _findDateIndex(widget.chartData, selected.startDate!);
          final endIdx = _findDateIndex(widget.chartData, selected.endDate!);
          if (startIdx != null && endIdx != null) {
            final startX = yRange.toX(startIdx - _scrollOffset);
            final startY = yRange.toY(selected.startPrice!);
            final endX = yRange.toX(endIdx - _scrollOffset);
            final endY = yRange.toY(selected.endPrice!);

            final distToStart = (Offset(touchX, touchY) - Offset(startX, startY)).distance;
            final distToEnd = (Offset(touchX, touchY) - Offset(endX, endY)).distance;

            const anchorThreshold = 25.0;
            if (distToStart <= anchorThreshold || distToEnd <= anchorThreshold) {
              final anchor = distToStart <= distToEnd ? 'start' : 'end';
              setState(() {
                _isMovingDrawing = true;
                _movingDrawingId = selected.id;
                _draggingAnchor = anchor;
                _cachedYRange = yRange;
              });
              return;
            }
          }

          // 레벨 선 근처 -> 평행 이동
          final dist = _fibonacciDistance(Offset(touchX, touchY), selected, yRange);
          isNearLine = dist <= 30;
        } else if (selected.type == DrawingType.supportResistanceZone) {
          // 지지/저항 영역: 상/하변 드래그 또는 평행 이동
          final upperY = yRange.toY(selected.price);
          final lowerY = yRange.toY(selected.lowerPrice);

          const edgeThreshold = 15.0;
          if ((touchY - upperY).abs() <= edgeThreshold) {
            setState(() {
              _isMovingDrawing = true;
              _movingDrawingId = selected.id;
              _draggingAnchor = 'upper';
              _cachedYRange = yRange;
            });
            return;
          } else if ((touchY - lowerY).abs() <= edgeThreshold) {
            setState(() {
              _isMovingDrawing = true;
              _movingDrawingId = selected.id;
              _draggingAnchor = 'lower';
              _cachedYRange = yRange;
            });
            return;
          }

          // 영역 내부 -> 평행 이동
          final topY = math.min(upperY, lowerY);
          final bottomY = math.max(upperY, lowerY);
          isNearLine = touchY >= topY - 5 && touchY <= bottomY + 5;
        }

        if (isNearLine) {
          setState(() {
            _isMovingDrawing = true;
            _movingDrawingId = selected.id;
            _draggingAnchor = null;
            _moveStartY = touchY;
            _moveStartPrice = selected.price;
            _moveStartStartPrice = selected.startPrice;
            _moveStartEndPrice = selected.endPrice;
            _cachedYRange = yRange;
          });
          return;
        }
      }
    }

    // 5) 기본: 스크롤/줌
    _startVisibleCount = _visibleCount;
    _dragRemainder = 0.0;
  }

  void handleScaleUpdate(ScaleUpdateDetails details, double chartWidth,
      ChartYRange yRange) {
    // 1) 수평선 드래그 배치 -> 미리보기 업데이트
    if (_isDraggingNewLine && _cachedYRange != null) {
      setState(() {
        _tempHorizontalPrice = _cachedYRange!.fromY(details.localFocalPoint.dy);
      });
      return;
    }

    // 2) 지지/저항 영역 드래그 배치
    if (_isDraggingNewZone && _cachedYRange != null) {
      setState(() {
        _tempZoneLowerPrice = _cachedYRange!.fromY(details.localFocalPoint.dy);
      });
      return;
    }

    // 3) 측정 도구 드래그
    if (_isMeasuring && _cachedYRange != null) {
      final price = _cachedYRange!.fromY(details.localFocalPoint.dy);
      final dataIndex = _cachedYRange!.fromX(details.localFocalPoint.dx);
      final fullIndex = (dataIndex + _scrollOffset).clamp(0, widget.chartData.length - 1);
      setState(() {
        _measureEndFullIndex = fullIndex;
        _measureEndPrice = price;
      });
      return;
    }

    // 4) 기존 드로잉 드래그 이동 / 앵커 드래그
    if (_isMovingDrawing && _movingDrawingId != null && _cachedYRange != null) {
      final currentX = details.localFocalPoint.dx;
      final currentY = details.localFocalPoint.dy;
      final currentPrice = _cachedYRange!.fromY(currentY);
      final drawings = ref.read(chartDrawingProvider);
      final target = drawings.where((d) => d.id == _movingDrawingId).firstOrNull;
      if (target != null) {
        // 추세선/피보나치 앵커 드래그
        if (_draggingAnchor != null &&
            (target.type == DrawingType.trendLine || target.type == DrawingType.fibonacci)) {
          final displayIdx = _cachedYRange!.fromX(currentX);
          final fullIdx = (displayIdx + _scrollOffset).clamp(0, widget.chartData.length - 1);
          final newDate = widget.chartData[fullIdx].date;
          final newPrice = currentPrice;

          if (_draggingAnchor == 'start') {
            ref.read(chartDrawingProvider.notifier).updateDrawingLocal(
              target.copyWith(startDate: newDate, startPrice: newPrice),
            );
          } else {
            ref.read(chartDrawingProvider.notifier).updateDrawingLocal(
              target.copyWith(endDate: newDate, endPrice: newPrice),
            );
          }
        }
        // 지지/저항 영역 상/하변 드래그
        else if (_draggingAnchor == 'upper' && target.type == DrawingType.supportResistanceZone) {
          ref.read(chartDrawingProvider.notifier).updateDrawingLocal(
            target.copyWith(price: currentPrice),
          );
        } else if (_draggingAnchor == 'lower' && target.type == DrawingType.supportResistanceZone) {
          ref.read(chartDrawingProvider.notifier).updateDrawingLocal(
            target.copyWith(lowerPrice: currentPrice),
          );
        }
        // 추세선/피보나치 평행 이동
        else if ((target.type == DrawingType.trendLine || target.type == DrawingType.fibonacci) &&
            _moveStartStartPrice != null && _moveStartEndPrice != null &&
            _moveStartY != null) {
          final startPrice = _cachedYRange!.fromY(_moveStartY!);
          final priceDelta = currentPrice - startPrice;
          ref.read(chartDrawingProvider.notifier).updateDrawingLocal(
            target.copyWith(
              startPrice: _moveStartStartPrice! + priceDelta,
              endPrice: _moveStartEndPrice! + priceDelta,
            ),
          );
        }
        // 지지/저항 영역 평행 이동
        else if (target.type == DrawingType.supportResistanceZone &&
            _moveStartPrice != null && _moveStartY != null) {
          final startPrice = _cachedYRange!.fromY(_moveStartY!);
          final priceDelta = currentPrice - startPrice;
          final zoneHeight = target.price - target.lowerPrice;
          ref.read(chartDrawingProvider.notifier).updateDrawingLocal(
            target.copyWith(
              price: _moveStartPrice! + priceDelta,
              lowerPrice: _moveStartPrice! - zoneHeight + priceDelta,
            ),
          );
        }
        // 수평선: price 직접 업데이트
        else {
          ref.read(chartDrawingProvider.notifier)
              .updateDrawingLocal(target.copyWith(price: currentPrice));
        }
      }
      return;
    }

    // 5) 기본: 스크롤/줌 (드로잉 모드 중에는 비활성)
    if (_drawingMode == DrawingMode.none) {
      _handleZoomScroll(details, chartWidth);
    }
  }

  void handleScaleEnd(ScaleEndDetails details) {
    // 1) 수평선 드래그 배치 완료 -> 선 확정
    if (_isDraggingNewLine && _tempHorizontalPrice != null) {
      _createHorizontalLine(_tempHorizontalPrice!);
      setState(() {
        _isDraggingNewLine = false;
        _tempHorizontalPrice = null;
        _cachedYRange = null;
      });
      return;
    }

    // 2) 지지/저항 영역 드래그 배치 완료 -> 영역 생성
    if (_isDraggingNewZone && _tempZoneUpperPrice != null && _tempZoneLowerPrice != null) {
      if ((_tempZoneUpperPrice! - _tempZoneLowerPrice!).abs() > 0.01) {
        _createSRZone(_tempZoneUpperPrice!, _tempZoneLowerPrice!);
      }
      setState(() {
        _isDraggingNewZone = false;
        _tempZoneUpperPrice = null;
        _tempZoneLowerPrice = null;
        _cachedYRange = null;
      });
      return;
    }

    // 3) 측정 도구 드래그 완료 -> 상태 클리어 (모드 유지)
    if (_isMeasuring) {
      setState(() {
        _isMeasuring = false;
        _measureStartFullIndex = null;
        _measureEndFullIndex = null;
        _measureStartPrice = null;
        _measureEndPrice = null;
        _cachedYRange = null;
      });
      return;
    }

    // 4) 기존 드로잉 이동 완료 -> Hive 저장
    if (_isMovingDrawing && _movingDrawingId != null) {
      final drawings = ref.read(chartDrawingProvider);
      final target = drawings.where((d) => d.id == _movingDrawingId).firstOrNull;
      if (target != null) {
        ref.read(chartDrawingProvider.notifier).updateDrawing(target);
      }
      setState(() {
        _isMovingDrawing = false;
        _movingDrawingId = null;
        _cachedYRange = null;
        _moveStartY = null;
        _moveStartPrice = null;
        _moveStartStartPrice = null;
        _moveStartEndPrice = null;
        _draggingAnchor = null;
      });
      return;
    }
  }

  // ─── 캔들 롱프레스 스크럽 ────────────────────────────────────

  void _handleCandleScrubStart(LongPressStartDetails details, ChartYRange yRange, int scrollOffset) {
    if (_drawingMode != DrawingMode.none) return;
    final dataIndex = yRange.fromX(details.localPosition.dx);
    final fullIndex = (dataIndex + scrollOffset).clamp(0, widget.chartData.length - 1);
    setState(() {
      _selectedCandleIndex = fullIndex;
      _selectedDrawingId = null;
    });
    _notifyDrawingActive();
    HapticFeedback.selectionClick();
  }

  void _handleCandleScrubUpdate(LongPressMoveUpdateDetails details, ChartYRange yRange, int scrollOffset) {
    if (_drawingMode != DrawingMode.none || _selectedCandleIndex == null) return;
    final dataIndex = yRange.fromX(details.localPosition.dx);
    final fullIndex = (dataIndex + scrollOffset).clamp(0, widget.chartData.length - 1);
    if (fullIndex != _selectedCandleIndex) {
      setState(() => _selectedCandleIndex = fullIndex);
      HapticFeedback.selectionClick();
    }
  }

  void _handleCandleScrubEnd() {
    if (_selectedCandleIndex != null) {
      setState(() {
        _selectedCandleIndex = null;
      });
    }
  }

  // ─── 설정 패널 ──────────────────────────────────────────────

  void showDrawingSettings() {
    if (_selectedDrawingId == null) return;
    final drawings = ref.read(chartDrawingProvider);
    final drawing = drawings.where((d) => d.id == _selectedDrawingId).firstOrNull;
    if (drawing == null) return;

    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DrawingSettingsSheet(
        drawing: drawing,
        onSave: (updated) {
          ref.read(chartDrawingProvider.notifier).updateDrawing(updated);
        },
      ),
    );
  }
}
