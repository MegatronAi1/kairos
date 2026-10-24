import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kairos_pager/core/models/models.dart';

Json _fixture(String name) => jsonDecode(File('test/fixtures/$name').readAsStringSync()) as Json;

void main() {
  test('tick parses sensors, forecast and health', () {
    final e = KEvent.fromJson(_fixture('tick.json'))! as TickEvent;
    expect(e.reactorId, 'R2');
    expect(e.sensors['do_pct'], 31.2);
    expect(e.value('power_kw'), 141.0);
    expect(e.forecast!.p10, 1989.0);
    expect(e.forecast!.provenance, Provenance.synthetic);
    expect(e.health!.state, HealthState.watch);
    expect(e.health!.topContributors.single.low, isTrue);
  });

  test('alarm parses state transition and PONR', () {
    final e = KEvent.fromJson(_fixture('alarm.json'))! as AlarmEvent;
    expect(e.state, HealthState.alarm);
    expect(e.previousState, HealthState.watch);
    expect(e.ponrHours, 4.5);
    expect(e.contributors, hasLength(2));
  });

  test('insight parses card and source', () {
    final e = KEvent.fromJson(_fixture('insight.json'))! as InsightEvent;
    expect(e.card.action, 'Reduce sugar feed 10% for 3 h');
    expect(e.card.evidence, contains('yield_model'));
    expect(e.fromAgent, isTrue);
  });

  test('ack and reactor summary parse', () {
    expect((KEvent.fromJson(_fixture('ack.json'))! as AckEvent).by, 'pager');
    final s = ReactorSummary.fromJson(_fixture('reactor_summary.json'));
    expect(s.plantId, 'pune');
    expect(s.isFaultBatch, isTrue);
    expect(s.state, HealthState.alarm);
    expect(s.lastTick, isNull);
  });

  test('unknown event type is ignored', () {
    expect(KEvent.fromJson({'type': 'mystery'}), isNull);
  });
}
