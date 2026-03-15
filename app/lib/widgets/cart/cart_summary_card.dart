import 'package:flutter/material.dart';

class CartSummaryCard extends StatelessWidget {
  const CartSummaryCard({
    super.key,
    required this.merchSubtotal,
    required this.mediaSubtotal,
    required this.grandTotal,
    required this.currency,
    required this.onCheckout,
    this.enabled = true,
    this.checkoutLabel = 'Continuer',
  });

  final double merchSubtotal;
  final double mediaSubtotal;
  final double grandTotal;
  final String currency;
  final VoidCallback onCheckout;
  final bool enabled;
  final String checkoutLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: <Color>[
            Color(0xFF101726),
            Color(0xFF192238),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(26),
        boxShadow: <BoxShadow>[
          BoxShadow(
            blurRadius: 26,
            offset: const Offset(0, 14),
            color: Colors.black.withValues(alpha: 0.18),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Recapitulatif',
            style: theme.textTheme.titleLarge?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 14),
          _SummaryLine(label: 'Sous-total Merch', value: '$merchSubtotal ${currency.toUpperCase()}'),
          const SizedBox(height: 8),
          _SummaryLine(label: 'Sous-total Media', value: '$mediaSubtotal ${currency.toUpperCase()}'),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 14),
            child: Divider(color: Color(0xFF374151), height: 1),
          ),
          _SummaryLine(
            label: 'Total global',
            value: '$grandTotal ${currency.toUpperCase()}',
            emphasized: true,
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: enabled ? onCheckout : null,
              icon: const Icon(Icons.lock_outline_rounded),
              label: Text(checkoutLabel),
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryLine extends StatelessWidget {
  const _SummaryLine({
    required this.label,
    required this.value,
    this.emphasized = false,
  });

  final String label;
  final String value;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final color = emphasized ? Colors.white : const Color(0xFFD1D5DB);
    return Row(
      children: <Widget>[
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: emphasized ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontWeight: emphasized ? FontWeight.w900 : FontWeight.w700,
          ),
        ),
      ],
    );
  }
}