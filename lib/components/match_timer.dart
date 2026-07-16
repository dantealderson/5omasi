import 'package:flutter/material.dart';
import 'package:khomasi/theme/app_colors.dart';
import 'dart:async';

class MatchTimer extends StatefulWidget {
  const MatchTimer({super.key});

  @override
  State<MatchTimer> createState() => _MatchTimerState();
}

class _MatchTimerState extends State<MatchTimer> {
  Timer? _timer;
  int _seconds = 0;
  bool _isRunning = false;
  
  @override
  void initState() {
    super.initState();
  }
  
  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
  
  void _toggleTimer() {
    setState(() {
      _isRunning = !_isRunning;
      if (_isRunning) {
        _startTimer();
      } else {
        _pauseTimer();
      }
    });
  }
  
  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _seconds++;
      });
    });
  }
  
  void _pauseTimer() {
    _timer?.cancel();
  }
  
  void _resetTimer() {
    setState(() {
      _seconds = 0;
      _isRunning = false;
    });
    _timer?.cancel();
  }
  
  String get _formattedTime {
    final minutes = _seconds ~/ 60;
    final seconds = _seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
  
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.dRaised : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Timer display
          Row(
            children: [
              Icon(
                Icons.timer,
                color: _isRunning ? Colors.green : (isDark ? Colors.grey[400] : Colors.grey),
                size: 24,
              ),
              const SizedBox(width: 8),
              Text(
                _formattedTime,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: _isRunning 
                      ? (isDark ? Colors.white : Colors.black) 
                      : (isDark ? Colors.grey[400] : Colors.grey[600]),
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
          
          // Control buttons
          Row(
            children: [
              // Play/Pause button
              Container(
                decoration: BoxDecoration(
                  color: _isRunning ? Colors.orange : Colors.green,
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  onPressed: _toggleTimer,
                  icon: Icon(
                    _isRunning ? Icons.pause : Icons.play_arrow,
                    color: Colors.white,
                  ),
                  tooltip: _isRunning ? 'إيقاف مؤقت' : 'بدء',
                ),
              ),
              const SizedBox(width: 8),
              
              // Reset button
              Container(
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  onPressed: _resetTimer,
                  icon: Icon(
                    Icons.refresh,
                    color: isDark ? Colors.grey[300] : Colors.grey[700],
                  ),
                  tooltip: 'إعادة تعيين',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}