class StepData {
  final DateTime date;
  final int steps;
  final double distanceMeters;
  final Duration duration;
  final double calories;

  const StepData({
    required this.date,
    required this.steps,
    required this.distanceMeters,
    required this.duration,
    required this.calories,
  });

  Map<String, dynamic> toJson() {
    return {
      'date': date.toIso8601String(),
      'steps': steps,
      'distanceMeters': distanceMeters,
      'durationSeconds': duration.inSeconds,
      'calories': calories,
    };
  }

  factory StepData.fromJson(Map<String, dynamic> json) {
    return StepData(
      date: DateTime.parse(json['date'] as String),
      steps: json['steps'] as int,
      distanceMeters: (json['distanceMeters'] as num).toDouble(),
      duration: Duration(seconds: json['durationSeconds'] as int),
      calories: (json['calories'] as num).toDouble(),
    );
  }
}
