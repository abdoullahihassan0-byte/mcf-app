class Loan {
  Loan({
    required this.id,
    required this.userId,
    required this.principalAmount,
    required this.interestRate,
    required this.durationDays,
    required this.totalDue,
    required this.status,
    this.remaining,
    this.rejectionReason,
  });

  final String id;
  final String userId;
  final double principalAmount;
  final double interestRate;
  final int durationDays;
  final double totalDue;
  final String status; // requested | approved | rejected | disbursed | active | completed | defaulted
  final double? remaining; // present seulement sur le detail (GET /loans/:id)
  final String? rejectionReason;

  factory Loan.fromJson(Map<String, dynamic> json) => Loan(
        id: json['id'] as String,
        userId: json['user_id'] as String,
        principalAmount: double.parse(json['principal_amount'].toString()),
        interestRate: double.parse(json['interest_rate'].toString()),
        durationDays: json['duration_days'] as int,
        totalDue: double.parse(json['total_due'].toString()),
        status: json['status'] as String,
        remaining: json['balance'] != null
            ? double.parse(json['balance']['remaining'].toString())
            : null,
        rejectionReason: json['rejection_reason'] as String?,
      );
}
