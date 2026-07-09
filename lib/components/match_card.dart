import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:khomasi/l10n/app_localizations.dart';

class MatchCard extends StatefulWidget {
  final int index;
  final String? matchTitle;
  final String? venue;
  final String? date;
  final String? time;
  final double? price;
  final int currentPlayers;
  final int maxPlayers;
  final double? distance;
  final String? surfaceType;
  final List<String>? friendsAttending;
  final String? imageUrl;
  final bool isFavorite;
  final bool isBooked;
  final DateTime? matchDateTime;
  final VoidCallback? onFavorite;
  final VoidCallback? onTap;

  const MatchCard({
    super.key,
    required this.index,
    this.matchTitle,
    this.venue,
    this.date,
    this.time,
    this.price,
    this.currentPlayers = 9,
    this.maxPlayers = 10,
    this.distance,
    this.surfaceType,
    this.friendsAttending,
    this.imageUrl,
    this.isFavorite = false,
    this.isBooked = false,
    this.matchDateTime,
    this.onFavorite,
    this.onTap,
  });

  @override
  State<MatchCard> createState() => _MatchCardState();
}

class _MatchCardState extends State<MatchCard> {
  bool _isPressed = false;
  Timer? _countdownTimer;
  String _countdown = '';

  bool get isFillingFast => widget.currentPlayers >= (widget.maxPlayers * 0.8);
  bool get isFull => widget.currentPlayers >= widget.maxPlayers;

  Color get statusColor {
    if (isFull) return Colors.red;
    if (isFillingFast) return Colors.orange;
    return Colors.green;
  }

  String get statusText {
    if (isFull) return tr(context, 'full');
    if (isFillingFast) return tr(context, 'fillingFast');
    return '${widget.currentPlayers}/${widget.maxPlayers}';
  }

  bool get _isDark => Theme.of(context).brightness == Brightness.dark;

  @override
  void initState() {
    super.initState();
    if (widget.isBooked && widget.matchDateTime != null) {
      // Defer first update to after initState (tr() needs context which isn't ready in initState)
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _updateCountdown();
      });
      _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) _updateCountdown();
      });
    }
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _updateCountdown() {
    if (widget.matchDateTime == null) return;

    final now = DateTime.now();
    final diff = widget.matchDateTime!.difference(now);

    if (diff.isNegative) {
      setState(() => _countdown = tr(context, 'started'));
      return;
    }

    final days = diff.inDays;
    final hours = diff.inHours % 24;
    final minutes = diff.inMinutes % 60;
    final seconds = diff.inSeconds % 60;

    String result = '';
    if (days > 0) {
      result = '$days ${tr(context, 'day')} $hours${tr(context, 'hours')}';
    } else if (hours > 0) {
      result = '$hours${tr(context, 'hours')} $minutes${tr(context, 'minutes')}';
    } else if (minutes > 0) {
      result = '$minutes${tr(context, 'minutes')} $seconds${tr(context, 'seconds')}';
    } else {
      result = '$seconds${tr(context, 'seconds')}';
    }

    setState(() => _countdown = result);
  }

  Widget _buildPlaceholderImage() {
    return Container(
      color: Colors.deepPurple.shade100,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.stadium,
              size: 48,
              color: Colors.deepPurple.shade300,
            ),
            const SizedBox(height: 4),
            Text(
              tr(context, 'stadium'),
              style: TextStyle(
                fontSize: 12,
                color: Colors.deepPurple.shade400,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: () {
        if (widget.onTap != null) {
          HapticFeedback.mediumImpact();
          widget.onTap!();
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        transform: Matrix4.identity()..scale(_isPressed ? 0.98 : 1.0),
        margin: EdgeInsets.symmetric(
          horizontal: screenWidth * 0.03,
          vertical: 8,
        ),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(20),
          border: widget.isBooked
              ? Border.all(color: Colors.green, width: 2)
              : null,
          boxShadow: [
            BoxShadow(
              color: widget.isBooked
                  ? Colors.green.withOpacity(0.2)
                  : Colors.black.withOpacity(_isDark ? 0.3 : 0.08),
              spreadRadius: _isPressed ? 1 : 2,
              blurRadius: _isPressed ? 4 : 8,
              offset: Offset(0, _isPressed ? 1 : 3),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image section
              SizedBox(
                height: 160,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Image with placeholder
                    widget.imageUrl != null && widget.imageUrl!.isNotEmpty
                        ? Image.network(
                            widget.imageUrl!,
                            fit: BoxFit.cover,
                            width: double.infinity,
                            height: double.infinity,
                            errorBuilder: (_, __, ___) => _buildPlaceholderImage(),
                          )
                        : _buildPlaceholderImage(),

                    // Gradient overlay
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withOpacity(0.6),
                          ],
                        ),
                      ),
                    ),

                    // Top badges row
                    Positioned(
                      top: 12,
                      left: 12,
                      right: 12,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Booked badge OR Surface type
                          if (widget.isBooked)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.green,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.check_circle, color: Colors.white, size: 14),
                                  const SizedBox(width: 4),
                                  Text(
                                    tr(context, 'booked'),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          else if (widget.surfaceType != null)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.5),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.grass, color: Colors.white, size: 14),
                                  const SizedBox(width: 4),
                                  Text(
                                    widget.surfaceType!,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                          // Favorite button
                          if (widget.onFavorite != null)
                            GestureDetector(
                              onTap: () {
                                HapticFeedback.lightImpact();
                                widget.onFavorite!();
                              },
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.9),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  widget.isFavorite ? Icons.favorite : Icons.favorite_border,
                                  color: widget.isFavorite ? Colors.red : Colors.grey[600],
                                  size: 18,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),

                    // Venue name at bottom of image
                    Positioned(
                      bottom: 12,
                      left: 12,
                      right: 12,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.venue ?? tr(context, 'stadium'),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (widget.distance != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              '${widget.distance} ${tr(context, 'km')}',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Card content
              Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Countdown timer for booked matches
                    if (widget.isBooked && _countdown.isNotEmpty) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.green.withOpacity(0.3)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.timer, color: Colors.green, size: 18),
                            const SizedBox(width: 8),
                            Text(
                              tr(context, 'startsIn'),
                              style: TextStyle(
                                color: Colors.green[700],
                                fontSize: 13,
                              ),
                            ),
                            Text(
                              _countdown,
                              style: TextStyle(
                                color: Colors.green[700],
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],

                    // Date and Time row
                    Row(
                      children: [
                        // Date
                        if (widget.date != null) ...[
                          Icon(
                            Icons.calendar_today,
                            size: 14,
                            color: _isDark ? Colors.grey[400] : Colors.grey[600],
                          ),
                          const SizedBox(width: 4),
                          Text(
                            widget.date!,
                            style: TextStyle(
                              color: _isDark ? Colors.grey[300] : Colors.grey[700],
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 12),
                        ],
                        // Time
                        Icon(
                          Icons.access_time,
                          size: 14,
                          color: _isDark ? Colors.grey[400] : Colors.grey[600],
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            widget.time ?? '9:00 م - 10:00 م',
                            style: TextStyle(
                              color: _isDark ? Colors.grey[300] : Colors.grey[700],
                              fontSize: 13,
                            ),
                          ),
                        ),
                        // Status badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: statusColor.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            statusText,
                            style: TextStyle(
                              color: statusColor,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 8),

                    // Progress bar
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: widget.currentPlayers / widget.maxPlayers,
                        backgroundColor: _isDark ? Colors.grey[700] : Colors.grey[200],
                        valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                        minHeight: 4,
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Bottom row - price and button
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Price
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              tr(context, 'price'),
                              style: TextStyle(
                                color: _isDark ? Colors.grey[400] : Colors.grey[600],
                                fontSize: 11,
                              ),
                            ),
                            Text(
                              '${widget.price?.toStringAsFixed(0) ?? "5000"} ${tr(context, 'currency')}',
                              style: const TextStyle(
                                fontSize: 18,
                                color: Colors.deepPurple,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),

                        // Book button
                        Material(
                          color: widget.isBooked
                              ? Colors.green
                              : (isFull ? Colors.grey : Colors.deepPurple),
                          borderRadius: BorderRadius.circular(20),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(20),
                            onTap: () {
                              HapticFeedback.mediumImpact();
                              if (widget.onTap != null) {
                                widget.onTap!();
                              }
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 10,
                              ),
                              child: Text(
                                widget.isBooked
                                    ? tr(context, 'bookedCheck')
                                    : (isFull ? tr(context, 'full') : tr(context, 'book')),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}