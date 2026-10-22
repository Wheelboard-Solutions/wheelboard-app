/// Referral programme rates + calculator for Service Providers.
///
/// Rates come from GET /referral-program/settings (admin-editable). The
/// calculation mirrors the backend `calculateReferralEarnings` so the
/// calculator updates instantly as the user drags the sliders.
class ReferralRates {
  final double onboardingBonus;
  final double commissionPercent;
  final int tierThreshold;
  final double tierBonus;
  final int defaultJobsPerMonth;
  final double defaultTicketValue;

  const ReferralRates({
    required this.onboardingBonus,
    required this.commissionPercent,
    required this.tierThreshold,
    required this.tierBonus,
    required this.defaultJobsPerMonth,
    required this.defaultTicketValue,
  });

  /// Defaults from the referral programme sheet; used until settings load.
  static const defaults = ReferralRates(
    onboardingBonus: 150,
    commissionPercent: 2,
    tierThreshold: 5,
    tierBonus: 500,
    defaultJobsPerMonth: 25,
    defaultTicketValue: 1500,
  );

  factory ReferralRates.fromJson(Map<String, dynamic> j) {
    double d(String k, double f) => (j[k] as num?)?.toDouble() ?? f;
    int i(String k, int f) => (j[k] as num?)?.toInt() ?? f;
    return ReferralRates(
      onboardingBonus: d('onboardingBonus', defaults.onboardingBonus),
      commissionPercent: d('commissionPercent', defaults.commissionPercent),
      tierThreshold: i('tierThreshold', defaults.tierThreshold),
      tierBonus: d('tierBonus', defaults.tierBonus),
      defaultJobsPerMonth: i('defaultJobsPerMonth', defaults.defaultJobsPerMonth),
      defaultTicketValue: d('defaultTicketValue', defaults.defaultTicketValue),
    );
  }
}

class ReferralMonth {
  final int month;
  final double onboarding;
  final double recurring;
  final double tierBonus;
  final double total;
  final double cumulative;

  const ReferralMonth(this.month, this.onboarding, this.recurring,
      this.tierBonus, this.total, this.cumulative);
}

class ReferralProjection {
  final double onboardingTotal;
  final double monthlyGrossRevenue;
  final double recurringMonthly;
  final double tierBonusTotal;
  final double firstMonthTotal;
  final double annualTotal;
  final List<ReferralMonth> schedule;

  const ReferralProjection({
    required this.onboardingTotal,
    required this.monthlyGrossRevenue,
    required this.recurringMonthly,
    required this.tierBonusTotal,
    required this.firstMonthTotal,
    required this.annualTotal,
    required this.schedule,
  });

  /// onboarding = partners × bonus; recurring = partners × jobs × ticket × %;
  /// tier bonus once partners ≥ threshold. Onboarding and tier bonus are paid
  /// in month 1; the commission repeats every month.
  factory ReferralProjection.calculate(
    ReferralRates r, {
    required int partners,
    required int jobsPerMonth,
    required double ticketValue,
  }) {
    final onboarding = partners * r.onboardingBonus;
    final gross = partners * jobsPerMonth * ticketValue;
    final recurring = gross * r.commissionPercent / 100;
    final tier = partners >= r.tierThreshold ? partners * r.tierBonus : 0.0;
    final schedule = <ReferralMonth>[];
    var cumulative = 0.0;
    for (var m = 1; m <= 12; m++) {
      final ob = m == 1 ? onboarding : 0.0;
      final tb = m == 1 ? tier : 0.0;
      final total = ob + recurring + tb;
      cumulative += total;
      schedule.add(ReferralMonth(m, ob, recurring, tb, total, cumulative));
    }
    return ReferralProjection(
      onboardingTotal: onboarding,
      monthlyGrossRevenue: gross,
      recurringMonthly: recurring,
      tierBonusTotal: tier,
      firstMonthTotal: onboarding + recurring + tier,
      annualTotal: onboarding + recurring * 12 + tier,
      schedule: schedule,
    );
  }
}

class ReferredPartner {
  final String partnerId;
  final String partnerName;
  final String onboardingDate;
  final String status;
  final int jobsThisMonth;
  final double onboardingFeeEarned;
  final double commission;
  final String payoutStatus;

  ReferredPartner.fromJson(Map<String, dynamic> j)
      : partnerId = j['partnerId']?.toString() ?? '',
        partnerName = j['partnerName']?.toString() ?? 'Partner',
        onboardingDate = j['onboardingDate']?.toString() ?? '',
        status = j['status']?.toString() ?? '',
        jobsThisMonth = (j['jobsThisMonth'] as num?)?.toInt() ?? 0,
        onboardingFeeEarned = (j['onboardingFeeEarned'] as num?)?.toDouble() ?? 0,
        commission = (j['commission'] as num?)?.toDouble() ?? 0,
        payoutStatus = j['payoutStatus']?.toString() ?? 'Pending';

  bool get isActive => status == 'Active';
}

class MyReferrals {
  final String code;
  final int referredPartners;
  final int activePartners;
  final int pendingVerification;
  final double onboardingEarned;
  final double commissionThisMonth;
  final double tierBonus;
  final int partnersToNextTier;
  final List<ReferredPartner> partners;

  MyReferrals.fromJson(Map<String, dynamic> j)
      : code = j['code']?.toString() ?? '',
        referredPartners = _int(j['summary'], 'referredPartners'),
        activePartners = _int(j['summary'], 'activePartners'),
        pendingVerification = _int(j['summary'], 'pendingVerification'),
        onboardingEarned = _dbl(j['summary'], 'onboardingEarned'),
        commissionThisMonth = _dbl(j['summary'], 'commissionThisMonth'),
        tierBonus = _dbl(j['summary'], 'tierBonus'),
        partnersToNextTier = _int(j['summary'], 'partnersToNextTier'),
        partners = ((j['partners'] as List?) ?? const [])
            .whereType<Map>()
            .map((e) => ReferredPartner.fromJson(Map<String, dynamic>.from(e)))
            .toList();

  static int _int(dynamic m, String k) =>
      m is Map ? (m[k] as num?)?.toInt() ?? 0 : 0;
  static double _dbl(dynamic m, String k) =>
      m is Map ? (m[k] as num?)?.toDouble() ?? 0 : 0;
}
