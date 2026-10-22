import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';

import '../../../models/referral_program_model.dart';
import '../../../services/referral_program_service.dart';
import '../../../theme/app_palette.dart';
import '../../../utils/share_service.dart';
import '../../../widgets/custom_snackbar.dart';

/// Refer & Earn for Service Providers: an earnings calculator driven by the
/// admin-set rates, the partner's own referral code, and partners they
/// brought in with what each has earned them.
class SpReferralScreen extends StatefulWidget {
  const SpReferralScreen({super.key});

  @override
  State<SpReferralScreen> createState() => _SpReferralScreenState();
}

class _SpReferralScreenState extends State<SpReferralScreen>
    with SingleTickerProviderStateMixin {
  final _service = ReferralProgramService();
  late final TabController _tabs = TabController(length: 2, vsync: this);

  ReferralRates _rates = ReferralRates.defaults;
  MyReferrals? _mine;
  Map<String, dynamic>? _referredBy;
  bool _loading = true;
  String? _error;

  int _partners = 5;
  int _jobs = ReferralRates.defaults.defaultJobsPerMonth;
  double _ticket = ReferralRates.defaults.defaultTicketValue;

  final _codeCtrl = TextEditingController();
  bool _applying = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _tabs.dispose();
    _codeCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        _service.getRates(),
        _service.getMyReferrals(),
        _service.getReferredBy(),
      ]);
      if (!mounted) return;
      setState(() {
        _rates = results[0] as ReferralRates;
        _mine = results[1] as MyReferrals;
        _referredBy = results[2] as Map<String, dynamic>;
        _jobs = _rates.defaultJobsPerMonth;
        _ticket = _rates.defaultTicketValue;
      });
    } catch (e) {
      if (mounted) setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _applyCode() async {
    final code = _codeCtrl.text.trim();
    if (code.length < 4) {
      SnackBarHelper.error('Enter a valid referral code');
      return;
    }
    setState(() => _applying = true);
    try {
      await _service.applyCode(code);
      SnackBarHelper.success('Referral code applied');
      _codeCtrl.clear();
      await _load();
    } catch (e) {
      SnackBarHelper.error(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _applying = false);
    }
  }

  void _shareCode(String code) {
    ShareService.shareGeneric(
      title: 'Join me on WheelBoard',
      content:
          'List your garage on WheelBoard and get service jobs from fleet owners near you. '
          'Use my referral code $code when you sign up.',
    );
  }

  // ── build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppPalette.bg,
      appBar: AppBar(
        backgroundColor: AppPalette.card,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: AppPalette.primary, size: 20),
          onPressed: () => Get.back()),
        centerTitle: true,
        title: Text('Refer & Earn', style: GoogleFonts.poppins(
          fontSize: 17, fontWeight: FontWeight.w600, color: AppPalette.textDark)),
        bottom: TabBar(
          controller: _tabs,
          labelColor: AppPalette.primary,
          unselectedLabelColor: AppPalette.textGrey,
          indicatorColor: AppPalette.primary,
          labelStyle: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600),
          tabs: const [Tab(text: 'Calculator'), Tab(text: 'My Referrals')],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppPalette.primary))
          : TabBarView(controller: _tabs, children: [
              _calculatorTab(),
              _referralsTab(),
            ]),
    );
  }

  // ── calculator ───────────────────────────────────────────────────────────
  Widget _calculatorTab() {
    final p = ReferralProjection.calculate(_rates,
        partners: _partners, jobsPerMonth: _jobs, ticketValue: _ticket);
    final toTier = _rates.tierThreshold - _partners;
    return ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 40), children: [
      _heroCard(p),
      const SizedBox(height: 14),
      _card(title: 'Your network', icon: Iconsax.people, child: Column(children: [
        _slider('Partners you refer', '$_partners', _partners.toDouble(), 0, 50, 50,
            (v) => setState(() => _partners = v.round())),
        _slider('Jobs per partner / month', '$_jobs', _jobs.toDouble(), 1, 100, 99,
            (v) => setState(() => _jobs = v.round())),
        _slider('Average job value', _inr(_ticket), _ticket, 200, 10000, 98,
            (v) => setState(() => _ticket = (v / 100).round() * 100.0)),
      ])),
      const SizedBox(height: 14),
      _card(title: 'How you earn', icon: Iconsax.money_recive, child: Column(children: [
        _row('Onboarding bonus (once verified)', '${_inr(_rates.onboardingBonus)} / partner'),
        _row('Commission', '${_pct(_rates.commissionPercent)} of job value'),
        _row('Tier bonus', '${_inr(_rates.tierBonus)} each at ${_rates.tierThreshold}+'),
        if (toTier > 0)
          _note('Refer $toTier more to unlock the tier bonus.'),
      ])),
      const SizedBox(height: 14),
      _card(title: 'Breakdown', icon: Iconsax.chart_2, child: Column(children: [
        _row('Onboarding (one-time)', _inr(p.onboardingTotal)),
        _row('Network job value / month', _inr(p.monthlyGrossRevenue)),
        _row('Commission / month', _inr(p.recurringMonthly)),
        _row('Tier bonus (one-time)', _inr(p.tierBonusTotal)),
        const Divider(color: AppPalette.border, height: 20),
        _row('First month', _inr(p.firstMonthTotal), bold: true),
        _row('12 months', _inr(p.annualTotal), bold: true),
      ])),
      const SizedBox(height: 14),
      _card(title: '12-month schedule', icon: Iconsax.calendar_1, child: _scheduleTable(p)),
      const SizedBox(height: 10),
      Text('Estimates only. Earnings depend on partners getting verified and completing jobs.',
        textAlign: TextAlign.center,
        style: GoogleFonts.poppins(fontSize: 11, color: AppPalette.textFaint)),
    ]);
  }

  Widget _heroCard(ReferralProjection p) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF7C3AED), Color(0xFF6D28D9)],
          begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(16)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('You could earn in 12 months', style: GoogleFonts.poppins(
          fontSize: 12, color: Colors.white.withValues(alpha: 0.85))),
        const SizedBox(height: 4),
        Text(_inr(p.annualTotal), style: GoogleFonts.poppins(
          fontSize: 30, fontWeight: FontWeight.w700, color: Colors.white)),
        const SizedBox(height: 10),
        Row(children: [
          _heroStat('First month', _inr(p.firstMonthTotal)),
          const SizedBox(width: 12),
          _heroStat('Every month after', _inr(p.recurringMonthly)),
        ]),
      ]),
    );
  }

  Widget _heroStat(String label, String value) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: GoogleFonts.poppins(fontSize: 11, color: Colors.white70)),
        Text(value, style: GoogleFonts.poppins(
          fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
      ]),
    ));

  Widget _scheduleTable(ReferralProjection p) {
    TextStyle h = GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: AppPalette.textGrey);
    TextStyle c = GoogleFonts.poppins(fontSize: 12, color: AppPalette.textDark);
    Widget cell(String t, TextStyle s, {TextAlign a = TextAlign.right}) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 6), child: Text(t, style: s, textAlign: a));
    return Table(
      columnWidths: const {0: FlexColumnWidth(0.8), 1: FlexColumnWidth(1.3), 2: FlexColumnWidth(1.3), 3: FlexColumnWidth(1.4)},
      children: [
        TableRow(children: [
          cell('Month', h, a: TextAlign.left), cell('Bonus', h), cell('Commission', h), cell('Total', h),
        ]),
        for (final m in p.schedule)
          TableRow(children: [
            cell('${m.month}', c, a: TextAlign.left),
            cell(_inr(m.onboarding + m.tierBonus), c),
            cell(_inr(m.recurring), c),
            cell(_inr(m.cumulative), c.copyWith(fontWeight: FontWeight.w600)),
          ]),
      ],
    );
  }

  // ── my referrals ─────────────────────────────────────────────────────────
  Widget _referralsTab() {
    if (_error != null || _mine == null) {
      return Center(child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Iconsax.warning_2, color: AppPalette.danger, size: 32),
          const SizedBox(height: 10),
          Text(_error ?? 'Could not load referrals', textAlign: TextAlign.center,
            style: GoogleFonts.poppins(fontSize: 13, color: AppPalette.textGrey)),
          const SizedBox(height: 12),
          TextButton(onPressed: _load, child: const Text('Retry')),
        ]),
      ));
    }
    final m = _mine!;
    return RefreshIndicator(
      color: AppPalette.primary,
      onRefresh: _load,
      child: ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 40), children: [
        _codeCard(m.code),
        const SizedBox(height: 14),
        Row(children: [
          _statTile('Referred', '${m.referredPartners}', Iconsax.people, AppPalette.blue, AppPalette.blueBg),
          const SizedBox(width: 10),
          _statTile('Active', '${m.activePartners}', Iconsax.tick_circle, AppPalette.green, AppPalette.greenBg),
          const SizedBox(width: 10),
          _statTile('Pending', '${m.pendingVerification}', Iconsax.timer_1, AppPalette.amber, AppPalette.amberBg),
        ]),
        const SizedBox(height: 14),
        _card(title: 'Your earnings', icon: Iconsax.wallet_3, child: Column(children: [
          _row('Onboarding bonuses', _inr(m.onboardingEarned)),
          _row('Commission this month', _inr(m.commissionThisMonth)),
          _row('Tier bonus', _inr(m.tierBonus)),
          if (m.partnersToNextTier > 0)
            _note('${m.partnersToNextTier} more active partner${m.partnersToNextTier == 1 ? '' : 's'} to unlock the tier bonus.'),
        ])),
        const SizedBox(height: 14),
        _card(title: 'Partners you referred', icon: Iconsax.shop, child: m.partners.isEmpty
            ? Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text('No partners yet. Share your code to get started.',
                  style: GoogleFonts.poppins(fontSize: 13, color: AppPalette.textGrey)))
            : Column(children: [for (final p in m.partners) _partnerTile(p)])),
        if (_referredBy != null && _referredBy!['referred'] != true) ...[
          const SizedBox(height: 14),
          _applyCodeCard(),
        ],
      ]),
    );
  }

  Widget _codeCard(String code) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppPalette.card, borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppPalette.border)),
      child: Column(children: [
        Text('Your referral code', style: GoogleFonts.poppins(fontSize: 12, color: AppPalette.textGrey)),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          decoration: BoxDecoration(
            color: AppPalette.primaryLight, borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppPalette.primary.withValues(alpha: 0.4))),
          child: SelectableText(code, style: GoogleFonts.poppins(
            fontSize: 24, fontWeight: FontWeight.w700, letterSpacing: 3, color: AppPalette.primary)),
        ),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: OutlinedButton.icon(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: code));
              SnackBarHelper.success('Code copied');
            },
            icon: const Icon(Iconsax.copy, size: 16),
            label: Text('Copy', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600)),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppPalette.primary, side: const BorderSide(color: AppPalette.primary),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
          )),
          const SizedBox(width: 10),
          Expanded(child: ElevatedButton.icon(
            onPressed: () => _shareCode(code),
            icon: const Icon(Iconsax.share, size: 16),
            label: Text('Share', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppPalette.primary, foregroundColor: Colors.white, elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
          )),
        ]),
        const SizedBox(height: 8),
        Text('Partners enter this code in Refer & Earn within 60 days of joining.',
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(fontSize: 11, color: AppPalette.textFaint)),
      ]),
    );
  }

  Widget _applyCodeCard() {
    return _card(title: 'Were you referred?', icon: Iconsax.ticket, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Enter the code of the partner who invited you.',
        style: GoogleFonts.poppins(fontSize: 12, color: AppPalette.textGrey)),
      const SizedBox(height: 10),
      Row(children: [
        Expanded(child: TextField(
          controller: _codeCtrl,
          textCapitalization: TextCapitalization.characters,
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp('[A-Za-z0-9]')),
            LengthLimitingTextInputFormatter(20),
          ],
          style: GoogleFonts.poppins(fontSize: 14, color: AppPalette.textDark, letterSpacing: 1.5),
          decoration: InputDecoration(
            hintText: 'e.g. WB7K2Q9M',
            hintStyle: GoogleFonts.poppins(fontSize: 13, color: AppPalette.textGrey),
            filled: true, fillColor: AppPalette.bg, isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            border: _ob(AppPalette.border), enabledBorder: _ob(AppPalette.border),
            focusedBorder: _ob(AppPalette.primary)),
        )),
        const SizedBox(width: 10),
        ElevatedButton(
          onPressed: _applying ? null : _applyCode,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppPalette.primary, foregroundColor: Colors.white, elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
          child: _applying
              ? const SizedBox(width: 16, height: 16,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : Text('Apply', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600)),
        ),
      ]),
    ]));
  }

  Widget _partnerTile(ReferredPartner p) {
    final color = p.isActive ? AppPalette.green : AppPalette.amber;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppPalette.bg, borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppPalette.border)),
      child: Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(p.partnerName, maxLines: 1, overflow: TextOverflow.ellipsis,
            style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: AppPalette.textDark)),
          Text('Joined ${p.onboardingDate} · ${p.jobsThisMonth} jobs this month',
            style: GoogleFonts.poppins(fontSize: 11, color: AppPalette.textGrey)),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
            child: Text(p.status, style: GoogleFonts.poppins(
              fontSize: 10, fontWeight: FontWeight.w600, color: color))),
        ])),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(_inr(p.onboardingFeeEarned + p.commission), style: GoogleFonts.poppins(
            fontSize: 14, fontWeight: FontWeight.w700, color: AppPalette.textDark)),
          Text(p.payoutStatus, style: GoogleFonts.poppins(fontSize: 11, color: AppPalette.textGrey)),
        ]),
      ]),
    );
  }

  // ── shared pieces ────────────────────────────────────────────────────────
  Widget _card({required String title, required IconData icon, required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppPalette.card, borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppPalette.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, size: 16, color: AppPalette.primary),
          const SizedBox(width: 8),
          Text(title, style: GoogleFonts.poppins(
            fontSize: 14, fontWeight: FontWeight.w700, color: AppPalette.textDark)),
        ]),
        const SizedBox(height: 12),
        child,
      ]),
    );
  }

  Widget _slider(String label, String value, double v, double min, double max,
      int divisions, ValueChanged<double> onChanged) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(child: Text(label, style: GoogleFonts.poppins(fontSize: 12, color: AppPalette.textGrey))),
        Text(value, style: GoogleFonts.poppins(
          fontSize: 14, fontWeight: FontWeight.w700, color: AppPalette.textDark)),
      ]),
      Slider(
        value: v.clamp(min, max), min: min, max: max, divisions: divisions,
        activeColor: AppPalette.primary, inactiveColor: AppPalette.primaryLight,
        onChanged: onChanged),
    ]);
  }

  Widget _row(String label, String value, {bool bold = false}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Expanded(flex: 3, child: Text(label, style: GoogleFonts.poppins(
        fontSize: 13, color: bold ? AppPalette.textDark : AppPalette.textGrey,
        fontWeight: bold ? FontWeight.w700 : FontWeight.w400))),
      const SizedBox(width: 12),
      Expanded(flex: 2, child: Text(value, textAlign: TextAlign.right, style: GoogleFonts.poppins(
        fontSize: 13, fontWeight: bold ? FontWeight.w700 : FontWeight.w600, color: AppPalette.textDark))),
    ]));

  Widget _note(String text) => Container(
    margin: const EdgeInsets.only(top: 8),
    padding: const EdgeInsets.all(10),
    width: double.infinity,
    decoration: BoxDecoration(color: AppPalette.amberBg, borderRadius: BorderRadius.circular(10)),
    child: Text(text, style: GoogleFonts.poppins(fontSize: 12, color: const Color(0xFF92400E))));

  Widget _statTile(String label, String value, IconData icon, Color color, Color bg) => Expanded(
    child: Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(14)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(height: 6),
        Text(value, style: GoogleFonts.poppins(
          fontSize: 18, fontWeight: FontWeight.w700, color: AppPalette.textDark)),
        Text(label, style: GoogleFonts.poppins(fontSize: 11, color: AppPalette.textGrey)),
      ]),
    ));

  OutlineInputBorder _ob(Color c) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: c));

  static String _pct(double v) =>
      '${v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString()}%';

  /// ₹ with Indian digit grouping (12,34,567).
  static String _inr(double v) {
    final n = v.round();
    final neg = n < 0;
    var s = n.abs().toString();
    if (s.length > 3) {
      final last3 = s.substring(s.length - 3);
      var rest = s.substring(0, s.length - 3);
      final parts = <String>[];
      while (rest.length > 2) {
        parts.insert(0, rest.substring(rest.length - 2));
        rest = rest.substring(0, rest.length - 2);
      }
      if (rest.isNotEmpty) parts.insert(0, rest);
      s = '${parts.join(',')},$last3';
    }
    return '${neg ? '-' : ''}₹$s';
  }
}
