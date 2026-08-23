/// Premium display prices (Philippine Peso).
abstract final class AppPricing {
  static const currencySymbol = '₱';

  static const monthlyAmount = 199;
  static const yearlyAmount = 1499;
  static const freeTrialDays = 7;

  /// Free plan and 7-day trial share this AI quiz allotment.
  static const freeQuizLimit = 3;

  /// Effective monthly cost when billed yearly (1499 ÷ 12).
  static int get yearlyPerMonthAmount => (yearlyAmount / 12).round();

  static String get monthly => formatPeso(monthlyAmount);
  static String get yearly => formatPeso(yearlyAmount);
  static String get yearlyPerMonth => formatPeso(yearlyPerMonthAmount);

  static String get upgradeFromMonthly => 'Upgrade — from $monthly/mo';

  static String get yearlyPlanDetail => 'Renews yearly · $yearly/yr';

  static String get yearlyBilledSubtitle => '$yearly billed once a year';

  static String get freeTrialLabel =>
      '$freeTrialDays-day free trial · cancel anytime';

  static String get freeQuizLimitLabel =>
      '$freeQuizLimit AI quizzes during your $freeTrialDays-day trial';

  static String get yearlySaveBadge {
    final fullYear = monthlyAmount * 12;
    final pct = ((fullYear - yearlyAmount) / fullYear * 100).round();
    return 'SAVE $pct%';
  }

  static String continueLabel({required bool yearly}) =>
      yearly ? 'Continue — $yearly/yr' : 'Continue — $monthly/mo';

  static String formatPeso(int amount) {
    final s = amount.toString();
    if (s.length <= 3) return '$currencySymbol$s';
    final buf = StringBuffer(currencySymbol);
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return buf.toString();
  }

  static String formatAmount(num amount) {
    if (amount == amount.roundToDouble()) {
      return formatPeso(amount.round());
    }
    return '$currencySymbol${amount.toStringAsFixed(2)}';
  }

  /// Free & free-trial tier.
  static const freeStorageLabel = '5 GB storage';

  /// Paid premium benefits (section 12 / plan picker).
  static const premiumBenefits = [
    '15 GB storage',
    'Unlimited AI quizzes',
    'Full quiz history & retakes',
    'Answer explanations with source pages',
    'Priority support',
  ];
}
