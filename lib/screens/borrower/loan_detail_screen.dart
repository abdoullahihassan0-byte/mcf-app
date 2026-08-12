import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../../core/session_provider.dart';
import '../../models/loan.dart';

class LoanDetailScreen extends ConsumerStatefulWidget {
  const LoanDetailScreen({super.key, required this.loanId});
  final String loanId;

  @override
  ConsumerState<LoanDetailScreen> createState() => _LoanDetailScreenState();
}

class _LoanDetailScreenState extends ConsumerState<LoanDetailScreen> {
  Loan? _loan;
  bool _loading = true;
  bool _submittingRepayment = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = ref.read(sessionProvider.notifier).apiClient;
      final response = await api.get('/loans/${widget.loanId}');
      setState(() => _loan = Loan.fromJson(response));
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _repay() async {
    final loan = _loan;
    if (loan == null || loan.remaining == null) return;

    setState(() => _submittingRepayment = true);
    try {
      final api = ref.read(sessionProvider.notifier).apiClient;
      await api.post('/repayments', {
        'loanId': loan.id,
        'amount': loan.remaining,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Demande envoyee - valide le paiement sur ton telephone Airtel Money'),
          ),
        );
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _submittingRepayment = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Detail du credit')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : _buildContent(),
    );
  }

  Widget _buildContent() {
    final loan = _loan!;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Statut : ${loan.status}', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text('Montant emprunte : ${loan.principalAmount.toStringAsFixed(0)} XAF'),
          Text('Total du : ${loan.totalDue.toStringAsFixed(0)} XAF'),
          if (loan.remaining != null)
            Text(
              'Restant : ${loan.remaining!.toStringAsFixed(0)} XAF',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          if (loan.status == 'rejected' && loan.rejectionReason != null) ...[
            const SizedBox(height: 8),
            Text(
              'Motif du rejet : ${loan.rejectionReason}',
              style: const TextStyle(color: Colors.red),
            ),
          ],
          const SizedBox(height: 24),
          if (loan.remaining != null && loan.remaining! > 0)
            FilledButton(
              onPressed: _submittingRepayment ? null : _repay,
              child: _submittingRepayment
                  ? const SizedBox(
                      width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Rembourser via Airtel Money'),
            ),
        ],
      ),
    );
  }
}
