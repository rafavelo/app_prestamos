class PaymentScheduleItem {
  final int number;
  final DateTime date;
  final double amortization;
  final double interest;
  final double payment;
  final double uniformPayment;
  final double balance;

  PaymentScheduleItem({
    required this.number,
    required this.date,
    required this.amortization,
    required this.interest,
    required this.payment,
    required this.uniformPayment,
    required this.balance,
  });
}

class LoanData {
  final double loanAmount;
  final int months;
  final double monthlyRate;
  final double averagePayment;
  final double uniformPayment;
  final DateTime disbursementDate;
  final List<PaymentScheduleItem> schedule;
  final double totalInterest;
  final double totalAmortization;
  final double totalPayments;
  final double totalUniformPayments;

  LoanData({
    required this.loanAmount,
    required this.months,
    required this.monthlyRate,
    required this.averagePayment,
    required this.uniformPayment,
    required this.disbursementDate,
    required this.schedule,
    required this.totalInterest,
    required this.totalAmortization,
    required this.totalPayments,
    required this.totalUniformPayments,
  });
}
