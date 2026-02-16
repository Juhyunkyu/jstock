// Basic Flutter widget test for Alpha Cycle app
// Note: Full app tests require Hive initialization.
// This test verifies basic widget construction.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:alpha_cycle/core/theme/app_colors.dart';

void main() {
  testWidgets('App theme and colors smoke test', (WidgetTester tester) async {
    // 기본 테마 색상 확인
    expect(AppColors.primary, isNotNull);
    expect(AppColors.primaryLight, isNotNull);
    expect(AppColors.primaryDark, isNotNull);

    // 기본 위젯 빌드 테스트
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          appBar: AppBar(
            title: const Text('알파 사이클'),
            backgroundColor: AppColors.primary,
          ),
          body: const Center(
            child: Text('3배 레버리지 ETF 분할매수 도우미'),
          ),
        ),
      ),
    );

    // 텍스트가 화면에 표시되는지 확인
    expect(find.text('알파 사이클'), findsOneWidget);
    expect(find.text('3배 레버리지 ETF 분할매수 도우미'), findsOneWidget);
  });

  testWidgets('Trading signal colors test', (WidgetTester tester) async {
    // 매매 신호 관련 색상 확인
    expect(AppColors.red500, isNotNull); // 매도/하락
    expect(AppColors.green500, isNotNull); // 매수/상승
    expect(AppColors.blue500, isNotNull); // 가중 매수
    expect(AppColors.amber500, isNotNull); // 익절

    // 색상이 올바른 범위에 있는지 확인
    expect(AppColors.red500.value, isNonZero);
    expect(AppColors.green500.value, isNonZero);
  });
}
