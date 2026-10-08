import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';

import '../../../controllers/Professional/calendar_controller.dart';
import '../../../models/Professional/calendar_event_model.dart';
import '../../../theme/design_system.dart';
import '../CalendarMarkDate/CalendarMarkDateScreen.dart';

/// My Calendar — a modern port of the web `/professional/calendar` availability
/// board. Shows a month grid (active / inactive / has-events), this-month stats,
/// a legend, and the selected day's events. The professional marks days as
/// Available / Unavailable; that availability is what company-transport and
/// business users see when they view the professional.
class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  final CalendarController c = Get.put(CalendarController());

  static const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  static const _months = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December'
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppPalette.bg,
      appBar: AppBar(
        backgroundColor: AppPalette.card,
        elevation: 0.5,
        automaticallyImplyLeading: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              size: 20, color: AppPalette.textDark),
          onPressed: () => Get.back(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('My Calendar', style: AppText.h2),
            Text('Mark your availability for trips and jobs',
                style: AppText.caption.on(AppPalette.textGrey)),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.md),
            child: GestureDetector(
              onTap: _openMarkDate,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                    gradient: AppPalette.brandGradient,
                    borderRadius: AppRadius.rPill),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Iconsax.add, size: 16, color: Colors.white),
                  const SizedBox(width: 4),
                  Text('Mark Date',
                      style: AppText.label
                          .on(Colors.white)
                          .weight(FontWeight.w600)),
                ]),
              ),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        color: AppPalette.primary,
        onRefresh: c.fetchData,
        child: Obx(() {
          if (c.isLoading.value && c.events.isEmpty) {
            return ListView(children: const [
              SizedBox(height: 120),
              AppLoading(message: 'Loading calendar…'),
            ]);
          }
          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              _monthCard(),
              AppSpacing.vGapLg,
              _statsRow(),
              AppSpacing.vGapLg,
              _selectedEvents(),
              AppSpacing.vGapLg,
              _legend(),
              const SizedBox(height: 24),
            ],
          );
        }),
      ),
    );
  }

  // ── Month card ──────────────────────────────────────────────────────────────
  Widget _monthCard() {
    final month = c.currentMonth.value;
    final cells = _buildDays(month);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppPalette.card,
        borderRadius: AppRadius.rXl,
        border: Border.all(color: AppPalette.border),
      ),
      child: Column(children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _navBtn(Icons.chevron_left_rounded, c.goToPrevMonth),
            Column(children: [
              Text(_months[month.month - 1],
                  style: AppText.h2.on(AppPalette.textDark)),
              Text('${month.year}', style: AppText.caption),
            ]),
            _navBtn(Icons.chevron_right_rounded, c.goToNextMonth),
          ],
        ),
        AppSpacing.vGapMd,
        Row(
          children: _weekdays
              .map((d) => Expanded(
                    child: Center(
                      child: Text(d,
                          style: AppText.micro
                              .on(AppPalette.textGrey)
                              .weight(FontWeight.w600)),
                    ),
                  ))
              .toList(),
        ),
        const SizedBox(height: 6),
        GridView.builder(
          shrinkWrap: true,
          padding: EdgeInsets.zero,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: cells.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            mainAxisSpacing: 4,
            crossAxisSpacing: 4,
          ),
          itemBuilder: (_, i) => _dayCell(cells[i]),
        ),
      ]),
    );
  }

  Widget _navBtn(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          borderRadius: AppRadius.rMd,
          border: Border.all(color: AppPalette.border),
        ),
        child: Icon(icon, size: 22, color: AppPalette.textMid),
      ),
    );
  }

  Widget _dayCell(_DayCell cell) {
    final dayEvents = c.eventsForKey(cell.key);
    final hasEvent = dayEvents.isNotEmpty;
    final selected = c.selectedDateKey.value == cell.key;
    final active = c.isActiveDay(cell.key);
    final inactive = c.isInactiveDay(cell.key);

    Color? bg;
    Color textColor = AppPalette.textDark;
    if (!cell.inMonth) {
      textColor = AppPalette.textFaint;
    } else if (selected) {
      bg = AppPalette.primary;
      textColor = Colors.white;
    } else if (active) {
      bg = AppPalette.greenBg;
      textColor = AppPalette.green;
    } else if (inactive) {
      bg = AppPalette.bg;
      textColor = AppPalette.textGrey;
    }

    return GestureDetector(
      onTap: cell.inMonth ? () => c.selectDate(cell.key) : null,
      child: Container(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: AppRadius.rMd,
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Text('${cell.day}',
                style: AppText.bodySm
                    .on(textColor)
                    .weight(FontWeight.w600)),
            if (hasEvent && cell.inMonth)
              Positioned(
                bottom: 5,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(
                    dayEvents.length > 3 ? 3 : dayEvents.length,
                    (_) => Container(
                      width: 4,
                      height: 4,
                      margin: const EdgeInsets.symmetric(horizontal: 1),
                      decoration: BoxDecoration(
                        color: selected ? Colors.white : AppPalette.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ── Stats ───────────────────────────────────────────────────────────────────
  Widget _statsRow() {
    return Row(children: [
      Expanded(
        child: _statCard(
          icon: Iconsax.trend_up,
          iconColor: AppPalette.green,
          iconBg: AppPalette.greenBg,
          label: 'Active Days',
          value: '${c.totalActiveDays.value}',
          sub: '${c.thisMonthAvailability.value}% availability',
          valueColor: AppPalette.green,
        ),
      ),
      AppSpacing.hGapMd,
      Expanded(
        child: _statCard(
          icon: Iconsax.calendar_1,
          iconColor: AppPalette.textMid,
          iconBg: AppPalette.bg,
          label: 'Total Events',
          value: '${c.totalEventsScheduled.value}',
          valueColor: AppPalette.textDark,
        ),
      ),
    ]);
  }

  Widget _statCard({
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required String label,
    required String value,
    String? sub,
    required Color valueColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppPalette.card,
        borderRadius: AppRadius.rLg,
        border: Border.all(color: AppPalette.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 32,
            height: 32,
            decoration:
                BoxDecoration(color: iconBg, borderRadius: AppRadius.rSm),
            child: Icon(icon, size: 18, color: iconColor),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(label,
                style: AppText.caption.on(AppPalette.textGrey),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
          ),
        ]),
        const SizedBox(height: 8),
        Text(value, style: AppText.h1.on(valueColor)),
        if (sub != null)
          Text(sub, style: AppText.micro.on(AppPalette.textGrey)),
      ]),
    );
  }

  // ── Selected-date events ──────────────────────────────────────────────────
  Widget _selectedEvents() {
    final key = c.selectedDateKey.value;
    if (key.isEmpty) {
      return _emptyPanel('Select a date to view events', null);
    }
    final dayEvents = c.eventsForKey(key);
    if (dayEvents.isEmpty) {
      // No events: offer the core availability action right here.
      return Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: AppPalette.card,
          borderRadius: AppRadius.rXl,
          border: Border.all(color: AppPalette.border),
        ),
        child: Column(children: [
          const Icon(Iconsax.calendar_1, size: 44, color: AppPalette.textFaint),
          AppSpacing.vGapSm,
          Text('No events on ${_prettyKey(key)}',
              style: AppText.bodySm.on(AppPalette.textGrey)),
          AppSpacing.vGapMd,
          Row(children: [
            Expanded(
              child: Obx(() => AppPrimaryButton(
                    label: 'Mark Available',
                    icon: Iconsax.tick_circle,
                    color: AppPalette.green,
                    loading: c.isSaving.value,
                    onPressed: () => _markAvailability(key, true),
                  )),
            ),
            AppSpacing.hGapMd,
            Expanded(
              child: AppSecondaryButton(
                label: 'Unavailable',
                color: AppPalette.textMid,
                onPressed: () => _markAvailability(key, false),
              ),
            ),
          ]),
        ]),
      );
    }
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppPalette.card,
        borderRadius: AppRadius.rXl,
        border: Border.all(color: AppPalette.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Events on ${_prettyKey(key)}',
            style: AppText.title.on(AppPalette.textDark)),
        AppSpacing.vGapMd,
        ...dayEvents.map(_eventCard),
      ]),
    );
  }

  Widget _eventCard(CalendarEvent e) {
    final typeColor = e.isTrip
        ? const Color(0xFF3B82F6)
        : e.isJob
            ? const Color(0xFF14B8A6)
            : AppPalette.green;
    final statusColor = e.isActive
        ? AppPalette.green
        : e.isCancelled
            ? AppPalette.danger
            : AppPalette.textGrey;

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppPalette.bg,
        borderRadius: AppRadius.rLg,
        border: Border.all(color: AppPalette.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(e.title,
                      style: AppText.subtitle.on(AppPalette.textDark)),
                  const SizedBox(height: 4),
                  _pill(e.type, typeColor),
                ]),
          ),
          GestureDetector(
            onTap: () => _openMarkDate(event: e),
            child: const Padding(
              padding: EdgeInsets.all(4),
              child: Icon(Iconsax.edit, size: 18, color: AppPalette.textGrey),
            ),
          ),
          GestureDetector(
            onTap: () => _confirmDelete(e),
            child: const Padding(
              padding: EdgeInsets.all(4),
              child: Icon(Iconsax.trash, size: 18, color: AppPalette.danger),
            ),
          ),
        ]),
        const SizedBox(height: 8),
        if (e.metadata['from'] != null &&
            e.metadata['to'] != null &&
            '${e.metadata['from']}'.isNotEmpty)
          _metaRow(Iconsax.location,
              '${e.metadata['from']} → ${e.metadata['to']}'),
        _metaRow(
            Iconsax.clock,
            e.isAvailability
                ? 'All Day'
                : [e.startClock, e.endClock]
                    .where((t) => t.isNotEmpty)
                    .join(' - ')),
        if (e.description.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(e.description, style: AppText.caption.on(AppPalette.textGrey)),
        ],
        const SizedBox(height: 8),
        _pill(e.status, statusColor),
      ]),
    );
  }

  Widget _metaRow(IconData icon, String text) {
    if (text.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(children: [
        Icon(icon, size: 14, color: AppPalette.textGrey),
        const SizedBox(width: 6),
        Expanded(
            child: Text(text,
                style: AppText.caption.on(AppPalette.textMid),
                maxLines: 1,
                overflow: TextOverflow.ellipsis)),
      ]),
    );
  }

  Widget _pill(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: AppRadius.rPill,
      ),
      child: Text(text,
          style: AppText.micro.on(color).weight(FontWeight.w600)),
    );
  }

  Widget _emptyPanel(String msg, IconData? icon) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: AppPalette.card,
        borderRadius: AppRadius.rXl,
        border: Border.all(color: AppPalette.border),
      ),
      child: Column(children: [
        Icon(icon ?? Iconsax.calendar_1, size: 44, color: AppPalette.textFaint),
        AppSpacing.vGapSm,
        Text(msg, style: AppText.bodySm.on(AppPalette.textGrey)),
      ]),
    );
  }

  // ── Legend ──────────────────────────────────────────────────────────────────
  Widget _legend() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppPalette.card,
        borderRadius: AppRadius.rXl,
        border: Border.all(color: AppPalette.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Legend', style: AppText.subtitle.on(AppPalette.textDark)),
        AppSpacing.vGapSm,
        _legendRow(AppPalette.greenBg, AppPalette.green, 'Active Day'),
        _legendRow(AppPalette.bg, AppPalette.border, 'Inactive Day'),
        _legendDotRow('Has Events'),
      ]),
    );
  }

  Widget _legendRow(Color bg, Color border, String label) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(children: [
        Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
              color: bg,
              borderRadius: AppRadius.rSm,
              border: Border.all(color: border, width: 1.5)),
        ),
        const SizedBox(width: 10),
        Text(label, style: AppText.caption.on(AppPalette.textGrey)),
      ]),
    );
  }

  Widget _legendDotRow(String label) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(children: [
        Container(
          width: 22,
          height: 22,
          alignment: Alignment.bottomCenter,
          decoration: BoxDecoration(
              color: AppPalette.card,
              borderRadius: AppRadius.rSm,
              border: Border.all(color: AppPalette.border, width: 1.5)),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 3),
            child: Container(
              width: 4,
              height: 4,
              decoration: const BoxDecoration(
                  color: AppPalette.primary, shape: BoxShape.circle),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Text(label, style: AppText.caption.on(AppPalette.textGrey)),
      ]),
    );
  }

  // ── Actions ─────────────────────────────────────────────────────────────────
  Future<void> _markAvailability(String key, bool isActive) async {
    final date = DateTime.tryParse(key);
    if (date == null) return;
    await c.markAvailability(date, isActive);
  }

  void _openMarkDate({CalendarEvent? event}) {
    DateTime initial = DateTime.now();
    if (event != null) {
      initial = DateTime.tryParse(event.startDate)?.toLocal() ?? initial;
    } else if (c.selectedDateKey.value.isNotEmpty) {
      initial = DateTime.tryParse(c.selectedDateKey.value) ?? initial;
    }
    Get.to(() => CalendarMarkDateScreen(initialDate: initial, event: event))
        ?.then((_) => c.fetchData());
  }

  void _confirmDelete(CalendarEvent e) {
    Get.dialog(
      AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Delete event', style: AppText.title),
        content: Text('Are you sure you want to delete "${e.title}"?',
            style: AppText.bodySm),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: Text('Cancel', style: AppText.label.on(AppPalette.textGrey)),
          ),
          TextButton(
            onPressed: () {
              Get.back();
              c.deleteEvent(e.id);
            },
            child: Text('Delete', style: AppText.label.on(AppPalette.danger)),
          ),
        ],
      ),
    );
  }

  // ── Day grid builder ──────────────────────────────────────────────────────
  List<_DayCell> _buildDays(DateTime month) {
    final year = month.year;
    final m = month.month;
    final leading = DateTime(year, m, 1).weekday - 1; // Mon-first offset (0..6)
    final daysInMonth = DateTime(year, m + 1, 0).day;
    final prevMonthDays = DateTime(year, m, 0).day;

    final cells = <_DayCell>[];
    for (var i = leading - 1; i >= 0; i--) {
      final d = prevMonthDays - i;
      cells.add(_DayCell(
          day: d, inMonth: false, key: _key(DateTime(year, m - 1, d))));
    }
    for (var d = 1; d <= daysInMonth; d++) {
      cells.add(
          _DayCell(day: d, inMonth: true, key: _key(DateTime(year, m, d))));
    }
    var next = 1;
    while (cells.length < 42) {
      cells.add(_DayCell(
          day: next, inMonth: false, key: _key(DateTime(year, m + 1, next))));
      next++;
    }
    return cells;
  }

  String _key(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String _prettyKey(String key) {
    final d = DateTime.tryParse(key);
    if (d == null) return key;
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[d.month - 1]} ${d.day}';
  }
}

class _DayCell {
  final int day;
  final bool inMonth;
  final String key;
  const _DayCell({required this.day, required this.inMonth, required this.key});
}
