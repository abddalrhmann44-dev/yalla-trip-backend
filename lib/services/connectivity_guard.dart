import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';

class ConnectivityGuard extends StatefulWidget {
  final Widget child;
  const ConnectivityGuard({super.key, required this.child});

  @override
  State<ConnectivityGuard> createState() => _ConnectivityGuardState();
}

class _ConnectivityGuardState extends State<ConnectivityGuard> {
  StreamSubscription<List<ConnectivityResult>>? _subscription;
  bool _offlineDialogOpen = false;
  bool _wasConnected = true;

  @override
  void initState() {
    super.initState();
    _checkInitialConnection();
    _subscription =
        Connectivity().onConnectivityChanged.listen(_onConnectivityChanged);
  }

  Future<void> _checkInitialConnection() async {
    final connected = await _isConnected();
    _wasConnected = connected;
    if (!connected && mounted) {
      _showNoInternetDialog();
    }
  }

  Future<bool> _isConnected() async {
    try {
      final results = await Connectivity().checkConnectivity();
      if (results.contains(ConnectivityResult.none)) return false;
      final lookup = await InternetAddress.lookup('google.com');
      return lookup.isNotEmpty && lookup.first.rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<void> _onConnectivityChanged(List<ConnectivityResult> results) async {
    final hasTransport = !results.contains(ConnectivityResult.none);
    final connected = hasTransport ? await _isConnected() : false;

    if (!connected) {
      if (!_offlineDialogOpen) _showNoInternetDialog();
      if (_wasConnected && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم فقد الاتصال بالإنترنت'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } else if (_offlineDialogOpen && mounted) {
      Navigator.of(context, rootNavigator: true).maybePop();
      _offlineDialogOpen = false;
    }

    _wasConnected = connected;
  }

  void _showNoInternetDialog() {
    if (!mounted) return;
    _offlineDialogOpen = true;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('لا يوجد اتصال بالإنترنت'),
        content: const Text('يرجى التحقق من اتصال الشبكة للمتابعة.'),
        actions: [
          TextButton(
            onPressed: () async {
              final nav = Navigator.of(context);
              final connected = await _isConnected();
              if (connected && mounted) {
                nav.pop();
                _offlineDialogOpen = false;
              }
            },
            child: const Text('إعادة المحاولة'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
