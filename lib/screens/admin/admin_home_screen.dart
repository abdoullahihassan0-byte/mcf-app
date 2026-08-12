import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../../core/session_provider.dart';
import '../../models/loan.dart';
import 'admin_loan_detail_screen.dart';

class AdminHomeScreen extends ConsumerStatefulWidget {
  const AdminHomeScreen({super.key});

  @override
  ConsumerState<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends ConsumerState<AdminHomeScreen> {
  List<Loan> _loans = [];
  bool _loading = true;
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
      final response = await api.getList('/loans');
      setState(() => _loans = response.map((e) => Loan.fromJson(e as Map<String, dynamic>)).toList());
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('MCF Admin - Tous les credits'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => ref.read(sessionProvider.notifier).logout(),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    itemCount: _loans.length,
                    itemBuilder: (context, index) {
                      final loan = _loans[index];
                      return ListTile(
                        title: Text('${loan.principalAmount.toStringAsFixed(0)} XAF'),
                        subtitle: Text(loan.status),
                        trailing: _statusChip(loan.status),
                        onTap: () async {
                          await Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => AdminLoanDetailScreen(loanId: loan.id),
                            ),
                          );
                          _load();
                        },
                      );
                    },
                  ),
                ),
    );
  }

  Widget _statusChip(String status) {
    final colors = {
      'requested': Colors.orange,
      'approved': Colors.blue,
      'disbursed': Colors.purple,
      'active': Colors.teal,
      'completed': Colors.green,
      'defaulted': Colors.red,
      'rejected': Colors.grey,
    };
    return Chip(
      label: Text(status, style: const TextStyle(fontSize: 11)),
      backgroundColor: (colors[status] ?? Colors.grey).withOpacity(0.15),
    );
  }
}
