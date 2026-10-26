import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../../../core/api/api_failure.dart';
import '../../../core/providers.dart';
import '../../../core/theme/hisbah_tokens.dart';
import '../../../core/widgets/state_views.dart';
import '../../../l10n/app_localizations.dart';
import '../../products/presentation/add_product_flow.dart' show FieldLabel;
import '../../sale/presentation/sale_widgets.dart';
import '../data/more_repository.dart';
import 'more_widgets.dart';

final supportTicketsProvider = FutureProvider.autoDispose<List<SupportTicket>>(
  (ref) => ref.watch(moreRepositoryProvider).supportTickets(),
);

final _when = DateFormat('dd/MM/yyyy · HH:mm', 'en');

const _types = ['technical', 'account', 'suggestion', 'other'];

String _typeLabel(AppLocalizations t, String type) => switch (type) {
  'technical' => t.supportTypeTechnical,
  'account' => t.supportTypeAccount,
  'suggestion' => t.supportTypeSuggestion,
  _ => t.supportTypeOther,
};

/// Technical support: a complaint (type, subject, details) to the Hisbah team, then every
/// complaint the store sent with its status and the team's reply. Works after the subscription ends.
class SupportScreen extends ConsumerStatefulWidget {
  const SupportScreen({super.key});

  @override
  ConsumerState<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends ConsumerState<SupportScreen> {
  final _subject = TextEditingController();
  final _details = TextEditingController();
  String? _type;
  bool _sending = false;
  Map<String, String> _errors = const {};
  String? _banner;

  @override
  void dispose() {
    _subject.dispose();
    _details.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final t = AppLocalizations.of(context);
    final errors = {
      if (_type == null) 'type': t.supportTypeRequired,
      if (_subject.text.trim().isEmpty) 'subject': t.supportSubjectRequired,
      if (_details.text.trim().isEmpty) 'details': t.supportDetailsRequired,
    };
    setState(() {
      _errors = errors;
      _banner = null;
    });
    if (errors.isNotEmpty) return;
    setState(() => _sending = true);
    try {
      await ref.read(moreRepositoryProvider).sendSupportTicket(type: _type!, subject: _subject.text, details: _details.text);
      if (!mounted) return;
      _subject.clear();
      _details.clear();
      setState(() => _type = null);
      ref.invalidate(supportTicketsProvider);
      showNote(context, t.supportSent);
    } on ValidationFailed catch (failure) {
      if (mounted) {
        setState(() {
          _errors = {
            for (final e in failure.fieldErrors.entries)
              if (e.value.isNotEmpty) e.key: e.value.first,
          };
          if (_errors.isEmpty) _banner = failure.message;
        });
      }
    } on ApiFailure catch (failure) {
      if (mounted) setState(() => _banner = failure.message ?? t.staffActionError);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final tickets = ref.watch(supportTicketsProvider);
    return Scaffold(
      appBar: AppBar(title: Text(t.moreSupport)),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(supportTicketsProvider.future),
        child: ListView(
          padding: EdgeInsets.fromLTRB(16, 12, 16, 24 + MediaQuery.paddingOf(context).bottom),
          children: [
            if (_banner != null) ...[
              ToneCard(tone: StatusTone.error, icon: Icons.error_outline_rounded, title: _banner!, alert: true),
              const SizedBox(height: 12),
            ],
            FieldLabel(label: t.supportType, required: true),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final type in _types)
                  ChoiceChip(
                    key: Key('support.type.$type'),
                    label: Text(_typeLabel(t, type)),
                    selected: _type == type,
                    onSelected: _sending
                        ? null
                        : (_) => setState(() {
                            _type = type;
                            _errors = {..._errors}..remove('type');
                          }),
                  ),
              ],
            ),
            if (_errors['type'] != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(_errors['type']!, style: TextStyle(fontSize: 12, color: StatusTone.error.fg)),
              ),
            const SizedBox(height: 14),
            MoreField(
              fieldKey: 'support.subject',
              label: t.supportSubject,
              controller: _subject,
              required: true,
              hint: t.phSupportSubject,
              error: _errors['subject'],
              enabled: !_sending,
            ),
            MoreField(
              fieldKey: 'support.details',
              label: t.supportDetails,
              controller: _details,
              required: true,
              hint: t.phSupportDetails,
              error: _errors['details'],
              enabled: !_sending,
              maxLines: 8,
              action: TextInputAction.newline,
            ),
            FilledButton(
              key: const Key('support.send'),
              onPressed: _sending ? null : _send,
              child: BusyLabel(busy: _sending, label: t.supportSend),
            ),
            const SizedBox(height: 22),
            GroupLabel(t.supportMine),
            const SizedBox(height: 8),
            tickets.when(
              loading: () => const LoadingView(rows: 2, padding: EdgeInsets.zero),
              error: (_, _) => ErrorView(message: t.supportLoadError, onRetry: () => ref.invalidate(supportTicketsProvider)),
              data: (list) => list.isEmpty
                  ? Text(t.supportNone, style: const TextStyle(color: HisbahColors.inkMuted))
                  : LineCard(
                      child: Column(
                        children: [
                          for (var i = 0; i < list.length; i++) ...[
                            if (i > 0) const Divider(height: 1, color: HisbahColors.border),
                            _TicketRow(ticket: list[i]),
                          ],
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TicketRow extends StatelessWidget {
  const _TicketRow({required this.ticket});

  final SupportTicket ticket;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final (label, tone) = switch (ticket.status) {
      'closed' => (t.supportStatusClosed, StatusTone.success),
      'in_progress' => (t.supportStatusInProgress, StatusTone.partial),
      _ => (t.supportStatusOpen, StatusTone.pending),
    };
    return Padding(
      key: Key('support.ticket.${ticket.id}'),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(ticket.subject, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: tone.bg,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: tone.line),
                ),
                child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: tone.fg)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            [
              _typeLabel(t, ticket.type),
              if (ticket.createdAt != null) _when.format(ticket.createdAt!),
              ?ticket.senderName,
            ].join(' · '),
            style: const TextStyle(fontSize: 12, color: HisbahColors.inkMuted),
          ),
          const SizedBox(height: 8),
          Text(ticket.details, style: const TextStyle(height: 1.6)),
          if (ticket.reply != null) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: HisbahColors.primaryTint, borderRadius: BorderRadius.circular(12)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    t.supportReply,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: HisbahColors.primary),
                  ),
                  const SizedBox(height: 4),
                  Text(ticket.reply!, style: const TextStyle(height: 1.6)),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
