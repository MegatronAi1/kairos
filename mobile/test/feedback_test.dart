import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kairos_pager/core/api/kairos_api.dart';
import 'package:kairos_pager/core/providers.dart';
import 'package:kairos_pager/core/storage/pairing_store.dart';
import 'package:kairos_pager/features/feedback/feedback_sheet.dart';

class _FakeApi extends KairosApi {
  _FakeApi() : super(const Pairing(serverUrl: 'https://example.test', token: 't'));

  final sent = <FeedbackPayload>[];

  @override
  Future<void> sendFeedback(FeedbackPayload f) async => sent.add(f);
}

void main() {
  testWidgets('feedback sheet validates the message and sends the payload', (tester) async {
    final api = _FakeApi();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [apiProvider.overrideWithValue(api)],
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => showFeedbackSheet(context, page: 'reactor', reactorId: 'PUN-R2'),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Send'));
    await tester.pump();
    expect(find.text('Please write a short message'), findsOneWidget);
    expect(api.sent, isEmpty);

    await tester.tap(find.text('Bug'));
    await tester.tap(find.byKey(const ValueKey('rating-2')));
    await tester.enterText(find.byKey(const ValueKey('feedback-message')), '  Alarm came late  ');
    await tester.tap(find.text('Send'));
    await tester.pumpAndSettle();

    expect(api.sent, hasLength(1));
    expect(api.sent.single.toJson(), {
      'category': 'bug',
      'rating': 2,
      'message': 'Alarm came late',
      'source': 'pager',
      'reactor_id': 'PUN-R2',
      'page': 'reactor',
    });
    expect(find.text('Thanks - your feedback reached the Kairos team'), findsOneWidget);
  });
}
