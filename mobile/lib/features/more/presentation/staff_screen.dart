import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../../../core/api/api_failure.dart';
import '../../../core/providers.dart';
import '../../../core/theme/hisbah_tokens.dart';
import '../../../core/widgets/ltr_value.dart';
import '../../../core/widgets/state_views.dart';
import '../../../l10n/app_localizations.dart';
import '../../auth/application/session_controller.dart';
import '../../auth/domain/app_user.dart';
import '../../auth/presentation/subscription_expired_screen.dart' show externalLinkLauncherProvider;
import '../../sale/presentation/sale_widgets.dart';
import '../data/more_repository.dart';
import 'more_widgets.dart';

final staffProvider = FutureProvider.autoDispose<List<StaffMember>>((ref) => ref.watch(moreRepositoryProvider).staff());

String roleName(AppLocalizations t, UserRole role) => switch (role) {
  UserRole.owner => t.roleOwner,
  UserRole.manager => t.roleManager,
  UserRole.employee => t.roleEmployee,
};

/// The owner's staff: who works in the store and in which role, an invite link for a new
/// manager or employee, a role change, and deactivation (US-0204, same rules as the web).
class StaffScreen extends ConsumerStatefulWidget {
  const StaffScreen({super.key});

  @override
  ConsumerState<StaffScreen> createState() => _StaffScreenState();
}

class _StaffScreenState extends ConsumerState<StaffScreen> {
  bool _busy = false;

  Future<void> _run(Future<void> Function() action, String done) async {
    final t = AppLocalizations.of(context);
    setState(() => _busy = true);
    try {
      await action();
      ref.invalidate(staffProvider);
      if (mounted) showNote(context, done);
    } on ApiFailure catch (failure) {
      if (mounted) showNote(context, failure is Forbidden ? t.staffOwnerOnly : (failure.message ?? t.staffActionError));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _actions(StaffMember member) async {
    final t = AppLocalizations.of(context);
    final other = member.role == UserRole.manager ? UserRole.employee : UserRole.manager;
    final choice = await showSaleSheet<String>(
      context,
      builder: (sheet) => Padding(
        padding: EdgeInsets.fromLTRB(16, 8, 16, 16 + MediaQuery.paddingOf(sheet).bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SheetHeader(title: member.name, closeLabel: t.cancel),
            const SizedBox(height: 8),
            LineCard(
              child: Column(
                children: [
                  MoreTile(
                    key: const Key('staff.makeRole'),
                    icon: other == UserRole.manager ? Icons.admin_panel_settings_outlined : Icons.badge_outlined,
                    title: other == UserRole.manager ? t.staffMakeManager : t.staffMakeEmployee,
                    onTap: () => Navigator.of(sheet).pop('role'),
                  ),
                  const Divider(height: 1, color: HisbahColors.border),
                  InkWell(
                    key: const Key('staff.deactivate'),
                    onTap: () => Navigator.of(sheet).pop('deactivate'),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
                      child: Row(
                        children: [
                          Icon(Icons.person_off_outlined, color: StatusTone.error.fg),
                          const SizedBox(width: 12),
                          Text(t.staffDeactivate, style: TextStyle(fontWeight: FontWeight.w700, color: StatusTone.error.fg)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
    if (!mounted || choice == null) return;
    final repository = ref.read(moreRepositoryProvider);
    if (choice == 'role') {
      await _run(() => repository.changeRole(member.id, other), t.staffRoleChanged(member.name, roleName(t, other)));
    } else if (await confirmDanger(
      context,
      title: t.staffDeactivateTitle(member.name),
      body: t.staffDeactivateBody,
      action: t.staffDeactivate,
    )) {
      await _run(() => repository.deactivate(member.id), t.staffDeactivated(member.name));
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final session = ref.watch(sessionProvider);
    final me = session is SignedIn ? session.user : null;
    final staff = ref.watch(staffProvider);

    return Scaffold(
      appBar: AppBar(title: Text(t.staffTitle)),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_busy) const LinearProgressIndicator(minHeight: 2),
          Expanded(
            child: staff.when(
              loading: () => const LoadingView(),
              error: (error, _) => ErrorView(
                message: error is Forbidden ? t.staffOwnerOnly : t.staffLoadError,
                onRetry: () => ref.invalidate(staffProvider),
              ),
              data: (members) => RefreshIndicator(
                onRefresh: () => ref.refresh(staffProvider.future),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  children: [
                    LineCard(
                      child: Column(
                        children: [
                          if (me != null) _PersonRow(name: me.name, email: me.email, badge: '${t.staffYou} · ${t.roleOwner}'),
                          for (final m in members) ...[
                            const Divider(height: 1, color: HisbahColors.border),
                            _PersonRow(
                              key: Key('staff.row.${m.id}'),
                              name: m.name,
                              email: m.email,
                              badge: m.active ? roleName(t, m.role) : t.staffInactive,
                              muted: !m.active,
                              onTap: m.active && !_busy ? () => _actions(m) : null,
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (members.isEmpty) ...[
                      const SizedBox(height: 12),
                      Text(t.staffEmpty, style: const TextStyle(color: HisbahColors.inkMuted, height: 1.6)),
                    ],
                    const SizedBox(height: 14),
                    Text(t.staffRolesNote, style: const TextStyle(fontSize: 13, height: 1.6, color: HisbahColors.inkMuted)),
                  ],
                ),
              ),
            ),
          ),
          ActionBar(
            bottomInset: MediaQuery.paddingOf(context).bottom,
            child: FilledButton.icon(
              key: const Key('staff.invite'),
              onPressed: () async {
                await showSaleSheet<void>(context, builder: (_) => InviteSheet(storeName: me?.storeName ?? ''));
                ref.invalidate(staffProvider);
              },
              icon: const Icon(Icons.person_add_alt_1_rounded),
              label: Text(t.staffInvite),
            ),
          ),
        ],
      ),
    );
  }
}

class _PersonRow extends StatelessWidget {
  const _PersonRow({super.key, required this.name, required this.email, required this.badge, this.muted = false, this.onTap});

  final String name;
  final String email;
  final String badge;
  final bool muted;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Opacity(
      opacity: muted ? 0.6 : 1,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
        child: Row(
          children: [
            InitialAvatar(name.trim().isEmpty ? '؟' : name.trim().characters.first),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: const TextStyle(fontWeight: FontWeight.w700)),
                  LtrValue(email, style: const TextStyle(fontSize: 13, color: HisbahColors.inkMuted)),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
              decoration: BoxDecoration(color: HisbahColors.ground, borderRadius: BorderRadius.circular(999)),
              child: Text(badge, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
            ),
            if (onTap != null) const Icon(Icons.more_vert_rounded, color: HisbahColors.inkMuted) else const SizedBox(width: 8),
          ],
        ),
      ),
    ),
  );
}

final _expiry = DateFormat('dd/MM/yyyy HH:mm', 'en');

/// «دعوة موظف»: the role and how long the link lives, then the link to copy or send on WhatsApp.
/// The link is shown once (the server keeps only its hash).
class InviteSheet extends ConsumerStatefulWidget {
  const InviteSheet({super.key, required this.storeName});

  final String storeName;

  @override
  ConsumerState<InviteSheet> createState() => _InviteSheetState();
}

class _InviteSheetState extends ConsumerState<InviteSheet> {
  final _email = TextEditingController();
  UserRole _role = UserRole.employee;
  int _hours = 24;
  bool _busy = false;
  String? _error;
  String? _emailError;
  StaffInvite? _invite;
  bool _whatsappFailed = false;
  bool _copied = false;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final t = AppLocalizations.of(context);
    setState(() {
      _busy = true;
      _error = null;
      _emailError = null;
    });
    try {
      final invite = await ref.read(moreRepositoryProvider).invite(role: _role, hours: _hours, email: _email.text);
      if (mounted) setState(() => _invite = invite);
    } on ValidationFailed catch (failure) {
      if (mounted) setState(() => _emailError = failure.fieldErrors['email']?.first ?? failure.message);
    } on ApiFailure catch (failure) {
      if (mounted) {
        setState(() => _error = failure is Forbidden ? t.staffOwnerOnly : (failure.message ?? t.staffActionError));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _whatsapp(StaffInvite invite) async {
    final t = AppLocalizations.of(context);
    final text = t.inviteWhatsappText(widget.storeName, roleName(t, invite.role), invite.link);
    var opened = false;
    try {
      opened = await ref.read(externalLinkLauncherProvider)(Uri.parse('https://wa.me/?text=${Uri.encodeComponent(text)}'));
    } on Object {
      opened = false;
    }
    if (mounted) setState(() => _whatsappFailed = !opened);
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final invite = _invite;
    return FormSheet(
      header: SheetHeader(title: t.staffInvite, closeLabel: t.cancel),
      action: invite == null
          ? FilledButton(
              key: const Key('invite.create'),
              onPressed: _busy ? null : _create,
              child: BusyLabel(busy: _busy, label: _busy ? t.inviteCreating : t.inviteCreate),
            )
          : FilledButton(
              key: const Key('invite.done'),
              onPressed: () => Navigator.of(context).pop(),
              child: Text(t.inviteDone),
            ),
      children: invite == null
          ? [
              GroupLabel(t.inviteRole),
              const SizedBox(height: 8),
              OptionRow(
                children: [
                  OptionButton(
                    key: const Key('invite.role.employee'),
                    label: t.roleEmployee,
                    selected: _role == UserRole.employee,
                    onTap: _busy ? null : () => setState(() => _role = UserRole.employee),
                  ),
                  OptionButton(
                    key: const Key('invite.role.manager'),
                    label: t.roleManager,
                    selected: _role == UserRole.manager,
                    onTap: _busy ? null : () => setState(() => _role = UserRole.manager),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              GroupLabel(t.inviteValid),
              const SizedBox(height: 8),
              OptionRow(
                children: [
                  for (final (hours, label) in [(24, t.invite24h), (72, t.invite3d), (168, t.invite7d)])
                    OptionButton(
                      key: Key('invite.hours.$hours'),
                      label: label,
                      selected: _hours == hours,
                      onTap: _busy ? null : () => setState(() => _hours = hours),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              MoreField(
                fieldKey: 'invite.email',
                label: t.inviteEmail,
                controller: _email,
                keyboard: TextInputType.emailAddress,
                ltr: true,
                helper: t.inviteEmailHint,
                error: _emailError,
                enabled: !_busy,
                action: TextInputAction.done,
              ),
              if (_error != null) ToneCard(tone: StatusTone.error, icon: Icons.error_outline_rounded, title: _error!, alert: true),
            ]
          : [
              ToneCard(tone: StatusTone.success, icon: Icons.check_circle_outline_rounded, title: t.inviteReady),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: HisbahColors.raised,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: HisbahColors.border),
                ),
                child: SelectableText(
                  invite.link,
                  key: const Key('invite.link'),
                  textDirection: TextDirection.ltr,
                  style: const TextStyle(fontSize: 13),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                [
                  roleName(t, invite.role),
                  if (invite.expiresAt != null) t.inviteExpires(_expiry.format(invite.expiresAt!)),
                  ?invite.email,
                ].join(' · '),
                style: const TextStyle(fontSize: 13, color: HisbahColors.inkMuted),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                key: const Key('invite.whatsapp'),
                onPressed: () => _whatsapp(invite),
                icon: const Icon(Icons.chat_outlined),
                label: Text(t.inviteWhatsapp),
              ),
              if (_whatsappFailed)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(t.inviteWhatsappFailed, style: TextStyle(color: StatusTone.error.fg, fontSize: 13)),
                ),
              const SizedBox(height: 8),
              // The confirmation is on the button itself: a snackbar would sit behind the sheet.
              OutlinedButton.icon(
                key: const Key('invite.copy'),
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: invite.link));
                  if (mounted) setState(() => _copied = true);
                },
                icon: Icon(_copied ? Icons.check_rounded : Icons.copy_rounded, size: 18),
                label: Text(_copied ? t.inviteCopied : t.inviteCopy),
              ),
              const SizedBox(height: 10),
              Text(t.inviteHowTo, style: const TextStyle(fontSize: 13, height: 1.6, color: HisbahColors.inkMuted)),
            ],
    );
  }
}
