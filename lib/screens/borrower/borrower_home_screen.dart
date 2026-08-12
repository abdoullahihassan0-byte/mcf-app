import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../../core/session_provider.dart';
import '../../models/loan.dart';
import 'loan_request_screen.dart';
import 'loan_detail_screen.dart';

class BorrowerHomeScreen extends ConsumerStatefulWidget {
  const BorrowerHomeScreen({super.key});

  @override
  ConsumerState<BorrowerHomeScreen> createState() => _BorrowerHomeScreenState();
}

class _BorrowerHomeScreenState extends ConsumerState<BorrowerHomeScreen> {
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
      final list = response.map((e) => Loan.fromJson(e as Map<String, dynamic>)).toList();
      setState(() => _loans = list);
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
        title: const Text('Mes credits'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => ref.read(sessionProvider.notifier).logout(),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _loans.isEmpty
              ? const Center(child: Text('Aucun credit pour le moment'))
              : ListView.builder(
                  itemCount: _loans.length,
                  itemBuilder: (context, index) {
                    final loan = _loans[index];
                    return ListTile(
                      title: Text('${loan.principalAmount.toStringAsFixed(0)} XAF'),
                      subtitle: Text(loan.status),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => LoanDetailScreen(loanId: loan.id)),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('Demander un credit'),
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const LoanRequestScreen()),
        ),
      ),
    );
  }
}
