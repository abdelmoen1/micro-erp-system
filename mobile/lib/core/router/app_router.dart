import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/application/session_controller.dart';
import '../../features/auth/domain/app_user.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/register_screen.dart';
import '../../features/auth/presentation/subscription_expired_screen.dart';
import '../../features/shell/app_shell.dart';
import '../../features/shell/splash_screen.dart';
import '../../features/shell/tab_screens.dart';
import '../providers.dart';

abstract final class Routes {
  static const splash = '/splash';
  static const login = '/login';
  static const register = '/register';
  static const subscriptionExpired = '/subscription-expired';
  static const home = '/home';
  static const pos = '/pos';
  static const customers = '/customers';
  static const products = '/products';
  static const more = '/more';
}

/// Role landing (US-1505): employee → POS, owner / manager → Home.
String landingFor(AppUser user) => user.role.landsOnPos ? Routes.pos : Routes.home;

/// Pure redirect rule, unit-testable without widgets.
String? sessionRedirect(SessionState session, Uri uri) {
  final location = uri.path;
  const entry = {Routes.splash, Routes.login, Routes.register, Routes.subscriptionExpired};

  switch (session) {
    case SessionRestoring():
      return location == Routes.splash ? null : Routes.splash;
    case AccountBlocked():
      // Shown on the login screen as a banner (hi-fi M-01 · 403); another account may sign in.
      return location == Routes.login ? null : Routes.login;
    case SubscriptionLapsed():
      // The trial or subscription has ended: only the renewal screen until it is activated.
      return location == Routes.subscriptionExpired ? null : Routes.subscriptionExpired;
    case SignedOut(:final reason, :final previousUserId):
      if (location == Routes.login || location == Routes.register) return null;
      if (reason != SignedOutReason.sessionExpired) return Routes.login;
      // Expired mid-use: remember where the user was, to return there after re-login.
      return Uri(
        path: Routes.login,
        queryParameters: {
          'expired': '1',
          if (!entry.contains(location)) 'from': uri.toString(),
          if (previousUserId != null) 'uid': '$previousUserId',
        },
      ).toString();
    case SignedIn(:final user):
      if (!entry.contains(location)) return null;
      final from = uri.queryParameters['from'];
      final sameUser = uri.queryParameters['uid'] == '${user.id}';
      return from != null && sameUser ? from : landingFor(user);
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier<int>(0);
  ref.listen(sessionProvider, (_, _) => refresh.value++);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: Routes.splash,
    refreshListenable: refresh,
    debugLogDiagnostics: kDebugMode,
    redirect: (context, state) => sessionRedirect(ref.read(sessionProvider), state.uri),
    routes: [
      GoRoute(path: Routes.splash, builder: (_, _) => const SplashScreen()),
      GoRoute(
        path: Routes.login,
        builder: (_, state) => LoginScreen(sessionExpired: state.uri.queryParameters['expired'] == '1'),
      ),
      GoRoute(path: Routes.register, builder: (_, _) => const RegisterScreen()),
      GoRoute(path: Routes.subscriptionExpired, builder: (_, _) => const SubscriptionExpiredScreen()),
      StatefulShellRoute.indexedStack(
        builder: (_, _, shell) => AppShell(shell: shell),
        branches: [
          for (final tab in AppTab.values)
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: tab.path,
                  builder: (_, _) => TabRootScreen(tab: tab),
                ),
              ],
            ),
        ],
      ),
    ],
  );
});
