import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../l10n/app_localizations.dart';

enum LegalTab { privacyPolicy, termsAndConditions }

class LegalDocumentsScreen extends StatefulWidget {
  final LegalTab initialTab;

  const LegalDocumentsScreen({
    super.key,
    this.initialTab = LegalTab.privacyPolicy,
  });

  static void show(BuildContext context, {LegalTab initialTab = LegalTab.privacyPolicy}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => FractionallySizedBox(
        heightFactor: 0.9,
        child: Container(
          decoration: const BoxDecoration(
            color: Color(0xFFFFF7F9),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            child: LegalDocumentsScreen(initialTab: initialTab),
          ),
        ),
      ),
    );
  }

  @override
  State<LegalDocumentsScreen> createState() => _LegalDocumentsScreenState();
}

class _LegalDocumentsScreenState extends State<LegalDocumentsScreen> {
  late LegalTab _currentTab;

  @override
  void initState() {
    super.initState();
    _currentTab = widget.initialTab;
  }

  Future<void> _launchUrl(String urlString) async {
    final Uri uri = Uri.parse(urlString);
    try {
      await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
        webOnlyWindowName: '_blank',
      );
    } catch (e) {
      try {
        await launchUrl(uri, webOnlyWindowName: '_blank');
      } catch (e2) {
        debugPrint('Could not launch $urlString: $e2');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFFF76B8A);
    const bgPinkColor = Color(0xFFFFF7F9);
    const textDark = Color(0xFF2D2529);
    const textMuted = Color(0xFF7A6B72);

    return Scaffold(
      backgroundColor: bgPinkColor,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.close, color: textDark),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          _currentTab == LegalTab.privacyPolicy ? AppLocalizations.of(context).ldPrivacyPolicy : AppLocalizations.of(context).ldTermsConditions,
          style: GoogleFonts.manrope(fontSize: 16, fontWeight: FontWeight.bold, color: textDark),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Tab selector bar
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Container(
              height: 42,
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: const Color(0xFFF5EBF0),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _currentTab = LegalTab.privacyPolicy),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        decoration: BoxDecoration(
                          color: _currentTab == LegalTab.privacyPolicy ? primaryColor : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          AppLocalizations.of(context).ldPrivacyPolicy,
                          style: GoogleFonts.manrope(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: _currentTab == LegalTab.privacyPolicy ? Colors.white : textMuted,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _currentTab = LegalTab.termsAndConditions),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        decoration: BoxDecoration(
                          color: _currentTab == LegalTab.termsAndConditions ? primaryColor : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          AppLocalizations.of(context).ldTermsConditions,
                          style: GoogleFonts.manrope(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: _currentTab == LegalTab.termsAndConditions ? Colors.white : textMuted,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Scrollable Document Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 760),
                  child: _currentTab == LegalTab.privacyPolicy
                      ? _buildPrivacyPolicyContent()
                      : _buildTermsContent(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrivacyPolicyContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildDocumentHeader(
          title: AppLocalizations.of(context).ldPrivacyPolicy2,
          effectiveDate: 'July 28, 2026',
          lastUpdated: 'July 28, 2026',
          appUrl: 'https://blushy.life',
        ),
        const SizedBox(height: 20),

        // Sanctuary Promise Box
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF0F3),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFF5D6DE)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('🔒 ', style: TextStyle(fontSize: 20)),
              Expanded(
                child: Text(
                  'Our Sanctuary Promise:\nWe do NOT sell, rent, or monetize your health data. Your intimate cycle and wellness logs belong exclusively to you.',
                  style: GoogleFonts.manrope(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF2D2529), height: 1.4),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        _buildSectionTitle('1. Introduction & Our Privacy Commitment'),
        _buildParagraph(
          'At Blushy, your privacy is our core principle. We recognize that menstrual cycle data, symptom logs, personal health insights, and emotional wellness notes are among the most sensitive personal data you generate.\nThis Privacy Policy explains how Blushy collects, uses, protects, and handles your information when you use our mobile application, website, Docsy AI Companion, partner connection tools, and community forums.',
        ),

        _buildSectionTitle('2. Information We Collect'),
        _buildParagraph('We collect information in three ways: information you provide directly, automated data necessary for app functionality, and information generated through your usage.'),

        _buildSubsectionTitle('A. Information You Directly Provide'),
        _buildBulletPoint('Account Information', 'Name, email address, password hash, and optional profile preferences (e.g., role selection: woman/man).'),
        _buildBulletPoint('Cycle & Health Logs', 'Period start dates, cycle length, flow intensity, physical symptoms, mood logs, sleep records, and onboarding wellness questionnaires.'),
        _buildBulletPoint('Docsy AI Companion Interactions', 'Text prompts, voice call audio snippets (processed in real-time), and personal memory notes you request Docsy to remember.'),
        _buildBulletPoint('Partner Connection Data', 'Connection link state and granular sharing permissions (e.g., whether to share cycle phase, mood summary, or decoder context with your connected partner).'),
        _buildBulletPoint('Community Contributions', 'Posts, comments, and interactions shared within the Blushy Community Hub.'),

        _buildSubsectionTitle('B. Information Collected Automatically'),
        _buildBulletPoint('Device & Technical Data', 'Browser type, OS version, application version, device locale, and anonymized interaction metrics for error debugging.'),
        _buildBulletPoint('Session Tokens', 'Secure authentication tokens stored locally to keep you signed in safely.'),

        _buildSectionTitle('3. How We Use Your Information'),
        _buildParagraph('We use your data strictly to deliver, personalize, and improve the Blushy experience:'),
        _buildBulletPoint('Cycle Predictions & Insights', 'Calculating period predictions, fertile window estimates, cycle phase analysis, and tailored health insights.'),
        _buildBulletPoint('Docsy AI Companion', 'Providing personalized conversational support, memory retention of your stated preferences, and voice call interaction.'),
        _buildBulletPoint('Partner Context Sharing', 'Enabling optional, permission-controlled cycle phase and mood summaries for your connected partner.'),
        _buildBulletPoint('Community Operations', 'Displaying community posts, moderating forum discussions, and processing anonymous post requests.'),
        _buildBulletPoint('Security & Account Access', 'Authenticating logins, preventing unauthorized account access, and maintaining system integrity.'),

        _buildSectionTitle('4. Data Protection, Storage & Encryption'),
        _buildBulletPoint('Encryption in Transit & at Rest', 'All communication between your device and our servers uses industry-standard TLS 1.3/HTTPS encryption. Database records are encrypted at rest using AES-256 standards.'),
        _buildBulletPoint('Voice Audio Security', 'Voice call audio streams are processed ephemerally for Speech-to-Text (STT) transcription and are not permanently archived as raw audio recordings.'),
        _buildBulletPoint('Access Control', 'Strict database access controls restrict backend operations to authorized automated services only.'),

        _buildSectionTitle('5. Partner Sharing & Granular Privacy Controls'),
        _buildParagraph('Blushy empowers you with 100% control over what your connected partner can see:'),
        _buildBulletPoint('Granular Toggles', 'You decide whether to share:\n• Your current menstrual cycle phase (e.g., Follicular, Luteal, Menstrual).\n• Mood and symptom summaries.\n• Partner Decoder context (allowing Docsy to offer tips to your partner for supportive communication).'),
        _buildBulletPoint('Instant Revocation', 'You can disconnect your partner or turn off any sharing permission at any time with immediate effect.'),

        _buildSectionTitle('6. Data Sharing & Third-Party Processors'),
        _buildParagraph('We never sell your data to advertisers, data brokers, or third parties. We share limited data only with trusted infrastructure providers essential to operating the app:'),
        _buildBulletPoint('Cloud Infrastructure & Database Services', 'Secure database and hosting providers (MongoDB Atlas, Node.js cloud servers).'),
        _buildBulletPoint('AI Processing Providers', 'Trusted API endpoints (OpenRouter / Grok / OpenAI Whisper) used strictly for real-time natural language processing and voice transcription. Third-party AI providers are contractually bound not to use your personal data to train public AI models.'),
        _buildBulletPoint('Legal Compliance', 'We will disclose data only if explicitly required by valid law enforcement orders or court subpoenas.'),

        _buildSectionTitle('7. Data Retention & Your Rights'),
        _buildParagraph('You retain full ownership of your data at all times:'),
        _buildBulletPoint('Right to Access & Export', 'You can view your cycle history and health logs anytime within the app.'),
        _buildBulletPoint('Right to Rectify', 'You can edit or update your period logs, mood history, and profile settings at any time.'),
        _buildClickableBulletPoint(
          label: AppLocalizations.of(context).ldRightToErasureDelete,
          prefixText: 'You may delete your account and clear all associated data directly from the Profile Settings screen or by contacting ',
          linkText: 'info@blushy.life',
          targetUrl: 'mailto:info@blushy.life',
          suffixText: '. Account deletion permanently wipes your profile, period history, Docsy chat history, and partner connection logs from our primary databases.',
        ),

        _buildSectionTitle('8. Children’s Privacy'),
        _buildParagraph('Blushy is designed for individuals aged 13 and older. We do not knowingly collect personal information from children under the age of 13. If we become aware that a child under 13 has provided personal data, we will take steps to delete such information immediately.'),

        _buildSectionTitle('9. Changes to This Privacy Policy'),
        _buildParagraph('We may update this Privacy Policy periodically to reflect new features or regulatory requirements. We will notify you of material changes by posting an update notice within the app or via email.'),

        _buildSectionTitle('10. Contact Us'),
        _buildParagraph('For any privacy-related questions, data requests, or feedback, please contact us at:'),
        _buildClickableBulletPoint(
          label: AppLocalizations.of(context).ldEmail,
          prefixText: '',
          linkText: 'info@blushy.life',
          targetUrl: 'mailto:info@blushy.life',
          suffixText: '',
        ),
        _buildClickableBulletPoint(
          label: AppLocalizations.of(context).ldWebsite,
          prefixText: '',
          linkText: 'https://blushy.life/privacy',
          targetUrl: 'https://blushy.life/privacy',
          suffixText: '',
        ),
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildTermsContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildDocumentHeader(
          title: AppLocalizations.of(context).ldTermsAndConditionsTerms,
          effectiveDate: 'July 28, 2026',
          lastUpdated: 'July 28, 2026',
          appUrl: 'https://blushy.life',
        ),
        const SizedBox(height: 20),

        // Medical Disclaimer Box
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF3CD),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFFFEEBA)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '⚠️ Medical Disclaimer (Important Notice)',
                style: GoogleFonts.manrope(fontSize: 14, fontWeight: FontWeight.bold, color: const Color(0xFF856404)),
              ),
              const SizedBox(height: 6),
              Text(
                'NOT MEDICAL ADVICE OR CONTRACEPTION:\nBlushy is an informational wellness and cycle tracking tool. It is NOT a medical device, diagnostic tool, or licensed healthcare provider.\n\n• No Medical Diagnosis: Information provided by Blushy, health insights, or Docsy AI Companion responses are for general educational and self-care tracking purposes only and must never replace professional medical advice, diagnosis, or treatment.\n• Not a Contraceptive Method: Period and fertility predictions generated by Blushy are estimates based on user-entered logs and statistical algorithms. Do not use Blushy as a primary method of birth control or contraception.\n• Emergency Care: If you are experiencing a medical emergency, severe pain, or unexpected symptoms, please consult a qualified physician or contact emergency medical services immediately.',
                style: GoogleFonts.manrope(fontSize: 12, color: const Color(0xFF856404), height: 1.4),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        _buildSectionTitle('1. Agreement to Terms'),
        _buildParagraph(
          'By downloading, accessing, or using Blushy (including the mobile application, website, Docsy AI Companion, partner feature, or community hub), you agree to be bound by these Terms and Conditions ("Terms"). If you do not agree to these Terms, please do not use the app.',
        ),

        _buildSectionTitle('2. Medical Disclaimer'),
        _buildParagraph('Please read the important medical disclaimer above carefully regarding informational usage and healthcare guidance.'),

        _buildSectionTitle('3. User Accounts & Security'),
        _buildBulletPoint('Account Creation', 'You agree to provide accurate and truthful information during registration.'),
        _buildBulletPoint('Account Security', 'You are responsible for maintaining the confidentiality of your account credentials and password.'),
        _buildClickableBulletPoint(
          label: AppLocalizations.of(context).ldUnauthorizedUse,
          prefixText: 'You must notify us immediately at ',
          linkText: 'info@blushy.life',
          targetUrl: 'mailto:info@blushy.life',
          suffixText: ' of any unauthorized access to your account.',
        ),

        _buildSectionTitle('4. Acceptable Use & Community Guidelines'),
        _buildParagraph('When participating in the Blushy Community or using Docsy AI Companion, you agree NOT to:'),
        _buildBulletPoint('Prohibited Behavior', '• Post or transmit any content that is harmful, abusive, harassing, defamatory, hateful, or discriminatory.\n• Share spam, promotional material, unauthorized advertising, or commercial solicitations.\n• Upload malicious code, viruses, or attempt to bypass system security measures.\n• Impersonate any person, brand, or entity.\n• Share explicit, non-consensual, or unlawful media.'),
        _buildParagraph('Violation of Community Guidelines may result in immediate post removal, temporary suspension, or permanent account termination.'),

        _buildSectionTitle('5. Docsy AI Companion & Automated Response Notice'),
        _buildBulletPoint('Nature of AI', 'Docsy is an artificial intelligence conversational assistant designed for empathetic wellness support and casual conversation.'),
        _buildBulletPoint('No Professional Consultation', 'Docsy does not act as a licensed therapist, clinical psychologist, or doctor.'),
        _buildBulletPoint('User Judgment', 'You acknowledge that AI-generated responses may occasionally contain inaccuracies. Users should exercise personal judgment and not rely solely on AI suggestions for critical decisions.'),

        _buildSectionTitle('6. Intellectual Property Rights'),
        _buildBulletPoint('Blushy Ownership', 'All logos, software code, UI design, branding, features, visual elements, and algorithms associated with Blushy are the exclusive intellectual property of Blushy and its licensors.'),
        _buildBulletPoint('Your Content', 'You retain ownership of the text logs, notes, and community posts you create within Blushy. By submitting community posts, you grant Blushy a non-exclusive, royalty-free license to display and distribute that content strictly within the Blushy platform.'),

        _buildSectionTitle('7. Termination of Service'),
        _buildBulletPoint('Termination by User', 'You may stop using Blushy and delete your account at any time via the app settings.'),
        _buildBulletPoint('Termination by Blushy', 'We reserve the right to suspend or terminate your account access without prior notice if you violate these Terms or engage in fraudulent, harmful, or illegal activities.'),

        _buildSectionTitle('8. Limitation of Liability'),
        _buildParagraph('To the maximum extent permitted by applicable law:'),
        _buildBulletPoint('"As-Is" Basis', 'Blushy is provided on an "AS IS" and "AS AVAILABLE" basis without warranties of any kind, whether express or implied.'),
        _buildBulletPoint('No Indirect Damages', 'Blushy and its developers, affiliates, or employees shall not be liable for any indirect, incidental, special, consequential, or punitive damages resulting from your use of or inability to use the service, including data loss or reliance on predictions or AI responses.'),

        _buildSectionTitle('9. Governing Law & Dispute Resolution'),
        _buildParagraph('These Terms shall be governed by and construed in accordance with the laws of the jurisdiction in which Blushy operates, without regard to its conflict of law principles. Any legal disputes arising under these Terms shall be resolved through good-faith negotiations or arbitration.'),

        _buildSectionTitle('10. Contact Information'),
        _buildParagraph('If you have any questions regarding these Terms and Conditions, please reach out to:'),
        _buildClickableBulletPoint(
          label: AppLocalizations.of(context).ldEmail,
          prefixText: '',
          linkText: 'info@blushy.life',
          targetUrl: 'mailto:info@blushy.life',
          suffixText: '',
        ),
        _buildClickableBulletPoint(
          label: AppLocalizations.of(context).ldWebsite,
          prefixText: '',
          linkText: 'https://blushy.life',
          targetUrl: 'https://blushy.life',
          suffixText: '',
        ),
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildDocumentHeader({
    required String title,
    required String effectiveDate,
    required String lastUpdated,
    required String appUrl,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.manrope(fontSize: 22, fontWeight: FontWeight.bold, color: const Color(0xFF2D2529)),
        ),
        const SizedBox(height: 8),
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              'Effective Date: $effectiveDate  |  Last Updated: $lastUpdated\nApplication: Blushy (Mobile App & Website) — ',
              style: GoogleFonts.manrope(fontSize: 12, color: const Color(0xFF7A6B72), height: 1.4),
            ),
            MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: () => _launchUrl(appUrl),
                child: Text(
                  appUrl,
                  style: GoogleFonts.manrope(
                    fontSize: 12,
                    color: const Color(0xFFF76B8A),
                    fontWeight: FontWeight.w600,
                    decoration: TextDecoration.underline,
                    height: 1.4,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 8),
      child: Text(
        title,
        style: GoogleFonts.manrope(fontSize: 16, fontWeight: FontWeight.bold, color: const Color(0xFFF76B8A)),
      ),
    );
  }

  Widget _buildSubsectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 14, bottom: 6),
      child: Text(
        title,
        style: GoogleFonts.manrope(fontSize: 14, fontWeight: FontWeight.w600, color: const Color(0xFF2D2529)),
      ),
    );
  }

  Widget _buildParagraph(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: GoogleFonts.manrope(fontSize: 13, color: const Color(0xFF4A3B43), height: 1.5),
      ),
    );
  }

  Widget _buildBulletPoint(String label, String detail) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• ', style: TextStyle(fontSize: 14, color: Color(0xFFF76B8A), fontWeight: FontWeight.bold)),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: GoogleFonts.manrope(fontSize: 13, color: const Color(0xFF4A3B43), height: 1.4),
                children: [
                  TextSpan(text: '$label: ', style: const TextStyle(fontWeight: FontWeight.bold)),
                  TextSpan(text: detail),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClickableBulletPoint({
    required String label,
    required String prefixText,
    required String linkText,
    required String targetUrl,
    required String suffixText,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• ', style: TextStyle(fontSize: 14, color: Color(0xFFF76B8A), fontWeight: FontWeight.bold)),
          Expanded(
            child: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text('$label: ', style: GoogleFonts.manrope(fontSize: 13, fontWeight: FontWeight.bold, color: const Color(0xFF4A3B43))),
                if (prefixText.isNotEmpty)
                  Text(prefixText, style: GoogleFonts.manrope(fontSize: 13, color: const Color(0xFF4A3B43))),
                MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    onTap: () => _launchUrl(targetUrl),
                    child: Text(
                      linkText,
                      style: GoogleFonts.manrope(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFFF76B8A),
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ),
                if (suffixText.isNotEmpty)
                  Text(suffixText, style: GoogleFonts.manrope(fontSize: 13, color: const Color(0xFF4A3B43))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
