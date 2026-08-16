enum PaymentStatus { paid, partial, unpaid, noPrice }

PaymentStatus getPaymentStatus(Map<String, dynamic> t) {
  final price = t['price'];
  if (price == null) return PaymentStatus.noPrice;
  final quantity = (t['quantity'] as num).toDouble();
  final total = quantity * (price as num).toDouble();
  final amountPaid = (t['amount_paid'] as num).toDouble();
  if (amountPaid <= 0) return PaymentStatus.unpaid;
  if (amountPaid >= total) return PaymentStatus.paid;
  return PaymentStatus.partial;
}

String paymentStatusLabel(PaymentStatus status) {
  switch (status) {
    case PaymentStatus.paid:
      return 'Paid';
    case PaymentStatus.partial:
      return 'Partial';
    case PaymentStatus.unpaid:
      return 'Unpaid';
    case PaymentStatus.noPrice:
      return '';
  }
}