/// In-app legal copy for Apple App Store and Google Play listings.
///
/// This is Notably's published terms, not a substitute for independent legal
/// advice. Update [kLegalEffectiveDate] when you change the text.
const kLegalEffectiveDate = '24 August 2026';
const kLegalContactEmail = 'support@notably.app';
const kLegalOperator = 'Notably';

enum LegalDoc { terms, privacy }

class LegalSection {
  const LegalSection(this.heading, this.body);
  final String heading;
  final String body;
}

const kTermsTitle = 'Terms of Use';
const kPrivacyTitle = 'Privacy Policy';

final kTermsSections = <LegalSection>[
  LegalSection(
    'Agreement',
    'These Terms of Use (“Terms”) are an agreement between you and $kLegalOperator '
        '(“Notably”, “we”, “us”) for your use of the Notably apps on iOS, Android, '
        'and the web, including related websites, cloud sync, and paid features '
        '(together, the “Service”).\n\n'
        'By creating an account, signing in, or tapping Agree, you accept these '
        'Terms and our Privacy Policy. If you do not agree, do not use the Service.\n\n'
        'Effective date: $kLegalEffectiveDate.',
  ),
  LegalSection(
    'Eligibility',
    'Notably is a digital notebook for students and anyone who takes notes — '
        'including children, similar to other handwriting apps. There is no minimum '
        'age to use the app on a device a parent or school provides.\n\n'
        'If you are under 18, a parent or guardian must review these Terms and our '
        'Privacy Policy and is responsible for your use of the Service.\n\n'
        'If you are under 13 (or under the digital-consent age in your country), a '
        'parent or guardian must create or supervise the account, consent to cloud '
        'sync and any AI features, and manage the Apple ID, Google account, or '
        'email used to sign in. Do not create an unsupervised account for a child '
        'in those age groups.\n\n'
        'You (or your parent) are responsible for keeping login details secret and '
        'for activity under the account.',
  ),
  LegalSection(
    'The Service',
    'Notably is a digital notebook. You can create notebooks, write by hand, import '
        'and mark up PDFs and images, organise a library, search your materials, '
        'and (where available) generate practice quizzes from documents.\n\n'
        'We may change, suspend, or discontinue features. We do not guarantee that '
        'the Service will be uninterrupted or error-free. You should keep your own '
        'backups of important files.',
  ),
  LegalSection(
    'Your content',
    'You keep ownership of notes, handwriting, PDFs, images, and other material '
        'you upload (“Your Content”). You grant Notably a limited licence to host, '
        'back up, transmit, and display Your Content solely to operate and improve '
        'the Service for you (for example cloud sync and on-device or cloud quiz '
        'generation).\n\n'
        'You represent that you have the rights to use Your Content and that it '
        'does not infringe others’ rights or the law. Do not upload malware or '
        'unlawful material.\n\n'
        'We may remove content or suspend accounts that violate these Terms.',
  ),
  LegalSection(
    'Subscriptions and payments',
    'Some features (including extra storage and unlimited AI quizzes, as described '
        'in the app) require a paid plan (“Premium”).\n\n'
        'On Apple devices, purchases and auto-renewing subscriptions are billed by '
        'Apple through your Apple ID. Manage or cancel in Settings → Apple ID → '
        'Subscriptions. Apple’s terms also apply. We cannot refund Apple charges; '
        'request refunds from Apple where available.\n\n'
        'On Google Play, purchases and subscriptions are billed by Google. Manage '
        'or cancel in Google Play → Payments & subscriptions. Google’s terms also '
        'apply. Refunds follow Google Play’s policies.\n\n'
        'On the web, Premium may be billed through local payment methods such as '
        'GCash, Maya, or card (processed by PayMongo). Web plans may not auto-renew '
        'the same way as store subscriptions; follow the in-app receipt and wallet '
        'confirmation.\n\n'
        'Prices are shown before you pay, usually in Philippine pesos (₱) unless '
        'the store localises currency. Promotional codes and student discounts may '
        'change or expire. Taxes may apply.\n\n'
        'If you subscribe through Apple or Google, payment is charged to your store '
        'account at confirmation of purchase. Subscriptions renew automatically '
        'unless cancelled at least 24 hours before the end of the current period. '
        'Your account will be charged for renewal within 24 hours prior to the end '
        'of the current period. You can restore purchases on a new device using '
        'the same Apple ID or Google account.',
  ),
  LegalSection(
    'AI features',
    'Quiz generation and similar tools may send portions of Your Content to a '
        'third-party AI provider (currently Google) to produce results. Output may '
        'be inaccurate. Do not rely on quizzes as official exam material. Do not '
        'submit content you are not allowed to share with processors.',
  ),
  LegalSection(
    'Acceptable use',
    'You agree not to reverse engineer the apps except as allowed by law, overload '
        'or disrupt the Service, attempt unauthorised access, scrape other users’ '
        'data, or use Notably to violate academic integrity rules of your school '
        'in a way that is unlawful. We may rate-limit or refuse service for abuse.',
  ),
  LegalSection(
    'Accounts and deletion',
    'You may sign out at any time. You may request deletion of your account and '
        'associated cloud data by contacting $kLegalContactEmail. Local copies on '
        'a device may remain until you uninstall the app or clear app data. Some '
        'records (for example invoices or fraud prevention) may be kept where the '
        'law requires.',
  ),
  LegalSection(
    'Disclaimer',
    'THE SERVICE IS PROVIDED “AS IS” AND “AS AVAILABLE”. TO THE MAXIMUM EXTENT '
        'PERMITTED BY LAW, NOTABLY DISCLAIMS WARRANTIES OF MERCHANTABILITY, FITNESS '
        'FOR A PARTICULAR PURPOSE, AND NON-INFRINGEMENT. WE DO NOT WARRANT THAT '
        'YOUR NOTES WILL NEVER BE LOST.',
  ),
  LegalSection(
    'Limitation of liability',
    'TO THE MAXIMUM EXTENT PERMITTED BY LAW, NOTABLY AND ITS OPERATORS ARE NOT '
        'LIABLE FOR INDIRECT, INCIDENTAL, SPECIAL, CONSEQUENTIAL, OR LOST-DATA '
        'DAMAGES, OR FOR AMOUNTS EXCEEDING THE FEES YOU PAID US FOR PREMIUM IN THE '
        'TWELVE MONTHS BEFORE THE CLAIM (OR ₱1,000 IF YOU PAID NOTHING).\n\n'
        'Some jurisdictions do not allow certain exclusions; in those places our '
        'liability is limited to the greatest extent allowed.',
  ),
  LegalSection(
    'Governing law',
    'These Terms are governed by the laws of the Republic of the Philippines, '
        'without regard to conflict-of-law rules. Courts in the Philippines have '
        'exclusive jurisdiction, except that you may have additional mandatory '
        'consumer rights in your country of residence (including EEA/UK consumers).',
  ),
  LegalSection(
    'Changes',
    'We may update these Terms. Material changes will be posted in the app or by '
        'email. Continued use after the effective date means you accept the update. '
        'If you do not agree, stop using the Service and delete your account.',
  ),
  LegalSection(
    'Contact',
    'Questions about these Terms: $kLegalContactEmail.',
  ),
];

final kPrivacySections = <LegalSection>[
  LegalSection(
    'Who we are',
    '$kLegalOperator provides Notably. This Privacy Policy explains what personal '
        'data we collect, why, and your choices. It applies to iOS, Android, and '
        'web. Effective date: $kLegalEffectiveDate.\n\n'
        'Contact: $kLegalContactEmail.',
  ),
  LegalSection(
    'Data we collect',
    'Account: email address, display name, sign-in identifiers (including Google '
        'if you use Google Sign-In), and a unique user ID.\n\n'
        'Content: notebooks, pages, ink, PDFs, images, and related metadata you '
        'create or import, stored locally and, when you are signed in, synced to '
        'our cloud.\n\n'
        'Usage and diagnostics: app version, device type, crash logs, and '
        'approximate activity needed to run sync, billing, and support (including '
        'optional bug reports you send).\n\n'
        'Payments: we do not store full card numbers. Apple and Google process '
        'store purchases. Web wallet/card payments are processed by PayMongo. We '
        'store subscription status, plan, expiry, and payment references needed '
        'to unlock Premium.',
  ),
  LegalSection(
    'How we use data',
    'We use data to create and secure your account, sync your library across '
        'devices, provide Premium and quizzes, prevent fraud and abuse, comply '
        'with law, and improve Notably. We do not sell your personal information.',
  ),
  LegalSection(
    'Processors',
    'We use service providers who process data on our instructions, including:\n'
        '• Supabase — authentication and application database\n'
        '• Cloudflare (including R2) — file storage and our API worker\n'
        '• Apple App Store / Google Play / RevenueCat — in-app purchases where used\n'
        '• PayMongo — web payments (GCash, Maya, card)\n'
        '• Google — Sign-In and, when you use AI quizzes, generative AI processing\n\n'
        'These providers may process data outside the Philippines. We use them '
        'only as needed to operate the Service.',
  ),
  LegalSection(
    'Retention',
    'We keep account and synced content while your account is open. After deletion '
        'we remove or anonymise personal data within a reasonable period unless we '
        'must keep it for legal, tax, or security reasons. Backups may persist for '
        'a limited time.',
  ),
  LegalSection(
    'Your rights',
    'Depending on where you live, you may request access, correction, deletion, '
        'or a copy of your personal data, or object to certain processing. Email '
        '$kLegalContactEmail. We will need to verify the request.\n\n'
        'You can also sign out, stop using cloud sync, or uninstall the app. '
        'Store subscriptions must be cancelled in Apple or Google settings.',
  ),
  LegalSection(
    'Children',
    'Notably may be used by children (for example school notes and homework) with '
        'a parent’s or guardian’s permission. We do not target advertising at '
        'children, and we do not sell children’s personal information.\n\n'
        'Cloud accounts, Google Sign-In, payments, and AI quizzes process personal '
        'data and document content. For users under 13 (or under the digital-consent '
        'age where you live), a parent or guardian must consent to that processing '
        'and should use a family-managed Apple ID, Google account, or their own '
        'email — not an unsupervised child-created account.\n\n'
        'Parents may request access or deletion of a child’s data at '
        '$kLegalContactEmail. If an account was created for a child without the '
        'required consent, contact us and we will delete it.',
  ),
  LegalSection(
    'Security',
    'We use industry-standard measures (encryption in transit, access controls). '
        'No method of storage or transmission is 100% secure.',
  ),
  LegalSection(
    'Changes',
    'We may update this Policy. The effective date above will change. Continued '
        'use means you accept the updated Policy where permitted by law.',
  ),
];
