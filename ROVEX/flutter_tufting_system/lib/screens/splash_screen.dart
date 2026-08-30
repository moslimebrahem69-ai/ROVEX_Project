import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/machine_service.dart';
import '../theme/hmi_colors.dart';
import 'hmi_shell_screen.dart';

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
  static const _minSplashDuration = Duration(milliseconds: 1200);
  static const _maxBootWait = Duration(milliseconds: 3500);
  static const _fadeDuration = Duration(milliseconds: 400);
  static const _transitionDuration = Duration(milliseconds: 300);
  static const _postLoadDelay = Duration(milliseconds: 150);
  static const _connectionPollInterval = Duration(milliseconds: 60);

  double _progress = 0.12;
  String _loadingMessage = 'Initializing ROVEX Control System...';

  late final AnimationController _fadeInController;

  @override
  void initState() {
    super.initState();

    _fadeInController = AnimationController(
      vsync: this,
      duration: _fadeDuration,
    )..forward();

    if (widget.autoBoot) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _boot());
    } else {
      _progress = 0.45;
    }
  }

  Future<void> _boot() async {
    final machineService = context.read<MachineService>();
    final bootStart = DateTime.now();

    if (!mounted) return;

    _updateLoadingState(
      progress: 0.35,
      message: 'Loading Machine Interface...',
    );

    await machineService.start();

    if (!mounted) return;

    _updateLoadingState(
      progress: 0.62,
      message: 'Preparing Precision Control Modules...',
    );

    await _waitForConnection(machineService);

    if (!mounted) return;

    await _ensureMinimumSplashDuration(bootStart);

    if (!mounted) return;

    setState(() {
      _progress = 1.0;
    });

    await Future<void>.delayed(_postLoadDelay);

    if (!mounted) return;

    _openHmi();
  }

  Future<void> _waitForConnection(MachineService machineService) async {
    final deadline = DateTime.now().add(_maxBootWait);

    while (
        mounted &&
        DateTime.now().isBefore(deadline) &&
        !machineService.status.connected) {
      await Future<void>.delayed(_connectionPollInterval);

      if (!mounted) return;

      setState(() {
        _progress = (_progress + 0.06).clamp(0.62, 0.98);
      });
    }
  }

  Future<void> _ensureMinimumSplashDuration(DateTime bootStart) async {
    final elapsed = DateTime.now().difference(bootStart);
    final remaining = _minSplashDuration - elapsed;

    if (remaining > Duration.zero) {
      await Future<void>.delayed(remaining);
    }
  }

  void _updateLoadingState({
    required double progress,
    required String message,
  }) {
    setState(() {
      _progress = progress;
      _loadingMessage = message;
    });
  }

  void _openHmi() {
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
        transitionDuration: _transitionDuration,
      ),
    );
  }

  @override
  void dispose() {
    _fadeInController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HmiColors.bg,
      body: FadeTransition(
        opacity: _fadeInController,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: 320,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildLogo(),
                  const SizedBox(height: 28),
                  _buildAppName(),
                  const SizedBox(height: 6),
                  _buildTagline(),
                  const SizedBox(height: 20),
                  _buildLoadingMessage(),
                  const SizedBox(height: 14),
                  _buildProgressBar(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogo() {
    return Container(
      width: 120,
      height: 120,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: HmiColors.panel,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: HmiColors.border,
        ),
      ),
      child: Image.asset(
        'assets/brand/dar_icon_log.png',
        fit: BoxFit.contain,
        filterQuality: FilterQuality.high,
        errorBuilder: (
          context,
          error,
          stackTrace,
        ) {
          return const Icon(
            Icons.precision_manufacturing,
            size: 60,
            color: HmiColors.accent,
          );
        },
      ),
    );
  }

  Widget _buildAppName() {
    return const Text(
      'ROVEX',
      style: TextStyle(
        color: HmiColors.text,
        fontSize: 24,
        fontWeight: FontWeight.w800,
        letterSpacing: 3.0,
      ),
    );
  }

  Widget _buildTagline() {
    return const Text(
      'Precision Control. Intelligent Automation.',
      textAlign: TextAlign.center,
      style: TextStyle(
        color: HmiColors.textDim,
        fontSize: 11,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.6,
      ),
    );
  }

  Widget _buildLoadingMessage() {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      child: Text(
        _loadingMessage,
        key: ValueKey(_loadingMessage),
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: HmiColors.textMute,
          fontSize: 11,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildProgressBar() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: LinearProgressIndicator(
        value: _progress,
        minHeight: 5,
        backgroundColor: HmiColors.border,
        color: HmiColors.accent,
      ),
    );
  }
}