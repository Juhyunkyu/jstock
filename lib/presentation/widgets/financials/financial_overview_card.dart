import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/financial_data.dart';

/// 기업 개요 카드 (섹션 1)
///
/// FMP /profile 데이터를 기반으로 기업 로고, 이름, 섹터/산업,
/// 시가총액, CEO, 직원수, IPO 일자, 기업 설명을 표시한다.
class FinancialOverviewCard extends StatefulWidget {
  final CompanyProfile profile;

  const FinancialOverviewCard({super.key, required this.profile});

  @override
  State<FinancialOverviewCard> createState() => _FinancialOverviewCardState();
}

class _FinancialOverviewCardState extends State<FinancialOverviewCard> {
  bool _isDescriptionExpanded = false;

  CompanyProfile get profile => widget.profile;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.appSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.appBorder.withValues(alpha: 0.5)),
        boxShadow: context.appCardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 상단: 로고 + 회사명 + 섹터/산업
          _buildHeader(context),
          Divider(height: 1, color: context.appDivider),
          // 2x2 그리드: 시가총액 / CEO / 직원수 / IPO
          _buildInfoGrid(context),
          // 기업 설명
          if (profile.description != null &&
              profile.description!.isNotEmpty) ...[
            Divider(height: 1, color: context.appDivider),
            _buildDescription(context),
          ],
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          // 로고
          _buildLogo(context),
          const SizedBox(width: 12),
          // 회사명 + 섹터 > 산업
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  profile.companyName,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: context.appTextPrimary,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (profile.sector != null || profile.industry != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    _buildSectorIndustry(),
                    style: TextStyle(
                      fontSize: 12,
                      color: context.appTextSecondary,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogo(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: profile.image != null && profile.image!.isNotEmpty
          ? Image.network(
              profile.image!,
              width: 48,
              height: 48,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => _buildFallbackIcon(context),
            )
          : _buildFallbackIcon(context),
    );
  }

  Widget _buildFallbackIcon(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: context.appIconBg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(
        Icons.business_rounded,
        size: 24,
        color: context.appTextHint,
      ),
    );
  }

  String _buildSectorIndustry() {
    final parts = <String>[];
    if (profile.sector != null && profile.sector!.isNotEmpty) {
      parts.add(profile.sector!);
    }
    if (profile.industry != null && profile.industry!.isNotEmpty) {
      parts.add(profile.industry!);
    }
    return parts.join(' > ');
  }

  Widget _buildInfoGrid(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _buildInfoItem(
                  context,
                  label: '시가총액',
                  value: _formatMarketCap(profile.mktCap),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildInfoItem(
                  context,
                  label: 'CEO',
                  value: profile.ceo ?? '-',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildInfoItem(
                  context,
                  label: '직원수',
                  value: _formatEmployees(profile.fullTimeEmployees),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildInfoItem(
                  context,
                  label: 'IPO',
                  value: _formatIpoDate(profile.ipoDate),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoItem(
    BuildContext context, {
    required String label,
    required String value,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: context.appTextHint,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: context.appTextPrimary,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _buildDescription(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AnimatedCrossFade(
            firstChild: Text(
              profile.description!,
              style: TextStyle(
                fontSize: 12,
                color: context.appTextHint,
                height: 1.5,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            secondChild: Text(
              profile.description!,
              style: TextStyle(
                fontSize: 12,
                color: context.appTextHint,
                height: 1.5,
              ),
            ),
            crossFadeState: _isDescriptionExpanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 200),
          ),
          const SizedBox(height: 4),
          GestureDetector(
            onTap: () {
              setState(() {
                _isDescriptionExpanded = !_isDescriptionExpanded;
              });
            },
            child: Text(
              _isDescriptionExpanded ? '접기' : '더 보기',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: context.appAccent,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 시가총액 포맷: $1.23T / $892B / $450M
  static String _formatMarketCap(double? value) {
    if (value == null) return '-';
    if (value >= 1e12) {
      return '\$${(value / 1e12).toStringAsFixed(2)}T';
    } else if (value >= 1e9) {
      return '\$${(value / 1e9).toStringAsFixed(0)}B';
    } else if (value >= 1e6) {
      return '\$${(value / 1e6).toStringAsFixed(0)}M';
    }
    return '\$${value.toStringAsFixed(0)}';
  }

  /// 직원수 포맷: 164,000명
  static String _formatEmployees(String? value) {
    if (value == null || value.isEmpty) return '-';
    final num = int.tryParse(value.replaceAll(',', ''));
    if (num == null) return value;
    // 천 단위 콤마 포맷
    final formatted = num.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]},',
    );
    return '$formatted명';
  }

  /// IPO 날짜 포맷: 1980.12.12
  static String _formatIpoDate(String? value) {
    if (value == null || value.isEmpty) return '-';
    // yyyy-MM-dd → yyyy.MM.dd
    return value.replaceAll('-', '.');
  }
}
