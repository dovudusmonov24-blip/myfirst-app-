import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:pedometer/pedometer.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../step_data.dart';
import 'stats_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  StreamSubscription<StepCount>? _stepSubscription;
  StreamSubscription<Position>? _positionSubscription;
  int _initialSteps = 0;
  int _steps = 0;
  bool _isWalking = false;
  DateTime? _startTime;
  Duration _elapsed = Duration.zero;
  Timer? _timer;

  final List<StepData> _history = [];

  static const double _caloriesPerStep = 0.04; // очень грубая оценка
  double _gpsDistanceMeters = 0; // расстояние по GPS за сессию
  Position? _lastPosition;

  @override
  void initState() {
    super.initState();
    _loadHistory();
    _initPedometer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _stepSubscription?.cancel();
    _positionSubscription?.cancel();
    super.dispose();
  }

  void _initPedometer() {
    // Педометр поддерживается только на Android / iOS.
    if (kIsWeb || !(Platform.isAndroid || Platform.isIOS)) {
      debugPrint('Pedometer недоступен на этой платформе, пропускаем инициализацию.');
      return;
    }

    _stepSubscription = Pedometer.stepCountStream.listen(
      _onStepCount,
      onError: _onStepError,
      cancelOnError: false,
    );
  }

  void _onStepCount(StepCount event) {
    if (!_isWalking) return;

    if (_initialSteps == 0) {
      _initialSteps = event.steps;
    }

    setState(() {
      _steps = event.steps - _initialSteps;
      if (_steps < 0) _steps = 0;
    });
  }

  void _onStepError(error) {
    // В реальном приложении можно показать пользователю сообщение
    debugPrint('Ошибка педометра: $error');
  }

  void _startWalking() {
    if (_isWalking) return;

    setState(() {
      _isWalking = true;
      _startTime = DateTime.now();
      _elapsed = Duration.zero;
      _steps = 0;
      _initialSteps = 0;
      _gpsDistanceMeters = 0;
      _lastPosition = null;
    });

    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!_isWalking || _startTime == null) return;
      setState(() {
        _elapsed = DateTime.now().difference(_startTime!);
      });
    });

    _startGpsTracking();
  }

  Future<void> _startGpsTracking() async {
    if (kIsWeb || !(Platform.isAndroid || Platform.isIOS)) {
      return;
    }

    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      // В реальном приложении можно показать диалог.
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return;
    }

    _positionSubscription?.cancel();
    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.best,
        distanceFilter: 2, // обновление каждые ~2 метра
      ),
    ).listen((position) {
      if (!_isWalking) return;
      if (_lastPosition != null) {
        final d = Geolocator.distanceBetween(
          _lastPosition!.latitude,
          _lastPosition!.longitude,
          position.latitude,
          position.longitude,
        );
        if (d > 0) {
          setState(() {
            _gpsDistanceMeters += d;
          });
        }
      }
      _lastPosition = position;
    });
  }

  Future<void> _stopAndSave() async {
    if (!_isWalking || _startTime == null) return;

    _timer?.cancel();
    _positionSubscription?.cancel();

    final duration = _elapsed;
    final record = _buildStepData(duration);

    setState(() {
      _isWalking = false;
      _history.add(record);
    });

    await _saveHistory();
  }

  StepData _buildStepData(Duration duration) {
    // если есть GPS‑данные за сессию, используем их, иначе оцениваем по шагам
    final distance = _gpsDistanceMeters > 0
        ? _gpsDistanceMeters
        : _steps * 0.78; // резервный вариант по длине шага
    final calories = _steps * _caloriesPerStep;

    return StepData(
      date: DateTime.now(),
      steps: _steps,
      distanceMeters: distance,
      duration: duration,
      calories: calories,
    );
  }

  Future<void> _loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString('step_history');
    if (jsonString == null) return;

    try {
      final List<dynamic> decoded = jsonDecode(jsonString) as List<dynamic>;
      final items = decoded
          .map(
            (e) => StepData.fromJson(e as Map<String, dynamic>),
          )
          .toList();
      setState(() {
        _history
          ..clear()
          ..addAll(items);
      });
    } catch (e) {
      debugPrint('Ошибка чтения истории шагов: $e');
    }
  }

  Future<void> _saveHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(
      _history.map((e) => e.toJson()).toList(),
    );
    await prefs.setString('step_history', encoded);
  }

  void _resetCurrent() {
    setState(() {
      _isWalking = false;
      _steps = 0;
      _initialSteps = 0;
      _elapsed = Duration.zero;
      _startTime = null;
    });
    _timer?.cancel();
  }

  void _openStats() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => StatsScreen(history: List.of(_history)),
      ),
    );
  }

  String _formatDuration(Duration d) {
    final hours = d.inHours.toString().padLeft(2, '0');
    final minutes = (d.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$hours:$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final currentDistanceMeters =
        _gpsDistanceMeters > 0 ? _gpsDistanceMeters : _steps * 0.78;
    final distanceKm = (currentDistanceMeters / 1000).toStringAsFixed(2);
    final calories = (_steps * _caloriesPerStep).toStringAsFixed(1);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Шагомер'),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF5B86E5),
              Color(0xFF36D1DC),
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Сегодня',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.white.withOpacity(0.9),
                      ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Твоя активность',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 20),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          'Шаги',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '$_steps',
                          style: const TextStyle(
                            fontSize: 44,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _isWalking ? 'Идёшь, продолжай в том же духе' : 'Нажми кнопку, чтобы начать ходьбу',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _InfoTile(
                              icon: Icons.route_rounded,
                              label: 'Дистанция',
                              value: '$distanceKm км',
                            ),
                            _InfoTile(
                              icon: Icons.access_time_filled_rounded,
                              label: 'Время',
                              value: _formatDuration(_elapsed),
                            ),
                            _InfoTile(
                              icon: Icons.local_fire_department_rounded,
                              label: 'Калории',
                              value: '$calories ккал',
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _isWalking ? _stopAndSave : _startWalking,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          backgroundColor: Colors.white,
                          foregroundColor: const Color(0xFF2563EB),
                        ),
                        child: Text(_isWalking ? 'Стоп и сохранить' : 'Начать ходьбу'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _resetCurrent,
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: Colors.white.withOpacity(0.7)),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: const Text('Сбросить текущую сессию'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: _openStats,
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Открыть статистику'),
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                if (_history.isNotEmpty)
                  Text(
                    'Сохранённых прогулок: ${_history.length}',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.white.withOpacity(0.9),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _InfoTile({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Column(
        children: [
          Icon(
            icon,
            size: 22,
            color: const Color(0xFF2563EB),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: Colors.grey),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}