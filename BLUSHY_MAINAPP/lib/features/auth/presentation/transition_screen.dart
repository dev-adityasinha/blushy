import 'package:flutter/material.dart';
import '../../../core/state.dart';
import '../../../theme/colors.dart';
import '../../../theme/scale.dart';
import 'dart:async';

class TransitionScreen extends StatefulWidget {
  const TransitionScreen({super.key});

  @override
  State<TransitionScreen> createState() => _TransitionScreenState();
}

class _TransitionScreenState extends State<TransitionScreen> {
  @override
  void initState() {
    super.initState();
    _startTransition();
  }

  void _startTransition() {
    debugPrint("BlushyDebug: TransitionScreen - _startTransition initiated");
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        debugPrint("BlushyDebug: TransitionScreen - 3s delay completed, mounted = true");
        try {
          final state = BlushyOSProvider.of(context);
          debugPrint("BlushyDebug: TransitionScreen - state resolved successfully");
          Navigator.of(context).pop();
          debugPrint("BlushyDebug: TransitionScreen - popped successfully");
          state.setOnboardingCompleted(true);
          debugPrint("BlushyDebug: TransitionScreen - setOnboardingCompleted called");
        } catch (e) {
          debugPrint("BlushyDebug: TransitionScreen - Error during pop/state update: $e");
        }
      } else {
        debugPrint("BlushyDebug: TransitionScreen - 3s delay completed but widget not mounted");
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BlushyColors.background,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              RichText(
                text: const TextSpan(
                  style: TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.5,
                    color: BlushyColors.primary,
                  ),
                  children: [
                    TextSpan(text: 'BLUSHY'),
                    TextSpan(
                      text: '.',
                      style: TextStyle(color: BlushyColors.accent),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 36),
              const SizedBox(
                width: 32,
                height: 32,
                child: CircularProgressIndicator(
                  color: BlushyColors.primary,
                  strokeWidth: 2.5,
                ),
              ),
              const SizedBox(height: 28),
              Text(
                'Building your Blushy space...',
                style: BlushyType.headline().copyWith(
                  fontSize: 28,
                  fontWeight: FontWeight.w400,
                  color: BlushyColors.text,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Curating your personalized wellness rhythm',
                style: BlushyType.body().copyWith(
                  fontSize: 14,
                  color: BlushyColors.secondaryText,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
