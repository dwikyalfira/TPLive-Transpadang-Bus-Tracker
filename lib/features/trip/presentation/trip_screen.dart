import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_motion.dart';
import '../../../core/ui/constrained_content.dart';
import '../../../core/ui/fade_through_route.dart';
import '../../../core/ui/state_views.dart';
import '../../../l10n/app_localizations.dart';
import '../../tracking/domain/bus_with_distance.dart';
import '../../tracking/presentation/providers.dart';
import '../../tracking/presentation/widgets/corridor_badge.dart';
import '../../tracking/presentation/widgets/follow_bus_button.dart';
import '../../tracking/presentation/widgets/format.dart';
import '../../tracking/presentation/widgets/halte_timeline_sheet.dart';
import '../../tracking/presentation/widgets/location_error_view.dart';
import '../domain/saved_place.dart';
import '../domain/trip_endpoint.dart';
import '../domain/trip_planner.dart';
import 'location_picker_screen.dart';
import 'trip_providers.dart';

/// Layar perencana perjalanan: pilih asal & tujuan (halte/tempat/GPS),
/// lalu tampilkan rute TransPadang.
class TripScreen extends ConsumerWidget {
  const TripScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final origin = ref.watch(tripOriginEndpointProvider);
    final destination = ref.watch(tripDestinationEndpointProvider);

    return Scaffold(
      appBar: AppBar(
          title: Text(AppLocalizations.of(context).searchDestinationTitle)),
      body: ConstrainedContent(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
              child: _RouteField(
                origin: origin,
                destination: destination,
                onTapOrigin: () => _pickOrigin(context, ref),
                onTapDestination: () => _pickDestination(context, ref),
              ),
            ),
            Expanded(
              child: _PlanArea(
                onPickOrigin: () => _pickOrigin(context, ref),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickOrigin(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final result = await Navigator.of(context).push<TripEndpoint>(
      _pickerRoute(
        LocationPickerScreen(title: l10n.pickOriginTitle, includeGps: true),
      ),
    );
    if (result != null) {
      ref.read(tripOriginEndpointProvider.notifier).state = result;
    }
  }

  Future<void> _pickDestination(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final result = await Navigator.of(context).push<TripEndpoint>(
      _pickerRoute(LocationPickerScreen(title: l10n.pickDestinationTitle)),
    );
    if (result != null) {
      ref.read(tripDestinationEndpointProvider.notifier).state = result;
      final saved = SavedPlace.fromEndpoint(result);
      if (saved != null) {
        ref.read(savedPlacesProvider.notifier).addRecent(saved);
      }
    }
  }

  /// Transisi halus (fade-through Material 3) menuju pemilih asal/tujuan.
  Route<TripEndpoint> _pickerRoute(Widget screen) {
    return fadeThroughRoute<TripEndpoint>(builder: (_) => screen);
  }
}

/// Kartu gabungan "Dari" / "Ke" — kedua kolom disatukan dalam satu kartu agar
/// lebih ringkas, dengan penghubung vertikal seperti aplikasi navigasi modern.
class _RouteField extends StatelessWidget {
  final TripEndpoint? origin;
  final TripEndpoint? destination;
  final VoidCallback onTapOrigin;
  final VoidCallback onTapDestination;

  const _RouteField({
    required this.origin,
    required this.destination,
    required this.onTapOrigin,
    required this.onTapDestination,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);

    return Material(
      color: scheme.surfaceVariant.withOpacity(0.5),
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _RouteFieldRow(
            label: l10n.fieldFrom,
            hint: l10n.hintPickOrigin,
            endpoint: origin,
            icon: Icons.trip_origin,
            accent: scheme.primary,
            onTap: onTapOrigin,
          ),
          // Penghubung vertikal antar baris (garis rute tepat di bawah ikon).
          Padding(
            padding: const EdgeInsets.only(left: 35),
            child: Row(
              children: [
                Container(
                  width: 2,
                  height: 12,
                  decoration: BoxDecoration(
                    color: scheme.outlineVariant,
                    borderRadius: BorderRadius.circular(1),
                  ),
                ),
              ],
            ),
          ),
          _RouteFieldRow(
            label: l10n.fieldTo,
            hint: l10n.hintPickDestination,
            endpoint: destination,
            icon: Icons.place,
            accent: const Color(0xFFC8163F),
            onTap: onTapDestination,
          ),
        ],
      ),
    );
  }
}

/// Satu baris pada [_RouteField] yang bisa diketuk untuk membuka pemilih.
class _RouteFieldRow extends StatelessWidget {
  final String label;
  final String hint;
  final TripEndpoint? endpoint;
  final IconData icon;
  final Color accent;
  final VoidCallback onTap;

  const _RouteFieldRow({
    required this.label,
    required this.hint,
    required this.endpoint,
    required this.icon,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);
    final hasValue = endpoint != null;
    final valueText =
        hasValue ? (endpoint!.isGps ? l10n.myLocation : endpoint!.label) : hint;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            // Wadah tonal M3 untuk ikon asal/tujuan.
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: accent.withOpacity(0.14),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 20, color: accent),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: theme.textTheme.labelMedium
                        ?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 2),
                  // Nama tempat + info koridor pada satu baris supaya tetap
                  // ringkas (menggantikan tiga baris terpisah). Nilai yang baru
                  // dipilih dianimasikan (fade + meluncur) saat berubah.
                  AnimatedSwitcher(
                    duration: AppMotion.medium2,
                    switchInCurve: AppMotion.emphasizedDecelerate,
                    switchOutCurve: AppMotion.emphasizedAccelerate,
                    transitionBuilder: (child, animation) => FadeTransition(
                      opacity: animation,
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0, 0.25),
                          end: Offset.zero,
                        ).animate(animation),
                        child: child,
                      ),
                    ),
                    child: Text.rich(
                      key: ValueKey(
                        '${hasValue ? endpoint!.label : hint}|${endpoint?.corridors}',
                      ),
                      TextSpan(
                        children: [
                          TextSpan(
                            text: valueText,
                            style: theme.textTheme.bodyLarge?.copyWith(
                              fontWeight:
                                  hasValue ? FontWeight.w600 : FontWeight.w400,
                              color: hasValue
                                  ? scheme.onSurface
                                  : scheme.onSurfaceVariant,
                            ),
                          ),
                          if (hasValue && endpoint!.corridors != null)
                            TextSpan(
                              text: '  ·  ${endpoint!.corridors}',
                              style: theme.textTheme.bodySmall
                                  ?.copyWith(color: scheme.onSurfaceVariant),
                            ),
                        ],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}

class _PlanArea extends ConsumerWidget {
  final VoidCallback onPickOrigin;

  const _PlanArea({required this.onPickOrigin});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final destination = ref.watch(tripDestinationEndpointProvider);
    if (destination == null) {
      return EmptyStateView(
        icon: Icons.route,
        message: l10n.planChooseDestination,
      );
    }

    final origin = ref.watch(tripOriginEndpointProvider);
    final locationAsync = origin.isGps ? ref.watch(userLocationProvider) : null;
    if (locationAsync != null && locationAsync.hasError) {
      return LocationErrorView(
        error: locationAsync.error!,
        onRetry: () => ref.invalidate(userLocationProvider),
        secondaryAction: TextButton(
          onPressed: onPickOrigin,
          child: Text(l10n.planPickStopInstead),
        ),
      );
    }
    if (locationAsync != null && locationAsync.valueOrNull == null) {
      return EmptyStateView(
        icon: Icons.my_location,
        message: l10n.planWaitingLocation,
      );
    }

    final plan = ref.watch(tripPlanProvider);
    if (plan == null) {
      return EmptyStateView(
        icon: Icons.hourglass_empty,
        message: l10n.planCalculating,
      );
    }
    if (!plan.hasOptions) {
      return EmptyStateView(
        icon: Icons.directions_bus_outlined,
        message: l10n.planNoRoute,
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        ...plan.options.map((option) => _OptionCard(option: option)),
      ],
    );
  }
}

class _OptionCard extends ConsumerWidget {
  final TripOption option;

  const _OptionCard({required this.option});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final buses = ref.watch(tripBusesProvider(option.legs.first));

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                for (final corridor
                    in option.legs.map((l) => l.corridor).toSet())
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: CorridorBadge(
                      corridor: corridor,
                      size: 30,
                      fontSize: 11,
                    ),
                  ),
                const Spacer(),
                Text(
                  l10n.minutesApprox(option.totalMinutes),
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              l10n.routeSummary(
                    formatDistance(option.totalKm),
                    option.legs.fold<int>(0, (s, l) => s + l.stopCount),
                  ) +
                  (option.transferCount > 0
                      ? l10n.routeSummaryTransit(option.transferCount)
                      : l10n.routeSummaryDirect),
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 12),
            _RouteSteps(option: option),
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 10),
            _BusSection(buses: buses),
          ],
        ),
      ),
    );
  }
}

/// Menampilkan alur perjalanan sebagai timeline vertikal: rail berwarna
/// koridor pada segmen naik bus, garis putus-putus untuk segmen jalan kaki,
/// dan node khusus pada titik pindah bus.
class _RouteSteps extends StatelessWidget {
  final TripOption option;

  const _RouteSteps({required this.option});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);
    const walkThresholdKm = 0.05;
    final gray = theme.colorScheme.onSurfaceVariant;

    final steps = <_Step>[];

    if (option.walkToBoardKm >= walkThresholdKm) {
      steps.add(_Step(
        nodeColor: scheme.surfaceVariant,
        icon: Icons.directions_walk,
        iconColor: scheme.onSurfaceVariant,
        text: l10n.stepWalkToBoard(
          formatDistance(option.walkToBoardKm),
          option.legs.first.board.nama,
        ),
        railColor: gray,
        railDashed: true,
      ));
    }

    for (var i = 0; i < option.legs.length; i++) {
      final leg = option.legs[i];
      steps.add(_Step(
        nodeColor: corridorAccent(leg.corridor, theme),
        code: leg.corridor,
        text: l10n.stepRide(
          leg.corridor,
          leg.board.nama,
          leg.alight.nama,
          leg.stopCount,
        ),
        railColor: corridorAccent(leg.corridor, theme),
        railDashed: false,
      ));

      if (i < option.legs.length - 1) {
        final next = option.legs[i + 1];
        final sameHalte =
            leg.alight.nama.toLowerCase() == next.board.nama.toLowerCase();
        final walks = !sameHalte && option.transferWalkKm >= walkThresholdKm;
        if (walks) {
          steps.add(_Step(
            nodeColor: scheme.surfaceVariant,
            icon: Icons.directions_walk,
            iconColor: scheme.onSurfaceVariant,
            text: l10n.stepWalkTransfer(
              formatDistance(option.transferWalkKm),
              next.board.nama,
              next.corridor,
            ),
            railColor: gray,
            railDashed: true,
          ));
        } else {
          steps.add(_Step(
            nodeColor: scheme.primaryContainer,
            icon: Icons.sync_alt,
            iconColor: scheme.onPrimaryContainer,
            text: l10n.stepTransfer(next.corridor, leg.alight.nama),
            railColor: corridorAccent(next.corridor, theme),
            railDashed: false,
          ));
        }
      }
    }

    if (option.walkFromAlightKm >= walkThresholdKm) {
      steps.add(_Step(
        nodeColor: scheme.surfaceVariant,
        icon: Icons.flag_outlined,
        iconColor: scheme.onSurfaceVariant,
        text: l10n.stepWalkToDestination(
          formatDistance(option.walkFromAlightKm),
        ),
        railColor: gray,
        railDashed: true,
      ));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var k = 0; k < steps.length; k++)
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: 26,
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 3),
                        child: _node(theme, steps[k]),
                      ),
                      Expanded(
                        child: k < steps.length - 1
                            ? _RailLine(
                                color: steps[k].railColor,
                                dashed: steps[k].railDashed,
                              )
                            : const SizedBox.shrink(),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Padding(
                    padding:
                        EdgeInsets.only(bottom: k < steps.length - 1 ? 16 : 0),
                    child: Text(
                      steps[k].text,
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _node(ThemeData theme, _Step step) {
    return Container(
      width: 22,
      height: 22,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: step.nodeColor,
        shape: BoxShape.circle,
      ),
      child: step.code != null
          ? Text(
              step.code!,
              style: TextStyle(
                color: onCorridorColor(step.code!),
                fontSize: 9,
                fontWeight: FontWeight.w700,
              ),
            )
          : Icon(step.icon, size: 13, color: step.iconColor),
    );
  }
}

class _Step {
  final Color nodeColor;
  final IconData? icon;
  final Color? iconColor;
  final String? code;
  final String text;
  final Color railColor;
  final bool railDashed;

  const _Step({
    required this.nodeColor,
    this.icon,
    this.iconColor,
    this.code,
    required this.text,
    required this.railColor,
    required this.railDashed,
  });
}

/// Segmen rail vertikal penghubung antar node timeline.
class _RailLine extends StatelessWidget {
  final Color color;
  final bool dashed;

  const _RailLine({required this.color, this.dashed = false});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _RailPainter(color: color, dashed: dashed),
      child: const SizedBox(width: double.infinity, height: double.infinity),
    );
  }
}

class _RailPainter extends CustomPainter {
  final Color color;
  final bool dashed;

  _RailPainter({required this.color, required this.dashed});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    final x = size.width / 2;
    if (!dashed) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
      return;
    }
    const dash = 3.0;
    const gap = 4.0;
    var y = 0.0;
    while (y < size.height) {
      final y2 = (y + dash).clamp(0.0, size.height);
      canvas.drawLine(Offset(x, y), Offset(x, y2), paint);
      y += dash + gap;
    }
  }

  @override
  bool shouldRepaint(_RailPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.dashed != dashed;
}

class _BusSection extends StatelessWidget {
  final List<TripBus> buses;

  const _BusSection({required this.buses});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    if (buses.isEmpty) {
      return Text(
        l10n.noBusesToBoard,
        style: theme.textTheme.bodySmall
            ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
      );
    }

    final top = buses.take(3).toList(growable: false);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.nearestBusesToBoard, style: theme.textTheme.labelLarge),
        const SizedBox(height: 2),
        Text(
          l10n.tapCardHint,
          style: theme.textTheme.bodySmall
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 8),
        for (final bus in top) _TripBusCard(item: bus),
      ],
    );
  }
}

/// Kartu bus pada hasil rute: dapat diketuk untuk membuka detail halte
/// (sama seperti daftar bus di layar utama) dan diikuti lewat tombol lonceng.
class _TripBusCard extends StatelessWidget {
  final TripBus item;

  const _TripBusCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final bus = item.bus;
    final progress = item.progress;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      color: theme.colorScheme.surfaceVariant.withOpacity(0.5),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => showBusTimeline(
          context,
          BusWithDistance(
            bus: bus,
            distanceKm: item.distanceKm,
            etaMinutes: item.etaMinutes,
            destinationLabel: progress.destinationLabel,
            resolvedHeading: progress.resolvedHeading,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 6, 4, 6),
          child: Row(
            children: [
              CorridorBadge(
                corridor: bus.corridor,
                size: 30,
                fontSize: 11,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.busLabel(bus.number),
                      style: theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      l10n.destinationLabel(progress.destinationLabel),
                      style: theme.textTheme.bodySmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    item.etaMinutes == null
                        ? formatDistance(item.distanceKm)
                        : l10n.etaPlusMinus(item.etaMinutes!),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    formatDistance(item.distanceKm),
                    style: theme.textTheme.labelSmall
                        ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
              FollowBusButton(
                bus: bus,
                payload: FollowPayload(
                  originLabel: progress.originLabel,
                  destinationLabel: progress.destinationLabel,
                  route: bus.route,
                  directionKey: progress.arahKey,
                  haltes: progress.direction.halte,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
