import 'package:flutter/material.dart';

class CircuitCalculsValidationPage extends StatefulWidget {
  const CircuitCalculsValidationPage({super.key});

  @override
  State<CircuitCalculsValidationPage> createState() => _CircuitCalculsValidationPageState();
}

class _CircuitCalculsValidationPageState extends State<CircuitCalculsValidationPage> {
  final Map<String, dynamic> _metrics = {
    'distance': 12.5,
    'elevation': 245,
    'estimatedTime': 1.5,
    'difficulty': 'Intermédiaire',
    'validationScore': 85,
  };

  bool _isValidated = false;
  final List<String> _validationMessages = [];

  @override
  void initState() {
    super.initState();
    _runValidation();
  }

  void _runValidation() {
    setState(() {
      _validationMessages.clear();
      _isValidated = false;
    });

    Future.delayed(const Duration(milliseconds: 1200), () {
      if (!mounted) return;
      setState(() {
        _validationMessages.addAll([
          "✓ Circuit fermé détecté",
          "✓ Points de départ et arrivée valides",
          "✓ Pas de croisements détectés",
          "✓ Distance acceptable (> 1 km)",
          "✓ Pente moyenne acceptable",
        ]);
        _isValidated = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("✓ Validation complétée avec succès")),
      );
    });
  }

  void _recalculateMetrics() {
    setState(() => _isValidated = false);
    _runValidation();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0.5,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Calculs & Validation", style: TextStyle(fontWeight: FontWeight.w700)),
            Text(
              "Analyser votre circuit",
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Métriques principales
            const Text(
              "Métriques",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Color(0xFF1F2A37),
              ),
            ),
            const SizedBox(height: 16),

            GridView.count(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _MetricCard(
                  icon: Icons.route,
                  label: "Distance",
                  value: "${_metrics['distance']} km",
                  color: const Color(0xFF1A73E8),
                ),
                _MetricCard(
                  icon: Icons.trending_up,
                  label: "Dénivelé",
                  value: "${_metrics['elevation']} m",
                  color: const Color(0xFFF59E0B),
                ),
                _MetricCard(
                  icon: Icons.schedule,
                  label: "Temps estimé",
                  value: "${_metrics['estimatedTime']}h",
                  color: const Color(0xFF34A853),
                ),
                _MetricCard(
                  icon: Icons.signal_cellular_alt,
                  label: "Difficulté",
                  value: _metrics['difficulty'],
                  color: const Color(0xFF9333EA),
                ),
              ],
            ),

            const SizedBox(height: 28),

            // Qualité du circuit
            const Text(
              "Qualité du circuit",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Color(0xFF1F2A37),
              ),
            ),
            const SizedBox(height: 16),

            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1A73E8).withOpacity(0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: const Color(0xFF1A73E8).withOpacity(0.3),
                  width: 1.5,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        _metrics['validationScore'] >= 80
                            ? Icons.check_circle
                            : Icons.warning,
                        size: 24,
                        color: _metrics['validationScore'] >= 80
                            ? const Color(0xFF34A853)
                            : const Color(0xFFF59E0B),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Score de validation",
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF1F2A37),
                            ),
                          ),
                          Text(
                            "${_metrics['validationScore']}/100",
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF6B7280),
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      Text(
                        _metrics['validationScore'] >= 80 ? "Excellent" : "À améliorer",
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: _metrics['validationScore'] >= 80
                              ? const Color(0xFF34A853)
                              : const Color(0xFFF59E0B),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: _metrics['validationScore'] / 100,
                      minHeight: 8,
                      backgroundColor: const Color(0xFF1A73E8).withOpacity(0.2),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        _metrics['validationScore'] >= 80
                            ? const Color(0xFF34A853)
                            : const Color(0xFFF59E0B),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 28),

            // Validation détaillée
            const Text(
              "Résultats de validation",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Color(0xFF1F2A37),
              ),
            ),
            const SizedBox(height: 16),

            if (!_isValidated)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: const Center(
                  child: CircularProgressIndicator(
                    color: Color(0xFF1A73E8),
                  ),
                ),
              )
            else
              Column(
                children: _validationMessages
                    .map((message) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _ValidationItem(message: message),
                        ))
                    .toList(),
              ),

            const SizedBox(height: 28),

            // Boutons d'action
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _recalculateMetrics,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1A73E8),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  "Relancer la validation",
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 12),

            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFF1A73E8), width: 1.5),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  "Retour",
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1A73E8),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _MetricCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF6B7280),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _ValidationItem extends StatelessWidget {
  final String message;

  const _ValidationItem({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF34A853).withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: const Color(0xFF34A853).withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.check_circle,
            size: 20,
            color: const Color(0xFF34A853),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1F2A37),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
