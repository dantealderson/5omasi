import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:khomasi/l10n/app_localizations.dart';
import 'package:khomasi/theme/app_colors.dart';
import 'package:khomasi/theme/app_text.dart';

/// The signature surface: a match rendered like a premium matchday ticket.
/// Floodlit photo hero, a gold hairline with a punched ticket-notch, mono
/// numerals for the price, and an emerald roster-fill bar.
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
  final bool isBooked;
  final DateTime? matchDateTime;
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
    this.isBooked = false,
    this.matchDateTime,
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

  /// Match-fill state on the premium scale:
  /// emerald (open) → gold (filling fast) → dim (full).
  Color _statusColor(AppPalette p) {
    if (isFull) return p.textLow;
    if (isFillingFast) return p.gold;
    return p.emerald;
  }

  String get statusText {
    if (isFull) return tr(context, 'full');
    if (isFillingFast) return tr(context, 'fillingFast');
    return '${widget.currentPlayers}/${widget.maxPlayers}';
  }

  @override
  void initState() {
    super.initState();
    if (widget.isBooked && widget.matchDateTime != null) {
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

  Widget _buildPlaceholderImage(AppPalette p) {
    return Container(
      color: p.surfaceRaised,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.stadium_outlined, size: 44, color: p.textLow),
            const SizedBox(height: 6),
            Text(
              tr(context, 'stadium'),
              style: TextStyle(fontSize: 12, color: p.textLow),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final screenWidth = MediaQuery.of(context).size.width;
    final accent = widget.isBooked ? p.gold : p.line;
    final status = _statusColor(p);

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
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        transform: Matrix4.identity()..scale(_isPressed ? 0.985 : 1.0),
        transformAlignment: Alignment.center,
        margin: EdgeInsets.symmetric(horizontal: screenWidth * 0.04, vertical: 8),
        decoration: BoxDecoration(
          color: p.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: accent, width: widget.isBooked ? 1.4 : 1),
          boxShadow: [
            BoxShadow(
              color: widget.isBooked
                  ? p.gold.withOpacity(0.14)
                  : Colors.black.withOpacity(p.isDark ? 0.35 : 0.06),
              blurRadius: _isPressed ? 6 : 16,
              offset: Offset(0, _isPressed ? 2 : 6),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildImage(p),
              _ticketNotch(p),
              _buildContent(p, status),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImage(AppPalette p) {
    return SizedBox(
      height: 158,
      child: Stack(
        fit: StackFit.expand,
        children: [
          widget.imageUrl != null && widget.imageUrl!.isNotEmpty
              ? Image.network(
                  widget.imageUrl!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _buildPlaceholderImage(p),
                )
              : _buildPlaceholderImage(p),

          // Floodlight vignette — darkens the base for legible overlays.
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, Color(0xCC05100D)],
                stops: [0.35, 1.0],
              ),
            ),
          ),

          Positioned(
            top: 12,
            left: 12,
            right: 12,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (widget.isBooked)
                  _badge(
                    icon: Icons.confirmation_number_outlined,
                    label: tr(context, 'booked'),
                    bg: p.gold,
                    fg: AppColors.onBrand,
                  )
                else if (widget.surfaceType != null)
                  _badge(
                    icon: Icons.grass_outlined,
                    label: widget.surfaceType!,
                    bg: Colors.black.withOpacity(0.45),
                    fg: Colors.white,
                  )
                else
                  const SizedBox.shrink(),
              ],
            ),
          ),

          Positioned(
            bottom: 12,
            left: 14,
            right: 14,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.venue ?? tr(context, 'stadium'),
                  style: AppText.kufi(size: 19, weight: 700, color: Colors.white),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (widget.distance != null) ...[
                  const SizedBox(height: 3),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.near_me_outlined,
                          size: 12, color: Colors.white70),
                      const SizedBox(width: 4),
                      Text(
                        '${widget.distance} ${tr(context, 'km')}',
                        style: const TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _badge({
    required IconData icon,
    required String label,
    required Color bg,
    required Color fg,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: fg, size: 13),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  /// Gold hairline with two punched notches at the edges — the ticket cue.
  Widget _ticketNotch(AppPalette p) {
    final notch = Container(
      width: 14,
      height: 14,
      decoration: BoxDecoration(color: p.background, shape: BoxShape.circle),
    );
    return SizedBox(
      height: 18,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Container(height: 1, color: p.gold.withOpacity(0.55)),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: Transform.translate(offset: const Offset(-7, 0), child: notch),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: Transform.translate(offset: const Offset(7, 0), child: notch),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(AppPalette p, Color status) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.isBooked && _countdown.isNotEmpty) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 12),
              decoration: BoxDecoration(
                color: p.goldSoft,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: p.gold.withOpacity(0.35)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.timer_outlined, color: p.gold, size: 16),
                  const SizedBox(width: 8),
                  Text('${tr(context, 'startsIn')} $_countdown',
                      style: TextStyle(
                          color: p.gold,
                          fontSize: 13,
                          fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],

          Row(
            children: [
              if (widget.date != null) ...[
                Icon(Icons.calendar_today_outlined, size: 13, color: p.textLow),
                const SizedBox(width: 5),
                Text(widget.date!,
                    style: TextStyle(
                        color: p.textMid, fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(width: 14),
              ],
              Icon(Icons.access_time_rounded, size: 13, color: p.textLow),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  widget.time ?? '',
                  style: TextStyle(color: p.textMid, fontSize: 13),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: status.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Text(
                  statusText,
                  style: TextStyle(
                      color: status, fontSize: 11, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // Roster-fill bar.
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: widget.maxPlayers == 0
                  ? 0
                  : widget.currentPlayers / widget.maxPlayers,
              backgroundColor: p.surfaceRaised,
              valueColor: AlwaysStoppedAnimation<Color>(status),
              minHeight: 6,
            ),
          ),

          const SizedBox(height: 14),

          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(tr(context, 'price'),
                      style: TextStyle(color: p.textLow, fontSize: 11)),
                  const SizedBox(height: 3),
                  // Headline number → mono "fixtures board" voice.
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        widget.price?.toStringAsFixed(0) ?? '5000',
                        style: AppText.mono(
                            size: 22, color: p.emerald, weight: FontWeight.w700),
                      ),
                      const SizedBox(width: 5),
                      Text(tr(context, 'currency'),
                          style: TextStyle(
                              color: p.textMid,
                              fontSize: 12,
                              fontWeight: FontWeight.w600)),
                    ],
                  ),
                ],
              ),
              _bookButton(p),
            ],
          ),
        ],
      ),
    );
  }

  Widget _bookButton(AppPalette p) {
    final Color bg =
        widget.isBooked ? p.gold : (isFull ? p.surfaceRaised : p.emerald);
    final Color fg = widget.isBooked
        ? AppColors.onBrand
        : (isFull ? p.textLow : p.onEmerald);
    final String label = widget.isBooked
        ? tr(context, 'bookedCheck')
        : (isFull ? tr(context, 'full') : tr(context, 'book'));

    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          HapticFeedback.mediumImpact();
          if (widget.onTap != null) widget.onTap!();
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 11),
          child: Text(
            label,
            style: TextStyle(color: fg, fontSize: 13, fontWeight: FontWeight.w700),
          ),
        ),
      ),
    );
  }
}
