import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/providers/app_provider.dart';

class CorridorScreen extends StatefulWidget {
  const CorridorScreen({super.key});

  @override
  State<CorridorScreen> createState() => _CorridorScreenState();
}

class _CorridorScreenState extends State<CorridorScreen> {
  StreamSubscription? _positionStream;
  List<Map<String, dynamic>> _signalsWithDistance = [];

  @override
  void initState() {
    super.initState();
    _startLocationTracking();
  }

  @override
  void dispose() {
    _positionStream?.cancel();
    super.dispose();
  }

  void _startLocationTracking() {
    final geofenceService =
        Provider.of<AppProvider>(context, listen: false).geofenceService;

    _positionStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 20,
      ),
    ).listen((Position position) async {
      _signalsWithDistance =
          await geofenceService.getAllSignalsWithDistance(position);
      if (mounted) {
        setState(() {});
      }
    });
  }

  String _formatDistance(double meters) {
    if (meters < 1000) {
      return '${meters.toStringAsFixed(0)}m';
    }
    return '${(meters / 1000).toStringAsFixed(1)}km';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.primary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'CORRIDOR STATUS',
          style: AppTextStyles.h2,
        ),
      ),
      body: SafeArea(
        child: Consumer<AppProvider>(
          builder: (context, provider, _) {
            if (!provider.isCorridorActive) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: AppColors.textSecond,
                      size: 48,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No active corridor',
                      style: AppTextStyles.body.copyWith(
                        color: AppColors.textSecond,
                      ),
                    ),
                  ],
                ),
              );
            }

            return SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Hospital Info ──────────────────────────────
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.cardBorder),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'ACTIVE CORRIDOR',
                          style: AppTextStyles.label,
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            const Icon(
                              Icons.local_hospital,
                              color: AppColors.primary,
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    provider.activeHospital,
                                    style: AppTextStyles.h3,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Priority: ${provider.activePriority}',
                                    style: AppTextStyles.bodySmall.copyWith(
                                      color: AppColors.textSecond,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // ── Signal Status List ─────────────────────────
                  Text('SIGNAL ZONES', style: AppTextStyles.label),
                  const SizedBox(height: 12),

                  if (_signalsWithDistance.isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 32),
                        child: Text(
                          'Loading signal data...',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.textSecond,
                          ),
                        ),
                      ),
                    )
                  else
                    ..._signalsWithDistance.map((signal) {
                      final inZone = signal['inzone'] as bool;
                      final distance = signal['distance'] as double;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: inZone
                              ? AppColors.green.withValues(alpha: 0.08)
                              : AppColors.card,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: inZone
                                ? AppColors.green.withValues(alpha: 0.4)
                                : AppColors.cardBorder,
                            width: inZone ? 2 : 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              inZone
                                  ? Icons.check_circle
                                  : Icons.location_on_outlined,
                              color: inZone
                                  ? AppColors.green
                                  : AppColors.textSecond,
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    signal['name'] as String,
                                    style: AppTextStyles.body.copyWith(
                                      fontWeight: FontWeight.w600,
                                      color: inZone
                                          ? AppColors.green
                                          : AppColors.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _formatDistance(distance),
                                    style: AppTextStyles.bodySmall.copyWith(
                                      color: inZone
                                          ? AppColors.green
                                          : AppColors.textSecond,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: inZone
                                    ? AppColors.green.withValues(alpha: 0.2)
                                    : AppColors.textDim.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                inZone ? 'IN ZONE' : '—',
                                style: TextStyle(
                                  color: inZone
                                      ? AppColors.green
                                      : AppColors.textSecond,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),

                  const SizedBox(height: 32),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
