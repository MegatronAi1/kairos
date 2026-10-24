import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kairos_pager/core/models/models.dart';
import 'package:kairos_pager/core/providers.dart';
import 'package:kairos_pager/widgets/status_copy.dart';

Json _fixture(String name) => jsonDecode(File('test/fixtures/$name').readAsStringSync()) as Json;

ReactorView _view(HealthState state, {TickEvent? tick, InsightEvent? insight, bool ack = false}) =>
    ReactorView(
      id: 'R2',
      batchId: 99,
      strategy: 'fault',
      isFaultBatch: true,
      state: state,
      acknowledged: ack,
      tick: tick,
      insight: insight,
    );

void main() {
  final tick = KEvent.fromJson(_fixture('tick.json'))! as TickEvent;
  final insight = KEvent.fromJson(_fixture('insight.json'))! as InsightEvent;

  test('thousands separator', () {
    expect(fmtThousands(3300), '3,300');
    expect(fmtThousands(912.4), '912');
    expect(fmtThousands(1234567), '1,234,567');
  });

  test('normal reactor reads as running smoothly with its forecast', () {
    expect(
      statusSentence(_view(HealthState.normal, tick: tick)),
      'Running smoothly · heading for 2,706 kg',
    );
    expect(statusSentence(_view(HealthState.normal)), 'Waiting for the first readings');
  });

  test('watch names the leading deviation in plain words', () {
    expect(statusSentence(_view(HealthState.watch, tick: tick)), 'Drifting · dissolved oxygen running low');
  });

  test('alarm uses the copilot title and notes acknowledgement', () {
    expect(statusSentence(_view(HealthState.alarm, insight: insight)), 'Oxygen limitation developing');
    expect(
      statusSentence(_view(HealthState.alarm, insight: insight, ack: true)),
      'Oxygen limitation developing · acknowledged',
    );
    expect(statusSentence(_view(HealthState.alarm)), 'Needs attention now');
  });
}
