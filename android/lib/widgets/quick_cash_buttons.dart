import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class QuickCashButtons extends StatelessWidget {
  final double total;
  final ValueChanged<double> onAmountSelected;

  const QuickCashButtons({
    super.key,
    required this.total,
    required this.onAmountSelected,
  });

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

    // Calculate smart denominations
    final List<double> suggestions = [total]; // Uang Pas

    final standardNotes = [10000.0, 20000.0, 50000.0, 100000.0];
    for (final note in standardNotes) {
      if (note > total && !suggestions.contains(note)) {
        suggestions.add(note);
      }
    }

    // Add next round 50k or 100k
    final nextFifty = (total / 50000).ceil() * 50000.0;
    if (nextFifty > total && !suggestions.contains(nextFifty)) {
      suggestions.add(nextFifty);
    }

    final nextHundred = (total / 100000).ceil() * 100000.0;
    if (nextHundred > total && !suggestions.contains(nextHundred)) {
      suggestions.add(nextHundred);
    }

    suggestions.sort();

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: suggestions.take(5).map((amount) {
        final isExact = amount == total;
        return ActionChip(
          backgroundColor: isExact ? const Color(0xFFDCFCE7) : const Color(0xFFF1F5F9),
          side: BorderSide(
            color: isExact ? const Color(0xFF86EFAC) : const Color(0xFFE2E8F0),
          ),
          label: Text(
            isExact ? 'Uang Pas (${currency.format(amount)})' : currency.format(amount),
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 12,
              color: isExact ? const Color(0xFF15803D) : const Color(0xFF334155),
            ),
          ),
          onPressed: () => onAmountSelected(amount),
        );
      }).toList(),
    );
  }
}
