import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_failure.dart';
import '../../../core/money/fixed_point.dart';
import '../../../core/providers.dart';
import '../../auth/domain/app_user.dart';
import '../../customers/domain/customer.dart';
import '../data/sale_repository.dart';
import '../domain/cart.dart';

/// M-04 «طريقة البيع»: كاش كامل (paid = total), جزئي (0 < paid < total), دين (paid = 0).
enum SaleMode { cash, partial, credit }

/// M-04 «موعد السداد» chips: none, +7 days, +30 days (doc 15 §5).
enum DueChoice {
  none(0),
  week(7),
  month(30);

  const DueChoice(this.days);

  final int days;

  DateTime? dateFrom(DateTime today) => days == 0 ? null : DateTime(today.year, today.month, today.day + days);
}

/// The last submit attempt's outcome, shown as the card above the confirm summary.
enum SubmitState {
  idle,
  busy,

  /// The request never left the phone; fields stay editable.
  offline,

  /// A timeout after sending: the sale may exist. Fields lock; retry sends the same key.
  uncertain,
  server,

  /// 422 CREDIT_LIMIT_EXCEEDED from the server (the balance changed since the list loaded).
  limit,

  /// 403 on the override: the account may not override any more.
  forbidden,

  /// Any other final refusal; [CheckoutState.serverMessage] says why.
  rejected,
}

/// Field-level problems found before sending (UI-AC-03).
enum PaidError { invalid, notBelowTotal }

class CheckoutState {
  const CheckoutState({
    this.mode = SaleMode.cash,
    this.paidText = '',
    this.method = 'palpay',
    this.customer,
    this.due = DueChoice.none,
    this.itemsOpen = false,
    this.customerMissing = false,
    this.paidError,
    this.submit = SubmitState.idle,
    this.serverMessage,
    this.reference,
    this.operationId,
    this.afterUncertain = false,
  });

  final SaleMode mode;
  final String paidText;

  /// `cash`, `jawwal_pay`, `palpay`, `bank_of_palestine` (05 §3.1).
  final String method;
  final Customer? customer;
  final DueChoice due;
  final bool itemsOpen;
  final bool customerMissing;
  final PaidError? paidError;
  final SubmitState submit;
  final String? serverMessage;

  /// Support reference (last 6 of the correlation id) for a 5xx.
  final String? reference;

  /// Names the pending POST /sales so a retry reuses its Idempotency-Key (05 §4.1).
  final String? operationId;

  /// The sale that finally went through had an uncertain attempt before it (M-06 replay note).
  final bool afterUncertain;

  bool get busy => submit == SubmitState.busy;

  /// Busy or uncertain: nothing may change until the server answers the same request.
  bool get locked => submit == SubmitState.busy || submit == SubmitState.uncertain;

  CheckoutState copyWith({
    SaleMode? mode,
    String? paidText,
    String? method,
    Customer? customer,
    bool clearCustomer = false,
    DueChoice? due,
    bool? itemsOpen,
    bool? customerMissing,
    PaidError? paidError,
    bool clearPaidError = false,
    SubmitState? submit,
    String? serverMessage,
    String? reference,
    String? operationId,
    bool clearOperation = false,
    bool? afterUncertain,
  }) => CheckoutState(
    mode: mode ?? this.mode,
    paidText: paidText ?? this.paidText,
    method: method ?? this.method,
    customer: clearCustomer ? null : (customer ?? this.customer),
    due: due ?? this.due,
    itemsOpen: itemsOpen ?? this.itemsOpen,
    customerMissing: customerMissing ?? this.customerMissing,
    paidError: clearPaidError ? null : (paidError ?? this.paidError),
    submit: submit ?? this.submit,
    serverMessage: serverMessage ?? (submit != null ? null : this.serverMessage),
    reference: reference ?? (submit != null ? null : this.reference),
    operationId: clearOperation ? null : (operationId ?? this.operationId),
    afterUncertain: afterUncertain ?? this.afterUncertain,
  );
}

/// The numbers behind M-04, derived from the cart and the form. Money is exact (agorot).
class CheckoutSummary {
  CheckoutSummary(this.cart, this.state, this.user)
    : total = cart.total,
      paid = switch (state.mode) {
        SaleMode.cash => cart.total,
        SaleMode.credit => Money.zero,
        SaleMode.partial => _paidOrZero(state.paidText, cart.total),
      };

  final Cart cart;
  final CheckoutState state;
  final AppUser? user;
  final Money total;
  final Money paid;

  Money get debt => total > paid ? total - paid : Money.zero;

  Customer? get customer => state.customer;

  /// D-26 on the client: would this debt take the customer above the limit?
  bool get overLimit => customer?.wouldExceedLimit(debt) ?? false;

  /// Employee: a restriction, the button is off. Also after the server's own 422.
  bool get limitBlocked => (overLimit && !(user?.canOverride ?? false)) || state.submit == SubmitState.limit;

  /// Owner / manager: a warning; confirming opens the explicit override sheet.
  bool get limitWarning => overLimit && (user?.canOverride ?? false) && state.submit != SubmitState.limit;

  Money get balanceAfter => (customer?.balance ?? Money.zero) + debt;

  Money get overBy {
    final limit = customer?.creditLimit;
    if (limit == null || !(balanceAfter > limit)) return Money.zero;
    return balanceAfter - limit;
  }

  static Money _paidOrZero(String text, Money total) {
    final value = parsePaid(text);
    if (value == null) return Money.zero;
    return value > total ? total : value;
  }

  /// `"20"`, `"20.5"`, `"20.50"` → money; anything else (or more than 2 decimals) → null.
  static Money? parsePaid(String text) {
    final t = text.trim();
    if (!RegExp(r'^\d{1,7}(\.\d{1,2})?$').hasMatch(t)) return null;
    return Money.parse(t);
  }
}

/// What a confirm led to, for the screen to navigate.
sealed class CheckoutOutcome {
  const CheckoutOutcome();
}

final class CheckoutStayed extends CheckoutOutcome {
  const CheckoutStayed();
}

/// Owner / manager over the limit: open the override confirmation (it is never sent from here).
final class CheckoutNeedsOverride extends CheckoutOutcome {
  const CheckoutNeedsOverride();
}

final class CheckoutDone extends CheckoutOutcome {
  const CheckoutDone(this.receipt, {required this.afterUncertain, required this.overridden});

  final SaleReceipt receipt;
  final bool afterUncertain;
  final bool overridden;
}

/// M-04 state and submit (US-0506). The server stays the authority for prices, stock and limits;
/// this only shapes the request and explains its answer.
class CheckoutController extends Notifier<CheckoutState> {
  @override
  CheckoutState build() => const CheckoutState();

  /// Any edit after a failed attempt is a new request, so it gets a new key.
  CheckoutState _edited(CheckoutState next) => next.copyWith(
    clearOperation: true,
    submit: state.submit == SubmitState.limit ? SubmitState.idle : state.submit,
  );

  void setMode(SaleMode mode) {
    if (state.locked) return;
    state = _edited(state.copyWith(mode: mode, customerMissing: false, clearPaidError: true));
  }

  void setPaid(String text) {
    if (state.locked) return;
    state = _edited(state.copyWith(paidText: text, clearPaidError: true));
  }

  void setMethod(String method) {
    if (state.locked) return;
    state = _edited(state.copyWith(method: method));
  }

  void setCustomer(Customer? customer) {
    if (state.locked) return;
    state = _edited(customer == null
        ? state.copyWith(clearCustomer: true)
        : state.copyWith(customer: customer, customerMissing: false));
  }

  void setDue(DueChoice due) {
    if (state.locked) return;
    state = _edited(state.copyWith(due: due));
  }

  void toggleItems() => state = state.copyWith(itemsOpen: !state.itemsOpen);

  /// Local checks before sending (UI-AC-03). True when the request may go.
  bool validate(Cart cart) {
    PaidError? paidError;
    if (state.mode == SaleMode.partial) {
      final paid = CheckoutSummary.parsePaid(state.paidText);
      if (paid == null || !paid.isPositive) {
        paidError = PaidError.invalid;
      } else if (!(paid < cart.total)) {
        paidError = PaidError.notBelowTotal;
      }
    }
    final customerMissing = state.mode != SaleMode.cash && state.customer == null;
    state = state.copyWith(customerMissing: customerMissing, paidError: paidError, clearPaidError: paidError == null);
    return paidError == null && !customerMissing;
  }

  Future<CheckoutOutcome> confirm(Cart cart, AppUser? user) async {
    if (state.busy) return const CheckoutStayed();
    final retryingUncertain = state.submit == SubmitState.uncertain;
    if (!retryingUncertain && !validate(cart)) return const CheckoutStayed();

    final summary = CheckoutSummary(cart, state, user);
    if (!retryingUncertain && summary.limitBlocked) return const CheckoutStayed();
    if (!retryingUncertain && summary.limitWarning) return const CheckoutNeedsOverride();
    return _send(cart, override: false);
  }

  /// The explicit «أوافق على التجاوز» (D-26): a different body, so a new operation and key.
  Future<CheckoutOutcome> confirmOverride(Cart cart) {
    state = state.copyWith(clearOperation: true);
    return _send(cart, override: true);
  }

  /// Closing the override sheet clears a 403 shown inside it.
  void dismissOverride() {
    if (state.submit == SubmitState.forbidden) state = state.copyWith(submit: SubmitState.idle);
  }

  Future<CheckoutOutcome> _send(Cart cart, {required bool override}) async {
    final wasUncertain = state.submit == SubmitState.uncertain || state.afterUncertain;
    final operationId = state.operationId ?? 'sale-${DateTime.now().microsecondsSinceEpoch}';
    state = state.copyWith(submit: SubmitState.busy, operationId: operationId);

    final summary = CheckoutSummary(cart, state, null);
    final dueDate = summary.debt.isPositive ? state.due.dateFrom(DateTime.now()) : null;
    final draft = SaleDraft(
      cart: cart,
      paidAmount: summary.paid,
      customerId: state.customer?.id,
      paymentMethod: summary.paid.isPositive ? state.method : null,
      dueDate: dueDate == null ? null : _isoDate(dueDate),
      confirmOverLimit: override,
    );

    try {
      final receipt = await ref.read(saleRepositoryProvider).submit(draft, operationId: operationId);
      if (!ref.mounted) return const CheckoutStayed();
      state = state.copyWith(submit: SubmitState.idle, clearOperation: true, afterUncertain: false);
      return CheckoutDone(receipt, afterUncertain: wasUncertain, overridden: override);
    } on ApiFailure catch (failure) {
      if (!ref.mounted) return const CheckoutStayed();
      return _onFailure(failure, override: override);
    }
  }

  CheckoutOutcome _onFailure(ApiFailure failure, {required bool override}) {
    switch (failure) {
      case NetworkFailure(:final maybeDelivered):
        state = state.copyWith(
          submit: maybeDelivered ? SubmitState.uncertain : SubmitState.offline,
          afterUncertain: maybeDelivered || state.afterUncertain,
        );
      case ServerError() || TooManyRequests():
        state = state.copyWith(submit: SubmitState.server, reference: failure.reference);
      case BusinessRuleViolation(code: 'CREDIT_LIMIT_EXCEEDED'):
        state = state.copyWith(submit: SubmitState.limit, clearOperation: true, serverMessage: failure.message);
      case BusinessRuleViolation(code: 'CREDIT_LIMIT_CONFIRMATION_REQUIRED'):
        // The server saw an over-limit the client did not (the balance changed): ask explicitly.
        state = state.copyWith(submit: SubmitState.idle, clearOperation: true);
        return const CheckoutNeedsOverride();
      case Forbidden() when override:
        state = state.copyWith(submit: SubmitState.forbidden, clearOperation: true);
      case ValidationFailed(:final fieldErrors) when fieldErrors.containsKey('customer_id'):
        state = state.copyWith(submit: SubmitState.idle, customerMissing: true, clearOperation: true);
      case Unauthenticated() || UserInactive():
        // The session handler takes over (re-login keeps the cart); the key stays for the retry.
        state = state.copyWith(submit: SubmitState.idle);
      default:
        state = state.copyWith(submit: SubmitState.rejected, clearOperation: true, serverMessage: failure.message);
    }
    return const CheckoutStayed();
  }

  static String _isoDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

final checkoutControllerProvider = NotifierProvider.autoDispose<CheckoutController, CheckoutState>(
  CheckoutController.new,
);
