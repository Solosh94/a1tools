import 'dart:async';
import 'package:flutter/material.dart';

import 'home_screen.dart';

class SplashVideoScreen extends StatefulWidget {
  const SplashVideoScreen({super.key});

  @override
  State<SplashVideoScreen> createState() => _SplashVideoScreenState();
}

class _SplashVideoScreenState extends State<SplashVideoScreen> {
  bool _navigated = false;
  bool _visible = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();

    // Subtle fade/scale in for the logo
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _visible = true);
    });

    // Safety: auto-continue after ~1.6s
    _timer = Timer(const Duration(milliseconds: 1600), _goNext);
  }

  void _goNext() {
    if (_navigated || !mounted) return;
    _navigated = true;
    _timer?.cancel();

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 250),
        pageBuilder: (_, __, ___) => const HomeScreen(),
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
      ),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white, // keep splash background white
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _goNext, // tap to skip
        child: Center(
          child: AnimatedOpacity(
            opacity: _visible ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOut,
            child: AnimatedScale(
              scale: _visible ? 1.0 : 0.98,
              duration: const Duration(milliseconds: 600),
              curve: Curves.easeOut,
              child: Image.asset(
                'assets/images/logo.png',
                height: 80,
                filterQuality: FilterQuality.high,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
