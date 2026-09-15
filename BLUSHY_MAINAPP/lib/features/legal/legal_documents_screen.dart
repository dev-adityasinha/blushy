import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../l10n/app_localizations.dart';
import '../../services/api_consent_service.dart' show kLegalDocumentVersions;

enum LegalTab { privacyPolicy, termsAndConditions, medicalDisclaimer }

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

  /// Full name, for the title bar.
  String _tabTitle(LegalTab tab) {
    final l10n = AppLocalizations.of(context);
    switch (tab) {
      case LegalTab.privacyPolicy:
        return l10n.ldPrivacyPolicy;
      case LegalTab.termsAndConditions:
        return l10n.ldTermsConditions;
      case LegalTab.medicalDisclaimer:
        return l10n.ldMedicalDisclaimer;
    }
  }

  /// Short name, for the pills.
  ///
  /// Three segments across a phone leaves each about a third of the width, and
  /// "Terms & Conditions" does not fit there at a legible size. The full name
  /// stays in the title bar above, so nothing is lost.
  String _tabLabel(LegalTab tab) {
    final l10n = AppLocalizations.of(context);
    switch (tab) {
      case LegalTab.privacyPolicy:
        return l10n.ldTabPrivacy;
      case LegalTab.termsAndConditions:
        return l10n.ldTabTerms;
      case LegalTab.medicalDisclaimer:
        return l10n.ldTabDisclaimer;
    }
  }

  Widget _buildTabContent(LegalTab tab) {
    switch (tab) {
      case LegalTab.privacyPolicy:
        return _buildPrivacyPolicyContent();
      case LegalTab.termsAndConditions:
        return _buildTermsContent();
      case LegalTab.medicalDisclaimer:
        return _buildMedicalDisclaimerContent();
    }
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
          _tabTitle(_currentTab),
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
                  for (final tab in LegalTab.values)
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _currentTab = tab),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          decoration: BoxDecoration(
                            color: _currentTab == tab ? primaryColor : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            _tabLabel(tab),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.manrope(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: _currentTab == tab ? Colors.white : textMuted,
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
                  child: _buildTabContent(_currentTab),
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
          effectiveDate: 'September 9, 2026',
          lastUpdated: 'September 9, 2026',
          appUrl: 'https://blushy.life',
          version: kLegalDocumentVersions['privacy_policy'],
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

        // Stated as a closed list, because "what a health app does not collect"
        // is the part users and reviewers actually want answered, and silence
        // reads as concealment.
        _buildSubsectionTitle('C. What We Do Not Collect'),
        _buildBulletPoint('No Location', 'Blushy never asks for location permission and holds no GPS or geolocation data.'),
        _buildBulletPoint('No Advertising', 'No ads, no ad networks, and no advertising identifiers.'),
        _buildBulletPoint('No Third-Party Analytics', 'No Google Analytics, Firebase Analytics or similar SDK. Usage counts are recorded in our own database against a pseudonymous id, and never carry your health entries.'),
        _buildBulletPoint('No Payments', 'Blushy does not process payments and collects no card, bank or UPI details.'),
        _buildBulletPoint('No Device or Wearable Data', 'Everything Blushy knows about your health is something you typed. We do not connect to Google Fit, Apple Health, or any tracker.'),

        _buildSectionTitle('3. How We Use Your Information'),
        _buildParagraph('We use your data strictly to deliver, personalize, and improve the Blushy experience:'),
        _buildBulletPoint('Cycle Predictions & Insights', 'Calculating period predictions, fertile window estimates, cycle phase analysis, and tailored health insights.'),
        _buildBulletPoint('Docsy AI Companion', 'Providing personalized conversational support, memory retention of your stated preferences, and voice call interaction.'),
        _buildBulletPoint('Partner Context Sharing', 'Enabling optional, permission-controlled cycle phase and mood summaries for your connected partner.'),
        _buildBulletPoint('Community Operations', 'Displaying community posts, moderating forum discussions, and processing anonymous post requests.'),
        _buildBulletPoint('Security & Account Access', 'Authenticating logins, preventing unauthorized account access, and maintaining system integrity.'),

        _buildSectionTitle('4. Data Protection, Storage & Encryption'),
        _buildBulletPoint('Encryption in Transit & at Rest', 'All communication between your device and our servers uses HTTPS/TLS. Our database provider encrypts stored data at rest.'),
        // Said plainly, because the opposite was implied elsewhere. A tracker
        // that computes your cycle and answers you through Docsy has to be able
        // to read what you log, so it cannot be end-to-end encrypted -- and a
        // privacy claim the product cannot keep is worse than none.
        _buildBulletPoint('Not End-to-End Encrypted', 'Our servers can read the health data you log. They have to: calculating your cycle, finding patterns and answering you through Docsy all happen on the server. We do not sell it, and nothing reaches your partner unless you switch that sharing on.'),
        _buildBulletPoint('Voice Audio Security', 'Voice call audio streams are processed ephemerally for Speech-to-Text (STT) transcription and are not permanently archived as raw audio recordings.'),
        _buildBulletPoint('Access Control', 'Strict database access controls restrict backend operations to authorized automated services only.'),

        _buildSectionTitle('5. Partner Sharing & Granular Privacy Controls'),
        _buildParagraph('Blushy empowers you with 100% control over what your connected partner can see:'),
        _buildBulletPoint('Granular Toggles', 'You decide whether to share:\n• Your current menstrual cycle phase (e.g., Follicular, Luteal, Menstrual).\n• Mood and symptom summaries.\n• Partner Decoder context (allowing Docsy to offer tips to your partner for supportive communication).'),
        _buildBulletPoint('Instant Revocation', 'You can disconnect your partner or turn off any sharing permission at any time with immediate effect.'),

        _buildSectionTitle('6. Data Sharing & Third-Party Processors'),
        _buildParagraph('We never sell your data to advertisers, data brokers, or third parties. We share limited data only with trusted infrastructure providers essential to operating the app:'),
        _buildBulletPoint('Cloud Infrastructure & Database Services', 'Application hosting (Render, Singapore) and database hosting (MongoDB Atlas).'),
        _buildBulletPoint('Email Delivery', 'Brevo, for verification codes, password resets and service notices.'),
        // The provider names were wrong here: transcription runs on Groq, not
        // OpenAI. And the line claiming they are "contractually bound not to
        // train on your data" asserted a contract term nobody had confirmed --
        // exactly the kind of promise that must not be made on a user's behalf.
        _buildBulletPoint('AI Processing Providers', 'OpenRouter (running the Grok model) for Docsy and generated notes, and Groq (Whisper) for voice transcription. Only what is needed to answer you is sent. Whether those providers retain or train on what they receive is governed by their own terms, not ours — we do not use your data to train any model of our own.'),
        _buildBulletPoint('Processing Outside India', 'Our servers are in Singapore, email delivery is in the EU, and AI requests go to providers outside India. Using Blushy means your data crosses borders.'),
        _buildBulletPoint('Legal Compliance', 'We will disclose data only if explicitly required by valid law enforcement orders or court subpoenas.'),

        _buildSectionTitle('7. Data Retention & Your Rights'),
        _buildParagraph('You retain full ownership of your data at all times:'),
        _buildBulletPoint('Right to Access & Export', 'You can view your cycle history and health logs anytime within the app.'),
        _buildBulletPoint('Right to Rectify', 'You can edit or update your period logs, mood history, and profile settings at any time.'),
        _buildClickableBulletPoint(
          label: AppLocalizations.of(context).ldRightToErasureDelete,
          prefixText: 'Open My Health and choose "Delete Account Permanently". You will be asked to confirm twice, the second time by typing DELETE, so it cannot happen by accident. You can also write to ',
          linkText: 'info@blushy.life',
          targetUrl: 'mailto:info@blushy.life',
          suffixText: '. Deletion permanently removes your profile, period and symptom history, journal entries, Docsy chat history, uploaded files, community posts and partner connections. It cannot be undone.',
        ),

        _buildSectionTitle('8. Your Consent'),
        _buildParagraph(
          'We process your health data because you agreed to it, and we keep a record of that agreement — which documents you accepted, which version of each, and when. You can see this at any time under My Health.',
        ),
        _buildBulletPoint('Asked Before, Not After', 'We ask you to agree before you enter any health information, not once it is already collected.'),
        _buildBulletPoint('Asked Again When Things Change', 'If we change this policy materially, we will ask you again rather than assume your earlier agreement covers the new version.'),
        _buildBulletPoint('Withdrawing', 'You can withdraw your agreement from My Health. Withdrawing stops us relying on it, and the health features stop working, because they depend on processing the data you withdrew agreement for. Withdrawing is not the same as deleting — if you want your data gone as well, delete your account.'),

        _buildSectionTitle('9. Children’s Privacy'),
        _buildParagraph('Blushy is designed for individuals aged 13 and older. We do not knowingly collect personal information from children under the age of 13. If we become aware that a child under 13 has provided personal data, we will take steps to delete such information immediately.'),

        _buildSectionTitle('10. Changes to This Privacy Policy'),
        _buildParagraph('We may update this Privacy Policy periodically to reflect new features or regulatory requirements. We will notify you of material changes by posting an update notice within the app or via email.'),

        _buildSectionTitle('11. Contact Us'),
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
          effectiveDate: 'September 9, 2026',
          lastUpdated: 'September 9, 2026',
          appUrl: 'https://blushy.life',
          version: kLegalDocumentVersions['terms'],
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
        _buildParagraph(
          'Please read the notice above carefully. The full Medical Disclaimer — what Blushy is, '
          'what each feature can and cannot tell you, and what to do in an emergency — is the third '
          'tab at the top of this screen, and forms part of these Terms.',
        ),

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

  /// The medical disclaimer.
  ///
  /// Says what Blushy is not, feature by feature, and covers only features that
  /// exist. An earlier draft disclaimed doctor discovery and doctor
  /// consultations, neither of which the app has ever offered -- disclaiming a
  /// feature you do not ship reads as evidence that you do.
  Widget _buildMedicalDisclaimerContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildDocumentHeader(
          title: '⚕️ Medical Disclaimer',
          effectiveDate: 'September 9, 2026',
          lastUpdated: 'September 9, 2026',
          appUrl: 'https://blushy.life',
          version: kLegalDocumentVersions['medical_disclaimer'],
        ),
        const SizedBox(height: 20),

        // The one thing to take away if nothing else on this screen is read.
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
              const Text('⚠️ ', style: TextStyle(fontSize: 20)),
              Expanded(
                child: Text(
                  'Blushy is not a doctor.\nNothing here is medical advice, diagnosis or treatment. In an emergency call 112 or go to the nearest hospital — do not wait for anything in this app.',
                  style: GoogleFonts.manrope(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF2D2529), height: 1.4),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        _buildSectionTitle('1. What Blushy Is'),
        _buildParagraph(
          'Blushy is a health and wellness app. It gives you tools to track your cycle, log how you feel, read general health information, and ask questions of an AI assistant.\nBlushy is not a hospital, clinic, laboratory, pharmacy or licensed healthcare provider, and does not practise medicine. It is not clinically validated or medically certified, and holds no regulatory approval or clearance as a medical device anywhere.',
        ),
        _buildParagraph(
          'Everything Blushy knows about your health is something you entered yourself. It does not connect to any wearable, tracker, health platform, laboratory or clinic.',
        ),

        _buildSectionTitle('2. Not a Substitute for Care'),
        _buildParagraph(
          'Everything in the app is for general information, education and your own record-keeping. It does not replace advice, diagnosis or treatment from a qualified doctor.',
        ),
        _buildBulletPoint('Ask a Professional', 'Take any question about a condition, symptom, medication or treatment to a qualified healthcare professional.'),
        _buildBulletPoint('Do Not Delay Care', 'Never disregard, delay or avoid professional advice because of something you read or tracked here.'),
        _buildBulletPoint('At Your Own Risk', 'Relying on any prediction, insight or AI answer from Blushy is your own decision.'),

        _buildSectionTitle('3. What We Do and Do Not Give You'),
        _buildParagraph('Blushy provides general health information, and personalised observations drawn from what you have logged. It does not provide medical advice, a diagnosis, treatment, or emergency care.'),
        _buildParagraph('Personalised observations are patterns and estimates from your own entries. They are not clinical judgment. Where there is too little of your data to say anything meaningful, the app tells you so instead of showing general guidance as though it were about you.'),

        _buildSectionTitle('4. AI-Generated Content'),
        _buildParagraph(
          'Docsy and the notes and articles Blushy generates are produced by general-purpose AI models run by third parties — OpenRouter for text, Groq for voice transcription. They are not medical models and carry no medical accreditation.',
        ),
        _buildBulletPoint('It Can Be Wrong', 'AI can misread what you wrote, generalise badly, or state something false with complete confidence.'),
        _buildBulletPoint('Nobody Checks It First', 'AI answers are not reviewed by a physician, or by any person, before you see them.'),
        _buildBulletPoint('Not a Diagnosis', 'If Docsy mentions a condition, that is information to take to a doctor — never a finding about you.'),

        _buildSectionTitle('5. Feature by Feature'),
        _buildBulletPoint('Cycle Predictions', 'Statistical estimates from the dates you logged. Not guarantees, and often wrong where cycles are irregular or logging is patchy. Do not use them as contraception.'),
        _buildBulletPoint('Period & Symptom Tracking', 'Only as accurate as what you entered. A symptom or an association listed here does not mean you have any condition, and cannot rule one out.'),
        _buildBulletPoint('Patterns & Correlations', 'A relationship between two things you logged is statistical and drawn only from your entries. It does not mean one caused the other.'),
        _buildBulletPoint('Sleep & Mood', 'Self-reported, and not a clinical or psychological assessment. Persistent sleep or mood difficulty deserves a professional, not an app.'),
        _buildBulletPoint('Life-Stage Guidance', 'Blushy does not determine or confirm which life stage you are in — that follows what you selected and logged. Perimenopause, menopause, pregnancy and postpartum all need professional care.'),
        _buildBulletPoint('Safety Alerts', 'A prompt to seek care, not an assessment. Just as importantly: the absence of an alert is not reassurance. Silence from Blushy never means nothing is wrong.'),
        _buildBulletPoint('Uploaded Medical Reports', 'Text is extracted automatically and may be incomplete or wrong. The report from your laboratory or clinician is the real document; ours is a convenience.'),
        _buildBulletPoint('Doctor-Visit Summaries', 'Compiled from your own entries for your convenience. Not a medical record, not a referral, and it may be incomplete.'),
        _buildBulletPoint('Partner Mode', 'What you share stays general or personalised wellness information. It is not medical advice for you or your partner.'),
        _buildBulletPoint('Community', 'Posts by other members are their own. Blushy does not write, review or endorse them, and other members are not doctors.'),

        _buildSectionTitle('6. No Guarantees'),
        _buildParagraph(
          'Predictions and insights are estimates. Two people with similar symptoms may have entirely different conditions, and Blushy cannot account for your medical history, genetics or circumstances.',
        ),
        _buildParagraph(
          'If Blushy shows no pattern and no alert, that reflects the limits of what you logged and what the app can detect. It is not an indication that you are well.',
        ),

        _buildSectionTitle('7. Emergencies'),
        _buildParagraph(
          'Blushy is not an emergency service and nobody monitors what you log.\nIf you are experiencing severe pain, heavy or uncontrolled bleeding, difficulty breathing, chest pain, thoughts of suicide or self-harm, or anything else that may be life-threatening, contact emergency services immediately, go to the nearest emergency department, or call 112. Do not wait for anything in this app.',
        ),

        _buildSectionTitle('8. Features Blushy Does Not Offer'),
        _buildParagraph('For the avoidance of doubt, Blushy does not provide:'),
        _buildBulletPoint('No Consultations', 'No appointments, messaging or consultations with doctors or other healthcare professionals, and no directory of providers.'),
        _buildBulletPoint('No Prescriptions or Tests', 'No prescriptions, medication supply, pharmacy services, laboratory testing, or clinical interpretation of results.'),
        _buildBulletPoint('No Contraceptive Guidance', 'Blushy is not a family-planning service and must not be used as one.'),
        _buildBulletPoint('No Emergency Response', 'No crisis or emergency response of any kind.'),

        _buildSectionTitle('9. Your Responsibility'),
        _buildBulletPoint('Your Decisions', 'You remain responsible for your health decisions and for seeking timely professional care. Blushy is a tool, not a decision-maker.'),
        _buildBulletPoint('Your Medication', 'Do not start, stop or change any medication or treatment based on anything in this app.'),
        _buildBulletPoint('Your Data', 'Inaccurate or incomplete entries produce inaccurate output.'),

        _buildSectionTitle('10. Contact'),
        _buildParagraph('Questions about this disclaimer, or a concern about something the app showed you:'),
        _buildClickableBulletPoint(
          label: AppLocalizations.of(context).ldEmail,
          prefixText: '',
          linkText: 'info@blushy.life',
          targetUrl: 'mailto:info@blushy.life',
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
    // Shown because the consent record names it. A user asked to agree again
    // after an update can then see which version they are looking at, rather
    // than having to take the prompt's word for it.
    String? version,
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
              'Effective Date: $effectiveDate  |  Last Updated: $lastUpdated'
              '${version == null ? '' : '  |  Version $version'}'
              '\nApplication: Blushy (Mobile App & Website) — ',
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
