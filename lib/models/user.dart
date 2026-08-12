class AppUser {
  AppUser({
    required this.id,
    required this.phoneNumber,
    required this.fullName,
    required this.role,
    required this.kycStatus,
  });

  final String id;
  final String phoneNumber;
  final String fullName;
  final String role; // 'borrower' | 'admin'
  final String kycStatus; // 'pending' | 'verified' | 'rejected'

  bool get isAdmin => role == 'admin';

  factory AppUser.fromJson(Map<String, dynamic> json) => AppUser(
        id: json['id'] as String,
        phoneNumber: json['phone_number'] as String,
        fullName: json['full_name'] as String,
        role: json['role'] as String,
        kycStatus: json['kyc_status'] as String,
      );
}
