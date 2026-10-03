import 'package:flutter/material.dart';

class ReceiptWiseLogo extends StatelessWidget {
  const ReceiptWiseLogo({this.size = 80, super.key});
  final double size;

  @override
  Widget build(BuildContext context) => Image.asset(
    'assets/branding/receiptwise_logo.png',
    width: size,
    height: size,
    fit: BoxFit.contain,
    semanticLabel: 'ReceiptWise smiling receipt logo',
  );
}
