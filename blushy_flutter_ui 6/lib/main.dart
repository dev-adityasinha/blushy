// ignore_for_file: deprecated_member_use
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'hero_redesign.dart';
import 'blushy_screens.dart';
import 'blushy_design_system.dart';
import 'platform_keynote_phone.dart';

void _navigateToBeta() async {
  const url = 'https://blushy.life/betaversion';
  final uri = Uri.parse(url);
  if (await canLaunchUrl(uri)) {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

// ═══════════════════════════════════════════════
//  DESIGN TOKENS & STYLE SYSTEM
// ═══════════════════════════════════════════════

class C {
  static const cream = Color(0xFFFAF6F0);
  static const ink = Color(0xFF1A0F0A);
  static const red = Color(0xFFE31C25);
  static const orange = Color(0xFFFF4A00);
  static const pink = Color(0xFFFF89BE);
  static const yellow = Color(0xFFFCB207);
  static const sand = Color(0xFFFFD4A8);
  static const roseBg = Color(0xFFF7C3CD); // Section 06 background
}


class Breakpoints {
  static const mobile = 768.0;
  static const tablet = 950.0;
  static const desktop = 1200.0;
}




class TypographyScale {
  // Desktop
  static const heroTitleDesktop = 56.0;
  static const heroBodyDesktop = 56.0;
  static const sectionDesktop = 40.0;
  static const displayDesktop = 48.0;
  static const statsDesktop = 38.0;
  static const bodyDesktop = 16.0;
  static const buttonDesktop = 14.5;
  static const captionDesktop = 11.0;
  
  // Tablet
  static const heroTitleTablet = 44.0;
  static const heroBodyTablet = 36.0;

  // Mobile
  static const heroTitleMobile = 32.0;
  static const heroBodyMobile = 26.0;
  static const sectionMobile = 28.0;
  static const displayMobile = 32.0;
  static const statsMobile = 24.0;
  static const bodyMobile = 14.0;
  static const buttonMobile = 14.0;
  static const captionMobile = 11.0;
}

class TSize {
  static double heroTitle(double sw) {
    if (sw >= Breakpoints.desktop) return TypographyScale.heroTitleDesktop;
    if (sw >= Breakpoints.mobile) return TypographyScale.heroTitleTablet;
    return TypographyScale.heroTitleMobile;
  }
  
  static double heroDesc(double sw) {
    if (sw >= Breakpoints.desktop) return TypographyScale.heroBodyDesktop;
    if (sw >= Breakpoints.mobile) return TypographyScale.heroBodyTablet;
    return TypographyScale.heroBodyMobile;
  }
  
  static double display(double sw, [double desktopSize = TypographyScale.displayDesktop]) => 
    sw > Breakpoints.tablet ? desktopSize : TypographyScale.displayMobile;
    
  static double sectionTitle(double sw, [double desktopSize = TypographyScale.sectionDesktop]) => 
    sw > Breakpoints.tablet ? desktopSize : TypographyScale.sectionMobile;
    
  static double statsNum(double sw) => 
    sw > Breakpoints.tablet ? TypographyScale.statsDesktop : TypographyScale.statsMobile;
    
  static double statsLabel(double sw) => 
    sw > Breakpoints.tablet ? TypographyScale.captionDesktop : TypographyScale.captionMobile;
    
  static double body(double sw, [double desktopSize = TypographyScale.bodyDesktop]) => 
    sw > Breakpoints.tablet ? desktopSize : TypographyScale.bodyMobile;
    
  static double btn(double sw) => 
    sw > Breakpoints.tablet ? TypographyScale.buttonDesktop : TypographyScale.buttonMobile;
    
  static double caption(double sw) => 
    sw > Breakpoints.tablet ? TypographyScale.captionDesktop : TypographyScale.captionMobile;
}
class T {
  static TextStyle d(double sz, {Color? c, bool it = false, double? h}) =>
      GoogleFonts.inter(
        fontSize: sz,
        fontWeight: FontWeight.w500,
        fontStyle: it ? FontStyle.italic : FontStyle.normal,
        letterSpacing: sz * -0.03,
        height: h ?? 0.95,
        color: c ?? C.ink,
      );

  static TextStyle b(double sz, {Color? c, FontWeight w = FontWeight.w400, double? h, bool it = false}) =>
      GoogleFonts.inter(fontSize: sz, fontWeight: w, color: c ?? C.ink, height: h ?? 1.55, letterSpacing: -0.01, fontStyle: it ? FontStyle.italic : null);

  static TextStyle e({Color? c}) =>
      GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 2.8, color: c ?? C.ink.withOpacity(0.55));
}

// ═══════════════════════════════════════════════
//  ENTRY POINT
// ═══════════════════════════════════════════════

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent, statusBarIconBrightness: Brightness.dark));
  runApp(const BlushyApp());
}

class BlushyApp extends StatelessWidget {
  const BlushyApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: "Blushy Women's Wellness",
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.light(primary: C.red, surface: C.cream),
          scaffoldBackgroundColor: C.cream,
          useMaterial3: true,
        ),
        home: const SelectionArea(child: RedesignedHomePage()),
      );
}

// ═══════════════════════════════════════════════
//  LAYOUT & ANIMATION HELPERS
// ═══════════════════════════════════════════════

class BlobPainter extends CustomPainter {
  final Color color;
  final double sigma;
  const BlobPainter(this.color, {this.sigma = 55});
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawCircle(
      Offset(size.width / 2, size.height / 2), size.width / 2,
      Paint()..color = color..maskFilter = MaskFilter.blur(BlurStyle.normal, sigma),
    );
  }
  @override
  bool shouldRepaint(BlobPainter oldDelegate) => oldDelegate.color != color;
}

Widget blob(Color color, double sz, {double sigma = 55}) =>
    SizedBox(width: sz, height: sz, child: CustomPaint(painter: BlobPainter(color, sigma: sigma)));

class Reveal extends StatefulWidget {
  final Widget child;
  final double delay, dy;
  const Reveal({super.key, required this.child, this.delay = 0, this.dy = 28});
  @override
  State<Reveal> createState() => _RevealState();
}

class _RevealState extends State<Reveal> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _opacity, _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 850));
    _opacity = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut).drive(Tween(begin: 0.0, end: 1.0));
    _slide = CurvedAnimation(parent: _ctrl, curve: const Cubic(.2,.8,.2,1)).drive(Tween(begin: widget.dy, end: 0.0));
    Future.delayed(Duration(milliseconds: (widget.delay * 1000).toInt()), () { if (mounted) _ctrl.forward(); });
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _ctrl,
        child: widget.child,
        builder: (_, ch) => Opacity(opacity: _opacity.value, child: Transform.translate(offset: Offset(0, _slide.value), child: ch)),
      );
}

class FloatAnimation extends StatefulWidget {
  final Widget child;
  final Duration duration;
  const FloatAnimation({super.key, required this.child, this.duration = const Duration(seconds: 6)});
  @override
  State<FloatAnimation> createState() => _FloatAnimationState();
}

class _FloatAnimationState extends State<FloatAnimation> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _y;
  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: widget.duration)..repeat(reverse: true);
    _y = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut).drive(Tween(begin: 0.0, end: -12.0));
  }
  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
      animation: _y, child: widget.child,
      builder: (_, ch) => Transform.translate(offset: Offset(0, _y.value), child: ch));
}

// Section responsive wrapping shell
Widget sectionWrapper({
  required Widget child,
  Color? bgColor,
  Decoration? decoration,
  EdgeInsets? padding,
}) {
  return Builder(builder: (context) {
    final sw = MediaQuery.of(context).size.width;
    final isDesktop = sw > Breakpoints.tablet;
    final isTablet = sw >= 600 && sw <= 950;
    
    final defaultPadding = EdgeInsets.symmetric(
      horizontal: isDesktop ? 60 : (isTablet ? 40 : 24), 
      vertical: isDesktop ? 80 : 48,
    );

    return Container(
      color: bgColor,
      decoration: decoration,
      width: double.infinity,
      alignment: Alignment.center,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 1300),
        padding: padding ?? defaultPadding,
        child: child,
      ),
    );
  });
}

// ═══════════════════════════════════════════════
//  COMPONENTS: INTERACTIVE PHONE FRAME
// ═══════════════════════════════════════════════

class PhoneFrame extends StatelessWidget {
  final Widget child;
  final Color bgColor;
  final int activeIndex;
  final String? cardTitle;
  final String? cardDesc;

  const PhoneFrame({
    super.key, 
    required this.child, 
    this.bgColor = C.cream, 
    this.activeIndex = 0,
    this.cardTitle,
    this.cardDesc,
  });

  @override
  Widget build(BuildContext context) {
    final sw = MediaQuery.of(context).size.width;
    final isDesktop = sw > Breakpoints.tablet;
    
    // Calculate the scale to match the target width
    final double targetWidth = isDesktop ? 260.0 : (330.0 * (sw / 400).clamp(0.5, 0.85));
    final double scale = targetWidth / 330.0;
    final double baseWidth = 330.0;

    return Transform.scale(
      scale: scale,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.topCenter,
        children: [
          // Shadow casing
          Container(
            width: baseWidth, 
            height: baseWidth * 19 / 9,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(48),
              boxShadow: [
                BoxShadow(color: C.ink.withOpacity(0.15), blurRadius: 100, spreadRadius: 0, offset: const Offset(0, 40)),
              ],
            ),
          ),
          // The phone device
          Container(
            width: baseWidth,
            height: baseWidth * 19 / 9,
            decoration: BoxDecoration(
              color: C.ink,
              border: Border.all(color: Colors.white.withOpacity(0.12), width: 1.5),
              borderRadius: BorderRadius.circular(48),
            ),
            padding: const EdgeInsets.all(12),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(36),
              child: Navigator(
                onGenerateRoute: (settings) => MaterialPageRoute(
                  builder: (context) => Container(
                    color: bgColor,
                    child: Stack(
                      children: [
                        Column(
                          children: [
                            const SizedBox(height: 32),
                            const BlushyTopBar(),
                            Expanded(child: child),
                            BlushyBottomNav(activeIndex: activeIndex),
                          ],
                        ),
                        Positioned(
                          top: 14, left: 24,
                          child: Text("9:41", style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13, color: C.ink)),
                        ),
                        Positioned(
                          top: 10, left: 0, right: 0,
                          child: Center(
                            child: Container(
                              width: 100, height: 26,
                              decoration: BoxDecoration(color: C.ink, borderRadius: BorderRadius.circular(20)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ),
        // Floating Card
        if (cardTitle != null && cardDesc != null)
          Positioned(
            left: activeIndex % 2 == 0 ? -140 : null,
            right: activeIndex % 2 != 0 ? -140 : null,
            top: activeIndex % 2 == 0 ? 100 : 220,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.95),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: [BoxShadow(color: C.ink.withOpacity(0.1), blurRadius: 30, spreadRadius: -5, offset: const Offset(0, 12))],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(cardTitle!, style: T.e(c: C.red)),
                  const SizedBox(height: 8),
                  Text(cardDesc!, style: T.b(14, c: C.ink, w: FontWeight.w500, h: 1.5)),
                ]
              )
            )
          ),
      ],
    ),
    );
  }
}

// ═══════════════════════════════════════════════
//  IN-MOCKUP SCREEN WIDGETS
// ═══════════════════════════════════════════════

class CycleScreen extends StatefulWidget {
  const CycleScreen({super.key});
  @override
  State<CycleScreen> createState() => _CycleScreenState();
}
class _CycleScreenState extends State<CycleScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _arc;
  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500));
    _arc = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut).drive(Tween(begin: 0.0, end: 0.333));
    Future.delayed(const Duration(milliseconds: 300), () { if (mounted) _ctrl.forward(); });
  }
  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(11, 4, 11, 8),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Today · Jun 14', style: T.e(c: C.ink.withOpacity(0.45))),
      Text('Hi, Taara', style: T.d(17, c: C.ink)),
      const SizedBox(height: 8),
      Center(child: SizedBox(width: 100, height: 100, child: AnimatedBuilder(
        animation: _arc,
        builder: (_, __) => CustomPaint(
          painter: _RingPainter(_arc.value),
          child: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text('Day 12', style: T.d(18, c: C.ink)),
            Text('Follicular', style: T.e(c: C.red)),
          ])),
        ),
      ))),
      const SizedBox(height: 8),
      for (final r in [['Mood','Energetic'],['Symptoms','Light'],['Energy','High']]) ...[
        Divider(color: C.ink.withOpacity(0.09), thickness: 0.5),
        Padding(padding: const EdgeInsets.symmetric(vertical: 2.5), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(r[0], style: T.b(8.5, c: C.ink.withOpacity(0.55))),
          Text(r[1], style: T.b(8.5, c: C.ink, w: FontWeight.w600)),
        ])),
      ],
      const Spacer(),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: List.generate(4, (i) => Container(
        width: 5, height: 5, margin: const EdgeInsets.symmetric(horizontal: 1.5),
        decoration: BoxDecoration(shape: BoxShape.circle, color: i == 0 ? C.red : C.ink.withOpacity(0.18)),
      ))),
    ]),
  );
}

class _RingPainter extends CustomPainter {
  final double p;
  const _RingPainter(this.p);
  @override
  void paint(Canvas canvas, Size size) {
    final ctr = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2 - 5;
    canvas.drawCircle(ctr, r, Paint()..color = C.ink.withOpacity(0.07)..style = PaintingStyle.stroke..strokeWidth = 5.5);
    canvas.drawArc(Rect.fromCircle(center: ctr, radius: r), -math.pi / 2, 2 * math.pi * p, false,
        Paint()..color = C.red..style = PaintingStyle.stroke..strokeWidth = 5.5..strokeCap = StrokeCap.round);
    canvas.drawCircle(Offset(ctr.dx, ctr.dy - r), 3, Paint()..color = C.pink);
  }
  @override
  bool shouldRepaint(_RingPainter o) => o.p != p;
}

class CompanionScreen extends StatelessWidget {
  const CompanionScreen({super.key});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(9, 4, 9, 8),
    child: Column(children: [
      Row(children: [
        Container(width: 26, height: 26, decoration: const BoxDecoration(shape: BoxShape.circle, color: C.red),
          child: const Icon(Icons.auto_awesome, size: 13, color: C.cream)),
        const SizedBox(width: 7),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Blushy', style: T.d(11, c: C.ink)),
          Text('• online · knows you', style: T.b(7.5, c: C.red)),
        ]),
      ]),
      const SizedBox(height: 3),
      Divider(color: C.ink.withOpacity(0.08), thickness: 0.5, height: 1),
      const SizedBox(height: 8),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _msg('How are you feeling this morning, Taara?', me: false),
        const SizedBox(height: 5),
        _msg('A bit tired.', me: true),
        const SizedBox(height: 5),
        _msg("You're mid-cycle, energy dips a little here.", me: false),
        const SizedBox(height: 7),
        Row(children: [_chip("Yes, let's"), const SizedBox(width: 5), _chip('Later')]),
      ])),
      Container(
        margin: const EdgeInsets.only(top: 5),
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(border: Border.all(color: C.ink.withOpacity(0.13), width: 0.5), borderRadius: BorderRadius.circular(999), color: C.cream),
        child: Row(children: [Text('🎙', style: T.b(9)), const SizedBox(width: 4), Text('Speak to Blushy…', style: T.b(7.5, c: C.ink.withOpacity(0.45)))]),
      ),
    ]),
  );
  static Widget _msg(String t, {required bool me}) => Align(
    alignment: me ? Alignment.centerRight : Alignment.centerLeft,
    child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 148), child: Container(
      padding: const EdgeInsets.all(7),
      decoration: BoxDecoration(
        color: me ? C.red : C.ink.withOpacity(0.055),
        borderRadius: BorderRadius.only(topLeft: const Radius.circular(11), topRight: const Radius.circular(11),
          bottomLeft: Radius.circular(me ? 11 : 3), bottomRight: Radius.circular(me ? 3 : 11)),
      ),
      child: Text(t, style: T.b(8.5, c: me ? C.cream : C.ink)),
    )),
  );
  static Widget _chip(String l) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3.5),
    decoration: BoxDecoration(border: Border.all(color: C.ink.withOpacity(0.18), width: 0.5), borderRadius: BorderRadius.circular(999)),
    child: Text(l, style: T.b(7.5, c: C.ink)),
  );
}

class HealthScreen extends StatelessWidget {
  const HealthScreen({super.key});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(11, 4, 11, 8),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Health assistant', style: T.e(c: C.ink.withOpacity(0.45))),
      Text('Understanding\nyour symptoms', style: T.d(15, c: C.ink)),
      const SizedBox(height: 9),
      Container(padding: const EdgeInsets.all(9), decoration: BoxDecoration(border: Border.all(color: C.ink.withOpacity(0.10), width: 0.5), borderRadius: BorderRadius.circular(13)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Signals we noticed', style: T.e(c: C.ink.withOpacity(0.55))),
        const SizedBox(height: 5),
        for (final s in [['Cramps','Mild',C.red],['Sleep','7h 20m',C.pink],['Mood','Steady',C.yellow]])
          Padding(padding: const EdgeInsets.only(bottom: 4.5), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Row(children: [Container(width: 6, height: 6, decoration: BoxDecoration(shape: BoxShape.circle, color: s[2] as Color)), const SizedBox(width: 5), Text(s[0] as String, style: T.b(8.5, c: C.ink))]),
            Text(s[1] as String, style: T.b(8.5, c: C.ink, w: FontWeight.w600)),
          ])),
      ])),
      const SizedBox(height: 7),
      Container(padding: const EdgeInsets.all(9), decoration: BoxDecoration(color: C.yellow.withOpacity(0.18), borderRadius: BorderRadius.circular(13)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Evidence-based note', style: T.e(c: C.ink.withOpacity(0.55))),
        const SizedBox(height: 3),
        Text('These patterns are typical mid-cycle. Not a diagnosis.', style: T.b(8.5, c: C.ink)),
      ])),
      const Spacer(),
      Container(width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 9), decoration: BoxDecoration(color: C.ink, borderRadius: BorderRadius.circular(999)),
        child: Center(child: Text('Talk to a clinician →', style: T.b(8.5, c: C.cream)))),
    ]),
  );
}

class PartnerScreen extends StatelessWidget {
  const PartnerScreen({super.key});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(11, 4, 11, 8),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text('Partner mode', style: T.e(c: C.ink.withOpacity(0.45))),
        Row(children: [Container(width: 6, height: 6, decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFF22C55E))), const SizedBox(width: 3), Text('Shared', style: T.b(7.5, c: C.ink.withOpacity(0.65)))]),
      ]),
      Text('Today, together', style: T.d(15, c: C.ink)),
      const SizedBox(height: 9),
      Container(padding: const EdgeInsets.all(9), decoration: BoxDecoration(color: C.red, borderRadius: BorderRadius.circular(13)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('For Saahus', style: T.e(c: C.cream.withOpacity(0.75))),
        const SizedBox(height: 3),
        Text("She's in her luteal phase, a hug goes a long way today.", style: T.d(11.5, c: C.cream, h: 1.2)),
      ])),
      const SizedBox(height: 6),
      Container(padding: const EdgeInsets.all(9), decoration: BoxDecoration(border: Border.all(color: C.ink.withOpacity(0.13), width: 0.5), borderRadius: BorderRadius.circular(13)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Suggested tonight', style: T.e(c: C.ink.withOpacity(0.55))),
        const SizedBox(height: 3),
        for (final r in [['Slow walk','7:00 pm'],['Warm dinner','8:15 pm'],['Early rest','10:30 pm']])
          Padding(padding: const EdgeInsets.only(top: 3.5), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(r[0], style: T.b(8.5)), Text(r[1], style: T.b(8.5))])),
      ])),
      const Spacer(),
      Row(children: [Icon(Icons.lock_outline, size: 9, color: C.ink.withOpacity(0.55)), const SizedBox(width: 3), Text('She decides what to share. Always.', style: T.b(7.5, c: C.ink.withOpacity(0.55)))]),
    ]),
  );
}

class SleepScreen extends StatelessWidget {
  const SleepScreen({super.key});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(11, 4, 11, 8),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Sleep intelligence', style: T.e(c: C.ink.withOpacity(0.45))),
      Text('Last night', style: T.d(15, c: C.ink)),
      const SizedBox(height: 9),
      Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: C.ink, borderRadius: BorderRadius.circular(13)), child: Stack(children: [
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Sleep score', style: T.e(c: C.cream.withOpacity(0.65))),
          Text('82', style: T.d(34, c: C.cream)),
          Text('7h 24m · recovery high', style: T.b(8, c: C.cream.withOpacity(0.65))),
        ]),
        Positioned(right: -4, top: -4, child: Icon(Icons.nightlight_round, size: 44, color: C.yellow.withOpacity(0.28))),
      ])),
      const SizedBox(height: 5),
      Row(children: [
        for (final s in [['Deep','1h 42m'],['REM','1h 55m'],['Light','3h 47m']])
          Expanded(child: Container(margin: const EdgeInsets.only(right: 4), padding: const EdgeInsets.symmetric(vertical: 5.5), decoration: BoxDecoration(border: Border.all(color: C.ink.withOpacity(0.10), width: 0.5), borderRadius: BorderRadius.circular(9)), child: Column(children: [
            Text(s[0], style: T.e(c: C.ink.withOpacity(0.45))),
            const SizedBox(height: 1.5),
            Text(s[1], style: T.b(8, c: C.ink, w: FontWeight.w600)),
          ]))),
      ]),
      const SizedBox(height: 5),
      Container(padding: const EdgeInsets.all(9), decoration: BoxDecoration(color: C.yellow.withOpacity(0.22), borderRadius: BorderRadius.circular(13)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Cycle note', style: T.e(c: C.ink.withOpacity(0.55))),
        const SizedBox(height: 3),
        Text("Deep sleep dips in luteal. Wind down 20 min earlier.", style: T.b(8.5)),
      ])),
    ]),
  );
}

class IndiaScreen extends StatelessWidget {
  const IndiaScreen({super.key});
  static const _l = ['English','हिन्दी','ಕನ್ನಡ','தமிழ்','తెలుగు','मराठी','বাংলা','پنجابی','ગુજ.'];
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(11, 4, 11, 8),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Built for India', style: T.e(c: C.ink.withOpacity(0.45))),
      Text('Speak your language', style: T.d(15, c: C.ink)),
      const SizedBox(height: 9),
      GridView.count(crossAxisCount: 3, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), crossAxisSpacing: 3.5, mainAxisSpacing: 3.5, childAspectRatio: 2.5, children: List.generate(_l.length, (i) {
        final s = i == 1;
        return Container(
          decoration: BoxDecoration(color: s ? C.red : Colors.transparent, border: s ? null : Border.all(color: C.ink.withOpacity(0.13), width: 0.5), borderRadius: BorderRadius.circular(7)),
          child: Center(child: Text(_l[i], style: T.b(8, c: s ? C.cream : C.ink), textAlign: TextAlign.center, overflow: TextOverflow.ellipsis)),
        );
      })),
      const SizedBox(height: 7),
      Container(padding: const EdgeInsets.all(9), decoration: BoxDecoration(color: C.sand.withOpacity(0.38), borderRadius: BorderRadius.circular(13)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Blushy · in Hindi', style: T.e(c: C.ink.withOpacity(0.55))),
        const SizedBox(height: 3),
        Text('आज कैसा महसूस हो रहा है?', style: T.d(12.5, c: C.ink)),
        const SizedBox(height: 2),
        Text('Cultural fluency, not translation.', style: T.b(8, c: C.ink.withOpacity(0.55))),
      ])),
      const Spacer(),
      Center(child: Text('13+ Indian languages · Made in India', style: T.b(7, c: C.ink.withOpacity(0.45)), textAlign: TextAlign.center)),
    ]),
  );
}

// ═══════════════════════════════════════════════
//  COMPONENTS: NAVIGATION BAR (WEB RESPONSIVE)
// ═══════════════════════════════════════════════

class NavBar extends StatefulWidget {
  final ScrollController scrollController;
  final List<GlobalKey> sectionKeys;
  const NavBar({super.key, required this.scrollController, required this.sectionKeys});
  @override
  State<NavBar> createState() => _NavBarState();
}

class _NavBarState extends State<NavBar> {
  bool _scrolled = false, _open = false;
  static const _items = [
    ['Our Philosophy', 2],
    ['Platform', 3],
    ['How It Works', 4],
    ['Privacy', 5],
    ['Community', 6],
    ['Vision', 7],
  ];

  @override
  void initState() {
    super.initState();
    widget.scrollController.addListener(_onScroll);
  }
  void _onScroll() {
    final s = widget.scrollController.offset > 40;
    if (s != _scrolled) setState(() => _scrolled = s);
  }
  @override
  void dispose() {
    widget.scrollController.removeListener(_onScroll);
    super.dispose();
  }

  void _scrollTo(int index) {
    final ctx = widget.sectionKeys[index].currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(ctx, duration: const Duration(milliseconds: 650), curve: Curves.easeInOut);
    }
    setState(() => _open = false);
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isDesktop = width > 850;

    return Stack(children: [
      AnimatedContainer(
        duration: const Duration(milliseconds: 280),
        decoration: BoxDecoration(
          color: _scrolled ? C.cream.withOpacity(0.92) : Colors.transparent,
          border: _scrolled ? Border(bottom: BorderSide(color: C.ink.withOpacity(0.08), width: 0.5)) : null,
        ),
        alignment: Alignment.center,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 1200),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            // Logo
            GestureDetector(onTap: () => _scrollTo(0), child: Row(children: [
              Image.asset('assets/newblushy1.png', height: 26, fit: BoxFit.contain),
              const SizedBox(width: 8),
              Text('Blushy', style: T.d(22, c: C.ink)),
            ])),

            // Desktop Links
            if (isDesktop) Row(children: _items.map((it) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: GestureDetector(
                onTap: () => _scrollTo(it[1] as int),
                child: Text(it[0] as String, style: T.b(14, c: C.ink.withOpacity(0.8), w: FontWeight.w500)),
              ),
            )).toList()),

            // Right Button / Menu
            Row(children: [
              GestureDetector(
                onTap: _navigateToBeta,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                  decoration: BoxDecoration(color: C.red, borderRadius: BorderRadius.circular(999)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Text('Join Beta', style: T.b(13, c: C.cream, w: FontWeight.w600)),
                    const SizedBox(width: 5),
                    const Icon(Icons.arrow_outward, size: 14, color: C.cream),
                  ]),
                ),
              ),
              if (!isDesktop) ...[
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: () => setState(() => _open = true),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(borderRadius: BorderRadius.circular(999), border: Border.all(color: C.ink.withOpacity(0.18), width: 0.5)),
                    child: const Icon(Icons.menu, size: 17, color: C.ink),
                  ),
                ),
              ],
            ]),
          ]),
        ),
      ),
      // Mobile Drawer overlay
      if (_open && !isDesktop) Positioned.fill(child: Container(
        color: C.ink, padding: const EdgeInsets.all(28),
        child: SafeArea(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('Blushy', style: T.d(28, c: C.cream)),
            GestureDetector(onTap: () => setState(() => _open = false), child: const Icon(Icons.close, color: C.cream, size: 24)),
          ]),
          const SizedBox(height: 52),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: _items.map((item) =>
            GestureDetector(onTap: () => _scrollTo(item[1] as int), child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Text(item[0] as String, style: T.d(46, c: C.cream)),
            ))).toList())),
        ])),
      )),
    ]);
  }
}

// ═══════════════════════════════════════════════
//  LANDING PAGE SECTIONS (RESPONSIVE DESKTOP + MOBILE)
// ═══════════════════════════════════════════════

// — 01 HERO —
class HeroSection extends StatefulWidget {
  final VoidCallback? onMeetApp, onVision;
  const HeroSection({super.key, this.onMeetApp, this.onVision});
  @override
  State<HeroSection> createState() => _HeroSectionState();
}
class _HeroSectionState extends State<HeroSection> with SingleTickerProviderStateMixin {
  late final AnimationController _floatCtrl;
  late final Animation<double> _float;
  @override
  void initState() {
    super.initState();
    _floatCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 7))..repeat(reverse: true);
    _float = Tween<double>(begin: 0, end: -11).animate(CurvedAnimation(parent: _floatCtrl, curve: Curves.easeInOut));
  }
  @override
  void dispose() { _floatCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final sw = MediaQuery.of(context).size.width;
    final isDesktop = sw > 850;

    return Container(
      color: C.cream,
      width: double.infinity,
      child: Stack(children: [
        Positioned(top: -60, left: -60, child: blob(C.pink.withOpacity(0.65), 320, sigma: 70)),
        Positioned(top: 30, right: -60, child: blob(C.yellow.withOpacity(0.55), 280, sigma: 65)),
        Positioned(bottom: -50, left: sw * 0.3, child: blob(C.red.withOpacity(0.32), 260, sigma: 70)),

        sectionWrapper(
          padding: EdgeInsets.fromLTRB(24, isDesktop ? 160 : 110, 24, 70),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (isDesktop) Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
              Expanded(flex: 7, child: _leftContent()),
              const SizedBox(width: 48),
              Expanded(flex: 5, child: _rightPhone()),
            ]) else ...[
              _leftContent(),
              const SizedBox(height: 52),
              Center(child: _rightPhone()),
            ],
            const SizedBox(height: 40),
            Center(child: Column(children: [
              Text('Scroll', style: T.e(c: C.ink.withOpacity(0.42))),
              const SizedBox(height: 6),
              Container(width: 1, height: 24, color: C.ink.withOpacity(0.27)),
            ])),
          ]),
        ),
      ]),
    );
  }

  Widget _leftContent() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Reveal(delay: .25, child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(color: C.cream.withOpacity(0.6), border: Border.all(color: C.ink.withOpacity(0.18), width: 0.5), borderRadius: BorderRadius.circular(999)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 6, height: 6, decoration: const BoxDecoration(shape: BoxShape.circle, color: C.red)),
        const SizedBox(width: 8),
        Text("AI-powered women's wellness · India", style: T.e(c: C.ink)),
      ]),
    )),
    const SizedBox(height: 28),
    Reveal(delay: .35, child: RichText(text: TextSpan(
      style: T.d(64, c: C.ink, h: 1.0),
      children: [
        const TextSpan(text: 'Wellness,\n'),
        TextSpan(text: 'reimagined', style: T.d(64, c: C.red, it: true, h: 1.0)),
        const TextSpan(text: '\nfor her.'),
      ],
    ))),
    const SizedBox(height: 22),
    Reveal(delay: .55, child: Text(
      "Blushy is building the intelligent app for women's wellness. Emotionally aware, deeply personal, and unmistakably human.",
      style: T.b(16.5, c: C.ink.withOpacity(0.75)),
    )),
    const SizedBox(height: 28),
    Reveal(delay: .68, child: Wrap(spacing: 12, runSpacing: 12, children: [
      _CTA(label: 'Meet the app', icon: Icons.arrow_forward, onTap: widget.onMeetApp),
      _CTA(label: 'Our vision', ghost: true, onTap: widget.onVision),
    ])),
  ]);

  Widget _rightPhone() => Reveal(delay: .8, child: Center(child: AnimatedBuilder(
    animation: _float, child: const PhoneFrame(child: CycleScreen()),
    builder: (_, ch) => Transform.translate(offset: Offset(0, _float.value), child: ch),
  )));
}


// — SOCIAL PROOF BANNER —
class SocialProofBanner extends StatefulWidget {
  final ScrollController sc;
  const SocialProofBanner({super.key, required this.sc});

  @override
  State<SocialProofBanner> createState() => _SocialProofBannerState();
}

class _SocialProofBannerState extends State<SocialProofBanner> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  bool _hasTriggered = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500));
    _ctrl.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        Future.delayed(const Duration(seconds: 5), () {
          if (mounted) {
            _ctrl.forward(from: 0.0);
          }
        });
      }
    });
    widget.sc.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) => _onScroll());
  }

  void _onScroll() {
    if (_hasTriggered) return;
    final RenderBox? rb = context.findRenderObject() as RenderBox?;
    if (rb == null) return;
    
    final position = rb.localToGlobal(Offset.zero).dy;
    final screenHeight = MediaQuery.of(context).size.height;
    // Trigger if it's visible at all on the screen or if we've scrolled past it
    if (position < screenHeight) {
      _hasTriggered = true;
      _ctrl.forward();
    }
  }

  @override
  void dispose() {
    widget.sc.removeListener(_onScroll);
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sw = MediaQuery.of(context).size.width;
    final isDesktop = sw > 850;
    
    return Container(
      color: C.cream,
      width: double.infinity,
      padding: const EdgeInsets.only(top: 48, bottom: 24),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 1200),
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: isDesktop 
            ? Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(child: _statItem(1000, "+", "Women interviewed", isDesktop)),
                  Container(width: 1, height: 40, color: C.ink.withOpacity(0.15)),
                  Expanded(child: _statItem(120, "+", "Beta users", isDesktop)),
                  Container(width: 1, height: 40, color: C.ink.withOpacity(0.15)),
                  Expanded(child: _statItemStr("India First", "Built for Indian women", isDesktop)),
                ],
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _statItem(1000, "+", "Women\ninterviewed", isDesktop)),
                  Expanded(child: _statItem(120, "+", "Beta\nusers", isDesktop)),
                  Expanded(child: _statItemStr("India\nFirst", "Built for\nIndian women", isDesktop)),
                ],
              ),
        ),
      ),
    );
  }

  Widget _statItem(int targetVal, String suffix, String subtitle, bool isDesktop) {
    final sw = MediaQuery.of(context).size.width;
    final double numSize = TSize.statsNum(sw);
    final double labelSize = TSize.statsLabel(sw);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        AnimatedBuilder(
          animation: _ctrl,
          builder: (context, child) {
            int currentVal = (_ctrl.value * targetVal).round();
            return Text("$currentVal$suffix", textAlign: TextAlign.center, style: T.d(numSize, c: C.ink, h: 1.1));
          },
        ),
        const SizedBox(height: 4),
        Text(subtitle, textAlign: TextAlign.center, style: T.b(labelSize, c: C.ink.withOpacity(0.65), h: 1.3)),
      ],
    );
  }

  Widget _statItemStr(String title, String subtitle, bool isDesktop) {
    final sw = MediaQuery.of(context).size.width;
    final double numSize = TSize.statsNum(sw);
    final double labelSize = TSize.statsLabel(sw);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(title, textAlign: TextAlign.center, style: T.d(numSize, c: C.ink, h: 1.1)),
        const SizedBox(height: 4),
        Text(subtitle, textAlign: TextAlign.center, style: T.b(labelSize, c: C.ink.withOpacity(0.65), h: 1.3)),
      ],
    );
  }
}

// — 02 PROBLEM —
class ProblemSection extends StatefulWidget {
  final ScrollController sc;
  const ProblemSection({super.key, required this.sc});

  @override
  State<ProblemSection> createState() => _ProblemSectionState();
}

class _ProblemSectionState extends State<ProblemSection> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  bool _hasTriggered = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400));
    widget.sc.addListener(_onScroll);
  }

  void _onScroll() {
    if (_hasTriggered) return;
    final RenderBox? rb = context.findRenderObject() as RenderBox?;
    if (rb == null) return;
    
    final position = rb.localToGlobal(Offset.zero).dy;
    final screenHeight = MediaQuery.of(context).size.height;
    if (position < screenHeight * 0.85) {
      _hasTriggered = true;
      _ctrl.forward();
    }
  }

  @override
  void dispose() {
    widget.sc.removeListener(_onScroll);
    _ctrl.dispose();
    super.dispose();
  }

  Widget _reveal(int index, Widget child) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) {
        final double start = (index * 0.15).clamp(0.0, 1.0);
        final double end = (start + 0.4).clamp(0.0, 1.0);
        
        final double p = ((_ctrl.value - start) / (end - start)).clamp(0.0, 1.0);
        final double curveP = Curves.easeOutCubic.transform(p);
        
        return Opacity(
          opacity: curveP,
          child: Transform.translate(
            offset: Offset(0, 30 * (1 - curveP)),
            child: child,
          ),
        );
      },
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final sw = MediaQuery.of(context).size.width;
    final sh = MediaQuery.of(context).size.height;
    final isDesktop = sw >= Breakpoints.desktop;

    return sectionWrapper(
      bgColor: C.cream,
      padding: EdgeInsets.fromLTRB(
        sw > 850 ? 60 : 24,
        sw > 850 ? 80 : 20,
        sw > 850 ? 60 : 24,
        sw > 850 ? 80 : 40,
      ),
      child: isDesktop 
          ? IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 58, child: _leftHeadline(sw, sh)),
                  Align(
                    alignment: Alignment.center,
                    child: FractionallySizedBox(
                      heightFactor: 0.65,
                      child: Container(
                        width: 1,
                        margin: const EdgeInsets.symmetric(horizontal: 50),
                        color: C.ink.withOpacity(0.12),
                      ),
                    ),
                  ),
                  Expanded(flex: 42, child: _rightContent(sh)),
                ],
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _leftHeadline(sw, sh),
                const SizedBox(height: 24),
                Center(child: _rightContent(sh)),
              ],
            ),
    );
  }

  double _getHeadlineSize(double sw, double sh) {
    double size = sw > 1400 ? 44 : (sw > 1100 ? 38 : (sw > 700 ? 34 : 26));
    double maxSizeByHeight = (sh - 100) / 10.5;
    if (size > maxSizeByHeight && sw > 700) return maxSizeByHeight;
    return size;
  }

  Widget _leftHeadline(double sw, double sh) {
    final size = _getHeadlineSize(sw, sh);
    return _reveal(0, Padding(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RichText(
            text: TextSpan(
              style: T.d(size, c: C.ink, h: 1.15),
              children: [
                const TextSpan(text: "Every woman lives one story.\n\nSo why is it scattered across "),
                TextSpan(
                  text: "five different apps?",
                  style: T.d(size, c: C.red, h: 1.2).copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          SizedBox(height: sw > 850 ? 76 : 28),
          // Quote
          Container(
            padding: EdgeInsets.symmetric(horizontal: sw > 850 ? 20 : 14, vertical: sw > 850 ? 16 : 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: C.ink.withOpacity(0.06)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "\"I wasn't looking for another period tracker. I was looking for something that finally understood my everyday life.\"",
                  style: T.b(sw > 850 ? 16.5 : 13.0, c: C.ink, h: sw > 850 ? 1.55 : 1.35, it: true),
                ),
                SizedBox(height: sw > 850 ? 12 : 6),
                Text(
                  "Early Beta User",
                  style: T.b(sw > 850 ? 13.5 : 11.0, c: C.ink.withOpacity(0.5)),
                ),
              ],
            ),
          ),
        ],
      ),
    ));
  }

  Widget _rightContent(double sh) {
    final double gap1 = sh > 800 ? 16 : 12;
    final double gap2 = sh > 800 ? 28 : 16;
    final double pSize = TSize.body(MediaQuery.of(context).size.width, 16);

    return Container(
      constraints: const BoxConstraints(maxWidth: 420),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _reveal(1, Text("THE BLUSHY DIFFERENCE", style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 3.0,
            color: C.red,
          ))),
          SizedBox(height: gap1),
          _reveal(2, Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDifferenceBullet("Your cycle."),
              _buildDifferenceBullet("Your thoughts."),
              _buildDifferenceBullet("Your AI companion."),
              _buildDifferenceBullet("Your partner."),
              _buildDifferenceBullet("Your community."),
            ],
          )),
          SizedBox(height: gap2),
          _reveal(3, Text(
            "They're not separate features.\n\nThey're chapters of the same journey.",
            style: T.b(pSize, c: C.ink.withOpacity(0.8), h: 1.4, it: true),
          )),
          SizedBox(height: gap2),
          _reveal(4, Text(
            "Blushy brings every chapter together, beautifully, privately, and intelligently.",
            style: T.b(pSize, c: C.ink, h: 1.4, w: FontWeight.bold),
          )),
          SizedBox(height: gap2),
          _reveal(5, Text(
            "One journey. One place. Blushy.",
            style: T.b(15, c: C.red, w: FontWeight.w600),
          )),
        ],
      ),
    );
  }

  Widget _buildDifferenceBullet(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(width: 4, height: 4, decoration: const BoxDecoration(color: C.red, shape: BoxShape.circle)),
          const SizedBox(width: 10),
          Text(text, style: T.b(15, c: C.ink, w: FontWeight.w500)),
        ],
      ),
    );
  }
}
// — 03 OUR PHILOSOPHY —
class PhilosophySection extends StatefulWidget {
  const PhilosophySection({super.key});

  @override
  State<PhilosophySection> createState() => _PhilosophySectionState();
}

class _PhilosophySectionState extends State<PhilosophySection> {
  @override
  Widget build(BuildContext context) {
    final sw = MediaQuery.of(context).size.width;
    final isDesktop = sw > Breakpoints.tablet;

    return sectionWrapper(
      bgColor: C.cream,
      padding: isDesktop ? null : const EdgeInsets.only(top: 48, bottom: 0, left: 24, right: 24),
      child: isDesktop 
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(flex: 5, child: _imageBox(isDesktop)),
                const SizedBox(width: 80),
                Expanded(flex: 7, child: _contentBox(isDesktop)),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _imageBox(isDesktop),
                Transform.translate(
                  offset: const Offset(0, -24),
                  child: Container(
                    decoration: BoxDecoration(
                      color: C.cream,
                      borderRadius: const BorderRadius.only(topRight: Radius.circular(24)),
                    ),
                    padding: const EdgeInsets.only(top: 24, right: 16),
                    child: _contentBox(isDesktop),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _imageBox(bool isDesktop) => Reveal(
    delay: .1, 
    child: ClipRRect(
      borderRadius: BorderRadius.circular(20), 
      child: isDesktop 
        ? AspectRatio(
            aspectRatio: 1.0,
            child: Image.asset('assets/nithyablushy.png', fit: BoxFit.cover),
          )
        : Image.asset('assets/nithyablushy.png', fit: BoxFit.contain),
    )
  );

  Widget _contentBox(bool isDesktop) {
    return Container(
      constraints: BoxConstraints(maxWidth: isDesktop ? 680 : 480),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Reveal(child: Text('OUR PHILOSOPHY', style: T.e(c: C.red))),
          const SizedBox(height: 12),
          Reveal(delay: .2, child: RichText(text: TextSpan(style: T.d(TSize.sectionTitle(MediaQuery.of(context).size.width, 36), c: C.ink, h: 1.15), children: [
            const TextSpan(text: 'We believe '),
            TextSpan(text: 'understanding', style: TextStyle(color: C.red, fontStyle: FontStyle.italic, fontFamily: GoogleFonts.playfairDisplay().fontFamily)),
            const TextSpan(text: ' comes before advice.'),
          ]))),
          const SizedBox(height: 24),
          
          // Side-by-side layout on desktop
          isDesktop
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 5, child: _buildManifestoQuote()),
                  const SizedBox(width: 48),
                  Expanded(flex: 5, child: _buildThreePrinciples()),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildManifestoQuote(),
                  const SizedBox(height: 32),
                  _buildThreePrinciples(),
                ],
              ),
          
          const SizedBox(height: 24),
          
          // Closing statement
          Reveal(delay: .5, child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Understanding isn't a feature.",
                style: T.b(15, c: C.ink, h: 1.4, w: FontWeight.bold),
              ),
              const SizedBox(height: 2),
              Text(
                "It's the foundation of everything we build.",
                style: T.b(15, c: C.red, h: 1.4, w: FontWeight.bold).copyWith(fontStyle: FontStyle.italic),
              ),
            ],
          )),
        ],
      )
    );
  }

  Widget _buildManifestoQuote() {
    return Reveal(
      delay: .3,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildManifestoLine("Before we help,\nwe listen."),
          const SizedBox(height: 12),
          _buildManifestoLine("Before we predict,\nwe understand."),
          const SizedBox(height: 12),
          _buildManifestoLine("Before we build,\nwe remember who we're building for."),
          const SizedBox(height: 12),
          Text(
            "Women.",
            style: T.d(26, c: C.red).copyWith(fontStyle: FontStyle.italic, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildManifestoLine(String text) {
    return Text(
      text,
      style: T.b(15, c: C.ink.withOpacity(0.85), h: 1.35, w: FontWeight.w500),
    );
  }

  Widget _buildThreePrinciples() {
    return Reveal(
      delay: .4,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildPrincipleItem("Listen", "Every conversation starts with your story."),
          const SizedBox(height: 16),
          _buildPrincipleItem("Understand", "Your journal, cycle and emotions become one living context."),
          const SizedBox(height: 16),
          _buildPrincipleItem("Protect", "You decide what stays private and what gets shared."),
        ],
      ),
    );
  }

  Widget _buildPrincipleItem(String title, String desc) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: T.d(17, c: C.ink).copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(desc, style: T.b(13, c: C.ink.withOpacity(0.65), h: 1.35)),
      ],
    );
  }
}


// — 04 PLATFORM —
class PlatformSection extends StatefulWidget {
  const PlatformSection({super.key});
  @override
  State<PlatformSection> createState() => _PlatformSectionState();
}
class _PlatformSectionState extends State<PlatformSection> {
  int _idx = 0;
  final List<GlobalKey> _itemKeys = List.generate(6, (_) => GlobalKey());
  static final _ps = [
    {
      'n': 'Cycle Intelligence',
      'tag': '01',
      'c': C.red,
      'ic': Icons.auto_awesome_outlined,
      'tl': "An adaptive AI engine that learns each woman's unique cycle.",
      's': const ScreenWelcome(isDemoMode: true),
    },
    {
      'n': 'Community',
      'tag': '02',
      'c': C.pink,
      'ic': Icons.forum_outlined,
      'tl': "Share questions, stories, and guidance in a safe, supportive space.",
      's': const ScreenCommunity(),
    },
    {
      'n': 'Sia AI Companion',
      'tag': '03',
      'c': Color(0xFFFF4A00),
      'ic': Icons.chat_bubble_outline,
      'tl': "Ask questions, get phase-aware guidance, and access doctor-reviewed resources.",
      's': const ScreenAI(isDemoMode: true),
    },
    {
      'n': 'Creative Journal',
      'tag': '04',
      'c': C.red,
      'ic': Icons.edit_note_outlined,
      'tl': "Express yourself with voice or text journals, mood tracking, and scrapbook stamps.",
      's': const ScreenVoice(isDemoMode: true),
    },
    {
      'n': 'Partner Mode',
      'tag': '05',
      'c': C.pink,
      'ic': Icons.favorite_outline,
      'tl': "A shared experience for couples, synchronized under her complete control.",
      's': const ScreenPartner(initialView: 1, isDemoMode: true),
    },
    {
      'n': 'Built for India',
      'tag': '06',
      'c': C.yellow,
      'ic': Icons.language_outlined,
      'tl': "Context that speaks her language.",
      's': const SizedBox.shrink(),
    },
  ];

  @override
  Widget build(BuildContext context) {
    final cur = _ps[_idx];
    final isDesktop = MediaQuery.of(context).size.width > Breakpoints.tablet;

    return sectionWrapper(
      bgColor: C.ink,
      padding: isDesktop ? null : const EdgeInsets.only(top: 16, bottom: 48, left: 24, right: 24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Reveal(child: Text('THE PLATFORM', style: T.e(c: C.red))),
        const SizedBox(height: 14),
        Reveal(delay: .1, child: RichText(text: TextSpan(style: T.d(TSize.display(MediaQuery.of(context).size.width, 44), c: C.cream, h: 1.05), children: const [
          TextSpan(text: 'One intelligence. '),
          TextSpan(text: 'Five\nexperiences.', style: TextStyle(color: C.orange, fontStyle: FontStyle.italic)),
        ]))),
        const SizedBox(height: 32),
        if (isDesktop) Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(flex: 7, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _itemsList(isDesktop),
            const SizedBox(height: 24),
            Text(cur['tl'] as String, style: T.b(16.5, c: C.cream.withOpacity(0.85))),
          ])),
          const SizedBox(width: 64),
          Expanded(flex: 5, child: _phoneSwitcher(isDesktop)),
        ]) else ...[
          _itemsList(isDesktop),
        ],
      ]),
    );
  }

  Widget _itemsList(bool isDesktop) => Column(children: [
    for (var i = 0; i < _ps.length; i++) InkWell(
      key: _itemKeys[i],
      onHover: (h) { if (h && isDesktop) setState(() => _idx = i); },
      onTap: () {
        setState(() => _idx = i);
        if (!isDesktop) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Future.delayed(const Duration(milliseconds: 320), () {
              final ctx = _itemKeys[i].currentContext;
              if (ctx != null) {
                Scrollable.ensureVisible(
                  ctx,
                  duration: const Duration(milliseconds: 400),
                  curve: Curves.easeInOut,
                  alignment: 0.0,
                );
              }
            });
          });
        }
      },
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Divider(color: C.cream.withOpacity(0.14), thickness: 0.5),
          Padding(padding: const EdgeInsets.symmetric(vertical: 12), child: Row(children: [
            Text(_ps[i]['tag'] as String, style: T.b(10, c: i == _idx ? _ps[i]['c'] as Color : C.cream.withOpacity(0.45))),
            const SizedBox(width: 12),
            Icon(_ps[i]['ic'] as IconData, size: 18, color: i == _idx ? _ps[i]['c'] as Color : C.cream.withOpacity(0.38)),
            const SizedBox(width: 12),
            Expanded(child: Text(_ps[i]['n'] as String, style: i == _idx
              ? T.d(28, c: _ps[i]['c'] as Color, it: true)
              : T.d(28, c: C.cream.withOpacity(0.48)))),
            Icon(i == _idx ? Icons.arrow_outward : Icons.arrow_upward, size: 18, color: i == _idx ? _ps[i]['c'] as Color : C.cream.withOpacity(0.28)),
          ])),
          AnimatedSize(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            child: (!isDesktop && i == _idx) ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),
                Text(_ps[i]['tl'] as String, style: T.b(15.5, c: C.cream.withOpacity(0.78))),
                const SizedBox(height: 24),
                Center(child: _phoneSwitcher(isDesktop)),
                const SizedBox(height: 24),
              ],
            ) : const SizedBox.shrink(),
          ),
        ]),
      ),
    Divider(color: C.cream.withOpacity(0.14), thickness: 0.5),
  ]);

  Widget _phoneSwitcher(bool isDesktop) {
    if (isDesktop) {
      return SizedBox(
        height: 520,
        child: OverflowBox(
          maxHeight: 680,
          alignment: Alignment.topCenter,
          child: Transform.translate(
            offset: const Offset(0, -170),
            child: PlatformKeynotePhone(
              activeIndex: _idx,
            ),
          ),
        ),
      );
    }
    return PlatformKeynotePhone(
      activeIndex: _idx,
    );
  }
}

// — 05 HOW IT WORKS —
class HowItWorksSection extends StatelessWidget {
  const HowItWorksSection({super.key});
  static const _steps = [
    ['Listen', 'She speaks naturally, through symptoms, moods, voice notes, and journals.'],
    ['Understand', 'Blushy connects her cycle, emotions, sleep, and habits into one complete picture.'],
    ['Personalize', 'Insights, reminders, and guidance adapt to her unique body, not generic averages.'],
    ['Connect', 'She discovers trusted stories, community support, and shared experiences when she needs them.'],
    ['Grow', 'Every cycle makes Blushy smarter about her, offering deeper support over time.']
  ];

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 1024;

    return sectionWrapper(
      bgColor: C.cream,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Reveal(child: Text('HOW IT WORKS', style: T.e(c: C.red))),
        const SizedBox(height: 18),
        Reveal(delay: .1, child: RichText(text: TextSpan(style: T.d(TSize.display(MediaQuery.of(context).size.width, 42), c: C.ink, h: 1.05), children: const [
          TextSpan(text: 'An intelligence that '),
          TextSpan(text: 'grows with her.', style: TextStyle(color: C.red, fontStyle: FontStyle.italic)),
        ]))),
        const SizedBox(height: 32),
        if (isDesktop) IntrinsicHeight(
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: _steps.asMap().entries.map((e) =>
            Expanded(child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Reveal(delay: .07 * e.key, child: _stepCard(context, e.key, e.value[0], e.value[1], isDesktop)),
            ))
          ).toList()),
        ) else Column(children: _steps.asMap().entries.map((e) =>
          Reveal(delay: .07 * e.key, child: Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: _stepCard(context, e.key, e.value[0], e.value[1], isDesktop),
          ))
        ).toList()),
      ]),
    );
  }

  Widget _stepCard(BuildContext context, int index, String title, String body, bool isDesktop) => Container(
    constraints: isDesktop ? const BoxConstraints(minHeight: 190) : null,
    padding: EdgeInsets.all(isDesktop ? 16 : 24),
    decoration: BoxDecoration(
      color: C.cream,
      border: Border.all(color: C.ink.withOpacity(0.13), width: 0.5),
      borderRadius: BorderRadius.circular(24),
    ),
    child: Stack(children: [
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('Step 0${index + 1}', style: T.e(c: C.ink.withOpacity(0.52))),
          Container(width: 7, height: 7, decoration: const BoxDecoration(shape: BoxShape.circle, color: C.red)),
        ]),
        const SizedBox(height: 32),
        Text(title, style: T.d(TSize.display(MediaQuery.of(context).size.width, 24), c: C.ink)),
        const SizedBox(height: 6),
        Text(body, style: T.b(12.5, c: C.ink.withOpacity(0.72))),
      ]),
      Positioned(right: -26, bottom: -26, child: SizedBox(width: 90, height: 90,
        child: CustomPaint(painter: BlobPainter(C.pink.withOpacity(0.30), sigma: 28)))),
    ]),
  );
}

// — 06 PRIVACY & TRUST —
class PrivacySection extends StatelessWidget {
  const PrivacySection({super.key});
  static const _items = [
    ['Built to listen', 'So you can be completely honest.'],
    ['Built to protect', 'So your most personal moments stay personal.'],
    ['Built to respect', 'Every choice is yours. Never assumed.'],
    ['Built to care', 'Technology should support people, never replace them.']
  ];

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 1024;
    final isTablet = MediaQuery.of(context).size.width >= 600 && MediaQuery.of(context).size.width < 1024;

    return sectionWrapper(
      bgColor: C.roseBg,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Reveal(child: Text('PRIVACY & TRUST', style: T.e(c: C.red))),
        const SizedBox(height: 20),
        if (isDesktop) Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(flex: 6, child: _headerTitle(context)),
          const SizedBox(width: 48),
          Expanded(flex: 6, child: _headerDesc()),
        ]) else ...[
          _headerTitle(context),
          const SizedBox(height: 16),
          _headerDesc(),
        ],
        const SizedBox(height: 36),
        if (isDesktop) Column(children: [
          Row(children: [
            Expanded(child: Reveal(delay: .05, child: _cardBox(_items[0][0], _items[0][1], isDesktop))),
            const SizedBox(width: 16),
            Expanded(child: Reveal(delay: .1, child: _cardBox(_items[1][0], _items[1][1], isDesktop))),
          ]),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: Reveal(delay: .15, child: _cardBox(_items[2][0], _items[2][1], isDesktop))),
            const SizedBox(width: 16),
            Expanded(child: Reveal(delay: .2, child: _cardBox(_items[3][0], _items[3][1], isDesktop))),
          ]),
        ]) else Column(children: _items.asMap().entries.map((e) =>
          Reveal(delay: .07 * e.key, child: Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: _cardBox(e.value[0], e.value[1], isDesktop),
          ))
        ).toList()),
      ]),
    );
  }

  Widget _headerTitle(BuildContext context) => RichText(text: TextSpan(style: T.d(TSize.display(MediaQuery.of(context).size.width, 48), c: C.ink, h: 1.05), children: const [
    TextSpan(text: 'Trust isn\'t given.\n'),
    TextSpan(text: 'It\'s designed.', style: TextStyle(color: C.red, fontStyle: FontStyle.italic)),
  ]));

  Widget _headerDesc() => Padding(
    padding: const EdgeInsets.only(top: 8),
    child: Text("The most personal product you'll ever use should disappear into the background, protecting your privacy without asking you to think about it.", style: T.b(16.5, c: C.ink.withOpacity(0.78))),
  );

  Widget _cardBox(String t, String d, bool isDesktop) => Container(
    padding: EdgeInsets.all(isDesktop ? 20 : 24),
    decoration: BoxDecoration(color: C.cream.withOpacity(0.85), borderRadius: BorderRadius.circular(24), border: Border.all(color: C.ink.withOpacity(0.08), width: 0.5)),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(padding: const EdgeInsets.only(top: 2), child: Icon(Icons.lock_outline, size: 19, color: C.red)),
      const SizedBox(width: 16),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(t, style: T.d(22, c: C.ink)),
        const SizedBox(height: 6),
        Text(d, style: T.b(14, c: C.ink.withOpacity(0.72))),
      ])),
    ]),
  );
}

// — 07 COMMUNITY —
class CommunitySection extends StatelessWidget {
  const CommunitySection({super.key});
  static const _p = [
    ['Shared Experiences', 'Real stories organized by life stage and symptoms, so support is always relevant.'],
    ['Expert Reviewed', 'Every educational post and health insight is reviewed, keeping conversations responsible.'],
    ['Safe Conversations', 'Thoughtful moderation and clear standards create a space where women feel comfortable.'],
    ['Ask Together', 'Learn from community discussions or ask anonymously when you need guidance.'],
    ['Support That Understands', 'Find women navigating similar cycles, fertility journeys, PCOS, or menopause.'],
    ['Privacy Always First', 'Share only what you choose. Personal health data is never exposed.']
  ];

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 1024;

    return sectionWrapper(
      bgColor: C.cream,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Reveal(child: Text('COMMUNITY', style: T.e(c: C.red))),
        const SizedBox(height: 18),
        Reveal(delay: .1, child: RichText(text: TextSpan(style: T.d(TSize.display(MediaQuery.of(context).size.width, 42), c: C.ink, h: 1.05), children: const [
          TextSpan(text: 'A community built '),
          TextSpan(text: 'on trust, not noise.', style: TextStyle(color: C.red, fontStyle: FontStyle.italic)),
        ]))),
        const SizedBox(height: 32),
        if (isDesktop) Column(children: [
          Row(children: [
            Expanded(child: Reveal(delay: .05, child: PillarCard(i: 0, t: _p[0][0], d: _p[0][1]))),
            const SizedBox(width: 16),
            Expanded(child: Reveal(delay: .1, child: PillarCard(i: 1, t: _p[1][0], d: _p[1][1]))),
            const SizedBox(width: 16),
            Expanded(child: Reveal(delay: .15, child: PillarCard(i: 2, t: _p[2][0], d: _p[2][1]))),
          ]),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: Reveal(delay: .2, child: PillarCard(i: 3, t: _p[3][0], d: _p[3][1]))),
            const SizedBox(width: 16),
            Expanded(child: Reveal(delay: .25, child: PillarCard(i: 4, t: _p[4][0], d: _p[4][1]))),
            const SizedBox(width: 16),
            Expanded(child: Reveal(delay: .3, child: PillarCard(i: 5, t: _p[5][0], d: _p[5][1]))),
          ]),
        ]) else Wrap(spacing: 12, runSpacing: 12, children: List.generate(_p.length, (i) =>
          Reveal(delay: .05 * i, child: PillarCard(i: i, t: _p[i][0], d: _p[i][1])))),
      ]),
    );
  }
}

class PillarCard extends StatefulWidget {
  final int i; final String t, d;
  const PillarCard({super.key, required this.i, required this.t, required this.d});
  @override
  State<PillarCard> createState() => _PillarCardState();
}
class _PillarCardState extends State<PillarCard> {
  bool _h = false;
  @override
  Widget build(BuildContext context) {
    final sw = MediaQuery.of(context).size.width;
    final isDesktop = sw >= 1024;
    final isMobile = sw < 600;
    final w = isDesktop ? double.infinity : (isMobile ? double.infinity : (sw - 60) / 2);

    return GestureDetector(
      onTapDown: (_) => setState(() => _h = true),
      onTapUp: (_) => setState(() => _h = false),
      onTapCancel: () => setState(() => _h = false),
      child: MouseRegion(
        onEnter: (_) => setState(() => _h = true),
        onExit: (_) => setState(() => _h = false),
        child: SizedBox(
          width: w,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 260),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: _h ? C.ink : Colors.transparent, border: Border.all(color: C.ink.withOpacity(0.15), width: 0.5), borderRadius: BorderRadius.circular(22)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text('0${widget.i+1}', style: T.e(c: _h ? C.cream.withOpacity(0.65) : C.ink.withOpacity(0.65))),
                Icon(Icons.arrow_outward, size: 14, color: _h ? C.cream.withOpacity(0.65) : C.ink.withOpacity(0.65)),
              ]),
              const SizedBox(height: 36),
              Text(widget.t, style: T.d(22, c: _h ? C.cream : C.ink)),
              const SizedBox(height: 6),
              Text(widget.d, style: T.b(13.5, c: _h ? C.cream.withOpacity(0.78) : C.ink.withOpacity(0.72))),
            ]),
          ),
        ),
      ),
    );
  }
}

// — 08 VISION —
class VisionSection extends StatelessWidget {
  const VisionSection({super.key});
  @override
  Widget build(BuildContext context) {
    return sectionWrapper(
      bgColor: C.red,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(top: -120, right: -120, child: blob(C.sand.withOpacity(0.38), 280, sigma: 65)),
          Positioned(bottom: -120, left: -120, child: blob(C.yellow.withOpacity(0.32), 250, sigma: 60)),
          SizedBox(
            width: double.infinity,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Reveal(child: Text('OUR VISION', style: T.e(c: C.cream.withOpacity(0.7)))),
              const SizedBox(height: 24),
              Reveal(delay: .15, child: RichText(text: TextSpan(style: T.d(TSize.display(MediaQuery.of(context).size.width, 52), c: C.cream, h: 1.05), children: const [
                TextSpan(text: 'A world where every woman never has to navigate '),
                TextSpan(text: 'her health alone.', style: TextStyle(fontStyle: FontStyle.italic)),
              ]))),
              const SizedBox(height: 28),
              Reveal(delay: .45, child: Text(
                "India is where we begin, not because it's the easiest place to build, but because it's where we're needed most.\n\nOur vision is simple: create something worthy of the trust of Indian women, then take that trust to the world.",
                style: T.d(17.5, c: C.cream.withOpacity(0.85), it: true, h: 1.35),
              )),
            ]),
          ),
        ],
      ),
    );
  }
}


// — 10 CONTACT —
class ContactSection extends StatelessWidget {
  final VoidCallback? onBackToTop;
  const ContactSection({super.key, this.onBackToTop});
  static const _ch = [
    ['General','info@blushy.life', 'mailto:info@blushy.life'],
    ['Founder & CEO','ceo@blushy.life', 'mailto:ceo@blushy.life'],
    ['Instagram','heyblushy', 'https://www.instagram.com/heyblushy/'],
    ['LinkedIn','Blushy.life', 'https://www.linkedin.com/company/blushy-life/']
  ];

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 900;
    final isTablet = MediaQuery.of(context).size.width >= 600 && MediaQuery.of(context).size.width < 900;

    return Container(
      color: C.ink,
      width: double.infinity,
      alignment: Alignment.center,
      child: Stack(children: [
        Positioned(top: -50, right: -50, child: blob(C.red.withOpacity(0.22), 240, sigma: 58)),
        Positioned(bottom: -50, left: -50, child: blob(C.sand.withOpacity(0.10), 210, sigma: 55)),
        sectionWrapper(
          padding: EdgeInsets.fromLTRB(isDesktop ? 60 : (isTablet ? 40 : 24), 54, isDesktop ? 60 : (isTablet ? 40 : 24), 24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Reveal(child: Text('CONTACT', style: T.e(c: C.cream.withOpacity(0.45)))),
            const SizedBox(height: 18),
            if (isDesktop) Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(flex: 5, child: _headerTitle(context)),
              const SizedBox(width: 48),
              Expanded(flex: 7, child: _linksGrid(context, 2)),
            ]) else ...[
              _headerTitle(context),
              const SizedBox(height: 32),
              _linksGrid(context, 1),
            ],
            const SizedBox(height: 32),
            if (isDesktop) Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, crossAxisAlignment: CrossAxisAlignment.end, children: [
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                RichText(text: TextSpan(style: TextStyle(fontFamily: 'Ada Hybrid', fontSize: 44, color: C.red, height: 1.0, letterSpacing: 4), children: const [TextSpan(text: 'BLUSHY'), TextSpan(text: '.', style: TextStyle(color: C.orange))])),
                const SizedBox(height: 8),
                Text("Care that understands her.\nBuilt in India for every woman, every stage, every day.", style: T.b(13.5, c: C.cream.withOpacity(0.60))),
              ]),
              _CTA(label: 'Back to top ↑', variant: BtnVariant.red, onTap: onBackToTop),
            ]) else Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              RichText(text: TextSpan(style: TextStyle(fontFamily: 'Ada Hybrid', fontSize: 44, color: C.red, height: 1.0, letterSpacing: 4), children: const [TextSpan(text: 'BLUSHY'), TextSpan(text: '.', style: TextStyle(color: C.orange))])),
              const SizedBox(height: 8),
              Text("Care that understands her.\nBuilt in India for every woman, every stage, every day.", style: T.b(13.5, c: C.cream.withOpacity(0.60))),
              const SizedBox(height: 24),
              _CTA(label: 'Back to top ↑', variant: BtnVariant.red, onTap: onBackToTop),
            ]),
            const SizedBox(height: 24),
            Divider(color: C.cream.withOpacity(0.12), thickness: 0.5),
            const SizedBox(height: 14),
            Wrap(spacing: 24, runSpacing: 12, alignment: WrapAlignment.spaceBetween, children: [
              Text('© ${DateTime.now().year} Blushy Healthcare Pvt Ltd.', style: T.b(12, c: C.cream.withOpacity(0.55))),
              Wrap(spacing: 16, children: ['Privacy','Terms','Safety'].map((t) => Text(t, style: T.b(12, c: C.cream.withOpacity(0.55)))).toList()),
            ]),
          ]),
        ),
      ]),
    );
  }

  Widget _headerTitle(BuildContext context) => RichText(text: TextSpan(style: T.d(TSize.display(MediaQuery.of(context).size.width, 48), c: C.cream, h: 1.05), children: const [
    TextSpan(text: "Let's build the\nfuture of\n"),
    TextSpan(text: 'her wellness.', style: TextStyle(color: C.orange, fontStyle: FontStyle.italic)),
  ]));

  Widget _linksGrid(BuildContext context, int crossAxisCount) {
    if (crossAxisCount == 1) {
      return Column(
        children: _ch.map((item) => Padding(
          padding: const EdgeInsets.only(bottom: 24),
          child: _linkItem(context, item[0], item[1], item[2]),
        )).toList(),
      );
    }
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _ch.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 2.2,
      ),
      itemBuilder: (_, i) => _linkItem(context, _ch[i][0], _ch[i][1], _ch[i][2]),
    );
  }

  Widget _linkItem(BuildContext context, String title, String val, String url) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
      Text(title, style: T.e(c: C.cream.withOpacity(0.55))),
      const SizedBox(height: 4),
      GestureDetector(
        onTap: () async {
          Clipboard.setData(ClipboardData(text: val));
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Copied $val'), backgroundColor: C.red, duration: const Duration(seconds: 2)));
          try {
            final uri = Uri.parse(url);
            if (await canLaunchUrl(uri)) {
              await launchUrl(uri, mode: LaunchMode.externalApplication);
            }
          } catch (_) {}
        },
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(children: [
            Expanded(child: Text(val, style: T.d(TSize.body(MediaQuery.of(context).size.width, 18), c: C.cream), overflow: TextOverflow.ellipsis)),
            const SizedBox(width: 4),
            Icon(Icons.arrow_outward, size: 14, color: C.sand),
          ]),
        ),
      ),
      const SizedBox(height: 8),
      Divider(color: C.cream.withOpacity(0.12), thickness: 0.5),
    ]);
  }
}

// ═══════════════════════════════════════════════
//  CTA BUTTON VARIANT HOOKS
// ═══════════════════════════════════════════════

enum BtnVariant { primary, red, ghost }

class _CTA extends StatefulWidget {
  final String label;
  final IconData? icon;
  final bool ghost;
  final BtnVariant variant;
  final VoidCallback? onTap;
  const _CTA({required this.label, this.icon, this.ghost = false, this.variant = BtnVariant.primary, this.onTap});
  @override
  State<_CTA> createState() => _CTAState();
}
class _CTAState extends State<_CTA> with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late final Animation<double> _s;
  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 130));
    _s = Tween(begin: 1.0, end: 0.955).animate(CurvedAnimation(parent: _c, curve: Curves.easeOut));
  }
  @override
  void dispose() { _c.dispose(); super.dispose(); }

  Color get _bg {
    if (widget.ghost || widget.variant == BtnVariant.ghost) return Colors.transparent;
    if (widget.variant == BtnVariant.red) return C.red;
    return C.ink;
  }
  Color get _fg => (widget.ghost || widget.variant == BtnVariant.ghost) ? C.ink : C.cream;
  Border? get _border => (widget.ghost || widget.variant == BtnVariant.ghost) ? Border.all(color: C.ink.withOpacity(0.28)) : null;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTapDown: (_) => _c.forward(),
    onTapUp: (_) { _c.reverse(); widget.onTap?.call(); },
    onTapCancel: () => _c.reverse(),
    child: ScaleTransition(scale: _s, child: AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 13),
      decoration: BoxDecoration(color: _bg, borderRadius: BorderRadius.circular(999), border: _border),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Text(widget.label, style: T.b(TSize.btn(MediaQuery.of(context).size.width), c: _fg, w: FontWeight.w500)),
        if (widget.icon != null) ...[const SizedBox(width: 7), Icon(widget.icon, size: 15, color: _fg)],
      ]),
    )),
  );
}

// ═══════════════════════════════════════════════
//  MAIN CONTROLLER HOME PAGE
// ═══════════════════════════════════════════════

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}
class _HomePageState extends State<HomePage> {
  final _sc = ScrollController();
  final _keys = List.generate(9, (_) => GlobalKey());
  void _go(int i) {
    final ctx = _keys[i].currentContext;
    if (ctx != null) Scrollable.ensureVisible(ctx, duration: const Duration(milliseconds: 650), curve: Curves.easeInOut);
  }
  @override
  void dispose() { _sc.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: C.cream,
    body: Stack(children: [
      SingleChildScrollView(
        controller: _sc,
        child: Column(children: [
          KeyedSubtree(key: _keys[0], child: HeroSection(onMeetApp: () => _go(3), onVision: () => _go(7))),
          KeyedSubtree(key: _keys[1], child: ProblemSection(sc: _sc)),
          KeyedSubtree(key: _keys[2], child: const PhilosophySection()),
          KeyedSubtree(key: _keys[3], child: const PlatformSection()),
          KeyedSubtree(key: _keys[4], child: const HowItWorksSection()),
          KeyedSubtree(key: _keys[5], child: const PrivacySection()),
          KeyedSubtree(key: _keys[6], child: const CommunitySection()),
          KeyedSubtree(key: _keys[7], child: const VisionSection()),
          KeyedSubtree(key: _keys[8], child: ContactSection(onBackToTop: () => _go(0))),
        ]),
      ),
      Positioned(top: 0, left: 0, right: 0, child: NavBar(scrollController: _sc, sectionKeys: _keys)),
    ]),
  );
}
