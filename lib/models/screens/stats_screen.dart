import 'package:flutter/material.dart';

import '../step_data.dart';

class StatsScreen extends StatelessWidget {
  final List<StepData> history;

  const StatsScreen({
    super.key,
    required this.history,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Статистика'),
        backgroundColor: Colors.transparent,
        foregroundColor: Theme.of(context).colorScheme.onBackground,
        elevation: 0,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              const Color(0xFF5B86E5).withOpacity(0.12),
              const Color(0xFF36D1DC).withOpacity(0.05),
            ],
          ),
        ),
        child: history.isEmpty
            ? const Center(
                child: Text(
                  'Пока нет сохранённых прогулок',
                  style: TextStyle(fontSize: 16),
                ),
              )
            : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: history.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final item = history[history.length - 1 - index];
                  final dateStr =
                      '${item.date.day.toString().padLeft(2, '0')}.${item.date.month.toString().padLeft(2, '0')}.${item.date.year}';
                  final durationMinutes = (item.duration.inSeconds / 60).toStringAsFixed(1);
                  final distanceKm = (item.distanceMeters / 1000).toStringAsFixed(2);

                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                dateStr,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                '${item.steps} шагов',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            children: [
                              _StatChip(label: 'Дистанция', value: '$distanceKm км'),
                              _StatChip(label: 'Время', value: '$durationMinutes мин'),
                              _StatChip(
                                label: 'Калории',
                                value: item.calories.toStringAsFixed(1),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;

  const _StatChip({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$label: ',
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
          Text(value),
        ],
      ),
    );
  }
}
