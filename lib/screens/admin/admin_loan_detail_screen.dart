import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../../core/session_provider.dart';
import '../../models/loan.dart';

class AdminLoanDetailScreen extends ConsumerStatefulWidget {
  const AdminLoanDetailScreen({super.key, required this.loanId});
  final String loanId;

  @override
  ConsumerState<AdminLoanDetailScreen> createState() => _AdminLoanDetailScreenState();
}

class _AdminLoanDetailScreenState extends ConsumerState<AdminLoanDetailScreen> {
  Loan? _loan;
  bool _loading = true;
  bool _actionInProgress = false;
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

  Future<void> _approve() async {
    await _runAction('/loans/${widget.loanId}/approve', 'Credit approuve');
  }

  Future<void> _disburse() async {
    await _runAction(
      '/loans/${widget.loanId}/disburse',
      'Decaissement initie - en attente de confirmation Airtel Money',
    );
  }

  Future<void> _reject() async {
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => _RejectReasonDialog(),
    );

    if (reason == null) return;

    await _runAction(
      '/loans/${widget.loanId}/reject',
      'Credit rejete',
      body: {'reason': reason},
    );
  }

  Future<void> _runAction(String path, String successMessage, {Map<String, dynamic>? body}) async {
    setState(() => _actionInProgress = true);
    try {
      final api = ref.read(sessionProvider.notifier).apiClient;
      await api.post(path, body ?? {});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(successMessage)));
      }
      await _load();
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _actionInProgress = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Detail du credit (admin)')),
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
          Text('Montant demande : ${loan.principalAmount.toStringAsFixed(0)} XAF'),
          Text('Total du (avec interet) : ${loan.totalDue.toStringAsFixed(0)} XAF'),
          Text('Duree : ${loan.durationDays} jours'),
          if (loan.status == 'rejected' && loan.rejectionReason != null) ...[
            const SizedBox(height: 8),
            Text(
              'Motif du rejet : ${loan.rejectionReason}',
              style: const TextStyle(color: Colors.red),
            ),
          ],
          const SizedBox(height: 24),
          if (loan.status == 'requested') ...[
            FilledButton(
              onPressed: _actionInProgress ? null : _approve,
              child: const Text('Approuver'),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: _actionInProgress ? null : _reject,
              style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Rejeter'),
            ),
          ],
          if (loan.status == 'approved') ...[
            const SizedBox(height: 8),
            FilledButton(
              onPressed: _actionInProgress ? null : _disburse,
              child: const Text('Decaisser via Airtel Money'),
            ),
          ],
          if (_actionInProgress) ...[
            const SizedBox(height: 16),
            const Center(child: CircularProgressIndicator()),
          ],
        ],
      ),
    );
  }
}

class _RejectReasonDialog extends StatefulWidget {
  @override
  State<_RejectReasonDialog> createState() => _RejectReasonDialogState();
}

class _RejectReasonDialogState extends State<_RejectReasonDialog> {
  final _controller = TextEditingController();
  String? _error;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Motif du rejet'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        maxLines: 3,
        decoration: InputDecoration(
          hintText: 'Ex : documents incomplets, score insuffisant...',
          errorText: _error,
          border: const OutlineInputBorder(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Annuler'),
        ),
        FilledButton(
          onPressed: () {
            final text = _controller.text.trim();
            if (text.isEmpty) {
              setState(() => _error = 'Le motif est obligatoire');
              return;
            }
            Navigator.of(context).pop(text);
          },
          child: const Text('Confirmer le rejet'),
        ),
      ],
    );
  }
}
