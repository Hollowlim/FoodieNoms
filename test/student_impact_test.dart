import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foodienoms/firebase/student_impact.dart';

void main() {
  test('counts collected quantities, including older code-less pickups', () {
    expect(
        collectedMealsSaved([
          {'status': 'collected', 'quantity': 3},
          {'status': 'collected', 'quantity': 2, 'pickupCode': '0007'},
        ]),
        5);
    expect(collectedMealsSaved(const []), 0);
  });

  test('reserved, ready, cancelled and missed pickups do not count', () {
    expect(
        collectedMealsSaved([
          for (final status in ['reserved', 'ready', 'cancelled', 'noshow'])
            {'status': status, 'quantity': 4},
          {'status': 'collected', 'quantity': 1},
        ]),
        1);
  });

  test('ignores missing, negative and malformed legacy quantities', () {
    expect(
        collectedMealsSaved([
          for (final quantity in [null, -1, 0, '2', 2.5])
            {'status': 'collected', 'quantity': quantity},
          {'quantity': 9},
          {'status': 'collected'},
        ]),
        0);
  });

  testWidgets('live history updates after collection without double counting',
      (tester) async {
    final history = StreamController<Iterable<Map<String, dynamic>>>();
    addTearDown(history.close);
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: MealsSavedSection(reservations: history.stream))));
    expect(find.text('Loading your completed pickups…'), findsOneWidget);
    expect(find.text('0 meals'), findsNothing);

    history.add([
      {'status': 'ready', 'quantity': 2},
    ]);
    await tester.pumpAndSettle();
    expect(find.text('0 meals'), findsOneWidget);

    final collected = [
      {'status': 'collected', 'quantity': 2},
      {'status': 'noshow', 'quantity': 4},
    ];
    history.add(collected);
    await tester.pumpAndSettle();
    expect(find.text('2 meals'), findsOneWidget);
    history.add(collected);
    await tester.pumpAndSettle();
    expect(find.text('2 meals'), findsOneWidget);
    history.add([
      {'status': 'collected', 'quantity': 1},
    ]);
    await tester.pumpAndSettle();
    expect(find.text('1 meal'), findsOneWidget);
  });

  testWidgets('history error does not present a false zero or stale count',
      (tester) async {
    final history = StreamController<Iterable<Map<String, dynamic>>>();
    addTearDown(history.close);
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: MealsSavedSection(reservations: history.stream))));
    history.add([
      {'status': 'collected', 'quantity': 3},
    ]);
    await tester.pumpAndSettle();
    history.addError(StateError('Unavailable'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Couldn’t load'), findsOneWidget);
    expect(find.text('—'), findsOneWidget);
    expect(find.text('0 meals'), findsNothing);
    expect(find.text('3 meals'), findsNothing);
    history.add([
      {'status': 'collected', 'quantity': 3},
    ]);
    await tester.pumpAndSettle();
    expect(find.text('3 meals'), findsOneWidget);
  });

  testWidgets('changing accounts clears the previous account count immediately',
      (tester) async {
    final first = StreamController<Iterable<Map<String, dynamic>>>();
    final second = StreamController<Iterable<Map<String, dynamic>>>();
    addTearDown(first.close);
    addTearDown(second.close);
    Widget profile(Stream<Iterable<Map<String, dynamic>>> history) =>
        MaterialApp(
            home: Scaffold(body: MealsSavedSection(reservations: history)));
    await tester.pumpWidget(profile(first.stream));
    first.add([
      {'status': 'collected', 'quantity': 8},
    ]);
    await tester.pumpAndSettle();
    expect(find.text('8 meals'), findsOneWidget);
    await tester.pumpWidget(profile(second.stream));
    expect(find.text('8 meals'), findsNothing);
    expect(find.text('Loading your completed pickups…'), findsOneWidget);
    second.add(const []);
    await tester.pumpAndSettle();
    expect(find.text('0 meals'), findsOneWidget);
  });
}
