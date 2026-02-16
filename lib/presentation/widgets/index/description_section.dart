import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

/// 지수/종목 소개 섹션 (확장/축소 가능)
class DescriptionSection extends StatefulWidget {
  final String symbol;
  final String name;

  const DescriptionSection({
    super.key,
    required this.symbol,
    required this.name,
  });

  @override
  State<DescriptionSection> createState() => _DescriptionSectionState();
}

class _DescriptionSectionState extends State<DescriptionSection> {
  bool _isDescExpanded = false;

  @override
  Widget build(BuildContext context) {
    final descriptions = {
      'NASDAQ 100': '''나스닥 100 지수(NASDAQ-100)는 나스닥 증권거래소에 상장된 비금융 기업 중 시가총액 상위 100개 기업으로 구성된 주가지수입니다.

• 1985년 1월 31일 시작
• 기술, 소비재, 헬스케어 등 다양한 섹터 포함
• Apple, Microsoft, NVIDIA, Amazon, Google 등 빅테크 기업 포함
• 금융 기업은 제외됨
• 시가총액 가중 방식으로 계산''',
      'S&P 500': '''S&P 500 지수는 미국 증권거래소에 상장된 시가총액 상위 500개 대형 기업으로 구성된 주가지수입니다.

• 1957년 시작, 미국 주식시장의 벤치마크
• 미국 주식시장 시가총액의 약 80% 커버
• 11개 섹터(기술, 금융, 헬스케어 등) 포함
• 분기별 리밸런싱
• 시가총액 가중 방식으로 계산''',
      'NVIDIA Corporation': '''NVIDIA(엔비디아)는 미국의 반도체 기업으로, GPU(그래픽처리장치) 및 AI 컴퓨팅 분야의 세계적 선두 기업입니다.

• 1993년 설립, 본사: 캘리포니아 산타클라라
• 2024-2025년 AI 열풍으로 시가총액 세계 1위 달성
• 주요 제품: GeForce(게이밍), Quadro(전문가용), Tesla/H100/B200(AI/데이터센터)
• AI 학습 및 추론용 GPU 시장 점유율 80% 이상
• CUDA 플랫폼으로 AI/ML 생태계 구축''',
      'Apple Inc.': '''Apple(애플)은 아이폰, 맥, 아이패드 등을 제조하는 미국의 기술 기업입니다.

• 1976년 스티브 잡스, 스티브 워즈니악이 설립
• 본사: 캘리포니아 쿠퍼티노
• 주요 제품: iPhone, Mac, iPad, Apple Watch, AirPods
• 서비스: App Store, Apple Music, iCloud, Apple TV+
• 시가총액 기준 세계 최대 기업 중 하나''',
      'Tesla, Inc.': '''Tesla(테슬라)는 전기차 및 청정에너지 기업으로, 일론 머스크가 이끌고 있습니다.

• 2003년 설립, 본사: 텍사스 오스틴
• 세계 최대 전기차 제조사
• 주요 제품: Model S, 3, X, Y, Cybertruck
• 에너지 사업: Powerwall, Megapack, Solar Roof
• 자율주행 기술(FSD) 개발 중''',
      'Microsoft Corporation': '''Microsoft(마이크로소프트)는 소프트웨어, 클라우드, AI 분야의 글로벌 기술 기업입니다.

• 1975년 빌 게이츠, 폴 앨런이 설립
• 본사: 워싱턴주 레드먼드
• 주요 제품: Windows, Office 365, Azure 클라우드
• OpenAI에 대규모 투자, Copilot AI 서비스 확대
• LinkedIn, GitHub, Activision Blizzard 인수''',
      'Alphabet Inc.': '''Alphabet(알파벳)은 Google의 모회사로, 검색, 광고, 클라우드, AI 분야의 선도 기업입니다.

• 2015년 구글 기업 구조조정으로 설립
• 본사: 캘리포니아 마운틴뷰
• 자회사: Google, YouTube, Waymo, DeepMind
• 주요 서비스: Google Search, Gmail, Google Cloud, Android
• AI 모델 Gemini 개발''',
      'Amazon.com, Inc.': '''Amazon(아마존)은 세계 최대 전자상거래 및 클라우드 컴퓨팅 기업입니다.

• 1994년 제프 베이조스가 설립
• 본사: 워싱턴주 시애틀
• 사업 영역: 전자상거래, AWS 클라우드, 프라임 비디오
• AWS는 세계 1위 클라우드 서비스
• Alexa AI 음성비서, Ring 스마트홈 기기''',
      'Meta Platforms, Inc.': '''Meta(메타)는 Facebook, Instagram, WhatsApp을 운영하는 소셜미디어 기업입니다.

• 2004년 마크 저커버그가 Facebook으로 설립
• 2021년 Meta로 사명 변경
• 본사: 캘리포니아 멘로파크
• 주요 서비스: Facebook, Instagram, WhatsApp, Messenger
• Reality Labs에서 VR/AR 기기 개발 (Quest)''',
    };

    final symbolDescriptions = {
      'NVDA': descriptions['NVIDIA Corporation'],
      'AAPL': descriptions['Apple Inc.'],
      'TSLA': descriptions['Tesla, Inc.'],
      'MSFT': descriptions['Microsoft Corporation'],
      'GOOGL': descriptions['Alphabet Inc.'],
      'GOOG': descriptions['Alphabet Inc.'],
      'AMZN': descriptions['Amazon.com, Inc.'],
      'META': descriptions['Meta Platforms, Inc.'],
      '^NDX': descriptions['NASDAQ 100'],
      '^GSPC': descriptions['S&P 500'],
    };

    String? description = descriptions[widget.name] ?? symbolDescriptions[widget.symbol];

    return Container(
      color: context.appSurface,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () => setState(() => _isDescExpanded = !_isDescExpanded),
            child: Row(
              children: [
                Text('소개', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: context.appTextPrimary)),
                const Spacer(),
                Icon(_isDescExpanded ? Icons.expand_less : Icons.expand_more, size: 20, color: context.appTextHint),
              ],
            ),
          ),
          const SizedBox(height: 6),
          AnimatedCrossFade(
            firstChild: Text(
              description ?? '${widget.name}에 대한 정보가 없습니다.',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 13, color: context.appTextSecondary, height: 1.6),
            ),
            secondChild: Text(
              description ?? '${widget.name}에 대한 정보가 없습니다.',
              style: TextStyle(fontSize: 13, color: context.appTextSecondary, height: 1.6),
            ),
            crossFadeState: _isDescExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 200),
          ),
        ],
      ),
    );
  }
}
