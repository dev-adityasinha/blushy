import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../theme/colors.dart';
import '../../../services/api_partner_service.dart';
import '../../../l10n/app_localizations.dart';
import '../partner_stage.dart';
import 'partner_stage_today.dart';
import '../../../shared/live_refresh.dart';

class PartnerSiaScreen extends StatefulWidget {
  final String? initialPrompt;
  const PartnerSiaScreen({super.key, this.initialPrompt});

  @override
  State<PartnerSiaScreen> createState() => _PartnerSiaScreenState();
}

class _PartnerSiaScreenState extends State<PartnerSiaScreen>
    with WidgetsBindingObserver, LiveRefresh {
  final TextEditingController _queryController = TextEditingController();
  final List<Map<String, dynamic>> _chatHistory = [];
  final ApiPartnerService _partnerService = ApiPartnerService();

  /// The connection this coaching is about. Without one there is nobody to
  /// ground the answers in, and the screen says so rather than guessing.
  String? _connectionId;

  /// Her cycle phase, when she shares it. Null otherwise, and never inferred.
  String? _phase;

  /// Her life stage, when she shares her onboarding. Null otherwise.
  ///
  /// This used to be read off her `partnerUser` object, where it did not
  /// exist, so it fell back to "everydayWellness" on every account -- and a
  /// partner of someone in her third trimester was coached as though she were
  /// having an ordinary week. The payload carries it now, behind her own
  /// `shareOnboarding` key.
  ///
  /// Held as it arrived and normalised at the point of use: the server sends
  /// snake_case (`ttc`, `first_period`) and the older client code wrote
  /// camelCase (`tryingToConceive`, `firstPeriodStarted`). Matching on one
  /// spelling silently missed the other.
  String? _stage;
  bool _loadingConnection = true;

  /// Whether her context actually reached the model on the last answer, and
  /// whether she has the partner-AI switch on at all. Both come back from the
  /// server, so the banner reports what happened rather than what we hoped.
  bool _usedHerContext = false;
  bool _aiAllowed = true;
  bool _thinking = false;

  /// The banner and the pills are built from her permitted context, so they
  /// go stale the same way the home screen did: she changes what she shares,
  /// or moves to a new phase overnight, and this still says what it said when
  /// the tab was first opened. Re-read on the same terms as everywhere else.
  @override
  Future<void> refreshNow() => _loadConnection();

  @override
  void dispose() {
    stopLiveRefresh();
    _queryController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _loadConnection();
    startLiveRefresh();
    if (widget.initialPrompt != null && widget.initialPrompt!.trim().isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _sendQuery(widget.initialPrompt!);
      });
    }
  }

  Future<void> _loadConnection() async {
    final connections = await _partnerService.getConnections();
    if (!mounted) return;
    final active = connections.firstWhere(
      (c) => c['status'] == 'active',
      orElse: () => <String, dynamic>{},
    );
    final connectionId = active['connectionId']?.toString();
    setState(() {
      _connectionId = connectionId;
      _loadingConnection = false;
    });

    if (connectionId == null) return;

    // The phase the questions are keyed on, from the same permission-filtered
    // payload the home screen reads. Absent when she is not sharing her cycle,
    // which is the case the general set is for.
    final shared = await _partnerService.getPartnerSharedData(connectionId);
    if (!mounted) return;
    final cycle = shared['cycleInfo'];
    setState(() {
      _phase = cycle is Map ? cycle['phase']?.toString() : null;
      _stage = shared['lifeStage']?.toString();
    });
  }

  /// Three questions worth asking, keyed on where she actually is.
  ///
  /// Not on her life stage: `lifeStage` is not in the shared-data payload at
  /// all, so the value this screen used to read was null on every account and
  /// silently became "everydayWellness". Keying on something the app does not
  /// receive would have been three made-up questions wearing a real label.
  ///
  /// Phrased as openings rather than answers. "What helps most on a heavy
  /// day?" leaves room for her to be different from the chart; "She needs a
  /// heat pack" does not.
  /// Her stage first where she shares it: being pregnant or six days
  /// postpartum says more about what he should ask than which week of a cycle
  /// it is. Falls through to the phase, and the phase set falls through to a
  /// general one on its own.
  ///
  /// Both sets live in `partner_stage_today.dart`, because Partner Home now
  /// offers the same questions beside the cycle card and two copies is how
  /// they drift.
  List<String> get _suggestions =>
      _stageSuggestions ?? partnerPhaseQuestions(_phase);

  /// Asks the relationship coach, grounded in what she has permitted.
  ///
  /// This used to post to `/ai/chat` with `context: 'partner_support'` and
  /// nothing else -- no cycle, no stage, no mood -- so the "partner coach" was
  /// a general chatbot that happened to sit in his app.
  ///
  /// `/ai/relationship-advice/:connectionId` already existed and was already
  /// doing the work: it gathers her context *behind her own permission keys*,
  /// runs the deterministic safety ruleset over the question and the answer,
  /// and reports back whether her data was used at all. Nothing here decides
  /// what he may see; the server does, from her switches.
  Future<void> _sendQuery(String query) async {
    final cleanQuery = query.trim();
    if (cleanQuery.isEmpty) return;

    setState(() {
      _chatHistory.add({"sender": "user", "text": cleanQuery});
      _thinking = true;
    });
    _queryController.clear();

    final connectionId = _connectionId;
    if (connectionId == null) {
      setState(() {
        _thinking = false;
        _chatHistory.add({
          "sender": "sia",
          "text": "Once you are connected, I can ground what I say in what "
              "she has chosen to share. Until then I can still answer general "
              "questions about how to support her.",
        });
      });
      return;
    }

    final result = await _partnerService.askRelationshipAi(
      connectionId: connectionId,
      question: cleanQuery,
    );
    if (!mounted) return;

    final error = result['error']?.toString();
    final answer = result['answer']?.toString();

    setState(() {
      _thinking = false;
      _usedHerContext = result['usedPartnerData'] == true;
      _aiAllowed = result['aiSuggestionsEnabled'] != false;

      if (answer != null && answer.trim().isNotEmpty) {
        _chatHistory.add({"sender": "sia", "text": answer.trim()});
        return;
      }

      // No invented answer. The fallbacks here were written for a girl going
      // through puberty -- "visit your school nurse", "your body blossoming"
      // -- and were being served to her partner, which was worse than saying
      // nothing at all.
      _chatHistory.add({
        "sender": "sia",
        "text": error != null && error.trim().isNotEmpty
            ? "I could not reach Docsy just now. $error"
            : "I could not reach Docsy just now. Please try again in a moment.",
      });
    });
  }

  /// Questions worth asking for the stage she is actually in.
  ///
  /// The set lives in `partner_stage_today.dart` because Partner Home
  /// offers the same three; keeping one copy is what stops a stage being
  /// added to one surface and missed on the other.
  ///
  /// Null for the stages where a cycle phase says more -- living with her
  /// cycle, hormonal health -- so those fall through rather than being given
  /// a vaguer version of what the phase already answers.
  List<String>? get _stageSuggestions =>
      partnerStageQuestions(PartnerStage.from(_stage));

  Widget _contextBanner() {
    late final IconData icon;
    late final String text;
    late final Color tint;

    if (!_aiAllowed) {
      icon = Icons.lock_person_rounded;
      tint = const Color(0xFF7209B7);
      text = 'She has partner suggestions switched off. I can still help with '
          'general questions.';
    } else if (_usedHerContext) {
      icon = Icons.sync_rounded;
      tint = const Color(0xFF0D9488);
      text = 'Grounded in what she is sharing with you today.';
    } else {
      icon = Icons.self_improvement_rounded;
      tint = BlushyColors.secondaryText;
      text = 'Nothing personal is being shared right now. I can still help '
          'with general questions.';
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 10, 16, 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFEFE8E0)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 15, color: tint),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.manrope(
                fontSize: 11.5,
                color: const Color(0xFF7A6B72),
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // These read `user_profile.json`, which on a partner account is *his*
    // profile -- so the "stage-aware" question was keyed on his own stage,
    // which is 'partner'. The questions now come from her phase, where she
    // shares it, and are general where she does not.
    final List<String> suggestions = _suggestions;

    return Scaffold(
      backgroundColor: BlushyColors.background,
      appBar: AppBar(
        backgroundColor: BlushyColors.background,
        elevation: 0,
        leading: Navigator.canPop(context)
            ? IconButton(
                icon: const Icon(Icons.arrow_back_ios_rounded, color: BlushyColors.text, size: 20),
                onPressed: () => Navigator.pop(context),
              )
            : null,
        title: Text(
          "Ask Docsy",
          style: GoogleFonts.manrope(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: BlushyColors.text,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // What this answer is grounded in. Held back until the connection
            // is known, so it does not flash "nothing shared" on every open.
            if (!_loadingConnection) _contextBanner(),
            if (_thinking)
              const Padding(
                padding: EdgeInsets.only(top: 6),
                child: SizedBox(
                  height: 2,
                  child: LinearProgressIndicator(
                    minHeight: 2,
                    color: BlushyColors.primary,
                    backgroundColor: Colors.transparent,
                  ),
                ),
              ),
            // Chat messages
            Expanded(
              child: _chatHistory.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(28.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.auto_awesome, color: BlushyColors.primary, size: 48),
                          const SizedBox(height: 16),
                          Text(
                            "Ask Docsy about supporting her",
                            textAlign: TextAlign.center,
                            style: GoogleFonts.manrope(fontSize: 18, fontWeight: FontWeight.bold, color: BlushyColors.text),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            "Learn about health stages, communication tips, and practical support guides.",
                            textAlign: TextAlign.center,
                            style: GoogleFonts.manrope(fontSize: 12, color: BlushyColors.secondaryText),
                          ),
                          const SizedBox(height: 24),
                          ...suggestions.map((suggestion) {
                            return GestureDetector(
                              onTap: () => _sendQuery(suggestion),
                              child: Container(
                                margin: const EdgeInsets.symmetric(vertical: 6),
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: BlushyColors.border),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.help_outline_rounded, size: 16, color: BlushyColors.primary),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        suggestion,
                                        style: GoogleFonts.manrope(fontSize: 12, fontWeight: FontWeight.w600, color: BlushyColors.text),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16.0),
                      itemCount: _chatHistory.length,
                      itemBuilder: (context, index) {
                        final msg = _chatHistory[index];
                        final isUser = msg["sender"] == "user";
                        return Align(
                          alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                          child: Container(
                            margin: const EdgeInsets.symmetric(vertical: 6),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: isUser ? BlushyColors.primary : Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: isUser ? null : Border.all(color: BlushyColors.border),
                            ),
                            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                            child: Text(
                              msg["text"]!,
                              style: GoogleFonts.manrope(
                                fontSize: 13,
                                color: isUser ? Colors.white : BlushyColors.text,
                                height: 1.45,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
            // Input field
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: BlushyColors.border)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _queryController,
                      style: GoogleFonts.manrope(fontSize: 13, color: BlushyColors.text),
                      decoration: InputDecoration(
                        hintText: AppLocalizations.of(context).psAskAboutHerActive,
                        hintStyle: GoogleFonts.manrope(color: BlushyColors.secondaryText.withValues(alpha: 0.5)),
                        border: InputBorder.none,
                      ),
                      onSubmitted: _sendQuery,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.send_rounded, color: BlushyColors.primary),
                    onPressed: () => _sendQuery(_queryController.text),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
