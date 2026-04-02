import 'package:flutter/material.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';

/// 개인정보 처리방침 BottomSheet
void showPrivacyPolicySheet(BuildContext context) {
  _showLegalSheet(
    context: context,
    title: '개인정보 처리방침',
    lastUpdated: '2026년 4월 2일',
    sections: const [
      _LegalSection(
        title: '1. 수집하는 개인정보',
        content:
            '${AppConstants.appName}은 별도의 회원가입 없이 사용할 수 있으며, '
            '서버에 개인정보를 전송하거나 저장하지 않습니다.\n\n'
            '앱에서 입력하는 모든 데이터(사이클, 거래내역, 관심종목, 메모 등)는 '
            '사용자의 기기(브라우저) 내 로컬 저장소(IndexedDB)에만 저장됩니다.',
      ),
      _LegalSection(
        title: '2. 외부 API 통신',
        content:
            '실시간 시세, 환율, 뉴스 등의 기능을 위해 다음 외부 서비스와 통신합니다:\n\n'
            '• Finnhub — 실시간 주가 (WebSocket)\n'
            '• Twelve Data — 차트 데이터, 환율\n'
            '• CNN — Fear & Greed Index\n'
            '• 한국수출입은행 — 매매기준율\n\n'
            '이 통신에는 사용자의 개인정보가 포함되지 않으며, '
            '종목 심볼과 같은 조회 요청만 전송됩니다.',
      ),
      _LegalSection(
        title: '3. 데이터 저장 위치',
        content:
            '모든 데이터는 사용자의 웹 브라우저 내 IndexedDB에 저장됩니다.\n\n'
            '• 서버 전송: 없음\n'
            '• 클라우드 동기화: 없음\n'
            '• 브라우저 데이터 삭제 시: 모든 앱 데이터가 삭제됩니다\n\n'
            '백업 기능을 통해 JSON 파일로 내보내기/복원이 가능합니다.',
      ),
      _LegalSection(
        title: '4. 쿠키 및 추적',
        content:
            '${AppConstants.appName}은 분석 도구, 광고 추적, 쿠키를 사용하지 않습니다.',
      ),
      _LegalSection(
        title: '5. 문의',
        content: '개인정보 관련 문의사항이 있으시면 앱 내 설정 > 앱 정보를 통해 연락해주세요.',
      ),
    ],
  );
}

/// 이용약관 BottomSheet
void showTermsOfServiceSheet(BuildContext context) {
  _showLegalSheet(
    context: context,
    title: '이용약관',
    lastUpdated: '2026년 4월 2일',
    sections: const [
      _LegalSection(
        title: '1. 서비스 개요',
        content:
            '${AppConstants.appName}은 레버리지 ETF 분할매수 전략을 위한 '
            '투자 보조 도구입니다. 매수/매도 신호를 계산하여 가이드를 제공하며, '
            '실제 주문은 사용자가 직접 증권사에서 실행합니다.',
      ),
      _LegalSection(
        title: '2. 투자 위험 고지',
        content:
            '⚠️ 중요: 이 앱은 투자 조언을 제공하지 않습니다.\n\n'
            '• 레버리지 ETF는 높은 변동성과 원금 손실 위험이 있습니다\n'
            '• 앱이 제공하는 신호와 계산은 참고용이며, 투자 판단의 근거가 아닙니다\n'
            '• 투자 손실에 대한 책임은 전적으로 사용자에게 있습니다\n'
            '• 과거 수익률이 미래 수익을 보장하지 않습니다',
      ),
      _LegalSection(
        title: '3. 데이터 정확성',
        content:
            '실시간 시세, 환율, 지표 데이터는 외부 API에서 제공되며, '
            '지연, 오류, 또는 일시적 불일치가 발생할 수 있습니다.\n\n'
            '데이터의 정확성을 보장하지 않으며, 중요한 투자 결정 시 '
            '증권사의 공식 데이터를 반드시 확인하시기 바랍니다.',
      ),
      _LegalSection(
        title: '4. 서비스 변경 및 중단',
        content:
            '앱의 기능은 사전 고지 없이 변경, 추가, 또는 제거될 수 있습니다. '
            '외부 API 서비스의 변경이나 중단으로 인해 일부 기능이 '
            '제한될 수 있으며, 이에 대한 책임을 지지 않습니다.',
      ),
      _LegalSection(
        title: '5. 면책 조항',
        content:
            '${AppConstants.appName}은 앱 사용으로 인해 발생하는 '
            '직접적, 간접적, 부수적, 특별, 결과적 손해에 대해 '
            '어떠한 책임도 지지 않습니다.',
      ),
    ],
  );
}

// ═══════════════════════════════════════════════════════════════
// 공통 레이아웃
// ═══════════════════════════════════════════════════════════════

void _showLegalSheet({
  required BuildContext context,
  required String title,
  required String lastUpdated,
  required List<_LegalSection> sections,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useRootNavigator: true,
    backgroundColor: Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF161B22)
        : Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (context) => DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) => Column(
        children: [
          // 핸들바
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: context.appTextHint.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // 타이틀
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: context.appTextPrimary,
                  ),
                ),
                const Spacer(),
                Text(
                  '최종 수정: $lastUpdated',
                  style: TextStyle(
                    fontSize: 11,
                    color: context.appTextHint,
                  ),
                ),
              ],
            ),
          ),
          Divider(color: context.appDivider, height: 1),
          // 본문
          Expanded(
            child: ListView.builder(
              controller: scrollController,
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
              itemCount: sections.length,
              itemBuilder: (context, index) {
                final section = sections[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        section.title,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: context.appTextPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        section.content,
                        style: TextStyle(
                          fontSize: 13,
                          color: context.appTextSecondary,
                          height: 1.6,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    ),
  );
}

class _LegalSection {
  final String title;
  final String content;
  const _LegalSection({required this.title, required this.content});
}
