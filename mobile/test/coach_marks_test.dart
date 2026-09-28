import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dha_vault/widgets/coach_marks/coach_mark_model.dart';
import 'package:dha_vault/widgets/coach_marks/coach_mark_card.dart';
import 'package:dha_vault/widgets/coach_marks/animated_coach_arrow.dart';

void main() {
  group('Coach Mark Unit Tests', () {
    test('CoachMarkStep model instantiates correctly with defaults', () {
      final key = GlobalKey();
      final step = CoachMarkStep(
        title: 'Add File',
        description: 'Upload PDFs, images, or documents to your secure vault.',
        targetKey: key,
      );

      expect(step.title, 'Add File');
      expect(step.description, 'Upload PDFs, images, or documents to your secure vault.');
      expect(step.targetKey, key);
      expect(step.position, CoachMarkPosition.auto);
      expect(step.borderRadius, 14.0);
    });

    testWidgets('CoachMarkCard displays step indicator, title, description, and buttons', (tester) async {
      bool nextPressed = false;
      bool skipPressed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CoachMarkCard(
              title: 'Scan Document',
              description: 'Scan physical documents with your camera.',
              stepIndex: 1,
              totalSteps: 5,
              onNext: () => nextPressed = true,
              onSkip: () => skipPressed = true,
            ),
          ),
        ),
      );

      expect(find.text('2 of 5'), findsOneWidget);
      expect(find.text('Scan Document'), findsOneWidget);
      expect(find.text('Scan physical documents with your camera.'), findsOneWidget);
      expect(find.text('Next'), findsOneWidget);
      expect(find.text('Skip'), findsOneWidget);

      await tester.tap(find.text('Next'));
      expect(nextPressed, isTrue);

      await tester.tap(find.text('Skip'));
      expect(skipPressed, isTrue);
    });

    testWidgets('CoachMarkCard displays completion state correctly', (tester) async {
      bool nextPressed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CoachMarkCard(
              title: "You're all set.",
              description: 'Explore your secure vault and start adding your documents.',
              stepIndex: 4,
              totalSteps: 5,
              isCompletionStep: true,
              onNext: () => nextPressed = true,
              onSkip: () {},
            ),
          ),
        ),
      );

      expect(find.text('Ready'), findsOneWidget);
      expect(find.text('Get Started'), findsOneWidget);
      expect(find.text('Skip'), findsNothing);

      await tester.tap(find.text('Get Started'));
      expect(nextPressed, isTrue);
    });

    testWidgets('AnimatedCoachArrow renders custom painter without exceptions', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 300,
              height: 300,
              child: AnimatedCoachArrow(
                start: Offset(150, 200),
                end: Offset(150, 50),
                animationValue: 0.5,
                pulseValue: 0.3,
              ),
            ),
          ),
        ),
      );

      expect(find.byType(AnimatedCoachArrow), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
