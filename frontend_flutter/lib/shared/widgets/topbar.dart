import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend_flutter/features/auth/providers/auth_provider.dart';
import 'package:frontend_flutter/features/auth/widgets/room_selector.dart';
import 'package:go_router/go_router.dart';
import 'package:frontend_flutter/core/network/api_client.dart';

class Topbar extends ConsumerWidget implements PreferredSizeWidget {
  final bool showMenuButton;

  const Topbar({super.key, this.showMenuButton = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final currentUserAsync = ref.watch(currentUserProvider);
    final theme = Theme.of(context);
    final mediaQuery = MediaQuery.of(context);
    final isNarrow = mediaQuery.size.width < 768;
    final isVeryNarrow = mediaQuery.size.width < 480;

    return Container(
      height: 70,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: 0.95),
        border: Border(
          bottom: BorderSide(color: theme.dividerTheme.color ?? theme.colorScheme.outline, width: 1),
        ),
      ),
      padding: EdgeInsets.symmetric(horizontal: isNarrow ? 12 : 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Lado Esquerdo: Menu / Logo / Título
          Expanded(
            child: Row(
              children: [
                if (showMenuButton) ...[
                  Semantics(
                    label: 'Abrir menu de navegação lateral',
                    button: true,
                    child: IconButton(
                      icon: Icon(LucideIcons.menu, color: theme.iconTheme.color, size: 24),
                      onPressed: () {
                        Scaffold.of(context).openDrawer();
                      },
                    ),
                  ),
                  const SizedBox(width: 4),
                ],
                if (!showMenuButton || !isVeryNarrow) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2563EB).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFF2563EB).withValues(alpha: 0.3), width: 1),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(LucideIcons.activity, color: Color(0xFF2563EB), size: 18),
                        if (!isNarrow) ...[
                          const SizedBox(width: 6),
                          const Text(
                            'DentalCRM',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF2563EB),
                              letterSpacing: -0.5,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(width: 1, height: 20, color: theme.dividerTheme.color ?? theme.colorScheme.outline),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: Text(
                    _getPageTitle(context),
                    style: TextStyle(
                      fontSize: isVeryNarrow ? 15 : 18,
                      fontWeight: FontWeight.w600,
                      color: theme.textTheme.titleLarge?.color ?? theme.colorScheme.onSurface,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),

          // Lado Direito: Sala, Usuário, Menu
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              currentUserAsync.when(
                data: (user) {
                  final initials = user.name.isNotEmpty
                      ? (user.name.split(' ').length > 1
                          ? '${user.name.split(' ')[0][0]}${user.name.split(' ')[1][0]}'
                          : user.name.substring(0, user.name.length > 1 ? 2 : 1))
                      : 'US';

                  final isDoctor = user.role?.name == 'doctor' ||
                      user.role?.name == 'dentist' ||
                      authState.role == 'doctor' ||
                      authState.role == 'medico';

                  String? avatarUrl = user.avatar;
                  if (avatarUrl != null && avatarUrl.isNotEmpty && avatarUrl.startsWith('/uploads')) {
                    avatarUrl = '$backendBaseUrl$avatarUrl';
                  }

                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isDoctor && !isNarrow) ...[
                        const RoomSelector(),
                        const SizedBox(width: 12),
                      ],
                      avatarUrl != null && avatarUrl.isNotEmpty
                          ? Container(
                              height: 38,
                              width: 38,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(color: const Color(0xFF2563EB), width: 2),
                                image: DecorationImage(
                                  image: NetworkImage(avatarUrl),
                                  fit: BoxFit.cover,
                                ),
                              ),
                            )
                          : Container(
                              height: 38,
                              width: 38,
                              decoration: BoxDecoration(
                                color: const Color(0xFF2563EB).withValues(alpha: 0.15),
                                shape: BoxShape.circle,
                                border: Border.all(color: const Color(0xFF2563EB), width: 2),
                              ),
                              child: Center(
                                child: Text(
                                  initials.toUpperCase(),
                                  style: const TextStyle(
                                    color: Color(0xFF2563EB),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ),
                      if (!isNarrow) ...[
                        const SizedBox(width: 10),
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              user.name,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: theme.textTheme.titleLarge?.color ?? theme.colorScheme.onSurface,
                              ),
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  user.role?.name ?? authState.role,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: theme.textTheme.bodyMedium?.color ?? theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                                if (isDoctor) ...[
                                  const SizedBox(width: 4),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF10B981).withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3), width: 1),
                                    ),
                                    child: const Text(
                                      'CRO',
                                      style: TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF10B981),
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ],
                    ],
                  );
                },
                loading: () => const SizedBox(width: 32, height: 32, child: Center(child: CircularProgressIndicator(strokeWidth: 2))),
                error: (e, _) => const Icon(LucideIcons.alertCircle, color: Colors.red, size: 20),
              ),
              PopupMenuButton(
                icon: Icon(LucideIcons.chevronDown, color: theme.iconTheme.color, size: 20),
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'profile',
                    child: Text('Meu Perfil'),
                  ),
                  const PopupMenuItem(
                    value: 'logout',
                    child: Text('Sair', style: TextStyle(color: Colors.red)),
                  ),
                ],
                onSelected: (value) {
                  if (value == 'logout') {
                    ref.read(authProvider.notifier).logout();
                  }
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(70);

  String _getPageTitle(BuildContext context) {
    final path = GoRouterState.of(context).uri.path;
    if (path.startsWith('/patients')) return 'Pacientes';
    if (path.startsWith('/communications')) return 'Comunicações';
    if (path.startsWith('/schedule')) return 'Agenda';
    if (path.startsWith('/financial')) return 'Financeiro';
    if (path.startsWith('/inventory')) return 'Estoque';
    if (path.startsWith('/trash')) return 'Lixeira (LGPD)';
    if (path.startsWith('/marketing')) return 'Marketing';
    if (path.startsWith('/settings')) return 'Configurações';
    return 'Painel de Controle';
  }
}

