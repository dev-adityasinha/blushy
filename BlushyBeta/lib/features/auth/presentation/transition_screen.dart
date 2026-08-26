import 'package:flutter/material.dart';
import '../../../core/state.dart';
import '../../../theme/colors.dart';
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
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            CircularProgressIndicator(
              color: BlushyColors.primary,
            ),
            SizedBox(height: 24),
            Text(
              'Building your Blushy space...',
              style: TextStyle(
                fontFamily: 'Georgia',
                fontSize: 20,
                color: BlushyColors.text,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
