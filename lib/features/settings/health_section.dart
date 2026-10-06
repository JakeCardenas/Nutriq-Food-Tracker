import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../app/format.dart';
import '../../app/theme.dart';
import '../../state/health_controller.dart';
import '../../widgets/adaptive.dart';
import '../../widgets/surfaces.dart';

/// Apple Health: optional and off by default. Reading (steps, workouts, active
/// energy, weight) and writing meal nutrition are separate switches.
class HealthSection extends StatelessWidget {
  const HealthSection({super.key});

  @override
  Widget build(BuildContext context) {
    final health = AppScope.of(context).health;
    return ListenableBuilder(
      listenable: health,
      builder: (context, _) {
        final status = health.status;
        if (status == HealthStatus.unsupported) {
          return NqGroup(
            header: 'Apple Health',
            footer: defaultTargetPlatform == TargetPlatform.iOS
                ? 'Apple Health isn’t available on this device.'
                : 'Apple Health is on iPhone only. Android Health Connect isn’t supported in this version.',
            children: const [NqRow(icon: Icons.favorite_border_rounded, title: 'Apple Health', value: 'Not available')],
          );
        }
        final connected = status == HealthStatus.connected;
        return NqGroup(
          header: 'Apple Health',
          footer: connected
              ? 'Read data stays on this phone and is never uploaded. To revoke access completely, open the '
                    'Health app → your profile → Apps → Nutriq.'
              : 'Optional. Nutriq asks Apple Health for permission only when you connect. Data you allow stays '
                    'on this phone and is never uploaded.',
          children: [
            NqRow(
              icon: Icons.favorite_border_rounded,
              title: connected ? 'Connected' : 'Connect Apple Health',
              subtitle: connected
                  ? (health.lastRead == null
                        ? 'Reading steps, workouts, energy and weight'
                        : 'Last read ${relativeTime(health.lastRead!)}')
                  : 'See steps, workouts, active energy and weight',
              trailing: status == HealthStatus.connecting
                  ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : null,
              showChevron: !connected && status != HealthStatus.connecting,
              onTap: switch (status) {
                HealthStatus.off || HealthStatus.error => health.connect,
                HealthStatus.connected => health.refresh,
                _ => null,
              },
            ),
            if (connected)
              NqRow(
                icon: Icons.restaurant_menu_rounded,
                title: 'Add meals to Apple Health',
                subtitle: 'Writes calories and macros once for each meal you log from now on',
                showChevron: false,
                trailing: Switch.adaptive(value: health.writeEnabled, onChanged: health.setWriteEnabled),
              ),
            if (health.message != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                child: Text(health.message!, style: NqText.footnote),
              ),
            if (connected)
              NqRow(
                icon: Icons.link_off_rounded,
                title: 'Disconnect',
                destructive: true,
                onTap: () async {
                  final ok = await confirmAction(
                    context,
                    title: 'Disconnect Apple Health?',
                    message:
                        'Nutriq stops reading and writing Apple Health on this phone. Data already written to '
                        'Apple Health stays there. You can also revoke access in the Health app.',
                    confirmLabel: 'Disconnect',
                  );
                  if (ok) await health.disconnect();
                },
              ),
          ],
        );
      },
    );
  }
}
