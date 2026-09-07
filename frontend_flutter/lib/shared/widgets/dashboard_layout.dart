import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend_flutter/features/settings/data/settings_provider.dart';
import 'package:frontend_flutter/shared/widgets/sidebar.dart';
import 'package:frontend_flutter/shared/widgets/topbar.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class DashboardLayout extends ConsumerWidget {
  final Widget child;

  const DashboardLayout({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clinicAsync = ref.watch(myClinicProvider);
    final status = clinicAsync.value?.status.toLowerCase();
    final showGraceBanner = status == 'grace_period' || status == 'past_due';

    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= 1024;

        final contentBody = Column(
          children: [
            Topbar(showMenuButton: !isDesktop),
            if (showGraceBanner)
              Container(
                width: double.infinity,
                color: Colors.amber[800],
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    const Icon(LucideIcons.triangleAlert, color: Colors.white, size: 18),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Atenção: Identificamos um problema no pagamento da sua assinatura. Você possui 3 dias de tolerância para regularizar.',
                        style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                    ),
                    TextButton(
                      onPressed: () => context.go('/settings'),
                      style: TextButton.styleFrom(foregroundColor: Colors.white),
                      child: const Text('Regularizar Agora', style: TextStyle(decoration: TextDecoration.underline, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: child,
            ),
          ],
        );

        if (isDesktop) {
          return Scaffold(
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            body: Row(
              children: [
                const Sidebar(),
                Expanded(child: contentBody),
              ],
            ),
          );
        }

        return Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          drawer: const Drawer(child: Sidebar()),
          body: contentBody,
        );
      },
    );
  }
}

