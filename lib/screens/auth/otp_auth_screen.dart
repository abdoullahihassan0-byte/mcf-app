import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../../core/session_provider.dart';

enum _Step { phone, code }

class OtpAuthScreen extends ConsumerStatefulWidget {
  const OtpAuthScreen({super.key});

  @override
  ConsumerState<OtpAuthScreen> createState() => _OtpAuthScreenState();
}

class _OtpAuthScreenState extends ConsumerState<OtpAuthScreen> {
  final _phoneController = TextEditingController();
  final _codeController = TextEditingController();
  final _nameController = TextEditingController();

  _Step _step = _Step.phone;
  bool _isNewUser = false;
  bool _loading = false;
  String? _error;

  Future<void> _requestOtp() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final notifier = ref.read(sessionProvider.notifier);
      final isNewUser = await notifier.requestOtp(phoneNumber: _phoneController.text.trim());
      setState(() {
        _isNewUser = isNewUser;
        _step = _Step.code;
      });
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _verifyOtp() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final notifier = ref.read(sessionProvider.notifier);
      await notifier.verifyOtp(
        phoneNumber: _phoneController.text.trim(),
        code: _codeController.text.trim(),
        fullName: _nameController.text.trim().isEmpty ? null : _nameController.text.trim(),
      );
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('MCF')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: _step == _Step.phone ? _buildPhoneStep() : _buildCodeStep(),
        ),
      ),
    );
  }

  List<Widget> _buildPhoneStep() {
    return [
      TextField(
        controller: _phoneController,
        keyboardType: TextInputType.phone,
        decoration: const InputDecoration(
          labelText: 'Numero de telephone',
          hintText: '+235...',
          border: OutlineInputBorder(),
        ),
      ),
      const SizedBox(height: 16),
      if (_error != null)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(_error!, style: const TextStyle(color: Colors.red)),
        ),
      FilledButton(
        onPressed: _loading ? null : _requestOtp,
        child: _loading
            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
            : const Text('Recevoir un code par SMS'),
      ),
    ];
  }

  List<Widget> _buildCodeStep() {
    return [
      Text('Code envoye au ${_phoneController.text}'),
      const SizedBox(height: 16),
      TextField(
        controller: _codeController,
        keyboardType: TextInputType.number,
        maxLength: 6,
        decoration: const InputDecoration(
          labelText: 'Code a 6 chiffres',
          border: OutlineInputBorder(),
        ),
      ),
      if (_isNewUser)
        TextField(
          controller: _nameController,
          decoration: const InputDecoration(
            labelText: 'Nom complet',
            border: OutlineInputBorder(),
          ),
        ),
      const SizedBox(height: 8),
      if (_error != null)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(_error!, style: const TextStyle(color: Colors.red)),
        ),
      FilledButton(
        onPressed: _loading ? null : _verifyOtp,
        child: _loading
            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
            : const Text('Valider'),
      ),
      const SizedBox(height: 8),
      TextButton(
        onPressed: _loading ? null : () => setState(() => _step = _Step.phone),
        child: const Text('Changer de numero'),
      ),
    ];
  }
}
