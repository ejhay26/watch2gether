import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:watch2gether/constants/theme.dart';
import 'package:watch2gether/ui/splash/splash_loading_screen.dart';

void main() {
  testWidgets('SplashLoadingScreen renders brand glyph, title, and telemetry', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme(),
        home: const SplashLoadingScreen(),
      ),
    );

    // Verify initial branding and title
    expect(find.text('Watch2Gether'), findsOneWidget);
    expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
    expect(find.text('STARTING COMPANION'), findsOneWidget);

    // Initial milestone status
    expect(find.text('Bootstrapping companion node...'), findsOneWidget);

    // Advance frame for animation controllers
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.byType(SplashLoadingScreen), findsOneWidget);
  });
}
