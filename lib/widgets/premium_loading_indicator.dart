import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class PremiumLoadingIndicator extends StatelessWidget {
  final String message;
  final Color color;

  const PremiumLoadingIndicator({
    super.key,
    this.message = 'جاري التحميل...',
    this.color = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(color: Colors.white70),
          const SizedBox(height: 20),
          Text(
            message,
            style: GoogleFonts.cairo(
              color: color.withValues(alpha: 0.7),
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
