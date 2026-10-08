import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';

import '../../../controllers/Professional/earning_summary_controller.dart';
import '../../../theme/design_system.dart';
import '../../../utils/format_utils.dart';
import '../widgets/calendar_header_widget.dart';
import '../widgets/earning_stat_card_widget.dart';
import '../widgets/transaction_item_widget.dart';

/// Earning Summary — real data from `GET /trips/professional/stats` (web parity),
/// brand design system. Stats, month-over-month, earnings chart, transactions.
class EarningSummaryScreen extends StatelessWidget {
  const EarningSummaryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(EarningSummaryController());

    return Scaffold(
      backgroundColor: AppPalette.bg,
      body: SafeArea(
        child: Column(
          children: [
            const CalendarHeaderWidget(
                title: 'Earning Summary', showMenu: false),
            Expanded(
              child: Obx(() {
                if (controller.isLoading.value &&
                    controller.transactions.isEmpty) {
                  return const AppLoading(message: 'Loading earnings…');
                }
                if (controller.hasError.value &&
                    controller.transactions.isEmpty) {
                  return AppErrorState(
                    message: controller.errorMessage.value.isEmpty
                        ? 'Failed to load earnings'
                        : controller.errorMessage.value,
                    onRetry: controller.fetchEarningsData,
                  );
                }
                return RefreshIndicator(
                  color: AppPalette.primary,
                  onRefresh: controller.fetchEarningsData,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    children: [
                      _stats(controller),
                      AppSpacing.vGapLg,
                      _monthCompare(controller),
                      AppSpacing.vGapXl,
                      Text('Earnings Over Time', style: AppText.h3),
                      AppSpacing.vGapMd,
                      _chart(controller),
                      AppSpacing.vGapXl,
                      Text('Transaction History', style: AppText.h3),
                      AppSpacing.vGapMd,
                      _transactions(controller),
                      const SizedBox(height: AppSpacing.xl),
                    ],
                  ),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }

  Widget _stats(EarningSummaryController c) {
    return Column(children: [
      Row(children: [
        Expanded(
          child: EarningStatCardWidget(
            icon: Iconsax.wallet_3,
            value: FormatUtils.formatAmount(c.totalIncome.value),
            label: 'Total income',
            iconColor: AppPalette.green,
          ),
        ),
        AppSpacing.hGapMd,
        Expanded(
          child: EarningStatCardWidget(
            icon: Iconsax.truck,
            value: c.tripsCompleted.value.toString(),
            label: 'Trips completed',
            iconColor: AppPalette.blue,
          ),
        ),
      ]),
      AppSpacing.vGapMd,
      Row(children: [
        Expanded(
          child: EarningStatCardWidget(
            icon: Iconsax.trend_up,
            value: FormatUtils.formatAmount(c.avgEarningPerTrip.value),
            label: 'Avg. / trip',
            iconColor: AppPalette.primary,
          ),
        ),
        AppSpacing.hGapMd,
        Expanded(
          child: EarningStatCardWidget(
            icon: Iconsax.clock,
            value: FormatUtils.formatAmount(c.pendingAmount.value),
            label: 'Pending amount',
            iconColor: AppPalette.amber,
          ),
        ),
      ]),
    ]);
  }

  Widget _monthCompare(EarningSummaryController c) {
    final pct = c.percentageChange.value;
    final up = pct >= 0;
    return AppCard(
      child: Row(children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('This Month', style: AppText.caption),
              const SizedBox(height: 2),
              Text(FormatUtils.formatAmount(c.thisMonthEarnings.value),
                  style: AppText.h2),
            ],
          ),
        ),
        Container(width: 1, height: 36, color: AppPalette.border),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(left: AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Last Month', style: AppText.caption),
                const SizedBox(height: 2),
                Text(FormatUtils.formatAmount(c.lastMonthEarnings.value),
                    style: AppText.h3.on(AppPalette.textMid)),
              ],
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: (up ? AppPalette.green : AppPalette.danger)
                .withValues(alpha: 0.12),
            borderRadius: AppRadius.rPill,
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(up ? Iconsax.arrow_up_3 : Iconsax.arrow_down,
                size: 13, color: up ? AppPalette.green : AppPalette.danger),
            const SizedBox(width: 3),
            Text('${up ? '+' : ''}${pct.toStringAsFixed(0)}%',
                style: AppText.micro
                    .on(up ? AppPalette.green : AppPalette.danger)
                    .weight(FontWeight.w700)),
          ]),
        ),
      ]),
    );
  }

  Widget _chart(EarningSummaryController c) {
    return Container(
      height: 200,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppPalette.card,
        borderRadius: AppRadius.rXl,
        border: Border.all(color: AppPalette.border),
      ),
      child: c.earningsChart.isEmpty
          ? const Center(
              child: AppEmptyState(
                  icon: Iconsax.chart_2, title: 'No data available'))
          : Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: c.earningsChart.map((e) {
                final maxAmount = c.earningsChart
                    .map((it) => (it['amount'] as num).toDouble())
                    .fold<double>(0, (a, b) => a > b ? a : b);
                final factor =
                    maxAmount > 0 ? (e['amount'] as num).toDouble() / maxAmount : 0.0;
                return Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Container(
                      width: 28,
                      height: 140 * factor,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [AppPalette.primary, AppPalette.primaryDark],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                        borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(6)),
                      ),
                    ),
                    AppSpacing.vGapSm,
                    Text('${e['month']}', style: AppText.micro.size(10)),
                  ],
                );
              }).toList(),
            ),
    );
  }

  Widget _transactions(EarningSummaryController c) {
    if (c.transactions.isEmpty) {
      return const AppEmptyState(
        icon: Iconsax.receipt_2,
        title: 'No transactions yet',
        subtitle: 'Completed-trip earnings will show up here.',
      );
    }
    return ListView.separated(
      shrinkWrap: true,
      padding: EdgeInsets.zero,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: c.transactions.length,
      separatorBuilder: (_, __) => AppSpacing.vGapSm,
      itemBuilder: (_, i) {
        final t = c.transactions[i];
        final from = t['from']?.toString();
        final to = t['to']?.toString();
        final label = (from != null && from.isNotEmpty && to != null && to.isNotEmpty)
            ? '$from → $to'
            : (t['description']?.toString() ?? 'Trip earning');
        return TransactionItemWidget(
          date: FormatUtils.formatDate(t['date'], format: 'dd MMM yyyy'),
          companyName: label,
          amount: FormatUtils.formatAmount(t['amount']),
          isCredit: (t['type']?.toString() ?? 'credit') != 'debit',
        );
      },
    );
  }
}
