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
            Color(0xFFFFE36A),
            Color(0xFFFF8ACD),
            Color(0xFF98E4FF),
          ],
          begin: Alignment.centerLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: const Color(0x1F0F172A)),
        boxShadow: <BoxShadow>[
          BoxShadow(
            blurRadius: 22,
            offset: const Offset(0, 14),
            color: const Color(0x22000000),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Recapitulatif',
            style: theme.textTheme.titleLarge?.copyWith(
              color: const Color(0xFF111827),
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 14),
          _SummaryLine(label: 'Sous-total Merch', value: '$merchSubtotal ${currency.toUpperCase()}'),
          const SizedBox(height: 8),
          _SummaryLine(label: 'Sous-total Media', value: '$mediaSubtotal ${currency.toUpperCase()}'),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 14),
            child: Divider(color: Color(0x40111827), height: 1),
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
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF111827),
                foregroundColor: Colors.white,
              ),
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
    final color = emphasized ? const Color(0xFF101828) : const Color(0xFF344054);
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