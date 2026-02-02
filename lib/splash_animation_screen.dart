import 'dart:async';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'home_screen.dart';

class SplashAnimationScreen extends StatefulWidget {
  const SplashAnimationScreen({super.key});

  @override
  State<SplashAnimationScreen> createState() => _SplashAnimationScreenState();
}

class _SplashAnimationScreenState extends State<SplashAnimationScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this);

    // Safety timeout in case the asset is slow to load.
    Timer(const Duration(seconds: 4), _goNextIfNeeded);
  }

  void _goNextIfNeeded() {
    if (_navigated || !mounted) return;
    _navigated = true;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const HomeScreen()),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const bg = Colors.white;
    return Scaffold(
      backgroundColor: bg,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _goNextIfNeeded, // allow skip on tap
        child: Center(
          child: Lottie.asset(
            'assets/lottie/intro.json',
            controller: _controller,
            onLoaded: (comp) {
              _controller
                ..duration = comp.duration
                ..forward().whenComplete(_goNextIfNeeded);
            },
          ),
        ),
      ),
    );
  }
}
