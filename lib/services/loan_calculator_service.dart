import 'dart:math';
import '../models/loan_data.dart';

class LoanCalculatorService {
  static LoanData calculateLoan({
    required double loanAmount,
    required int months,
    required double annualRate,
    required DateTime disbursementDate,
    required bool isFrenchSystem,
  }) {
    final monthlyRate = annualRate / 100;
    final schedule = <PaymentScheduleItem>[];

    double balance = loanAmount;
    double totalInterest = 0;
    double totalAmortization = 0;
    double totalPayments = 0;
    double uniformPayment = 0;

    schedule.add(PaymentScheduleItem(
      number: 0,
      date: disbursementDate,
      amortization: 0,
      interest: 0,
      payment: 0,
      uniformPayment: 0,
      balance: loanAmount,
    ));

    if (isFrenchSystem) {
      if (monthlyRate > 0) {
        uniformPayment = loanAmount *
            (monthlyRate * pow(1 + monthlyRate, months)) /
            (pow(1 + monthlyRate, months) - 1);
      } else {
        uniformPayment = loanAmount / months;
      }

      for (int i = 1; i <= months; i++) {
        final paymentDate = DateTime(
            disbursementDate.year, disbursementDate.month + i, disbursementDate.day);
        final interest = balance * monthlyRate;
        double amortization = uniformPayment - interest;
        balance -= amortization;
        if (i == months && balance.abs() < 0.05) balance = 0;

        schedule.add(PaymentScheduleItem(
          number: i,
          date: paymentDate,
          amortization: amortization,
          interest: interest,
          payment: uniformPayment,
          uniformPayment: uniformPayment,
          balance: balance,
        ));

        totalInterest += interest;
        totalAmortization += amortization;
        totalPayments += uniformPayment;
      }
    } else {
      final monthlyAmortization = loanAmount / months;

      double totalPaymentsPreCalc = 0;
      double tempBalance = loanAmount;
      for (int i = 1; i <= months; i++) {
        totalPaymentsPreCalc += (monthlyAmortization + (tempBalance * monthlyRate));
        tempBalance -= monthlyAmortization;
      }
      uniformPayment = totalPaymentsPreCalc / months;

      for (int i = 1; i <= months; i++) {
        final paymentDate = DateTime(
            disbursementDate.year, disbursementDate.month + i, disbursementDate.day);
        final interest = balance * monthlyRate;
        final payment = monthlyAmortization + interest;
        balance -= monthlyAmortization;
        if (i == months && balance < 0.01) balance = 0;

        schedule.add(PaymentScheduleItem(
          number: i,
          date: paymentDate,
          amortization: monthlyAmortization,
          interest: interest,
          payment: payment,
          uniformPayment: uniformPayment,
          balance: balance,
        ));

        totalInterest += interest;
        totalAmortization += monthlyAmortization;
        totalPayments += payment;
      }
    }

    return LoanData(
      loanAmount: loanAmount,
      months: months,
      monthlyRate: monthlyRate * 100,
      averagePayment: uniformPayment,
      uniformPayment: uniformPayment,
      disbursementDate: disbursementDate,
      schedule: schedule,
      totalInterest: totalInterest,
      totalAmortization: totalAmortization,
      totalPayments: totalPayments,
      totalUniformPayments:
          isFrenchSystem ? (uniformPayment * months) : totalPayments,
    );
  }

  static String formatCurrency(double amount) => amount.toStringAsFixed(2);

  static String formatDate(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/'
      '${date.month.toString().padLeft(2, '0')}/'
      '${date.year}';
}
