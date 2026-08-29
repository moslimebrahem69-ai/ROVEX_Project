import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:rovex/l10n/l10n.dart';
import 'package:rovex/screens/splash_screen.dart';
import 'package:rovex/config/project_credits.dart';
import 'package:rovex/services/machine_service.dart';

void main() {
  testWidgets('Splash shows credits and ayah', (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => MachineService()),
          ChangeNotifierProvider(create: (_) => LocaleController()),
        ],
        child: const MaterialApp(home: SplashScreen(autoBoot: false)),
      ),
    );
    await tester.pump();
    expect(find.textContaining('استعينوا بالصبر والصلاة'), findsOneWidget);
    expect(find.textContaining(ProjectCredits.deanNameAr), findsOneWidget);
    expect(find.textContaining(ProjectCredits.supervisorTitleAr), findsOneWidget);
  });
}
