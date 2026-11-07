import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:rosea_pos/core/errors/app_error.dart';
import 'package:rosea_pos/features/catalog/domain/catalog.dart';
import 'package:rosea_pos/features/checkout/domain/checkout_draft.dart';
import 'package:rosea_pos/features/checkout/domain/pay_intent.dart';
import 'package:rosea_pos/features/checkout/domain/payment_draft.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Phrases that would mean we failed Golden Rule #7 — a bare, non-actionable error.
const _banned = <String>['unexpected error', 'an error occurred', 'unknown error'];

// At least one of these must appear — the "what to do" part of every message.
const _actionCues = <String>[
  'try again', 'check', 'wait', 'adjust', 'choose', 'retry', 'sign in',
  'queued', 'saved', 'add ', 'fix', 'refresh', 'connection', 'tell the owner',
  'start a', 'open a', 'new ticket', 'performer', 'positive', 'already paid',
  'match', 'remove',
];

/// Asserts a user-facing message is actionable and never generic.
void expectActionable(AppError e) {
  final m = e.message.trim();
  expect(m, isNotEmpty);
  expect(m.length, greaterThanOrEqualTo(12), reason: 'too terse: "$m"');
  final lower = m.toLowerCase();
  for (final bad in _banned) {
    expect(lower.contains(bad), isFalse, reason: 'generic copy not allowed: "$m"');
  }
  expect(_actionCues.any(lower.contains), isTrue, reason: 'no "what to do" cue in: "$m"');
}

DraftLine _line() => const DraftLine(
      id: 'l1', refId: 'svc1', kind: CatalogKind.service, name: 'Cut',
      unitPriceCents: 5000, qty: 1, lineDiscountCents: 0,
      performerStaffId: 'st1', performerName: 'Lea',
    );

void main() {
  group('mapAuthError — every branch is actionable', () {
    test('rate limited (429)', () {
      expectActionable(mapAuthError(const AuthException('too many requests', statusCode: '429')));
    });
    test('bad credentials (400)', () {
      expectActionable(mapAuthError(const AuthException('invalid login credentials', statusCode: '400')));
    });
    test('other auth exception', () {
      expectActionable(mapAuthError(const AuthException('Email not confirmed')));
    });
    test('network', () {
      expectActionable(mapAuthError(TimeoutException('x')));
    });
    test('unknown', () {
      expectActionable(mapAuthError(const FormatException('weird')));
    });
  });

  group('mapPayError — every branch is actionable', () {
    test('P0001 / P0002 / P0004 surface the server message', () {
      expectActionable(mapPayError(PostgrestException(message: 'This ticket is already paid. Open a new ticket to ring up more.', code: 'P0001')));
      expectActionable(mapPayError(PostgrestException(message: 'Payments total 90.00 but the ticket is 100.00. Adjust the split so it matches.', code: 'P0002')));
      expectActionable(mapPayError(PostgrestException(message: 'Add at least one service or product before taking payment.', code: 'P0004')));
    });
    test('insufficient_privilege (42501)', () {
      expectActionable(mapPayError(PostgrestException(message: 'permission denied', code: '42501')));
    });
    test('other DB error falls back to actionable copy (not raw PG text)', () {
      final e = mapPayError(PostgrestException(message: 'duplicate key value violates unique constraint', code: '23505'));
      expectActionable(e);
      expect(e.message.toLowerCase(), isNot(contains('duplicate key'))); // no raw PG text
    });
    test('transport (queued) and unknown', () {
      expectActionable(mapPayError(TimeoutException('offline')));
      expectActionable(mapPayError(const FormatException('weird response')));
    });
  });

  group('validatePayable — every rejection is actionable', () {
    test('empty / no performer / split mismatch / non-positive', () {
      expectActionable(validatePayable(draft: const CheckoutDraft(), pay: const PaymentDraft(), openedByStaffId: 'st1')!);
      expectActionable(validatePayable(draft: CheckoutDraft(lines: [_line()]), pay: const PaymentDraft(), openedByStaffId: null)!);
      expectActionable(validatePayable(
        draft: CheckoutDraft(lines: [_line()]),
        pay: const PaymentDraft(payments: [Payment(id: 'p', method: PaymentMethod.cash, appliedCents: 4000)]),
        openedByStaffId: 'st1',
      )!);
    });
  });
}
