import 'dart:ui';

import 'package:flutter/material.dart';

class ActiveCircuitHeaderBanner extends StatelessWidget {
  const ActiveCircuitHeaderBanner({
    super.key,
    required this.circuitName,
  });

  final String circuitName;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 280),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.72),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.24),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.map_outlined,
                  color: Colors.white,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'CARTE ACTIVE',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.72),
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.1,
                        height: 1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      circuitName.toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        height: 1.1,
                      ),
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