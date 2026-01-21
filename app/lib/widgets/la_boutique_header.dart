import 'package:flutter/material.dart';

/// Header pixel-perfect (style comme ton visuel) :
/// - Titre: "La boutique"
/// - Sous-titre: "Merch, stickers, accessoires & photos"
/// - Barre de recherche pill + bouton filtre dégradé
/// - Coins arrondis en bas + ombre douce
class LaBoutiqueHeader extends StatelessWidget {
  const LaBoutiqueHeader({
    super.key,
    required this.onBack,
    required this.onSearchIconTap,
    required this.onQueryChanged,
    this.hintText = "Rechercher un article, un groupe…",
  });

  final VoidCallback onBack;
  final VoidCallback onSearchIconTap;
  final ValueChanged<String> onQueryChanged;
  final String hintText;

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;

    return Container(
      padding: EdgeInsets.fromLTRB(16, top + 10, 16, 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          stops: [0.00, 0.35, 0.72, 1.00],
          colors: [
            Color(0xFFFFB36A), // orange pastel
            Color(0xFFFF6FB1), // rose
            Color(0xFF8B7BFF), // violet
            Color(0xFF66C7FF), // bleu clair
          ],
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.10),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Top bar (boutons + titres)
          Row(
            children: [
              _RoundIconGlassButton(
                icon: Icons.arrow_back_rounded,
                onTap: onBack,
              ),
              const SizedBox(width: 12),

              // Titres centrés visuellement (entre 2 boutons)
              Expanded(
                child: Column(
                  children: const [
                    Text(
                      "La boutique",
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 34,
                        height: 1.05,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.6,
                        color: Color(0xFF111827),
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      "Merch, stickers, accessoires & photos",
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 16,
                        height: 1.15,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1F2937),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 12),
              _RoundIconGlassButton(
                icon: Icons.search_rounded,
                onTap: onSearchIconTap,
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Search pill
          _SearchPillExact(
            hintText: hintText,
            onChanged: onQueryChanged,
          ),
        ],
      ),
    );
  }
}

class _RoundIconGlassButton extends StatelessWidget {
  const _RoundIconGlassButton({
    required this.icon,
    required this.onTap,
  });

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Ink(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.20),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Colors.white.withOpacity(0.28), width: 1),
        ),
        child: Icon(icon, size: 22, color: const Color(0xFF111827)),
      ),
    );
  }
}

class _SearchPillExact extends StatelessWidget {
  const _SearchPillExact({
    required this.hintText,
    required this.onChanged,
  });

  final String hintText;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 54,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.90),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withOpacity(0.70), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 16,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.search_rounded, size: 22, color: Color(0xFF6B7280)),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              onChanged: onChanged,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: hintText,
                hintStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF6B7280),
                ),
                border: InputBorder.none,
                isDense: true,
              ),
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Color(0xFF111827),
              ),
            ),
          ),
          const SizedBox(width: 10),

          // Bouton filtre à droite (dégradé comme sur le visuel)
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFFF6FB1), Color(0xFF66C7FF)],
              ),
              borderRadius: BorderRadius.circular(999),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.10),
                  blurRadius: 12,
                  offset: const Offset(0, 8),
                )
              ],
            ),
            child: const Icon(Icons.tune_rounded, size: 20, color: Colors.white),
          ),
        ],
      ),
    );
  }
}
