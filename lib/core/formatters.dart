import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

final NumberFormat moneyFormat = NumberFormat("#,##0.00", "en_US");

class CurrencyInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    if (newValue.text.isEmpty) return newValue.copyWith(text: '');
    String newText = newValue.text.replaceAll(RegExp(r'[^0-9.]'), '');
    if (newText.split('.').length > 2) return oldValue;
    List<String> parts = newText.split('.');
    String integerPart = parts[0];
    String? decimalPart = parts.length > 1 ? parts[1] : null;
    final formatter = NumberFormat("#,###", "en_US");
    String formattedInteger =
        integerPart.isNotEmpty ? formatter.format(int.tryParse(integerPart) ?? 0) : "";
    String finalText = formattedInteger;
    if (newText.contains('.')) {
      finalText += ".";
      if (decimalPart != null) {
        if (decimalPart.length > 2) decimalPart = decimalPart.substring(0, 2);
        finalText += decimalPart;
      }
    }
    return TextEditingValue(
        text: finalText, selection: TextSelection.collapsed(offset: finalText.length));
  }
}
