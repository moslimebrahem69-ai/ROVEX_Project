import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';


import '../services/machine_service.dart';
import '../theme/hmi_colors.dart';
import 'hmi_shell_screen.dart';

/// Loading screen — logo + progress bar. Nothing else.
class SplashScreen extends StatefulWidget {
  final bool autoBoot;

  const SplashScreen({
    super.key,
    this.autoBoot = true,
  });

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  double _progress = 0.12;

  String _loadingMessage =
      'Initializing ROVEX Control System...';

  late final AnimationController _fadeIn;

  static const _minSplash =
      Duration(milliseconds: 1200);

  static const _maxWait =
      Duration(milliseconds: 3500);

  @override
  void initState() {
    super.initState();

    _fadeIn = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    )..forward();

    if (widget.autoBoot) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _boot(),
      );
    } else {
      _progress = 0.45;
    }
  }

  Future<void> _boot() async {
    final svc = context.read<MachineService>();
    final started = DateTime.now();
    if (!mounted) return;

    setState(() {
      _progress = 0.35;
      _loadingMessage =
          'Loading Machine Interface...';
    });

    await svc.start();

    if (!mounted) return;

    setState(() {
      _progress = 0.62;
      _loadingMessage =
          'Preparing Precision Control Modules...';
    });

    final deadline =
        DateTime.now().add(_maxWait);

    while (
        mounted &&
        DateTime.now().isBefore(deadline)) {
      if (svc.status.connected) {
        break;
      }

      await Future<void>.delayed(
        const Duration(milliseconds: 60),
      );

      if (!mounted) return;

      setState(() {
        _progress =
            (_progress + 0.06).clamp(0.62, 0.98);
      });
    }

    if (!mounted) return;

    final elapsed =
        DateTime.now().difference(started);

    final remain =
        _minSplash - elapsed;

    if (remain > Duration.zero) {
      await Future<void>.delayed(remain);
    }

    if (!mounted) return;

    setState(() {
      _progress = 1.0;
    });

    await Future<void>.delayed(
      const Duration(milliseconds: 150),
    );

    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (
          context,
          animation,
          secondaryAnimation,
        ) {
          return const HmiShellScreen();
        },
        transitionsBuilder: (
          context,
          animation,
          secondaryAnimation,
          child,
        ) {
          return FadeTransition(
            opacity: animation,
            child: child,
          );
        },
        transitionDuration:
            const Duration(milliseconds: 300),
      ),
    );
  }

  @override
  void dispose() {
    _fadeIn.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HmiColors.bg,
      body: FadeTransition(
        opacity: _fadeIn,
        child: Center(
          child: ConstrainedBox(
            constraints:
                const BoxConstraints(maxWidth: 320),
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(
                horizontal: 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // -------------------------------------------------
                  // ROVEX LOGO
                  // -------------------------------------------------

                  Container(
                    width: 120,
                    height: 120,
                    padding:
                        const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: HmiColors.panel,
                      borderRadius:
                          BorderRadius.circular(28),
                      border: Border.all(
                        color: HmiColors.border,
                      ),
                    ),
                    child: Image.asset(
                      'assets/brand/dar_icon_log.png',
                      fit: BoxFit.contain,
                      filterQuality:
                          FilterQuality.high,
                      errorBuilder:
                          (context, error, stackTrace) {
                        return const Icon(
                          Icons.precision_manufacturing,
                          size: 60,
                          color: HmiColors.accent,
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 28),

                  // -------------------------------------------------
                  // APP NAME
                  // -------------------------------------------------

                  const Text(
                    'ROVEX',
                    style: TextStyle(
                      color: HmiColors.text,
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 3.0,
                    ),
                  ),

                  const SizedBox(height: 6),

                  // -------------------------------------------------
                  // TAGLINE
                  // -------------------------------------------------

                  const Text(
                    'Precision Control. Intelligent Automation.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: HmiColors.textDim,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.6,
                    ),
                  ),

                  const SizedBox(height: 20),

                  // -------------------------------------------------
                  // LOADING MESSAGE
                  // -------------------------------------------------

                  AnimatedSwitcher(
                    duration:
                        const Duration(milliseconds: 250),
                    child: Text(
                      _loadingMessage,
                      key: ValueKey(
                        _loadingMessage,
                      ),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: HmiColors.textMute,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),

                  const SizedBox(height: 14),

                  // -------------------------------------------------
                  // PROGRESS BAR
                  // -------------------------------------------------

                  ClipRRect(
                    borderRadius:
                        BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: _progress,
                      minHeight: 5,
                      backgroundColor:
                          HmiColors.border,
                      color: HmiColors.accent,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}