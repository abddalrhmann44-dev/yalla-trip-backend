// ═══════════════════════════════════════════════════════════════
//  TALAA — Payment WebView Page
//
//  Hosts the gateway iframe (Paymob / Kashier / Fawry / mock) inside
//  the app instead of bouncing the user out to the system browser.
//
//  The page watches navigation events for the success/fail redirect
//  URLs we registered with the gateway, closes itself with a result,
//  and lets the booking flow take over (status polling, navigation).
//
//  IMPORTANT: trusting the redirect URL alone is NOT enough — it can
//  be spoofed.  The actual source-of-truth for "did the money arrive?"
//  is the gateway's server-to-server webhook, which is verified via
//  HMAC on the backend.  This page simply gives us a snappy UX hint
//  so we can pop into the status screen without a 4-second poll.
// ═══════════════════════════════════════════════════════════════

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../widgets/constants.dart';

const _kOrange = Color(0xFFFF6D00);

/// Outcome of a checkout WebView session.
///
/// We distinguish three cases so the caller can route accordingly:
/// success → status page, failure → retry, cancelled → method picker.
enum PaymentWebViewOutcome { success, failure, cancelled }

/// Hosts the gateway iframe. Pop returns a [PaymentWebViewOutcome].
class PaymentWebViewPage extends StatefulWidget {
  /// Checkout URL handed back by the backend (`/payments/initiate`).
  final String checkoutUrl;

  /// Substring(s) the gateway redirects to on a successful capture.
  /// Defaults cover Paymob's `success=true` query param, Kashier's
  /// `paymentStatus=SUCCESS`, and our mock provider's `mock-success`.
  final List<String> successMatchers;

  /// Substring(s) signalling a failure / declined transaction.
  final List<String> failureMatchers;

  /// Optional title shown in the AppBar; defaults to "إتمام الدفع".
  final String? title;

  const PaymentWebViewPage({
    super.key,
    required this.checkoutUrl,
    this.successMatchers = const [
      'success=true',
      'paymentStatus=SUCCESS',
      'mock-success',
    ],
    this.failureMatchers = const [
      'success=false',
      'paymentStatus=FAILED',
      'mock-failure',
    ],
    this.title,
  });

  @override
  State<PaymentWebViewPage> createState() => _PaymentWebViewPageState();
}

class _PaymentWebViewPageState extends State<PaymentWebViewPage> {
  late final WebViewController _ctrl;
  bool _loading = true;
  // Keep track of whether we already popped so we never accidentally
  // double-close the route (the gateway can fire several redirects in
  // a row while finalising the transaction).
  bool _resolved = false;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _ctrl = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..setNavigationDelegate(NavigationDelegate(
        onPageStarted: (_) {
          if (mounted) setState(() => _loading = true);
        },
        onPageFinished: (_) {
          if (mounted) setState(() => _loading = false);
        },
        onNavigationRequest: _onNavigation,
        onWebResourceError: (err) {
          // Silently ignore noisy iframe sub-resource errors — only
          // a hard navigation failure on the main frame should be
          // surfaced, and that is rare in practice.
          debugPrint('webview error: ${err.description}');
        },
      ))
      ..loadRequest(Uri.parse(widget.checkoutUrl));
  }

  /// Called for every URL the gateway tries to navigate to.  We
  /// intercept the success/failure redirects without actually loading
  /// them — saves a round-trip and avoids the gateway's "thank you"
  /// page flashing on screen.
  NavigationDecision _onNavigation(NavigationRequest req) {
    final url = req.url.toLowerCase();
    if (_matchesAny(url, widget.successMatchers)) {
      _finish(PaymentWebViewOutcome.success);
      return NavigationDecision.prevent;
    }
    if (_matchesAny(url, widget.failureMatchers)) {
      _finish(PaymentWebViewOutcome.failure);
      return NavigationDecision.prevent;
    }
    return NavigationDecision.navigate;
  }

  bool _matchesAny(String url, List<String> needles) {
    for (final n in needles) {
      if (n.isNotEmpty && url.contains(n.toLowerCase())) return true;
    }
    return false;
  }

  void _finish(PaymentWebViewOutcome outcome) {
    if (_resolved) return;
    _resolved = true;
    if (!mounted) return;
    Navigator.of(context).pop(outcome);
  }

  Future<bool> _confirmExit() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('إلغاء الدفع؟'),
        content: const Text(
          'لو خرجت دلوقتى، الدفع لسه مش متأكد. '
          'تقدر ترجع تكمّل أو تجرّب طريقة دفع تانية.',
          style: TextStyle(height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('أكمّل الدفع'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('إلغاء'),
          ),
        ],
      ),
    );
    return ok == true;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await _confirmExit()) {
          _finish(PaymentWebViewOutcome.cancelled);
        }
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.close_rounded, color: context.kText),
            onPressed: () async {
              if (await _confirmExit()) {
                _finish(PaymentWebViewOutcome.cancelled);
              }
            },
          ),
          title: Text(
            widget.title ?? 'إتمام الدفع',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: context.kText,
            ),
          ),
          centerTitle: true,
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(2),
            child: _loading
                ? const LinearProgressIndicator(
                    minHeight: 2,
                    color: _kOrange,
                    backgroundColor: Color(0xFFFFE0B2),
                  )
                : const SizedBox(height: 2),
          ),
        ),
        body: Column(
          children: [
            _trustBanner(),
            Expanded(child: WebViewWidget(controller: _ctrl)),
          ],
        ),
      ),
    );
  }

  Widget _trustBanner() => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        color: const Color(0xFFFFF8E1),
        child: Row(
          children: [
            const Icon(Icons.lock_rounded, size: 14, color: Color(0xFF8D6E00)),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                'صفحة دفع آمنة — بياناتك بتروح للبنك مباشرة، التطبيق مش بيشوفها',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.brown.shade800,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );
}
